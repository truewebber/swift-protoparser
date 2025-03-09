import XCTest

@testable import SwiftProtoParser

/// Tests for Proto3 reference validation rules.
final class ReferenceValidationTests: XCTestCase {
  // Test validator
  private var validator: ValidatorV2!
  private var referenceValidator: ReferenceValidator!
  private var state: ValidationState!

  override func setUp() {
    super.setUp()
    state = ValidationState()
    validator = ValidatorV2()
    referenceValidator = ReferenceValidator(state: state)
  }

  override func tearDown() {
    validator = nil
    referenceValidator = nil
    state = nil
    super.tearDown()
  }

  // MARK: - Type Registration Tests

  /// Test registering types from a file.
  func testRegisterTypes() throws {
    // Set the current package
    state.currentPackage = "test"

    // Create a file with messages and enums
    let message1 = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Message1",
      fields: [],
      oneofs: [],
      options: []
    )

    let message2 = MessageNode(
      location: SourceLocation(line: 5, column: 1),
      name: "Message2",
      fields: [],
      oneofs: [],
      options: []
    )

    let enum1 = EnumNode(
      location: SourceLocation(line: 10, column: 1),
      name: "Enum1",
      values: [
        EnumValueNode(
          location: SourceLocation(line: 11, column: 3),
          name: "ZERO",
          number: 0,
          options: []
        )
      ],
      options: []
    )

    // Create a file that contains these types
    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [message1, message2, enum1]
    )

    // Register types
    try referenceValidator.registerTypes(file)

    // Verify types are registered with correct fully qualified names
    XCTAssertNotNil(state.definedTypes["test.Message1"])
    XCTAssertNotNil(state.definedTypes["test.Message2"])
    XCTAssertNotNil(state.definedTypes["test.Enum1"])
  }

  /// Test registering types with duplicate names.
  func testRegisterDuplicateTypes() throws {
    // Set the current package
    state.currentPackage = "test"

    // Create a file with a message
    let message1 = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Message",
      fields: [],
      oneofs: [],
      options: []
    )

    // Create a file that contains this message
    let file1 = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [message1]
    )

    // Register the first message
    try referenceValidator.registerTypes(file1)

    // Create another file with a message with the same name
    let message2 = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Message",
      fields: [],
      oneofs: [],
      options: []
    )

    // Create a file that contains this message
    let file2 = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [message2]
    )

    // Registering the second message should throw
    XCTAssertThrowsError(try referenceValidator.registerTypes(file2)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      if case .duplicateTypeName(let name) = validationError {
        XCTAssertEqual(name, "test.Message", "Error should contain the duplicate type name")
      } else {
        XCTFail("Expected duplicateTypeName error")
      }
    }
  }

  /// Test registering types with no package.
  func testRegisterTypesNoPackage() throws {
    // No package set
    state.currentPackage = nil

    // Create a file with a message
    let message = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Message",
      fields: [],
      oneofs: [],
      options: []
    )

    // Create a file that contains this message
    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "",
      imports: [],
      options: [],
      definitions: [message]
    )

    // Register types
    try referenceValidator.registerTypes(file)

    // Verify type is registered with just the name (no package prefix)
    XCTAssertNotNil(state.definedTypes["Message"])
  }

  // MARK: - Type Reference Tests

  /// Test validating a simple type reference.
  func testValidateSimpleTypeReference() throws {
    // Set the current package
    state.currentPackage = "test"

    // Register a type
    let message = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Message",
      fields: [],
      oneofs: [],
      options: []
    )
    try state.registerType("test.Message", node: message)

    // Validate reference to the type
    XCTAssertNoThrow(try referenceValidator.validateTypeReference("Message", inMessage: nil))
  }

  /// Test validating a fully qualified type reference.
  func testValidateFullyQualifiedTypeReference() throws {
    // Set the current package
    state.currentPackage = "test"

    // Register a type
    let message = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Message",
      fields: [],
      oneofs: [],
      options: []
    )
    try state.registerType("test.Message", node: message)

    // Validate reference to the type with fully qualified name
    XCTAssertNoThrow(try referenceValidator.validateTypeReference(".test.Message", inMessage: nil))
  }

  /// Test validating a type reference in a different package.
  func testValidateTypeReferenceInDifferentPackage() throws {
    // Set the current package
    state.currentPackage = "test"

    // Register a type in a different package
    let message = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Message",
      fields: [],
      oneofs: [],
      options: []
    )
    try state.registerType("other.Message", node: message)

    // Validate reference to the type with fully qualified name
    XCTAssertNoThrow(try referenceValidator.validateTypeReference(".other.Message", inMessage: nil))

    // Validate reference to the type with package name
    XCTAssertNoThrow(try referenceValidator.validateTypeReference("other.Message", inMessage: nil))
  }

  /// Test validating a nested type reference.
  func testValidateNestedTypeReference() throws {
    // Set the current package
    state.currentPackage = "test"

    // Register a nested type
    let nestedMessage = MessageNode(
      location: SourceLocation(line: 5, column: 3),
      name: "NestedMessage",
      fields: [],
      oneofs: [],
      options: []
    )
    let parentMessage = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "ParentMessage",
      fields: [],
      oneofs: [],
      options: [],
      messages: [nestedMessage]
    )
    try state.registerType("test.ParentMessage", node: parentMessage)
    try state.registerType("test.ParentMessage.NestedMessage", node: nestedMessage)

    // Validate reference to the nested type
    XCTAssertNoThrow(try referenceValidator.validateTypeReference("ParentMessage.NestedMessage", inMessage: nil))
    XCTAssertNoThrow(try referenceValidator.validateTypeReference(".test.ParentMessage.NestedMessage", inMessage: nil))
  }

  /// Test validating a type reference within a message scope.
  func testValidateTypeReferenceInMessageScope() throws {
    // Set the current package
    state.currentPackage = "test"

    // Register a nested type
    let nestedMessage = MessageNode(
      location: SourceLocation(line: 5, column: 3),
      name: "NestedMessage",
      fields: [],
      oneofs: [],
      options: []
    )
    let parentMessage = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "ParentMessage",
      fields: [],
      oneofs: [],
      options: [],
      messages: [nestedMessage]
    )
    try state.registerType("test.ParentMessage", node: parentMessage)
    try state.registerType("test.ParentMessage.NestedMessage", node: nestedMessage)

    // Push the parent message onto the scope stack
    state.scopeStack.append(ValidationState.Scope(typeName: "test.ParentMessage", node: parentMessage))

    // Validate reference to the nested type from within the parent message
    XCTAssertNoThrow(try referenceValidator.validateTypeReference("NestedMessage", inMessage: parentMessage))
  }

  /// Test validating an undefined type reference.
  func testValidateUndefinedTypeReference() throws {
    // Set the current package
    state.currentPackage = "test"

    // Create a message to reference from
    let message = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Message",
      fields: [],
      oneofs: [],
      options: []
    )

    // Validate reference to an undefined type
    XCTAssertThrowsError(try referenceValidator.validateTypeReference("UndefinedType", inMessage: message)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      if case .undefinedType(let typeName, let referencedIn) = validationError {
        XCTAssertEqual(typeName, "UndefinedType", "Error should contain the undefined type name")
        XCTAssertEqual(referencedIn, "Message", "Error should contain the referencing message name")
      } else {
        XCTFail("Expected undefinedType error")
      }
    }
  }

  /// Test validating an undefined nested type reference.
  func testValidateUndefinedNestedTypeReference() throws {
    // Set the current package
    state.currentPackage = "test"

    // Register a parent type
    let parentMessage = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "ParentMessage",
      fields: [],
      oneofs: [],
      options: []
    )
    try state.registerType("test.ParentMessage", node: parentMessage)

    // Validate reference to an undefined nested type
    XCTAssertThrowsError(try referenceValidator.validateTypeReference("ParentMessage.UndefinedNested", inMessage: nil)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      if case .undefinedType(let typeName, let referencedIn) = validationError {
        XCTAssertEqual(typeName, "test.ParentMessage.UndefinedNested", "Error should contain the undefined type name")
        XCTAssertEqual(referencedIn, "service", "Error should contain the referencing context")
      } else {
        XCTFail("Expected undefinedType error")
      }
    }
  }

  // MARK: - Cross-Reference Tests

  /// Test validating cross references in a file.
  func testValidateCrossReferences() throws {
    // Set the current package
    state.currentPackage = "test"

    // Register message types
    let messageA = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "MessageA",
      fields: [],
      oneofs: [],
      options: []
    )
    let messageB = MessageNode(
      location: SourceLocation(line: 5, column: 1),
      name: "MessageB",
      fields: [
        FieldNode(
          location: SourceLocation(line: 6, column: 3),
          name: "message_a_field",
          type: .named("MessageA"),
          number: 1,
          isRepeated: false,
          options: []
        )
      ],
      oneofs: [],
      options: []
    )
    try state.registerType("test.MessageA", node: messageA)
    try state.registerType("test.MessageB", node: messageB)

    // Create a file with these messages
    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [messageA, messageB]
    )

    // Validate cross references
    XCTAssertNoThrow(try referenceValidator.validateCrossReferences(file))
  }

  /// Test validating cross references with undefined types.
  func testValidateCrossReferencesWithUndefinedTypes() throws {
    // Set the current package
    state.currentPackage = "test"

    // Create a message with a field referencing an undefined type
    let message = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Message",
      fields: [
        FieldNode(
          location: SourceLocation(line: 2, column: 3),
          name: "undefined_field",
          type: .named("UndefinedType"),
          number: 1,
          isRepeated: false,
          options: []
        )
      ],
      oneofs: [],
      options: []
    )
    try state.registerType("test.Message", node: message)

    // Create a file with this message
    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [message]
    )

    // Validate cross references - should throw for undefined type
    XCTAssertThrowsError(try referenceValidator.validateCrossReferences(file)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      if case .undefinedType(let typeName, let referencedIn) = validationError {
        XCTAssertEqual(typeName, "UndefinedType", "Error should contain the undefined type name")
        XCTAssertEqual(referencedIn, "Message", "Error should contain the referencing message name")
      } else {
        XCTFail("Expected undefinedType error")
      }
    }
  }

  /// Test validating service cross references.
  func testValidateServiceCrossReferences() throws {
    // Set the current package
    state.currentPackage = "test"

    // Register message types for service inputs/outputs
    let requestMessage = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Request",
      fields: [],
      oneofs: [],
      options: []
    )
    let responseMessage = MessageNode(
      location: SourceLocation(line: 5, column: 1),
      name: "Response",
      fields: [],
      oneofs: [],
      options: []
    )
    try state.registerType("test.Request", node: requestMessage)
    try state.registerType("test.Response", node: responseMessage)

    // Create a service using these message types
    let service = ServiceNode(
      location: SourceLocation(line: 10, column: 1),
      name: "TestService",
      rpcs: [
        RPCNode(
          location: SourceLocation(line: 11, column: 3),
          name: "TestMethod",
          inputType: "Request",
          outputType: "Response",
          clientStreaming: false,
          serverStreaming: false,
          options: []
        )
      ],
      options: []
    )

    // Create a file with this service
    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [requestMessage, responseMessage, service]
    )

    // Validate cross references
    XCTAssertNoThrow(try referenceValidator.validateCrossReferences(file))
  }

  /// Test validating service cross references with undefined input type.
  func testValidateServiceCrossReferencesWithUndefinedInputType() throws {
    // Set the current package
    state.currentPackage = "test"

    // Register only the response message type
    let responseMessage = MessageNode(
      location: SourceLocation(line: 5, column: 1),
      name: "Response",
      fields: [],
      oneofs: [],
      options: []
    )
    try state.registerType("test.Response", node: responseMessage)

    // Create a service with undefined input type
    let service = ServiceNode(
      location: SourceLocation(line: 10, column: 1),
      name: "TestService",
      rpcs: [
        RPCNode(
          location: SourceLocation(line: 11, column: 3),
          name: "TestMethod",
          inputType: "UndefinedRequest",  // Undefined type
          outputType: "Response",
          clientStreaming: false,
          serverStreaming: false,
          options: []
        )
      ],
      options: []
    )

    // Create a file with this service
    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [responseMessage, service]
    )

    // Validate cross references - should throw for undefined input type
    XCTAssertThrowsError(try referenceValidator.validateCrossReferences(file)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      if case .undefinedType(let typeName, let referencedIn) = validationError {
        XCTAssertEqual(typeName, "UndefinedRequest", "Error should contain the undefined type name")
        XCTAssertEqual(referencedIn, "TestService", "Error should contain the referencing service name")
      } else {
        XCTFail("Expected undefinedType error")
      }
    }
  }

  /// Test validating service cross references with undefined output type.
  func testValidateServiceCrossReferencesWithUndefinedOutputType() throws {
    // Set the current package
    state.currentPackage = "test"

    // Register only the request message type
    let requestMessage = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Request",
      fields: [],
      oneofs: [],
      options: []
    )
    try state.registerType("test.Request", node: requestMessage)

    // Create a service with undefined output type
    let service = ServiceNode(
      location: SourceLocation(line: 10, column: 1),
      name: "TestService",
      rpcs: [
        RPCNode(
          location: SourceLocation(line: 11, column: 3),
          name: "TestMethod",
          inputType: "Request",
          outputType: "UndefinedResponse",  // Undefined type
          clientStreaming: false,
          serverStreaming: false,
          options: []
        )
      ],
      options: []
    )

    // Create a file with this service
    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [requestMessage, service]
    )

    // Validate cross references - should throw for undefined output type
    XCTAssertThrowsError(try referenceValidator.validateCrossReferences(file)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      if case .undefinedType(let typeName, let referencedIn) = validationError {
        XCTAssertEqual(typeName, "UndefinedResponse", "Error should contain the undefined type name")
        XCTAssertEqual(referencedIn, "TestService", "Error should contain the referencing service name")
      } else {
        XCTFail("Expected undefinedType error")
      }
    }
  }

  /// Test validating imported type references.
  func testValidateImportedTypeReferences() throws {
    // Set the current package
    state.currentPackage = "test"

    // Add an imported type
    state.importedTypes["ImportedType"] = "other.ImportedType"

    // Create a message with a field referencing the imported type
    let message = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Message",
      fields: [
        FieldNode(
          location: SourceLocation(line: 2, column: 3),
          name: "imported_field",
          type: .named("ImportedType"),
          number: 1,
          isRepeated: false,
          options: []
        )
      ],
      oneofs: [],
      options: []
    )
    try state.registerType("test.Message", node: message)

    // Create a file with this message
    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [message]
    )

    // Validate cross references - should not throw for imported type
    XCTAssertNoThrow(try referenceValidator.validateCrossReferences(file))
  }

  /// Test resolving type names.
  func testResolveTypeName() throws {
    // Set the current package
    state.currentPackage = "test"

    // Test resolving a simple type name
    let message = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Message",
      fields: [],
      oneofs: [],
      options: []
    )
    try state.registerType("test.Message", node: message)

    // Create a field with a simple type reference
    let field = FieldNode(
      location: SourceLocation(line: 2, column: 3),
      name: "message_field",
      type: .named("Message"),
      number: 1,
      isRepeated: false,
      options: []
    )

    // Create a message containing this field
    let containerMessage = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "ContainerMessage",
      fields: [field],
      oneofs: [],
      options: []
    )

    // Create a file with these messages
    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [message, containerMessage]
    )

    // Validate cross references - should resolve the type name correctly
    XCTAssertNoThrow(try referenceValidator.validateCrossReferences(file))
  }
}
