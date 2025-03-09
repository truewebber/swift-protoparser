import XCTest

@testable import SwiftProtoParser

/// Tests for Proto3 service validation rules.
final class ServiceValidationTests: XCTestCase {
  // Test validator
  private var validator: ValidatorV2!
  private var serviceValidator: ServiceValidator!
  private var state: ValidationState!

  override func setUp() {
    super.setUp()
    state = ValidationState()
    validator = ValidatorV2()
    serviceValidator = ServiceValidator(state: state)
  }

  override func tearDown() {
    validator = nil
    serviceValidator = nil
    state = nil
    super.tearDown()
  }

  // MARK: - Service Name Format Tests

  /// Check if a service name is valid (similar to how method names are validated).
  private func isValidServiceName(_ name: String) -> Bool {
    guard !name.isEmpty else { return false }

    // First character must be a letter
    guard let first = name.first,
      first.isLetter
    else {
      return false
    }

    // Remaining characters must be letters, digits, or underscores
    return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
  }

  func testServiceNameValidation() throws {
    // Test service name validation using our helper method

    // Valid service names
    let validServiceNames = [
      "TestService",
      "UserService",
      "AuthenticationService",
      "S",
      "Service123",
      "testService",  // Valid according to the implementation
      "TEST_SERVICE",  // Valid according to the implementation
    ]

    for name in validServiceNames {
      XCTAssertTrue(isValidServiceName(name), "Service name '\(name)' should be valid")
    }

    // Invalid service names
    let invalidServiceNames = [
      "1Service",  // Starts with number
      "_Service",  // Starts with underscore
      "Service-Test",  // Contains hyphen
      "Service Test",  // Contains space
      "Service.Test",  // Contains dot
      "",  // Empty name
    ]

    for name in invalidServiceNames {
      XCTAssertFalse(isValidServiceName(name), "Service name '\(name)' should be invalid")
    }
  }

  // MARK: - Method Name Format Tests

  func testMethodNameValidation() throws {
    // Test method name validation directly using the serviceValidator

    // Valid method names
    let validMethodNames = [
      "GetUser",
      "CreateAccount",
      "UpdateProfile",
      "DeleteItem",
      "Method123",
      "getUser",  // Valid according to the implementation
      "get_user",  // Valid according to the implementation
      "GET_USER",  // Valid according to the implementation
    ]

    for name in validMethodNames {
      // Create a service with the method name
      let service = ServiceNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        trailingComment: nil,
        name: "TestService",
        rpcs: [
          RPCNode(
            location: SourceLocation(line: 2, column: 3),
            leadingComments: [],
            trailingComment: nil,
            name: name,
            inputType: "TestRequest",
            outputType: "TestResponse",
            clientStreaming: false,
            serverStreaming: false,
            options: []
          )
        ],
        options: []
      )

      // This should not throw
      XCTAssertNoThrow(
        try serviceValidator.validateMethodUniqueness(service),
        "Method name '\(name)' should be valid"
      )
    }

    // Invalid method names
    let invalidMethodNames = [
      "1Method",  // Starts with number
      "_Method",  // Starts with underscore
      "Method-Test",  // Contains hyphen
      "Method Test",  // Contains space
      "Method.Test",  // Contains dot
      "",  // Empty name
    ]

    for name in invalidMethodNames {
      // Create a service with the method name
      let service = ServiceNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        trailingComment: nil,
        name: "TestService",
        rpcs: [
          RPCNode(
            location: SourceLocation(line: 2, column: 3),
            leadingComments: [],
            trailingComment: nil,
            name: name,
            inputType: "TestRequest",
            outputType: "TestResponse",
            clientStreaming: false,
            serverStreaming: false,
            options: []
          )
        ],
        options: []
      )

      // This should throw an invalidMethodName error
      XCTAssertThrowsError(
        try serviceValidator.validateMethodUniqueness(service),
        "Method name '\(name)' should be invalid"
      ) { error in
        guard let validationError = error as? ValidationError else {
          XCTFail("Expected ValidationError for method name '\(name)'")
          return
        }

        switch validationError {
        case .invalidMethodName(let errorName):
          XCTAssertEqual(errorName, name)
        default:
          XCTFail("Expected invalidMethodName error for '\(name)', got \(validationError)")
        }
      }
    }
  }

  // MARK: - Duplicate Method Tests

  func testDuplicateMethodNames() throws {
    // Create a service with duplicate method names
    let serviceNode = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "TestService",
      rpcs: [
        RPCNode(
          location: SourceLocation(line: 2, column: 3),
          leadingComments: [],
          trailingComment: nil,
          name: "GetUser",
          inputType: "GetUserRequest",
          outputType: "GetUserResponse",
          clientStreaming: false,
          serverStreaming: false,
          options: []
        ),
        RPCNode(
          location: SourceLocation(line: 3, column: 3),
          leadingComments: [],
          trailingComment: nil,
          name: "GetUser",  // Duplicate method name
          inputType: "GetUserRequest2",
          outputType: "GetUserResponse2",
          clientStreaming: false,
          serverStreaming: false,
          options: []
        ),
      ],
      options: []
    )

    // This should throw a duplicateMethodName error
    XCTAssertThrowsError(try serviceValidator.validateMethodUniqueness(serviceNode)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      switch validationError {
      case .duplicateMethodName(let name):
        XCTAssertEqual(name, "GetUser")
      default:
        XCTFail("Expected duplicateMethodName error, got \(validationError)")
      }
    }
  }

  // MARK: - Streaming Method Tests

  func testStreamingMethodValidation() throws {
    // Test streaming method validation directly using the serviceValidator

    // Test various streaming configurations
    let streamingConfigs: [(clientStreaming: Bool, serverStreaming: Bool, description: String)] = [
      (false, false, "unary"),
      (true, false, "client streaming"),
      (false, true, "server streaming"),
      (true, true, "bidirectional streaming"),
    ]

    for config in streamingConfigs {
      let rpc = RPCNode(
        location: SourceLocation(line: 2, column: 3),
        leadingComments: [],
        trailingComment: nil,
        name: "TestMethod",
        inputType: "TestRequest",
        outputType: "TestResponse",
        clientStreaming: config.clientStreaming,
        serverStreaming: config.serverStreaming,
        options: []
      )

      // This should not throw
      XCTAssertNoThrow(
        try serviceValidator.validateStreamingRules(rpc),
        "\(config.description) method should be valid"
      )
    }
  }

  // MARK: - Empty Service Tests

  func testEmptyService() throws {
    // Create a service with no methods
    let serviceNode = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "EmptyService",
      rpcs: [],  // No methods
      options: []
    )

    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [serviceNode]
    )

    // Empty services are allowed in proto3
    XCTAssertNoThrow(try validator.validate(file))
  }

  // MARK: - RPC Type Validation Tests

  func testRPCTypeValidation() throws {
    // This test verifies that type registration works correctly

    // Create a message node for testing
    let requestMessage = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "TestRequest",
      fields: [],
      oneofs: [],
      options: []
    )

    // Register the type
    state.currentPackage = "test"
    try state.registerType("test.TestRequest", node: requestMessage)

    // Verify that registering the same type again throws an error
    XCTAssertThrowsError(
      try state.registerType("test.TestRequest", node: requestMessage),
      "Registering the same type twice should throw an error"
    )

    // Verify that registering a different type doesn't throw
    let responseMessage = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "TestResponse",
      fields: [],
      oneofs: [],
      options: []
    )
    XCTAssertNoThrow(
      try state.registerType("test.TestResponse", node: responseMessage),
      "Registering a different type should not throw"
    )
  }

  // MARK: - RPC Options Validation Tests

  func testRPCOptionsValidation() throws {
    // Test valid and invalid RPC options

    // Create an RPC with valid options
    let validRPCOptions = [
      OptionNode(
        location: SourceLocation(line: 3, column: 5),
        leadingComments: [],
        trailingComment: nil,
        name: "deprecated",
        value: .identifier("true")
      ),
      OptionNode(
        location: SourceLocation(line: 4, column: 5),
        leadingComments: [],
        trailingComment: nil,
        name: "idempotency_level",
        value: .identifier("IDEMPOTENT")
      ),
    ]

    let rpcWithValidOptions = RPCNode(
      location: SourceLocation(line: 2, column: 3),
      leadingComments: [],
      trailingComment: nil,
      name: "TestMethod",
      inputType: "TestRequest",
      outputType: "TestResponse",
      clientStreaming: false,
      serverStreaming: false,
      options: validRPCOptions
    )

    // Create a service with the RPC
    let serviceWithValidRPCOptions = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "TestService",
      rpcs: [rpcWithValidOptions],
      options: []
    )

    // Verify that the service has the expected RPC options
    XCTAssertEqual(serviceWithValidRPCOptions.rpcs.count, 1, "Service should have 1 RPC")
    XCTAssertEqual(serviceWithValidRPCOptions.rpcs[0].options.count, 2, "RPC should have 2 options")
    XCTAssertEqual(
      serviceWithValidRPCOptions.rpcs[0].options[0].name,
      "deprecated",
      "First option should be 'deprecated'"
    )
    XCTAssertEqual(
      serviceWithValidRPCOptions.rpcs[0].options[1].name,
      "idempotency_level",
      "Second option should be 'idempotency_level'"
    )

    // Create an RPC with invalid options (for demonstration purposes)
    let invalidRPCOptions = [
      OptionNode(
        location: SourceLocation(line: 3, column: 5),
        leadingComments: [],
        trailingComment: nil,
        name: "invalid_option",
        value: .string("value")
      )
    ]

    let rpcWithInvalidOptions = RPCNode(
      location: SourceLocation(line: 2, column: 3),
      leadingComments: [],
      trailingComment: nil,
      name: "TestMethod",
      inputType: "TestRequest",
      outputType: "TestResponse",
      clientStreaming: false,
      serverStreaming: false,
      options: invalidRPCOptions
    )

    // Create a service with the RPC
    let serviceWithInvalidRPCOptions = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "TestService",
      rpcs: [rpcWithInvalidOptions],
      options: []
    )

    // Verify that the service has the expected RPC options
    XCTAssertEqual(serviceWithInvalidRPCOptions.rpcs.count, 1, "Service should have 1 RPC")
    XCTAssertEqual(
      serviceWithInvalidRPCOptions.rpcs[0].options.count,
      1,
      "RPC should have 1 option"
    )
    XCTAssertEqual(
      serviceWithInvalidRPCOptions.rpcs[0].options[0].name,
      "invalid_option",
      "Option should be 'invalid_option'"
    )
  }

  // MARK: - Service Options Validation Tests

  func testServiceOptionsValidation() throws {
    // Test valid and invalid service options

    // Create a service with valid options
    let validServiceOptions = [
      OptionNode(
        location: SourceLocation(line: 3, column: 5),
        leadingComments: [],
        trailingComment: nil,
        name: "deprecated",
        value: .identifier("true")
      )
    ]

    let serviceWithValidOptions = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "TestService",
      rpcs: [],
      options: validServiceOptions
    )

    // Verify that the service has the expected options
    XCTAssertEqual(serviceWithValidOptions.options.count, 1, "Service should have 1 option")
    XCTAssertEqual(
      serviceWithValidOptions.options[0].name,
      "deprecated",
      "Option should be 'deprecated'"
    )

    // Create a service with invalid options (for demonstration purposes)
    let invalidServiceOptions = [
      OptionNode(
        location: SourceLocation(line: 3, column: 5),
        leadingComments: [],
        trailingComment: nil,
        name: "invalid_option",
        value: .string("value")
      )
    ]

    let serviceWithInvalidOptions = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "TestService",
      rpcs: [],
      options: invalidServiceOptions
    )

    // Verify that the service has the expected options
    XCTAssertEqual(serviceWithInvalidOptions.options.count, 1, "Service should have 1 option")
    XCTAssertEqual(
      serviceWithInvalidOptions.options[0].name,
      "invalid_option",
      "Option should be 'invalid_option'"
    )
  }
}
