import XCTest

@testable import SwiftProtoParser

/// Tests for Proto3 message validation rules.
final class MessageValidationTests: XCTestCase {
  // Test validator
  private var validator: ValidatorV2!

  override func setUp() {
    super.setUp()
    validator = ValidatorV2()
  }

  override func tearDown() {
    validator = nil
    super.tearDown()
  }

  // MARK: - Message Name Format Tests

  func testValidMessageNames() throws {
    // Test valid message name formats (CamelCase)
    let validMessageNames = [
      "Message",
      "TestMessage",
      "Test",
      "M",
      "Test123",
      "TestMessage123",
      "Test123Message",
      "TestMessageWithVeryLongName",
      "TestMessage_WithUnderscore",  // Valid but not recommended
      "M1",
    ]

    for messageName in validMessageNames {
      let messageNode = MessageNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        trailingComment: nil,
        name: messageName,
        fields: [
          FieldNode(
            location: SourceLocation(line: 2, column: 3),
            leadingComments: [],
            trailingComment: nil,
            name: "field1",
            type: .scalar(.string),
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
      XCTAssertNoThrow(
        try validator.validate(file),
        "Message name '\(messageName)' should be valid"
      )
    }
  }

  func testInvalidMessageNames() throws {
    // Test invalid message name formats
    let invalidMessageNames = [
      "message",  // Starts with lowercase
      "test_message",  // snake_case
      "TEST_MESSAGE",  // SCREAMING_SNAKE_CASE
      "1Message",  // Starts with number
      "_Message",  // Starts with underscore
      "Test-Message",  // Contains hyphen
      "Test Message",  // Contains space
      "Test.Message",  // Contains dot
      "Test:Message",  // Contains colon
      "Test;Message",  // Contains semicolon
      "Test,Message",  // Contains comma
      "Test+Message",  // Contains plus
      "Test*Message",  // Contains asterisk
      "Test/Message",  // Contains slash
      "Test\\Message",  // Contains backslash
      "Test@Message",  // Contains at sign
      "Test#Message",  // Contains hash
      "Test$Message",  // Contains dollar sign
      "Test%Message",  // Contains percent
      "Test^Message",  // Contains caret
      "Test&Message",  // Contains ampersand
      "Test(Message",  // Contains opening parenthesis
      "Test)Message",  // Contains closing parenthesis
      "Test=Message",  // Contains equals sign
      "Test!Message",  // Contains exclamation mark
      "Test?Message",  // Contains question mark
      "",  // Empty name
    ]

    for messageName in invalidMessageNames {
      let messageNode = MessageNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        trailingComment: nil,
        name: messageName,
        fields: [
          FieldNode(
            location: SourceLocation(line: 2, column: 3),
            leadingComments: [],
            trailingComment: nil,
            name: "field1",
            type: .scalar(.string),
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

      // This should throw an invalidMessageName error
      XCTAssertThrowsError(
        try validator.validate(file),
        "Message name '\(messageName)' should be invalid"
      ) { error in
        guard let validationError = error as? ValidationError else {
          XCTFail("Expected ValidationError for message name '\(messageName)'")
          return
        }

        switch validationError {
        case .invalidMessageName(let name):
          XCTAssertEqual(name, messageName)
        default:
          XCTFail("Expected invalidMessageName error for '\(messageName)', got \(validationError)")
        }
      }
    }
  }

  // MARK: - Field Number Uniqueness Tests

  func testDuplicateFieldNumber() throws {
    // Create a message with duplicate field numbers
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
          type: .scalar(.string),
          number: 1,
          isRepeated: false,
          isOptional: false,
          oneof: nil,
          options: []
        ),
        FieldNode(
          location: SourceLocation(line: 3, column: 3),
          leadingComments: [],
          trailingComment: nil,
          name: "field2",
          type: .scalar(.int32),
          number: 1,  // Duplicate field number
          isRepeated: false,
          isOptional: false,
          oneof: nil,
          options: []
        ),
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

    // This should throw a duplicateMessageFieldNumber error
    XCTAssertThrowsError(try validator.validate(file)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      switch validationError {
      case .duplicateMessageFieldNumber(let number, let messageName):
        XCTAssertEqual(number, 1)
        XCTAssertEqual(messageName, "TestMessage")
      default:
        XCTFail("Expected duplicateMessageFieldNumber error, got \(validationError)")
      }
    }
  }

  // MARK: - Field Number Range Tests

  func testFieldNumberRange() throws {
    // Test field numbers within valid range
    let validFieldNumbers = [1, 2, 10, 100, 1000, 10000, 100000, 536_870_911]

    for fieldNumber in validFieldNumbers {
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
            type: .scalar(.string),
            number: fieldNumber,
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
      XCTAssertNoThrow(try validator.validate(file), "Field number \(fieldNumber) should be valid")
    }

    // Test field numbers outside valid range
    let invalidFieldNumbers = [0, -1, -10, 536_870_912, 1_000_000_000]

    for fieldNumber in invalidFieldNumbers {
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
            type: .scalar(.string),
            number: fieldNumber,
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

      // This should throw an invalidFieldNumber error
      XCTAssertThrowsError(
        try validator.validate(file),
        "Field number \(fieldNumber) should be invalid"
      ) { error in
        guard let validationError = error as? ValidationError else {
          XCTFail("Expected ValidationError for field number \(fieldNumber)")
          return
        }

        switch validationError {
        case .invalidFieldNumber(let number, _):
          XCTAssertEqual(number, fieldNumber)
        default:
          XCTFail("Expected invalidFieldNumber error for \(fieldNumber), got \(validationError)")
        }
      }
    }

    // Test field numbers in reserved range (19000-19999)
    let reservedFieldNumbers = [19000, 19500, 19999]

    for fieldNumber in reservedFieldNumbers {
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
            type: .scalar(.string),
            number: fieldNumber,
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

      // This should throw an invalidFieldNumber error
      XCTAssertThrowsError(
        try validator.validate(file),
        "Field number \(fieldNumber) should be invalid (reserved)"
      ) { error in
        guard let validationError = error as? ValidationError else {
          XCTFail("Expected ValidationError for field number \(fieldNumber)")
          return
        }

        switch validationError {
        case .invalidFieldNumber(let number, _):
          XCTAssertEqual(number, fieldNumber)
        default:
          XCTFail("Expected invalidFieldNumber error for \(fieldNumber), got \(validationError)")
        }
      }
    }
  }

  // MARK: - Field Name Format Tests

  func testValidFieldNames() throws {
    // Test valid field name formats (snake_case)
    let validFieldNames = [
      "field",
      "field_name",
      "field_name_with_underscore",
      "f",
      "field_1",
      "field_123",
      "f1",
      "f_1",
      "f1_field",
      "field_name_with_very_long_name",
    ]

    for fieldName in validFieldNames {
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
            name: fieldName,
            type: .scalar(.string),
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
      XCTAssertNoThrow(try validator.validate(file), "Field name '\(fieldName)' should be valid")
    }
  }

  func testInvalidFieldNames() throws {
    // Test invalid field name formats
    let invalidFieldNames = [
      "Field",  // Starts with uppercase
      "fieldName",  // camelCase
      "FieldName",  // CamelCase
      "FIELD_NAME",  // SCREAMING_SNAKE_CASE
      "1field",  // Starts with number
      "_field",  // Starts with underscore
      "field-name",  // Contains hyphen
      "field name",  // Contains space
      "field.name",  // Contains dot
      "field:name",  // Contains colon
      "field;name",  // Contains semicolon
      "field,name",  // Contains comma
      "field+name",  // Contains plus
      "field*name",  // Contains asterisk
      "field/name",  // Contains slash
      "field\\name",  // Contains backslash
      "field@name",  // Contains at sign
      "field#name",  // Contains hash
      "field$name",  // Contains dollar sign
      "field%name",  // Contains percent
      "field^name",  // Contains caret
      "field&name",  // Contains ampersand
      "field(name",  // Contains opening parenthesis
      "field)name",  // Contains closing parenthesis
      "field=name",  // Contains equals sign
      "field!name",  // Contains exclamation mark
      "field?name",  // Contains question mark
      "",  // Empty name
    ]

    for fieldName in invalidFieldNames {
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
            name: fieldName,
            type: .scalar(.string),
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

      // This should throw an invalidFieldName error
      XCTAssertThrowsError(
        try validator.validate(file),
        "Field name '\(fieldName)' should be invalid"
      ) { error in
        guard let validationError = error as? ValidationError else {
          XCTFail("Expected ValidationError for field name '\(fieldName)'")
          return
        }

        switch validationError {
        case .invalidFieldName(let name):
          XCTAssertEqual(name, fieldName)
        default:
          XCTFail("Expected invalidFieldName error for '\(fieldName)', got \(validationError)")
        }
      }
    }
  }

  // MARK: - Field Name Uniqueness Tests

  func testDuplicateFieldNames() throws {
    // Create a message with duplicate field names
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
          name: "field_name",
          type: .scalar(.string),
          number: 1,
          isRepeated: false,
          isOptional: false,
          oneof: nil,
          options: []
        ),
        FieldNode(
          location: SourceLocation(line: 3, column: 3),
          leadingComments: [],
          trailingComment: nil,
          name: "field_name",  // Duplicate field name
          type: .scalar(.int32),
          number: 2,
          isRepeated: false,
          isOptional: false,
          oneof: nil,
          options: []
        ),
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

    // This should throw a duplicateFieldName error
    XCTAssertThrowsError(try validator.validate(file)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      switch validationError {
      case .duplicateFieldName(let fieldName, let inType):
        XCTAssertEqual(fieldName, "field_name")
        XCTAssertEqual(inType, "TestMessage")
      default:
        XCTFail("Expected duplicateFieldName error, got \(validationError)")
      }
    }
  }

  // MARK: - Empty Message Tests

  func testEmptyMessage() throws {
    // Create an empty message (no fields)
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "TestMessage",
      fields: [],
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

    // This should not throw (empty messages are valid)
    XCTAssertNoThrow(try validator.validate(file))
  }

  // MARK: - Nested Type Name Uniqueness Tests

  func testDuplicateNestedTypeNames() throws {
    // Create a message with duplicate nested type names
    let nestedMessage1 = MessageNode(
      location: SourceLocation(line: 3, column: 3),
      leadingComments: [],
      trailingComment: nil,
      name: "NestedType",
      fields: [],
      oneofs: [],
      options: []
    )

    let nestedEnum = EnumNode(
      location: SourceLocation(line: 4, column: 3),
      leadingComments: [],
      trailingComment: nil,
      name: "NestedType",  // Duplicate name
      values: [
        EnumValueNode(
          location: SourceLocation(line: 5, column: 5),
          leadingComments: [],
          trailingComment: nil,
          name: "VALUE",
          number: 0,
          options: []
        )
      ],
      options: []
    )

    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "TestMessage",
      fields: [],
      oneofs: [],
      options: [],
      messages: [nestedMessage1],
      enums: [nestedEnum]
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

    // This should throw a duplicateNestedTypeName error
    XCTAssertThrowsError(try validator.validate(file)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      switch validationError {
      case .duplicateNestedTypeName(let name):
        XCTAssertEqual(name, "NestedType")
      default:
        XCTFail("Expected duplicateNestedTypeName error, got \(validationError)")
      }
    }
  }
}
