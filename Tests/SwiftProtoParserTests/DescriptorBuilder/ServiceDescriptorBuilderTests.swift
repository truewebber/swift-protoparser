import XCTest
import SwiftProtobuf
@testable import SwiftProtoParser

final class ServiceDescriptorBuilderTests: XCTestCase {
  
  // MARK: - Basic Service Building Tests
  
  func testBuildBasicService() throws {
    // Given: Simple service with basic methods
    let serviceNode = ServiceNode(
      name: "UserService",
      methods: [
        RPCMethodNode(
          name: "GetUser",
          inputType: "GetUserRequest",
          outputType: "GetUserResponse"
        ),
        RPCMethodNode(
          name: "ListUsers",
          inputType: "ListUsersRequest",
          outputType: "ListUsersResponse"
        )
      ]
    )
    
    // When: Building descriptor
    let serviceProto = try ServiceDescriptorBuilder.build(from: serviceNode)
    
    // Then: Basic properties are set correctly
    XCTAssertEqual(serviceProto.name, "UserService")
    XCTAssertEqual(serviceProto.method.count, 2)
    
    // Verify methods
    XCTAssertEqual(serviceProto.method[0].name, "GetUser")
    XCTAssertEqual(serviceProto.method[0].inputType, "GetUserRequest")
    XCTAssertEqual(serviceProto.method[0].outputType, "GetUserResponse")
    XCTAssertFalse(serviceProto.method[0].clientStreaming)
    XCTAssertFalse(serviceProto.method[0].serverStreaming)
    
    XCTAssertEqual(serviceProto.method[1].name, "ListUsers")
    XCTAssertEqual(serviceProto.method[1].inputType, "ListUsersRequest")
    XCTAssertEqual(serviceProto.method[1].outputType, "ListUsersResponse")
    XCTAssertFalse(serviceProto.method[1].clientStreaming)
    XCTAssertFalse(serviceProto.method[1].serverStreaming)
  }
  
  func testBuildEmptyService() throws {
    // Given: Empty service (no methods)
    let serviceNode = ServiceNode(name: "EmptyService", methods: [])
    
    // When: Building descriptor
    let serviceProto = try ServiceDescriptorBuilder.build(from: serviceNode)
    
    // Then: Service is created without methods
    XCTAssertEqual(serviceProto.name, "EmptyService")
    XCTAssertEqual(serviceProto.method.count, 0)
    XCTAssertFalse(serviceProto.hasOptions)
  }
  
  // MARK: - Streaming Tests
  
  func testBuildServiceWithStreamingMethods() throws {
    // Given: Service with different streaming types
    let serviceNode = ServiceNode(
      name: "StreamingService",
      methods: [
        // Unary
        RPCMethodNode(
          name: "Unary",
          inputType: "Request",
          outputType: "Response",
          inputStreaming: false,
          outputStreaming: false
        ),
        // Server streaming
        RPCMethodNode(
          name: "ServerStream",
          inputType: "Request",
          outputType: "Response",
          inputStreaming: false,
          outputStreaming: true
        ),
        // Client streaming
        RPCMethodNode(
          name: "ClientStream",
          inputType: "Request",
          outputType: "Response",
          inputStreaming: true,
          outputStreaming: false
        ),
        // Bidirectional streaming
        RPCMethodNode(
          name: "BidirectionalStream",
          inputType: "Request",
          outputType: "Response",
          inputStreaming: true,
          outputStreaming: true
        )
      ]
    )
    
    // When: Building descriptor
    let serviceProto = try ServiceDescriptorBuilder.build(from: serviceNode)
    
    // Then: Streaming flags are set correctly
    XCTAssertEqual(serviceProto.method.count, 4)
    
    // Unary
    XCTAssertFalse(serviceProto.method[0].clientStreaming)
    XCTAssertFalse(serviceProto.method[0].serverStreaming)
    
    // Server streaming
    XCTAssertFalse(serviceProto.method[1].clientStreaming)
    XCTAssertTrue(serviceProto.method[1].serverStreaming)
    
    // Client streaming
    XCTAssertTrue(serviceProto.method[2].clientStreaming)
    XCTAssertFalse(serviceProto.method[2].serverStreaming)
    
    // Bidirectional streaming
    XCTAssertTrue(serviceProto.method[3].clientStreaming)
    XCTAssertTrue(serviceProto.method[3].serverStreaming)
  }
  
  // MARK: - Service Options Tests
  
  func testBuildServiceWithBasicOptions() throws {
    // Given: Service with basic options
    let serviceNode = ServiceNode(
      name: "DeprecatedService",
      methods: [
        RPCMethodNode(name: "Method", inputType: "Request", outputType: "Response")
      ],
      options: [
        OptionNode(name: "deprecated", value: .boolean(true))
      ]
    )
    
    // When: Building descriptor
    let serviceProto = try ServiceDescriptorBuilder.build(from: serviceNode)
    
    // Then: Options are set correctly
    XCTAssertTrue(serviceProto.hasOptions)
    XCTAssertTrue(serviceProto.options.deprecated)
  }
  
  func testBuildServiceWithCustomOptions() throws {
    // Given: Service with custom options
    let serviceNode = ServiceNode(
      name: "CustomService",
      methods: [
        RPCMethodNode(name: "Method", inputType: "Request", outputType: "Response")
      ],
      options: [
        OptionNode(name: "deprecated", value: .boolean(false)),
        OptionNode(name: "custom_service_option", value: .string("custom_value"))
      ]
    )
    
    // When: Building descriptor
    let serviceProto = try ServiceDescriptorBuilder.build(from: serviceNode)
    
    // Then: Standard options processed, custom options ignored
    XCTAssertTrue(serviceProto.hasOptions)
    XCTAssertFalse(serviceProto.options.deprecated)
  }
  
  // MARK: - Method Options Tests
  
  func testBuildServiceWithMethodOptions() throws {
    // Given: Service with method-specific options
    let serviceNode = ServiceNode(
      name: "ServiceWithMethodOptions",
      methods: [
        RPCMethodNode(
          name: "NormalMethod",
          inputType: "Request",
          outputType: "Response"
        ),
        RPCMethodNode(
          name: "DeprecatedMethod",
          inputType: "Request",
          outputType: "Response",
          options: [OptionNode(name: "deprecated", value: .boolean(true))]
        ),
        RPCMethodNode(
          name: "IdempotentMethod",
          inputType: "Request",
          outputType: "Response",
          options: [OptionNode(name: "idempotency_level", value: .identifier("NO_SIDE_EFFECTS"))]
        )
      ]
    )
    
    // When: Building descriptor
    let serviceProto = try ServiceDescriptorBuilder.build(from: serviceNode)
    
    // Then: Method options are set correctly
    XCTAssertEqual(serviceProto.method.count, 3)
    
    // First method has no options
    XCTAssertFalse(serviceProto.method[0].hasOptions)
    
    // Second method is deprecated
    XCTAssertTrue(serviceProto.method[1].hasOptions)
    XCTAssertTrue(serviceProto.method[1].options.deprecated)
    
    // Third method has idempotency level
    XCTAssertTrue(serviceProto.method[2].hasOptions)
    XCTAssertEqual(serviceProto.method[2].options.idempotencyLevel, .noSideEffects)
  }
  
  func testBuildMethodWithAllIdempotencyLevels() throws {
    // Given: Methods with different idempotency levels
    let serviceNode = ServiceNode(
      name: "IdempotencyService",
      methods: [
        RPCMethodNode(
          name: "NoSideEffects",
          inputType: "Request",
          outputType: "Response",
          options: [OptionNode(name: "idempotency_level", value: .identifier("NO_SIDE_EFFECTS"))]
        ),
        RPCMethodNode(
          name: "Idempotent",
          inputType: "Request",
          outputType: "Response",
          options: [OptionNode(name: "idempotency_level", value: .identifier("IDEMPOTENT"))]
        ),
        RPCMethodNode(
          name: "Unknown",
          inputType: "Request",
          outputType: "Response",
          options: [OptionNode(name: "idempotency_level", value: .identifier("INVALID_LEVEL"))]
        )
      ]
    )
    
    // When: Building descriptor
    let serviceProto = try ServiceDescriptorBuilder.build(from: serviceNode)
    
    // Then: Idempotency levels are set correctly
    XCTAssertEqual(serviceProto.method.count, 3)
    
    XCTAssertEqual(serviceProto.method[0].options.idempotencyLevel, .noSideEffects)
    XCTAssertEqual(serviceProto.method[1].options.idempotencyLevel, .idempotent)
    XCTAssertEqual(serviceProto.method[2].options.idempotencyLevel, .idempotencyUnknown) // fallback
  }
  
  func testBuildMethodWithCustomOptions() throws {
    // Given: Method with custom options
    let serviceNode = ServiceNode(
      name: "CustomMethodService",
      methods: [
        RPCMethodNode(
          name: "CustomMethod",
          inputType: "Request",
          outputType: "Response",
          options: [
            OptionNode(name: "deprecated", value: .boolean(true)),
            OptionNode(name: "custom_method_option", value: .number(42))
          ]
        )
      ]
    )
    
    // When: Building descriptor
    let serviceProto = try ServiceDescriptorBuilder.build(from: serviceNode)
    
    // Then: Standard options processed, custom ignored
    XCTAssertEqual(serviceProto.method.count, 1)
    XCTAssertTrue(serviceProto.method[0].hasOptions)
    XCTAssertTrue(serviceProto.method[0].options.deprecated)
  }
  
  // MARK: - Complex Scenarios Tests
  
  func testBuildComplexService() throws {
    // Given: Complex service with multiple features
    let serviceNode = ServiceNode(
      name: "ComplexService",
      methods: [
        RPCMethodNode(
          name: "SimpleMethod",
          inputType: "SimpleRequest",
          outputType: "SimpleResponse"
        ),
        RPCMethodNode(
          name: "StreamingMethod",
          inputType: "StreamRequest",
          outputType: "StreamResponse",
          inputStreaming: true,
          outputStreaming: true,
          options: [
            OptionNode(name: "deprecated", value: .boolean(true)),
            OptionNode(name: "idempotency_level", value: .identifier("IDEMPOTENT"))
          ]
        ),
        RPCMethodNode(
          name: "ServerStreamMethod",
          inputType: "Request",
          outputType: "Response",
          inputStreaming: false,
          outputStreaming: true,
          options: [OptionNode(name: "deprecated", value: .boolean(false))]
        )
      ],
      options: [
        OptionNode(name: "deprecated", value: .boolean(false))
      ]
    )
    
    // When: Building descriptor
    let serviceProto = try ServiceDescriptorBuilder.build(from: serviceNode)
    
    // Then: All features work together
    XCTAssertEqual(serviceProto.name, "ComplexService")
    XCTAssertEqual(serviceProto.method.count, 3)
    
    // Check service options
    XCTAssertTrue(serviceProto.hasOptions)
    XCTAssertFalse(serviceProto.options.deprecated)
    
    // Check method 1 (simple)
    XCTAssertEqual(serviceProto.method[0].name, "SimpleMethod")
    XCTAssertFalse(serviceProto.method[0].clientStreaming)
    XCTAssertFalse(serviceProto.method[0].serverStreaming)
    XCTAssertFalse(serviceProto.method[0].hasOptions)
    
    // Check method 2 (bidirectional streaming with options)
    XCTAssertEqual(serviceProto.method[1].name, "StreamingMethod")
    XCTAssertTrue(serviceProto.method[1].clientStreaming)
    XCTAssertTrue(serviceProto.method[1].serverStreaming)
    XCTAssertTrue(serviceProto.method[1].hasOptions)
    XCTAssertTrue(serviceProto.method[1].options.deprecated)
    XCTAssertEqual(serviceProto.method[1].options.idempotencyLevel, .idempotent)
    
    // Check method 3 (server streaming)
    XCTAssertEqual(serviceProto.method[2].name, "ServerStreamMethod")
    XCTAssertFalse(serviceProto.method[2].clientStreaming)
    XCTAssertTrue(serviceProto.method[2].serverStreaming)
    XCTAssertTrue(serviceProto.method[2].hasOptions)
    XCTAssertFalse(serviceProto.method[2].options.deprecated)
  }
  
  // MARK: - Edge Cases Tests
  
  func testBuildServiceWithSpecialCharactersInNames() throws {
    // Given: Service with special characters in names
    let serviceNode = ServiceNode(
      name: "Special_Service",
      methods: [
        RPCMethodNode(
          name: "Method_With_Underscores",
          inputType: "Request_Type",
          outputType: "Response_Type"
        ),
        RPCMethodNode(
          name: "Method123",
          inputType: "RequestType123",
          outputType: "ResponseType456"
        )
      ]
    )
    
    // When: Building descriptor
    let serviceProto = try ServiceDescriptorBuilder.build(from: serviceNode)
    
    // Then: Special characters are preserved
    XCTAssertEqual(serviceProto.name, "Special_Service")
    XCTAssertEqual(serviceProto.method[0].name, "Method_With_Underscores")
    XCTAssertEqual(serviceProto.method[0].inputType, "Request_Type")
    XCTAssertEqual(serviceProto.method[0].outputType, "Response_Type")
    XCTAssertEqual(serviceProto.method[1].name, "Method123")
    XCTAssertEqual(serviceProto.method[1].inputType, "RequestType123")
    XCTAssertEqual(serviceProto.method[1].outputType, "ResponseType456")
  }
  
  func testBuildServiceWithLongNames() throws {
    // Given: Service with very long names
    let longServiceName = String(repeating: "A", count: 100)
    let longMethodName = String(repeating: "B", count: 100)
    let longTypeName = String(repeating: "C", count: 100)
    
    let serviceNode = ServiceNode(
      name: longServiceName,
      methods: [
        RPCMethodNode(
          name: longMethodName,
          inputType: longTypeName + "Request",
          outputType: longTypeName + "Response"
        )
      ]
    )
    
    // When: Building descriptor
    let serviceProto = try ServiceDescriptorBuilder.build(from: serviceNode)
    
    // Then: Long names are handled correctly
    XCTAssertEqual(serviceProto.name, longServiceName)
    XCTAssertEqual(serviceProto.method[0].name, longMethodName)
    XCTAssertEqual(serviceProto.method[0].inputType, longTypeName + "Request")
    XCTAssertEqual(serviceProto.method[0].outputType, longTypeName + "Response")
  }
  
  // MARK: - Error Handling Tests
  
  func testBuildServiceWithInvalidOptionValue() throws {
    // Given: Service with invalid option value type
    let serviceNode = ServiceNode(
      name: "InvalidOptionService",
      methods: [
        RPCMethodNode(name: "Method", inputType: "Request", outputType: "Response")
      ],
      options: [
        OptionNode(name: "deprecated", value: .string("not_boolean"))
      ]
    )
    
    // When: Building descriptor (should not throw, just ignore invalid options)
    let serviceProto = try ServiceDescriptorBuilder.build(from: serviceNode)
    
    // Then: Invalid options are ignored, defaults used
    XCTAssertTrue(serviceProto.hasOptions)
    XCTAssertFalse(serviceProto.options.deprecated) // default value
  }
  
  func testBuildMethodWithInvalidOptionValue() throws {
    // Given: Method with invalid option value type
    let serviceNode = ServiceNode(
      name: "InvalidMethodOptionService",
      methods: [
        RPCMethodNode(
          name: "InvalidMethod",
          inputType: "Request",
          outputType: "Response",
          options: [
            OptionNode(name: "deprecated", value: .number(123)),
            OptionNode(name: "idempotency_level", value: .boolean(true))
          ]
        )
      ]
    )
    
    // When: Building descriptor (should not throw)
    let serviceProto = try ServiceDescriptorBuilder.build(from: serviceNode)
    
    // Then: Invalid options are ignored
    XCTAssertEqual(serviceProto.method.count, 1)
    XCTAssertTrue(serviceProto.method[0].hasOptions)
    XCTAssertFalse(serviceProto.method[0].options.deprecated) // default value
    XCTAssertEqual(serviceProto.method[0].options.idempotencyLevel, .idempotencyUnknown) // default
  }
  
  func testBuildServiceWithDuplicateMethodNames() throws {
    // Given: Service with duplicate method names (valid in protobuf)
    let serviceNode = ServiceNode(
      name: "DuplicateMethodService",
      methods: [
        RPCMethodNode(
          name: "SameMethod",
          inputType: "Request1",
          outputType: "Response1"
        ),
        RPCMethodNode(
          name: "SameMethod",
          inputType: "Request2",
          outputType: "Response2"
        )
      ]
    )
    
    // When: Building descriptor
    let serviceProto = try ServiceDescriptorBuilder.build(from: serviceNode)
    
    // Then: Both methods are included (protobuf allows this)
    XCTAssertEqual(serviceProto.method.count, 2)
    XCTAssertEqual(serviceProto.method[0].name, "SameMethod")
    XCTAssertEqual(serviceProto.method[1].name, "SameMethod")
    XCTAssertEqual(serviceProto.method[0].inputType, "Request1")
    XCTAssertEqual(serviceProto.method[1].inputType, "Request2")
  }
}
