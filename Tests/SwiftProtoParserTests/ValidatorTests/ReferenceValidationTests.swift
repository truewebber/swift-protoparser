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
    XCTAssertNotNil(state.definedTypes["test.test.Message1"])
    XCTAssertNotNil(state.definedTypes["test.test.Message2"])
    XCTAssertNotNil(state.definedTypes["test.test.Enum1"])
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
        XCTAssertEqual(name, "test.test.Message", "Error should contain the duplicate type name")
      }
      else {
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

    // Create a message
    let message = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Message",
      fields: [],
      oneofs: [],
      options: []
    )

    // Register the message directly
    try state.registerType("test.Message", node: message)
    
    // Add the message to the definedTypes dictionary directly
    state.definedTypes["test.Message"] = message
    
    // Create a field that references the message with a simple name
    let field = FieldNode(
      location: SourceLocation(line: 2, column: 3),
      name: "message_field",
      type: .named("Message"),
      number: 1,
      isRepeated: false,
      options: []
    )
    
    // Create a container message with the field
    let containerMessage = MessageNode(
      location: SourceLocation(line: 5, column: 1),
      name: "ContainerMessage",
      fields: [field],
      oneofs: [],
      options: []
    )
    
    // Create a file with both messages
    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [message, containerMessage]
    )
    
    // Validate cross references - should not throw
    XCTAssertNoThrow(try referenceValidator.validateCrossReferences(file))
  }

  /// Test validating a fully qualified type reference.
  func testValidateFullyQualifiedTypeReference() throws {
    // Set the current package
    state.currentPackage = "test"

    // Create a message
    let message = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Message",
      fields: [],
      oneofs: [],
      options: []
    )

    // Register the message directly
    try state.registerType("test.Message", node: message)
    
    // Add the message to the definedTypes dictionary directly
    state.definedTypes["test.Message"] = message
    
    // Create a file with the message
    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [message]
    )
    
    // Create a field that references the message with a fully qualified name
    let field = FieldNode(
      location: SourceLocation(line: 2, column: 3),
      name: "message_field",
      type: .named(".test.Message"),
      number: 1,
      isRepeated: false,
      options: []
    )
    
    // Create a container message with the field
    let containerMessage = MessageNode(
      location: SourceLocation(line: 5, column: 1),
      name: "ContainerMessage",
      fields: [field],
      oneofs: [],
      options: []
    )
    
    // Create a file with the container message
    let containerFile = FileNode(
      location: SourceLocation(line: 5, column: 1),
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [containerMessage]
    )
    
    // Validate cross references - should not throw
    XCTAssertNoThrow(try referenceValidator.validateCrossReferences(containerFile))

    // Validate reference to an undefined type with fully qualified name - should throw
    XCTAssertThrowsError(try referenceValidator.validateTypeReference(".undefined.Type", inMessage: nil)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      if case .undefinedType(let typeName, let referencedIn) = validationError {
        XCTAssertEqual(typeName, "undefined", "Error should contain the undefined type name")
        XCTAssertEqual(referencedIn, "service", "Error should contain the referencing context")
      }
      else {
        XCTFail("Expected undefinedType error")
      }
    }
  }

  /// Test validating a type reference in a different package.
  func testValidateTypeReferenceInDifferentPackage() throws {
    // Set the current package
    state.currentPackage = "test"

    // Create a message in the current package
    let message1 = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Message",
      fields: [],
      oneofs: [],
      options: []
    )

    // Register the message directly
    try state.registerType("test.Message", node: message1)
    
    // Add the message to the definedTypes dictionary directly
    state.definedTypes["test.Message"] = message1

    // Create a message in a different package
    let message2 = MessageNode(
      location: SourceLocation(line: 5, column: 1),
      name: "OtherMessage",
      fields: [],
      oneofs: [],
      options: []
    )

    // Register the message with a different package
    try state.registerType("other.OtherMessage", node: message2)
    
    // Add the message to the definedTypes dictionary directly
    state.definedTypes["other.OtherMessage"] = message2
    
    // Create a field that references the message in a different package
    let field1 = FieldNode(
      location: SourceLocation(line: 2, column: 3),
      name: "other_message_field",
      type: .named("other.OtherMessage"),
      number: 1,
      isRepeated: false,
      options: []
    )
    
    // Create a field that references the message in a different package with leading dot
    let field2 = FieldNode(
      location: SourceLocation(line: 3, column: 3),
      name: "other_message_field_qualified",
      type: .named(".other.OtherMessage"),
      number: 2,
      isRepeated: false,
      options: []
    )
    
    // Create a container message with the fields
    let containerMessage = MessageNode(
      location: SourceLocation(line: 10, column: 1),
      name: "ContainerMessage",
      fields: [field1, field2],
      oneofs: [],
      options: []
    )
    
    // Create a file with the container message
    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [containerMessage]
    )
    
    // Validate cross references - should not throw
    XCTAssertNoThrow(try referenceValidator.validateCrossReferences(file))
  }

  /// Test validating a nested type reference.
  func testValidateNestedTypeReference() throws {
    // Set the current package
    state.currentPackage = "test"

    // Create a nested message
    let nestedMessage = MessageNode(
      location: SourceLocation(line: 5, column: 3),
      name: "NestedMessage",
      fields: [],
      oneofs: [],
      options: []
    )

    // Create a parent message with the nested message
    let parentMessage = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "ParentMessage",
      fields: [],
      oneofs: [],
      options: [],
      messages: [nestedMessage]
    )

    // Register the parent message directly
    try state.registerType("test.ParentMessage", node: parentMessage)
    
    // Register the nested message directly
    try state.registerType("test.ParentMessage.NestedMessage", node: nestedMessage)
    
    // Add the messages to the definedTypes dictionary directly
    state.definedTypes["test.ParentMessage"] = parentMessage
    state.definedTypes["test.ParentMessage.NestedMessage"] = nestedMessage
    
    // Create a field that references the nested message with fully qualified name
    let field = FieldNode(
      location: SourceLocation(line: 3, column: 3),
      name: "nested_field_qualified",
      type: .named(".test.ParentMessage.NestedMessage"),
      number: 2,
      isRepeated: false,
      options: []
    )
    
    // Create a container message with the field
    let containerMessage = MessageNode(
      location: SourceLocation(line: 10, column: 1),
      name: "ContainerMessage",
      fields: [field],
      oneofs: [],
      options: []
    )
    
    // Create a file with the parent message and container message
    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [parentMessage, containerMessage]
    )
    
    // Validate cross references - should not throw
    XCTAssertNoThrow(try referenceValidator.validateCrossReferences(file))
  }

  /// Test validating a type reference in message scope.
  func testValidateTypeReferenceInMessageScope() throws {
    // Set the current package
    state.currentPackage = "test"

    // Create a nested message
    let nestedMessage = MessageNode(
      location: SourceLocation(line: 5, column: 3),
      name: "NestedMessage",
      fields: [],
      oneofs: [],
      options: []
    )

    // Create a parent message with the nested message
    let parentMessage = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "ParentMessage",
      fields: [
        FieldNode(
          location: SourceLocation(line: 2, column: 3),
          name: "nested_field",
          type: .named("NestedMessage"),  // Reference to nested message
          number: 1,
          isRepeated: false,
          options: []
        )
      ],
      oneofs: [],
      options: [],
      messages: [nestedMessage]
    )

    // Register the parent message directly
    try state.registerType("test.ParentMessage", node: parentMessage)
    
    // Register the nested message directly
    try state.registerType("test.ParentMessage.NestedMessage", node: nestedMessage)
    
    // Add the messages to the definedTypes dictionary directly
    state.definedTypes["test.ParentMessage"] = parentMessage
    state.definedTypes["test.ParentMessage.NestedMessage"] = nestedMessage
    
    // Push the parent message onto the scope stack
    state.pushScope(parentMessage)

    // Validate reference to the nested type from within the parent message - should not throw
    XCTAssertNoThrow(try referenceValidator.validateTypeReference("NestedMessage", inMessage: parentMessage))

    // Pop the scope
    state.popScope()
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
    
    // Create a file node with the message
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test",
      definitions: [message]
    )
    
    // Register the types
    try referenceValidator.registerTypes(fileNode)

    // Validate reference to an undefined type
    XCTAssertThrowsError(try referenceValidator.validateTypeReference("UndefinedType", inMessage: message)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      if case .undefinedType(let typeName, let referencedIn) = validationError {
        XCTAssertEqual(typeName, "UndefinedType", "Error should contain the undefined type name")
        XCTAssertEqual(referencedIn, "Message", "Error should contain the referencing message name")
      }
      else {
        XCTFail("Expected undefinedType error")
      }
    }
  }

  /// Test validating an undefined nested type reference.
  func testValidateUndefinedNestedTypeReference() throws {
    // Set the current package
    state.currentPackage = "test"

    // Create a parent message
    let parentMessage = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "ParentMessage",
      fields: [],
      oneofs: [],
      options: []
    )

    // Register the parent message directly
    try state.registerType("test.ParentMessage", node: parentMessage)
    
    // Add the parent message to the definedTypes dictionary directly
    state.definedTypes["test.ParentMessage"] = parentMessage
    
    // Create a field that references an undefined nested type
    let field = FieldNode(
      location: SourceLocation(line: 2, column: 3),
      name: "undefined_nested_field",
      type: .named("ParentMessage.UndefinedNested"),
      number: 1,
      isRepeated: false,
      options: []
    )
    
    // Create a container message with the field
    let containerMessage = MessageNode(
      location: SourceLocation(line: 5, column: 1),
      name: "ContainerMessage",
      fields: [field],
      oneofs: [],
      options: []
    )
    
    // Create a file with the parent message and container message
    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [parentMessage, containerMessage]
    )
    
    // Validate cross references - should throw for undefined nested type
    XCTAssertThrowsError(try referenceValidator.validateCrossReferences(file)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      if case .undefinedType(let typeName, let referencedIn) = validationError {
        XCTAssertEqual(typeName, "ParentMessage.UndefinedNested", "Error should contain the undefined type name")
        XCTAssertEqual(referencedIn, "ContainerMessage", "Error should contain the referencing message name")
      }
      else {
        XCTFail("Expected undefinedType error")
      }
    }
  }

  // MARK: - Cross-Reference Tests

  /// Test validating cross references.
  func testValidateCrossReferences() throws {
    // Set the current package
    state.currentPackage = "test"

    // Create two messages that reference each other
    let messageA = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "MessageA",
      fields: [
        FieldNode(
          location: SourceLocation(line: 2, column: 3),
          name: "b_field",
          type: .named("MessageB"),  // Reference to MessageB
          number: 1,
          isRepeated: false,
          options: []
        )
      ],
      oneofs: [],
      options: []
    )

    let messageB = MessageNode(
      location: SourceLocation(line: 5, column: 1),
      name: "MessageB",
      fields: [
        FieldNode(
          location: SourceLocation(line: 6, column: 3),
          name: "a_field",
          type: .named("MessageA"),  // Reference to MessageA
          number: 1,
          isRepeated: false,
          options: []
        )
      ],
      oneofs: [],
      options: []
    )

    // Register the messages directly
    try state.registerType("test.MessageA", node: messageA)
    try state.registerType("test.MessageB", node: messageB)
    
    // Add the messages to the definedTypes dictionary directly
    state.definedTypes["test.MessageA"] = messageA
    state.definedTypes["test.MessageB"] = messageB

    // Create a file with these messages for cross-reference validation
    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [messageA, messageB]
    )

    // Validate cross references - should not throw
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

    // Create a file with this message
    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [message]
    )
    
    // Register the types
    try referenceValidator.registerTypes(file)

    // Validate cross references - should throw for undefined type
    XCTAssertThrowsError(try referenceValidator.validateCrossReferences(file)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      if case .undefinedType(let typeName, let referencedIn) = validationError {
        XCTAssertEqual(typeName, "UndefinedType", "Error should contain the undefined type name")
        XCTAssertEqual(referencedIn, "Message", "Error should contain the referencing message name")
      }
      else {
        XCTFail("Expected undefinedType error")
      }
    }
  }

  /// Test validating service cross references.
  func testValidateServiceCrossReferences() throws {
    // Set the current package
    state.currentPackage = "test"

    // Create request and response messages
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

    // Create a service with an RPC method
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

    // Register the messages directly
    try state.registerType("test.Request", node: requestMessage)
    try state.registerType("test.Response", node: responseMessage)
    
    // Add the messages to the definedTypes dictionary directly
    state.definedTypes["test.Request"] = requestMessage
    state.definedTypes["test.Response"] = responseMessage

    // Create a file with these definitions for cross-reference validation
    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [requestMessage, responseMessage, service]
    )

    // Validate cross references - should not throw
    XCTAssertNoThrow(try referenceValidator.validateCrossReferences(file))
  }

  /// Test validating service cross references with undefined input type.
  func testValidateServiceCrossReferencesWithUndefinedInputType() throws {
    // Set the current package
    state.currentPackage = "test"

    // Create only the response message type
    let responseMessage = MessageNode(
      location: SourceLocation(line: 5, column: 1),
      name: "Response",
      fields: [],
      oneofs: [],
      options: []
    )

    // Register the response message directly
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
      }
      else {
        XCTFail("Expected undefinedType error")
      }
    }
  }

  /// Test validating service cross references with undefined output type.
  func testValidateServiceCrossReferencesWithUndefinedOutputType() throws {
    // Set the current package
    state.currentPackage = "test"

    // Create a request message
    let requestMessage = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Request",
      fields: [],
      oneofs: [],
      options: []
    )

    // Register the request message directly
    try state.registerType("test.Request", node: requestMessage)
    
    // Add the message to the definedTypes dictionary directly
    state.definedTypes["test.Request"] = requestMessage

    // Create a service with an RPC method that has an undefined output type
    let service = ServiceNode(
      location: SourceLocation(line: 10, column: 1),
      name: "TestService",
      rpcs: [
        RPCNode(
          location: SourceLocation(line: 11, column: 3),
          name: "TestMethod",
          inputType: "Request",
          outputType: "UndefinedResponse",  // This type doesn't exist
          clientStreaming: false,
          serverStreaming: false,
          options: []
        )
      ],
      options: []
    )

    // Create a file with these definitions for cross-reference validation
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
      }
      else {
        XCTFail("Expected undefinedType error")
      }
    }
  }

  /// Test validating imported type references.
  func testValidateImportedTypeReferences() throws {
    // Set the current package
    state.currentPackage = "test"

    // Create a message that references an imported type
    let message = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Message",
      fields: [
        FieldNode(
          location: SourceLocation(line: 2, column: 3),
          name: "imported_field",
          type: .named("ImportedType"),  // Reference to an imported type
          number: 1,
          isRepeated: false,
          options: []
        )
      ],
      oneofs: [],
      options: []
    )

    // Register the message directly
    try state.registerType("test.Message", node: message)
    
    // Add the message to the definedTypes dictionary directly
    state.definedTypes["test.Message"] = message

    // Create a dummy message for the imported type
    let importedMessage = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "ImportedType",
      fields: [],
      oneofs: [],
      options: []
    )
    
    // Register the imported type directly
    try state.registerType("ImportedType", node: importedMessage)
    
    // Add the imported type to the definedTypes dictionary directly
    state.definedTypes["ImportedType"] = importedMessage

    // Add the imported type to the state
    state.importedTypes["ImportedType"] = "imported.proto"

    // Create a file with this message for cross-reference validation
    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test",
      imports: [
        ImportNode(
          location: SourceLocation(line: 3, column: 1),
          path: "imported.proto"
        )
      ],
      options: [],
      definitions: [message]
    )

    // Validate cross references - should not throw
    XCTAssertNoThrow(try referenceValidator.validateCrossReferences(file))
  }

  /// Test resolving type names.
  func testResolveTypeName() throws {
    // Set the current package
    state.currentPackage = "test"

    // Create a message
    let containerMessage = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "ContainerMessage",
      fields: [
        FieldNode(
          location: SourceLocation(line: 2, column: 3),
          name: "field",
          type: .named("Message"),  // Reference to another message
          number: 1,
          isRepeated: false,
          options: []
        )
      ],
      oneofs: [],
      options: []
    )

    // Create a message that will be referenced
    let referencedMessage = MessageNode(
      location: SourceLocation(line: 5, column: 1),
      name: "Message",
      fields: [],
      oneofs: [],
      options: []
    )

    // Register the messages directly
    try state.registerType("test.ContainerMessage", node: containerMessage)
    try state.registerType("test.Message", node: referencedMessage)
    
    // Add the messages to the definedTypes dictionary directly
    state.definedTypes["test.ContainerMessage"] = containerMessage
    state.definedTypes["test.Message"] = referencedMessage

    // This should not throw because the referenced message exists
    XCTAssertNoThrow(try referenceValidator.validateTypeReference("Message", inMessage: containerMessage))
  }
}
