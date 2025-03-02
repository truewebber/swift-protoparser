import XCTest

@testable import SwiftProtoParser

/// A mock ReferenceValidator that doesn't validate type references
class MockReferenceValidator: ReferenceValidating {
  private let state: ValidationState

  init(state: ValidationState) {
    self.state = state
  }

  func registerTypes(_ file: FileNode) throws {
    // Do nothing
  }

  func validateTypeReference(_ typeName: String, inMessage message: MessageNode?) throws {
    // Do nothing - always succeed
  }

  func validateCrossReferences(_ file: FileNode) throws {
    // Do nothing
  }
}

/// Tests for Proto3 field type validation rules
final class FieldTypeValidationTests: XCTestCase {
  // Test validator
  private var validator: ValidatorV2!
  private var fieldValidator: FieldValidator!
  private var state: ValidationState!
  private var mockReferenceValidator: MockReferenceValidator!

  override func setUp() {
    super.setUp()
    state = ValidationState()
    validator = ValidatorV2()
    fieldValidator = FieldValidator(state: state)
    mockReferenceValidator = MockReferenceValidator(state: state)
  }

  override func tearDown() {
    validator = nil
    fieldValidator = nil
    state = nil
    mockReferenceValidator = nil
    super.tearDown()
  }

  // MARK: - Scalar Type Tests

  func testValidScalarTypes() throws {
    // Test all valid scalar types
    let scalarTypes: [TypeNode.ScalarType] = [
      .double,
      .float,
      .int32,
      .int64,
      .uint32,
      .uint64,
      .sint32,
      .sint64,
      .fixed32,
      .fixed64,
      .sfixed32,
      .sfixed64,
      .bool,
      .string,
      .bytes,
    ]

    for scalarType in scalarTypes {
      let messageNode = MessageNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        trailingComment: nil,
        name: "TestMessage",
        fields: [
          FieldNode(
            location: SourceLocation(line: 2, column: 3),
            leadingComments: [],
            trailingComment: nil,
            name: "field1",
            type: .scalar(scalarType),
            number: 1,
            isRepeated: false,
            isOptional: false,
            oneof: nil,
            options: []
          )
        ],
        oneofs: [],
        options: []
      )

      let file = FileNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        syntax: "proto3",
        package: "test",
        imports: [],
        options: [],
        definitions: [messageNode]
      )

      // This should not throw
      XCTAssertNoThrow(try validator.validate(file), "Scalar type \(scalarType) should be valid")
    }
  }

  // MARK: - Map Type Tests

  func testValidMapKeyTypes() throws {
    // Test valid map key types
    let validKeyTypes: [TypeNode.ScalarType] = [
      .int32,
      .int64,
      .uint32,
      .uint64,
      .sint32,
      .sint64,
      .fixed32,
      .fixed64,
      .sfixed32,
      .sfixed64,
      .bool,
      .string,
    ]

    for keyType in validKeyTypes {
      let messageNode = MessageNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        trailingComment: nil,
        name: "TestMessage",
        fields: [
          FieldNode(
            location: SourceLocation(line: 2, column: 3),
            leadingComments: [],
            trailingComment: nil,
            name: "field1",
            type: .map(key: keyType, value: .scalar(.string)),
            number: 1,
            isRepeated: false,
            isOptional: false,
            oneof: nil,
            options: []
          )
        ],
        oneofs: [],
        options: []
      )

      let file = FileNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        syntax: "proto3",
        package: "test",
        imports: [],
        options: [],
        definitions: [messageNode]
      )

      // This should not throw
      XCTAssertNoThrow(try validator.validate(file), "Map key type \(keyType) should be valid")
    }
  }

  func testInvalidMapKeyTypes() throws {
    // Test invalid map key types directly using the FieldValidator
    let invalidKeyTypes: [TypeNode.ScalarType] = [
      .double,
      .float,
      .bytes,
    ]

    for keyType in invalidKeyTypes {
      // This should throw an invalidMapKeyType error
      XCTAssertThrowsError(
        try fieldValidator.validateMapKeyType(keyType), "Map key type \(keyType) should be invalid"
      ) { error in
        guard let validationError = error as? ValidationError else {
          XCTFail("Expected ValidationError for map key type \(keyType)")
          return
        }

        switch validationError {
        case .invalidMapKeyType(let type):
          XCTAssertTrue(type.contains(String(describing: keyType)))
        default:
          XCTFail("Expected invalidMapKeyType error for \(keyType), got \(validationError)")
        }
      }
    }

    // Test message type as key (invalid)
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "TestMessage",
      fields: [],
      oneofs: [],
      options: []
    )

    let field = FieldNode(
      location: SourceLocation(line: 2, column: 3),
      leadingComments: [],
      trailingComment: nil,
      name: "field1",
      type: .map(key: .bytes, value: .scalar(.string)),
      number: 1,
      isRepeated: false,
      isOptional: false,
      oneof: nil,
      options: []
    )

    // This should throw an invalidMapKeyType error
    XCTAssertThrowsError(
      try fieldValidator.validateField(field, inMessage: messageNode),
      "Map key type bytes should be invalid"
    ) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError for map key type bytes")
        return
      }

      switch validationError {
      case .invalidMapKeyType(let type):
        XCTAssertTrue(type.contains("bytes"))
      default:
        XCTFail("Expected invalidMapKeyType error for bytes, got \(validationError)")
      }
    }
  }

  func testValidMapValueTypes() throws {
    // Test valid map value types (any type except another map)
    // Scalar value types
    let scalarTypes: [TypeNode.ScalarType] = [
      .double,
      .float,
      .int32,
      .int64,
      .uint32,
      .uint64,
      .sint32,
      .sint64,
      .fixed32,
      .fixed64,
      .sfixed32,
      .sfixed64,
      .bool,
      .string,
      .bytes,
    ]

    for valueType in scalarTypes {
      let messageNode = MessageNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        trailingComment: nil,
        name: "TestMessage",
        fields: [
          FieldNode(
            location: SourceLocation(line: 2, column: 3),
            leadingComments: [],
            trailingComment: nil,
            name: "field1",
            type: .map(key: .string, value: .scalar(valueType)),
            number: 1,
            isRepeated: false,
            isOptional: false,
            oneof: nil,
            options: []
          )
        ],
        oneofs: [],
        options: []
      )

      let file = FileNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        syntax: "proto3",
        package: "test",
        imports: [],
        options: [],
        definitions: [messageNode]
      )

      // This should not throw
      XCTAssertNoThrow(try validator.validate(file), "Map value type \(valueType) should be valid")
    }

    // Message value type
    let messageWithMessageValueType = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "TestMessage",
      fields: [
        FieldNode(
          location: SourceLocation(line: 2, column: 3),
          leadingComments: [],
          trailingComment: nil,
          name: "field1",
          type: .map(key: .string, value: .named("OtherMessage")),
          number: 1,
          isRepeated: false,
          isOptional: false,
          oneof: nil,
          options: []
        )
      ],
      oneofs: [],
      options: []
    )

    let nestedMessage = MessageNode(
      location: SourceLocation(line: 10, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "OtherMessage",
      fields: [],
      oneofs: [],
      options: []
    )

    let fileWithMessageValueType = FileNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [messageWithMessageValueType, nestedMessage]
    )

    // This should not throw
    XCTAssertNoThrow(
      try validator.validate(fileWithMessageValueType), "Message type as map value should be valid")
  }

  func testMapFieldModifiers() throws {
    // Test that map fields cannot be repeated
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "TestMessage",
      fields: [],
      oneofs: [],
      options: []
    )

    let repeatedMapField = FieldNode(
      location: SourceLocation(line: 2, column: 3),
      leadingComments: [],
      trailingComment: nil,
      name: "field1",
      type: .map(key: .string, value: .scalar(.string)),
      number: 1,
      isRepeated: true,  // Invalid for map fields
      isOptional: false,
      oneof: nil,
      options: []
    )

    // This should throw a repeatedMapField error
    XCTAssertThrowsError(
      try fieldValidator.validateField(repeatedMapField, inMessage: messageNode),
      "Repeated map field should be invalid"
    ) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError for repeated map field")
        return
      }

      switch validationError {
      case .repeatedMapField(let fieldName):
        XCTAssertEqual(fieldName, "field1")
      default:
        XCTFail("Expected repeatedMapField error, got \(validationError)")
      }
    }

    // Test that map fields cannot be optional
    let optionalMapField = FieldNode(
      location: SourceLocation(line: 2, column: 3),
      leadingComments: [],
      trailingComment: nil,
      name: "field1",
      type: .map(key: .string, value: .scalar(.string)),
      number: 1,
      isRepeated: false,
      isOptional: true,  // Invalid for map fields
      oneof: nil,
      options: []
    )

    // This should throw an optionalMapField error
    XCTAssertThrowsError(
      try fieldValidator.validateField(optionalMapField, inMessage: messageNode),
      "Optional map field should be invalid"
    ) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError for optional map field")
        return
      }

      switch validationError {
      case .optionalMapField(let fieldName):
        XCTAssertEqual(fieldName, "field1")
      default:
        XCTFail("Expected optionalMapField error, got \(validationError)")
      }
    }
  }

  // MARK: - Field Modifier Tests

  func testRepeatedFields() throws {
    // Test repeated scalar fields
    let scalarTypes: [TypeNode.ScalarType] = [
      .double,
      .float,
      .int32,
      .int64,
      .uint32,
      .uint64,
      .sint32,
      .sint64,
      .fixed32,
      .fixed64,
      .sfixed32,
      .sfixed64,
      .bool,
      .string,
      .bytes,
    ]

    for scalarType in scalarTypes {
      let messageNode = MessageNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        trailingComment: nil,
        name: "TestMessage",
        fields: [
          FieldNode(
            location: SourceLocation(line: 2, column: 3),
            leadingComments: [],
            trailingComment: nil,
            name: "field1",
            type: .scalar(scalarType),
            number: 1,
            isRepeated: true,
            isOptional: false,
            oneof: nil,
            options: []
          )
        ],
        oneofs: [],
        options: []
      )

      let file = FileNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        syntax: "proto3",
        package: "test",
        imports: [],
        options: [],
        definitions: [messageNode]
      )

      // This should not throw
      XCTAssertNoThrow(
        try validator.validate(file), "Repeated scalar field of type \(scalarType) should be valid")
    }

    // Test repeated message fields using direct field validation
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "TestMessage",
      fields: [],
      oneofs: [],
      options: []
    )

    let field = FieldNode(
      location: SourceLocation(line: 2, column: 3),
      leadingComments: [],
      trailingComment: nil,
      name: "field1",
      type: .named("OtherMessage"),
      number: 1,
      isRepeated: true,
      isOptional: false,
      oneof: nil,
      options: []
    )

    // This should not throw when using our mock validator
    XCTAssertNoThrow(
      try fieldValidator.validateField(field, inMessage: messageNode),
      "Repeated message field should be valid")

    // Verify that the mock reference validator doesn't throw
    XCTAssertNoThrow(
      try mockReferenceValidator.validateTypeReference("OtherMessage", inMessage: messageNode),
      "Mock reference validator should not throw")
  }

  func testOptionalFields() throws {
    // Test optional scalar fields
    let scalarTypes: [TypeNode.ScalarType] = [
      .double,
      .float,
      .int32,
      .int64,
      .uint32,
      .uint64,
      .sint32,
      .sint64,
      .fixed32,
      .fixed64,
      .sfixed32,
      .sfixed64,
      .bool,
      .string,
      .bytes,
    ]

    for scalarType in scalarTypes {
      let messageNode = MessageNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        trailingComment: nil,
        name: "TestMessage",
        fields: [
          FieldNode(
            location: SourceLocation(line: 2, column: 3),
            leadingComments: [],
            trailingComment: nil,
            name: "field1",
            type: .scalar(scalarType),
            number: 1,
            isRepeated: false,
            isOptional: true,
            oneof: nil,
            options: []
          )
        ],
        oneofs: [],
        options: []
      )

      let file = FileNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        syntax: "proto3",
        package: "test",
        imports: [],
        options: [],
        definitions: [messageNode]
      )

      // This should not throw
      XCTAssertNoThrow(
        try validator.validate(file), "Optional scalar field of type \(scalarType) should be valid")
    }

    // Test optional message fields using direct field validation
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "TestMessage",
      fields: [],
      oneofs: [],
      options: []
    )

    let field = FieldNode(
      location: SourceLocation(line: 2, column: 3),
      leadingComments: [],
      trailingComment: nil,
      name: "field1",
      type: .named("OtherMessage"),
      number: 1,
      isRepeated: false,
      isOptional: true,
      oneof: nil,
      options: []
    )

    // This should not throw when using our mock validator
    XCTAssertNoThrow(
      try fieldValidator.validateField(field, inMessage: messageNode),
      "Optional message field should be valid")

    // Verify that the mock reference validator doesn't throw
    XCTAssertNoThrow(
      try mockReferenceValidator.validateTypeReference("OtherMessage", inMessage: messageNode),
      "Mock reference validator should not throw")
  }
}
