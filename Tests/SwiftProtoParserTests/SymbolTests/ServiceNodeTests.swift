import XCTest

@testable import SwiftProtoParser

/// Test suite for ServiceNode.
///
/// This test suite verifies the functionality of the ServiceNode component
/// according to the acceptance criteria defined in ACCEPTANCE_CRITERIA.md.
///
/// Acceptance Criteria:.
/// - Parse service definitions.
/// - Parse RPC method definitions.
/// - Parse streaming options.
/// - Validate service and method names.
/// - Validate input and output types.
final class ServiceNodeTests: XCTestCase {

  // MARK: - Basic Service Tests

  /// Test creating and validating a basic service.
  ///
  /// This test verifies that a basic service can be created and validated.
  func testBasicService() throws {
    // Create a basic service
    let serviceNode = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      name: "UserService",
      rpcs: [],
      options: []
    )

    // Verify properties
    XCTAssertEqual(serviceNode.name, "UserService", "Service name should match")
    XCTAssertEqual(serviceNode.rpcs.count, 0, "Service should have no RPCs initially")
    XCTAssertEqual(serviceNode.options.count, 0, "Service should have no options initially")
    XCTAssertEqual(serviceNode.location.line, 1, "Service location line should match")
    XCTAssertEqual(serviceNode.location.column, 1, "Service location column should match")
  }

  /// Test creating a service with RPC methods.
  ///
  /// This test verifies that a service with RPC methods can be created and validated.
  func testServiceWithRPCs() throws {
    // Create RPC methods
    let getUser = RPCNode(
      location: SourceLocation(line: 2, column: 3),
      name: "GetUser",
      inputType: "GetUserRequest",
      outputType: "GetUserResponse"
    )

    let createUser = RPCNode(
      location: SourceLocation(line: 3, column: 3),
      name: "CreateUser",
      inputType: "CreateUserRequest",
      outputType: "CreateUserResponse"
    )

    // Create a service with RPCs
    let serviceNode = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      name: "UserService",
      rpcs: [getUser, createUser],
      options: []
    )

    // Verify properties
    XCTAssertEqual(serviceNode.name, "UserService", "Service name should match")
    XCTAssertEqual(serviceNode.rpcs.count, 2, "Service should have 2 RPCs")
    XCTAssertEqual(serviceNode.rpcs[0].name, "GetUser", "First RPC name should match")
    XCTAssertEqual(serviceNode.rpcs[1].name, "CreateUser", "Second RPC name should match")

    // Verify method names set
    let methodNames = serviceNode.methodNames
    XCTAssertEqual(methodNames.count, 2, "Service should have 2 method names")
    XCTAssertTrue(methodNames.contains("GetUser"), "Method names should contain GetUser")
    XCTAssertTrue(methodNames.contains("CreateUser"), "Method names should contain CreateUser")
  }

  /// Test creating a service with streaming RPCs.
  ///
  /// This test verifies that a service with streaming RPC methods can be created and validated.
  func testServiceWithStreamingRPCs() throws {
    // Create streaming RPC methods
    let streamUsers = RPCNode(
      location: SourceLocation(line: 2, column: 3),
      name: "StreamUsers",
      inputType: "StreamUsersRequest",
      outputType: "User",
      clientStreaming: false,
      serverStreaming: true
    )

    let uploadUsers = RPCNode(
      location: SourceLocation(line: 3, column: 3),
      name: "UploadUsers",
      inputType: "User",
      outputType: "UploadUsersResponse",
      clientStreaming: true,
      serverStreaming: false
    )

    let chatService = RPCNode(
      location: SourceLocation(line: 4, column: 3),
      name: "Chat",
      inputType: "ChatMessage",
      outputType: "ChatMessage",
      clientStreaming: true,
      serverStreaming: true
    )

    // Create a service with streaming RPCs
    let serviceNode = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      name: "StreamingService",
      rpcs: [streamUsers, uploadUsers, chatService],
      options: []
    )

    // Verify properties
    XCTAssertEqual(serviceNode.rpcs.count, 3, "Service should have 3 RPCs")

    // Verify streaming properties
    XCTAssertFalse(
      serviceNode.rpcs[0].clientStreaming,
      "StreamUsers should not have client streaming"
    )
    XCTAssertTrue(serviceNode.rpcs[0].serverStreaming, "StreamUsers should have server streaming")

    XCTAssertTrue(serviceNode.rpcs[1].clientStreaming, "UploadUsers should have client streaming")
    XCTAssertFalse(
      serviceNode.rpcs[1].serverStreaming,
      "UploadUsers should not have server streaming"
    )

    XCTAssertTrue(serviceNode.rpcs[2].clientStreaming, "Chat should have client streaming")
    XCTAssertTrue(serviceNode.rpcs[2].serverStreaming, "Chat should have server streaming")

    // Test streamingRPCs method
    let streamingRPCs = serviceNode.streamingRPCs()
    XCTAssertEqual(streamingRPCs.count, 3, "All RPCs should be streaming")
    XCTAssertTrue(
      streamingRPCs.contains { $0.name == "StreamUsers" },
      "StreamUsers should be in streaming RPCs"
    )
    XCTAssertTrue(
      streamingRPCs.contains { $0.name == "UploadUsers" },
      "UploadUsers should be in streaming RPCs"
    )
    XCTAssertTrue(streamingRPCs.contains { $0.name == "Chat" }, "Chat should be in streaming RPCs")
  }

  /// Test creating a service with options.
  ///
  /// This test verifies that a service with options can be created and validated.
  func testServiceWithOptions() throws {
    // Create options
    let deprecatedOption = OptionNode(
      location: SourceLocation(line: 2, column: 3),
      name: "deprecated",
      value: .identifier("true"),
      pathParts: []
    )

    let customOption = OptionNode(
      location: SourceLocation(line: 3, column: 3),
      name: "custom_option",
      value: .string("value"),
      pathParts: []
    )

    // Create a service with options
    let serviceNode = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      name: "UserService",
      rpcs: [],
      options: [deprecatedOption, customOption]
    )

    // Verify properties
    XCTAssertEqual(serviceNode.options.count, 2, "Service should have 2 options")
    XCTAssertEqual(serviceNode.options[0].name, "deprecated", "First option name should match")
    XCTAssertEqual(serviceNode.options[1].name, "custom_option", "Second option name should match")

    // Verify option values
    if case .identifier(let value) = serviceNode.options[0].value {
      XCTAssertEqual(value, "true", "Deprecated option value should be true")
    }
    else {
      XCTFail("Expected identifier value")
    }

    if case .string(let value) = serviceNode.options[1].value {
      XCTAssertEqual(value, "value", "Custom option value should match")
    }
    else {
      XCTFail("Expected string value")
    }
  }

  /// Test creating an RPC with options.
  ///
  /// This test verifies that an RPC with options can be created and validated.
  func testRPCWithOptions() throws {
    // Create options
    let deprecatedOption = OptionNode(
      location: SourceLocation(line: 3, column: 5),
      name: "deprecated",
      value: .identifier("true"),
      pathParts: []
    )

    let timeoutOption = OptionNode(
      location: SourceLocation(line: 4, column: 5),
      name: "timeout",
      value: .number(30.5),
      pathParts: []
    )

    // Create an RPC with options
    let rpcNode = RPCNode(
      location: SourceLocation(line: 2, column: 3),
      name: "GetUser",
      inputType: "GetUserRequest",
      outputType: "GetUserResponse",
      options: [deprecatedOption, timeoutOption]
    )

    // Create a service with the RPC
    let serviceNode = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      name: "UserService",
      rpcs: [rpcNode],
      options: []
    )

    // Verify properties
    XCTAssertEqual(serviceNode.rpcs.count, 1, "Service should have 1 RPC")
    XCTAssertEqual(serviceNode.rpcs[0].options.count, 2, "RPC should have 2 options")
    XCTAssertEqual(
      serviceNode.rpcs[0].options[0].name,
      "deprecated",
      "First option name should match"
    )
    XCTAssertEqual(
      serviceNode.rpcs[0].options[1].name,
      "timeout",
      "Second option name should match"
    )

    // Verify option values
    if case .identifier(let value) = serviceNode.rpcs[0].options[0].value {
      XCTAssertEqual(value, "true", "Deprecated option value should be true")
    }
    else {
      XCTFail("Expected identifier value")
    }

    if case .number(let value) = serviceNode.rpcs[0].options[1].value {
      XCTAssertEqual(value, 30.5, "Timeout option value should match")
    }
    else {
      XCTFail("Expected number value")
    }
  }

  // MARK: - RPC Management Tests

  /// Test finding an RPC by name.
  ///
  /// This test verifies that an RPC can be found by name.
  func testFindRPCByName() throws {
    // Create RPC methods
    let getUser = RPCNode(
      location: SourceLocation(line: 2, column: 3),
      name: "GetUser",
      inputType: "GetUserRequest",
      outputType: "GetUserResponse"
    )

    let createUser = RPCNode(
      location: SourceLocation(line: 3, column: 3),
      name: "CreateUser",
      inputType: "CreateUserRequest",
      outputType: "CreateUserResponse"
    )

    // Create a service with RPCs
    let serviceNode = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      name: "UserService",
      rpcs: [getUser, createUser],
      options: []
    )

    // Test finding RPCs
    let foundRPC = serviceNode.findRPC(named: "GetUser")
    XCTAssertNotNil(foundRPC, "Should find the RPC")
    XCTAssertEqual(foundRPC?.name, "GetUser", "Found RPC name should match")

    let notFoundRPC = serviceNode.findRPC(named: "NonExistentRPC")
    XCTAssertNil(notFoundRPC, "Should not find a non-existent RPC")
  }

  /// Test message references in RPCs.
  ///
  /// This test verifies that message references in RPCs are correctly tracked.
  func testMessageReferences() throws {
    // Create RPC methods
    let getUser = RPCNode(
      location: SourceLocation(line: 2, column: 3),
      name: "GetUser",
      inputType: "GetUserRequest",
      outputType: "GetUserResponse"
    )

    let createUser = RPCNode(
      location: SourceLocation(line: 3, column: 3),
      name: "CreateUser",
      inputType: "CreateUserRequest",
      outputType: "GetUserResponse"  // Intentionally reusing the same output type
    )

    // Create a service with RPCs
    let serviceNode = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      name: "UserService",
      rpcs: [getUser, createUser],
      options: []
    )

    // Test message references
    let references = serviceNode.messageReferences
    XCTAssertEqual(references.count, 3, "Should have 3 unique message references")
    XCTAssertTrue(references.contains("GetUserRequest"), "Should contain GetUserRequest")
    XCTAssertTrue(references.contains("GetUserResponse"), "Should contain GetUserResponse")
    XCTAssertTrue(references.contains("CreateUserRequest"), "Should contain CreateUserRequest")
  }

  // MARK: - Validation Tests

  /// Test validation of valid service.
  ///
  /// This test verifies that validation passes for a valid service.
  func testValidServiceValidation() throws {
    // Create a valid RPC
    let getUser = RPCNode(
      location: SourceLocation(line: 2, column: 3),
      name: "GetUser",
      inputType: "GetUserRequest",
      outputType: "GetUserResponse"
    )

    // Create a valid service
    let serviceNode = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      name: "UserService",
      rpcs: [getUser],
      options: []
    )

    // Validation should not throw
    XCTAssertNoThrow(try serviceNode.validate(), "Valid service should pass validation")
  }

  /// Test validation of service name.
  ///
  /// This test verifies that validation fails for a service with an invalid name.
  func testInvalidServiceNameValidation() throws {
    // Create services with invalid names
    let invalidNames = ["lowercase", "123Service", "Service-Name", ""]

    for invalidName in invalidNames {
      let serviceNode = ServiceNode(
        location: SourceLocation(line: 1, column: 1),
        name: invalidName,
        rpcs: [
          RPCNode(
            location: SourceLocation(line: 2, column: 3),
            name: "GetUser",
            inputType: "GetUserRequest",
            outputType: "GetUserResponse"
          )
        ],
        options: []
      )

      // Validation should throw
      XCTAssertThrowsError(try serviceNode.validate()) { error in
        guard let parserError = error as? ParserError else {
          XCTFail("Expected ParserError")
          return
        }

        if case .invalidServiceName(let name) = parserError {
          XCTAssertEqual(name, invalidName, "Error should contain the invalid name")
        }
        else {
          XCTFail("Expected invalidServiceName error")
        }
      }
    }
  }

  /// Test validation of empty service.
  ///
  /// This test verifies that a service with no RPCs fails validation.
  func testEmptyServiceValidation() throws {
    // Create an empty service
    let serviceNode = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      name: "UserService",
      rpcs: [],
      options: []
    )

    // Validation should throw
    XCTAssertThrowsError(try serviceNode.validate()) { error in
      guard let parserError = error as? ParserError else {
        XCTFail("Expected ParserError")
        return
      }

      if case .custom(let message) = parserError {
        XCTAssertTrue(message.contains("UserService"), "Error should mention the service name")
        XCTAssertTrue(
          message.contains("at least one RPC"),
          "Error should mention the need for RPCs"
        )
      }
      else {
        XCTFail("Expected custom error for empty service")
      }
    }
  }

  /// Test validation of RPC name.
  ///
  /// This test verifies that validation fails for an RPC with an invalid name.
  func testInvalidRPCNameValidation() throws {
    // Create invalid RPC names
    let invalidNames = ["lowercase", "123Method", "Method-Name", ""]

    for invalidName in invalidNames {
      let serviceNode = ServiceNode(
        location: SourceLocation(line: 1, column: 1),
        name: "UserService",
        rpcs: [
          RPCNode(
            location: SourceLocation(line: 2, column: 3),
            name: invalidName,
            inputType: "GetUserRequest",
            outputType: "GetUserResponse"
          )
        ],
        options: []
      )

      // Validation should throw
      XCTAssertThrowsError(try serviceNode.validate()) { error in
        guard let parserError = error as? ParserError else {
          XCTFail("Expected ParserError")
          return
        }

        if case .invalidRPCName(let name) = parserError {
          XCTAssertEqual(name, invalidName, "Error should contain the invalid name")
        }
        else {
          XCTFail("Expected invalidRPCName error")
        }
      }
    }
  }

  /// Test validation of duplicate RPC names.
  ///
  /// This test verifies that validation fails for a service with duplicate RPC names.
  func testDuplicateRPCNameValidation() throws {
    // Create RPCs with duplicate names
    let serviceNode = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      name: "UserService",
      rpcs: [
        RPCNode(
          location: SourceLocation(line: 2, column: 3),
          name: "GetUser",
          inputType: "GetUserRequest",
          outputType: "GetUserResponse"
        ),
        RPCNode(
          location: SourceLocation(line: 3, column: 3),
          name: "GetUser",  // Duplicate name
          inputType: "GetUserRequest2",
          outputType: "GetUserResponse2"
        ),
      ],
      options: []
    )

    // Validation should throw
    XCTAssertThrowsError(try serviceNode.validate()) { error in
      guard let parserError = error as? ParserError else {
        XCTFail("Expected ParserError")
        return
      }

      if case .custom(let message) = parserError {
        XCTAssertTrue(
          message.contains("Duplicate RPC method name"),
          "Error should mention duplicate name"
        )
        XCTAssertTrue(message.contains("GetUser"), "Error should mention the duplicate name")
      }
      else {
        XCTFail("Expected custom error for duplicate RPC name")
      }
    }
  }

  /// Test validation of message types.
  ///
  /// This test verifies that validation fails for an RPC with invalid message types.
  func testInvalidMessageTypeValidation() throws {
    // Create RPCs with invalid message types
    let invalidInputType = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      name: "UserService",
      rpcs: [
        RPCNode(
          location: SourceLocation(line: 2, column: 3),
          name: "GetUser",
          inputType: "",  // Invalid input type
          outputType: "GetUserResponse"
        )
      ],
      options: []
    )

    // Validation should throw for invalid input type
    XCTAssertThrowsError(try invalidInputType.validate()) { error in
      guard let parserError = error as? ParserError else {
        XCTFail("Expected ParserError")
        return
      }

      if case .custom(let message) = parserError {
        XCTAssertTrue(message.contains("Invalid message type"), "Error should mention invalid type")
      }
      else {
        XCTFail("Expected custom error for invalid message type")
      }
    }

    // Create RPCs with invalid output types
    let invalidOutputType = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      name: "UserService",
      rpcs: [
        RPCNode(
          location: SourceLocation(line: 2, column: 3),
          name: "GetUser",
          inputType: "GetUserRequest",
          outputType: ""  // Invalid output type
        )
      ],
      options: []
    )

    // Validation should throw for invalid output type
    XCTAssertThrowsError(try invalidOutputType.validate()) { error in
      guard let parserError = error as? ParserError else {
        XCTFail("Expected ParserError")
        return
      }

      if case .custom(let message) = parserError {
        XCTAssertTrue(message.contains("Invalid message type"), "Error should mention invalid type")
      }
      else {
        XCTFail("Expected custom error for invalid message type")
      }
    }
  }

  /// Test validation of RPC options.
  ///
  /// This test verifies that validation fails for an RPC with invalid options.
  func testRPCOptionValidation() throws {
    // Create an RPC with a valid timeout option
    let validTimeoutOption = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      name: "UserService",
      rpcs: [
        RPCNode(
          location: SourceLocation(line: 2, column: 3),
          name: "GetUser",
          inputType: "GetUserRequest",
          outputType: "GetUserResponse",
          options: [
            OptionNode(
              location: SourceLocation(line: 3, column: 5),
              name: "timeout",
              value: .string("30s"),
              pathParts: []
            )
          ]
        )
      ],
      options: []
    )

    // Validation should not throw for valid timeout
    XCTAssertNoThrow(
      try validTimeoutOption.validate(),
      "Valid timeout option should pass validation"
    )

    // Create an RPC with an invalid timeout option (missing unit)
    let invalidTimeoutOption = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      name: "UserService",
      rpcs: [
        RPCNode(
          location: SourceLocation(line: 2, column: 3),
          name: "GetUser",
          inputType: "GetUserRequest",
          outputType: "GetUserResponse",
          options: [
            OptionNode(
              location: SourceLocation(line: 3, column: 5),
              name: "timeout",
              value: .string("30"),  // Missing unit
              pathParts: []
            )
          ]
        )
      ],
      options: []
    )

    // Validation should throw for invalid timeout
    XCTAssertThrowsError(try invalidTimeoutOption.validate()) { error in
      guard let parserError = error as? ParserError else {
        XCTFail("Expected ParserError")
        return
      }

      if case .custom(let message) = parserError {
        XCTAssertTrue(message.contains("Invalid RPC option"), "Error should mention invalid option")
        XCTAssertTrue(message.contains("timeout"), "Error should mention the option name")
      }
      else {
        XCTFail("Expected custom error for invalid RPC option")
      }
    }
  }

  /// Test validation of service options.
  ///
  /// This test verifies that validation fails for a service with invalid options.
  func testServiceOptionValidation() throws {
    // Create a service with a valid deprecated option
    let validDeprecatedOption = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      name: "UserService",
      rpcs: [
        RPCNode(
          location: SourceLocation(line: 2, column: 3),
          name: "GetUser",
          inputType: "GetUserRequest",
          outputType: "GetUserResponse"
        )
      ],
      options: [
        OptionNode(
          location: SourceLocation(line: 3, column: 5),
          name: "deprecated",
          value: .identifier("true"),
          pathParts: []
        )
      ]
    )

    // Validation should not throw for valid deprecated option
    XCTAssertNoThrow(
      try validDeprecatedOption.validate(),
      "Valid deprecated option should pass validation"
    )

    // Create a service with an invalid deprecated option
    let invalidDeprecatedOption = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      name: "UserService",
      rpcs: [
        RPCNode(
          location: SourceLocation(line: 2, column: 3),
          name: "GetUser",
          inputType: "GetUserRequest",
          outputType: "GetUserResponse"
        )
      ],
      options: [
        OptionNode(
          location: SourceLocation(line: 3, column: 5),
          name: "deprecated",
          value: .string("yes"),  // Invalid value type
          pathParts: []
        )
      ]
    )

    // Validation should throw for invalid deprecated option
    XCTAssertThrowsError(try invalidDeprecatedOption.validate()) { error in
      guard let parserError = error as? ParserError else {
        XCTFail("Expected ParserError")
        return
      }

      if case .custom(let message) = parserError {
        XCTAssertTrue(
          message.contains("Invalid service option"),
          "Error should mention invalid option"
        )
        XCTAssertTrue(message.contains("deprecated"), "Error should mention the option name")
      }
      else {
        XCTFail("Expected custom error for invalid service option")
      }
    }
  }
}
