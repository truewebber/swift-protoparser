import XCTest

@testable import SwiftProtoParser

/// Test suite for SemanticValidator.
///
/// This test suite verifies the functionality of the SemanticValidator component
/// which is responsible for validating semantic rules in proto files.
final class SemanticValidatorTests: XCTestCase {

  // Test subject
  private var validator: SemanticValidator!
  private var state: ValidationState!

  override func setUp() {
    super.setUp()
    state = ValidationState()
    validator = SemanticValidator(state: state)
  }

  override func tearDown() {
    validator = nil
    state = nil
    super.tearDown()
  }

  // MARK: - File Validation Tests

  /// Test validating a file with invalid syntax version.
  func testInvalidSyntaxVersion() {
    // Create a file with invalid syntax
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto2",  // Invalid for this validator
      package: "test.package",
      filePath: "test.proto"
    )

    // Should throw
    XCTAssertThrowsError(try validator.validateSemanticRules(fileNode)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      if case .invalidSyntaxVersion(let version) = validationError {
        XCTAssertEqual(version, "proto2", "Error should contain the invalid syntax version")
      }
      else {
        XCTFail("Expected invalidSyntaxVersion error")
      }
    }
  }

  /// Test validating a file with valid syntax version.
  func testValidSyntaxVersion() {
    // Create a file with valid syntax
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto"
    )

    // Should not throw
    XCTAssertNoThrow(try validator.validateSemanticRules(fileNode))
  }

  /// Test validating a file with empty enums.
  func testEmptyEnum() {
    // Create an enum with no values
    let enumNode = EnumNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestEnum",
      values: [],
      options: []
    )

    // Create a file with the empty enum
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto",
      definitions: [enumNode]
    )

    // Should throw
    XCTAssertThrowsError(try validator.validateSemanticRules(fileNode)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      if case .emptyEnum(let name) = validationError {
        XCTAssertEqual(name, "TestEnum", "Error should contain the enum name")
      }
      else {
        XCTFail("Expected emptyEnum error")
      }
    }
  }

  /// Test validating a file with an enum whose first value is not zero.
  func testEnumFirstValueNotZero() {
    // Create an enum with first value not zero
    let enumNode = EnumNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestEnum",
      values: [
        EnumValueNode(
          location: SourceLocation(line: 2, column: 3),
          name: "FIRST",
          number: 1,  // Should be 0 in proto3
          options: []
        )
      ],
      options: []
    )

    // Create a file with the invalid enum
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto",
      definitions: [enumNode]
    )

    // Should throw
    XCTAssertThrowsError(try validator.validateSemanticRules(fileNode)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      if case .firstEnumValueNotZero(let name) = validationError {
        XCTAssertEqual(name, "TestEnum", "Error should contain the enum name")
      }
      else {
        XCTFail("Expected firstEnumValueNotZero error")
      }
    }
  }

  /// Test validating a file with an enum with duplicate values.
  func testEnumDuplicateValues() {
    // Create an enum with duplicate values
    let enumNode = EnumNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestEnum",
      values: [
        EnumValueNode(
          location: SourceLocation(line: 2, column: 3),
          name: "FIRST",
          number: 0,
          options: []
        ),
        EnumValueNode(
          location: SourceLocation(line: 3, column: 3),
          name: "SECOND",
          number: 1,
          options: []
        ),
        EnumValueNode(
          location: SourceLocation(line: 4, column: 3),
          name: "DUPLICATE",
          number: 1,  // Duplicate value
          options: []
        ),
      ],
      options: []
    )

    // Create a file with the invalid enum
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto",
      definitions: [enumNode]
    )

    // Should throw
    XCTAssertThrowsError(try validator.validateSemanticRules(fileNode)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      if case .duplicateEnumValue(let name, let value) = validationError {
        XCTAssertEqual(name, "DUPLICATE", "Error should contain the enum value name")
        XCTAssertEqual(value, 1, "Error should contain the duplicate value")
      }
      else {
        XCTFail("Expected duplicateEnumValue error")
      }
    }
  }

  /// Test validating a file with an enum with allow_alias option.
  func testEnumWithAllowAlias() {
    // Create an enum with allow_alias option and duplicate values
    let enumNode = EnumNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestEnum",
      values: [
        EnumValueNode(
          location: SourceLocation(line: 2, column: 3),
          name: "FIRST",
          number: 0,
          options: []
        ),
        EnumValueNode(
          location: SourceLocation(line: 3, column: 3),
          name: "SECOND",
          number: 1,
          options: []
        ),
        EnumValueNode(
          location: SourceLocation(line: 4, column: 3),
          name: "ALIAS",
          number: 1,  // Duplicate value, but allowed with allow_alias
          options: []
        ),
      ],
      options: [
        OptionNode(
          location: SourceLocation(line: 1, column: 10),
          name: "allow_alias",
          value: .identifier("true")
        )
      ]
    )

    // Create a file with the valid enum (due to allow_alias)
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto",
      definitions: [enumNode]
    )

    // Should not throw
    XCTAssertNoThrow(try validator.validateSemanticRules(fileNode))
  }

  /// Test validating a file with a valid enum.
  func testValidEnum() {
    // Create a valid enum
    let enumNode = EnumNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestEnum",
      values: [
        EnumValueNode(
          location: SourceLocation(line: 2, column: 3),
          name: "FIRST",
          number: 0,
          options: []
        ),
        EnumValueNode(
          location: SourceLocation(line: 3, column: 3),
          name: "SECOND",
          number: 1,
          options: []
        ),
        EnumValueNode(
          location: SourceLocation(line: 4, column: 3),
          name: "THIRD",
          number: 2,
          options: []
        ),
      ],
      options: []
    )

    // Create a file with the valid enum
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto",
      definitions: [enumNode]
    )

    // Should not throw
    XCTAssertNoThrow(try validator.validateSemanticRules(fileNode))
  }

  // MARK: - Message Validation Tests

  /// Test validating a message with an empty oneof.
  func testEmptyOneof() {
    // Create a message with an empty oneof
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage",
      fields: [],
      oneofs: [
        OneofNode(
          location: SourceLocation(line: 2, column: 3),
          name: "test_oneof",
          fields: []  // Empty oneof
        )
      ],
      options: []
    )

    // Create a file with the invalid message
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto",
      definitions: [messageNode]
    )

    // Should throw
    XCTAssertThrowsError(try validator.validateSemanticRules(fileNode)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      if case .emptyOneof(let name) = validationError {
        XCTAssertEqual(name, "test_oneof", "Error should contain the oneof name")
      }
      else {
        XCTFail("Expected emptyOneof error")
      }
    }
  }

  /// Test validating a message with an invalid field number.
  func testInvalidFieldNumber() {
    // Create a message with an invalid field number
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage",
      fields: [
        FieldNode(
          location: SourceLocation(line: 2, column: 3),
          name: "test_field",
          type: .scalar(.int32),
          number: 0,  // Invalid field number (must be > 0)
          isRepeated: false,
          options: []
        )
      ],
      oneofs: [],
      options: []
    )

    // Create a file with the invalid message
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto",
      definitions: [messageNode]
    )

    // Should throw
    XCTAssertThrowsError(try validator.validateSemanticRules(fileNode)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      if case .invalidFieldNumber(let number, _) = validationError {
        XCTAssertEqual(number, 0, "Error should contain the invalid field number")
      }
      else {
        XCTFail("Expected invalidFieldNumber error")
      }
    }
  }

  /// Test validating a message with a field number in the reserved range.
  func testReservedFieldNumber() {
    // Create a message with a field number in the reserved range
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage",
      fields: [
        FieldNode(
          location: SourceLocation(line: 2, column: 3),
          name: "test_field",
          type: .scalar(.int32),
          number: 19500,  // Reserved range (19000-19999)
          isRepeated: false,
          options: []
        )
      ],
      oneofs: [],
      options: []
    )

    // Create a file with the invalid message
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto",
      definitions: [messageNode]
    )

    // Should throw
    XCTAssertThrowsError(try validator.validateSemanticRules(fileNode)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      if case .invalidFieldNumber(let number, _) = validationError {
        XCTAssertEqual(number, 19500, "Error should contain the invalid field number")
      }
      else {
        XCTFail("Expected invalidFieldNumber error")
      }
    }
  }

  /// Test validating a message with duplicate field numbers.
  func testDuplicateFieldNumbers() {
    // Create a message with duplicate field numbers
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage",
      fields: [
        FieldNode(
          location: SourceLocation(line: 2, column: 3),
          name: "first_field",
          type: .scalar(.int32),
          number: 1,
          isRepeated: false,
          options: []
        ),
        FieldNode(
          location: SourceLocation(line: 3, column: 3),
          name: "second_field",
          type: .scalar(.string),
          number: 1,  // Duplicate field number
          isRepeated: false,
          options: []
        ),
      ],
      oneofs: [],
      options: []
    )

    // Create a file with the invalid message
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto",
      definitions: [messageNode]
    )

    // Should throw
    XCTAssertThrowsError(try validator.validateSemanticRules(fileNode)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      if case .duplicateMessageFieldNumber(let number, let messageName) = validationError {
        XCTAssertEqual(number, 1, "Error should contain the duplicate field number")
        XCTAssertEqual(messageName, "TestMessage", "Error should contain the message name")
      }
      else {
        XCTFail("Expected duplicateMessageFieldNumber error")
      }
    }
  }

  /// Test validating a message with a repeated map field.
  func testRepeatedMapField() {
    // Create a message with a repeated map field
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage",
      fields: [
        FieldNode(
          location: SourceLocation(line: 2, column: 3),
          name: "test_map",
          type: .map(key: .string, value: .scalar(.int32)),
          number: 1,
          isRepeated: true,  // Invalid for map fields
          options: []
        )
      ],
      oneofs: [],
      options: []
    )

    // Create a file with the invalid message
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto",
      definitions: [messageNode]
    )

    // Should throw
    XCTAssertThrowsError(try validator.validateSemanticRules(fileNode)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      if case .repeatedMapField(let name) = validationError {
        XCTAssertEqual(name, "test_map", "Error should contain the field name")
      }
      else {
        XCTFail("Expected repeatedMapField error")
      }
    }
  }

  /// Test validating a message with nested messages and enums.
  func testNestedTypesValidation() {
    // Create a nested enum with invalid first value
    let nestedEnum = EnumNode(
      location: SourceLocation(line: 5, column: 5),
      name: "NestedEnum",
      values: [
        EnumValueNode(
          location: SourceLocation(line: 6, column: 7),
          name: "FIRST",
          number: 1,  // Should be 0 in proto3
          options: []
        )
      ],
      options: []
    )

    // Create a nested message with a oneof that has a field
    let nestedMessage = MessageNode(
      location: SourceLocation(line: 10, column: 5),
      name: "NestedMessage",
      fields: [],
      oneofs: [
        OneofNode(
          location: SourceLocation(line: 11, column: 7),
          name: "nested_oneof",
          fields: [
            FieldNode(
              location: SourceLocation(line: 12, column: 9),
              name: "oneof_field",
              type: .scalar(.int32),
              number: 1,
              isRepeated: false,
              options: []
            )
          ]
        )
      ],
      options: []
    )

    // Create a parent message with the nested types
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "ParentMessage",
      fields: [
        FieldNode(
          location: SourceLocation(line: 2, column: 3),
          name: "test_field",
          type: .scalar(.int32),
          number: 1,
          isRepeated: false,
          options: []
        )
      ],
      oneofs: [],
      options: [],
      messages: [nestedMessage],
      enums: [nestedEnum]
    )

    // Create a file with the invalid message
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto",
      imports: [],
      options: [],
      definitions: [messageNode]
    )

    // Should throw for the nested enum first
    XCTAssertThrowsError(try validator.validateSemanticRules(fileNode)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      if case .firstEnumValueNotZero(let name) = validationError {
        XCTAssertEqual(name, "NestedEnum", "Error should contain the enum name")
      }
      else {
        XCTFail("Expected firstEnumValueNotZero error, got \(validationError)")
      }
    }
  }

  /// Test validating a valid message.
  func testValidMessage() {
    // Create a valid message
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage",
      fields: [
        FieldNode(
          location: SourceLocation(line: 2, column: 3),
          name: "first_field",
          type: .scalar(.int32),
          number: 1,
          isRepeated: false,
          options: []
        ),
        FieldNode(
          location: SourceLocation(line: 3, column: 3),
          name: "second_field",
          type: .scalar(.string),
          number: 2,
          isRepeated: true,
          options: []
        ),
        FieldNode(
          location: SourceLocation(line: 4, column: 3),
          name: "map_field",
          type: .map(key: .string, value: .scalar(.int32)),
          number: 3,
          isRepeated: false,
          options: []
        ),
      ],
      oneofs: [
        OneofNode(
          location: SourceLocation(line: 5, column: 3),
          name: "test_oneof",
          fields: [
            FieldNode(
              location: SourceLocation(line: 6, column: 5),
              name: "oneof_field_1",
              type: .scalar(.int32),
              number: 4,
              isRepeated: false,
              options: []
            ),
            FieldNode(
              location: SourceLocation(line: 7, column: 5),
              name: "oneof_field_2",
              type: .scalar(.string),
              number: 5,
              isRepeated: false,
              options: []
            ),
          ]
        )
      ],
      options: []
    )

    // Create a file with the valid message
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto",
      definitions: [messageNode]
    )

    // Should not throw
    XCTAssertNoThrow(try validator.validateSemanticRules(fileNode))
  }

  // MARK: - Service Validation Tests

  /// Test validating a service with duplicate method names.
  func testDuplicateMethodNames() {
    // Create a service with duplicate method names
    let serviceNode = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestService",
      rpcs: [
        RPCNode(
          location: SourceLocation(line: 2, column: 3),
          name: "TestMethod",
          inputType: "TestRequest",
          outputType: "TestResponse",
          clientStreaming: false,
          serverStreaming: false,
          options: []
        ),
        RPCNode(
          location: SourceLocation(line: 3, column: 3),
          name: "TestMethod",  // Duplicate method name
          inputType: "AnotherRequest",
          outputType: "AnotherResponse",
          clientStreaming: false,
          serverStreaming: false,
          options: []
        ),
      ],
      options: []
    )

    // Create a file with the invalid service
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto",
      definitions: [serviceNode]
    )

    // Should throw
    XCTAssertThrowsError(try validator.validateSemanticRules(fileNode)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      if case .duplicateMethodName(let name) = validationError {
        XCTAssertEqual(name, "TestMethod", "Error should contain the method name")
      }
      else {
        XCTFail("Expected duplicateMethodName error")
      }
    }
  }

  /// Test validating a valid service.
  func testValidService() {
    // Create a valid service
    let serviceNode = ServiceNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestService",
      rpcs: [
        RPCNode(
          location: SourceLocation(line: 2, column: 3),
          name: "Method1",
          inputType: "TestRequest",
          outputType: "TestResponse",
          clientStreaming: false,
          serverStreaming: false,
          options: []
        ),
        RPCNode(
          location: SourceLocation(line: 3, column: 3),
          name: "Method2",
          inputType: "AnotherRequest",
          outputType: "AnotherResponse",
          clientStreaming: true,
          serverStreaming: true,
          options: []
        ),
      ],
      options: []
    )

    // Create a file with the valid service
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto",
      definitions: [serviceNode]
    )

    // Should not throw
    XCTAssertNoThrow(try validator.validateSemanticRules(fileNode))
  }

  // MARK: - Complex File Validation Tests

  /// Test validating a complex file with multiple definitions.
  func testComplexFileValidation() {
    // Create a valid enum
    let enumNode = EnumNode(
      location: SourceLocation(line: 5, column: 1),
      name: "TestEnum",
      values: [
        EnumValueNode(
          location: SourceLocation(line: 6, column: 3),
          name: "FIRST",
          number: 0,
          options: []
        ),
        EnumValueNode(
          location: SourceLocation(line: 7, column: 3),
          name: "SECOND",
          number: 1,
          options: []
        ),
      ],
      options: []
    )

    // Create a valid message
    let messageNode = MessageNode(
      location: SourceLocation(line: 10, column: 1),
      name: "TestMessage",
      fields: [
        FieldNode(
          location: SourceLocation(line: 11, column: 3),
          name: "enum_field",
          type: .named("TestEnum"),
          number: 1,
          isRepeated: false,
          options: []
        )
      ],
      oneofs: [],
      options: []
    )

    // Create a valid service
    let serviceNode = ServiceNode(
      location: SourceLocation(line: 15, column: 1),
      name: "TestService",
      rpcs: [
        RPCNode(
          location: SourceLocation(line: 16, column: 3),
          name: "TestMethod",
          inputType: "TestMessage",
          outputType: "TestMessage",
          clientStreaming: false,
          serverStreaming: false,
          options: []
        )
      ],
      options: []
    )

    // Create a file with all the valid definitions
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto",
      definitions: [enumNode, messageNode, serviceNode]
    )

    // Should not throw
    XCTAssertNoThrow(try validator.validateSemanticRules(fileNode))
  }
}
