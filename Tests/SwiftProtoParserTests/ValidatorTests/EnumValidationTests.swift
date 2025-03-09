import XCTest

@testable import SwiftProtoParser

/// Tests for Proto3 enum validation rules.
final class EnumValidationTests: XCTestCase {
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

  // MARK: - First Value Must Be Zero Tests

  func testEnumFirstValueMustBeZero() throws {
    // Create an enum with first value not zero
    let enumNode = EnumNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "TestEnum",
      values: [
        EnumValueNode(
          location: SourceLocation(line: 2, column: 3),
          leadingComments: [],
          trailingComment: nil,
          name: "FIRST",
          number: 1,  // Should be 0
          options: []
        )
      ],
      options: []
    )

    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [enumNode]
    )

    // This should throw a firstEnumValueNotZero error
    XCTAssertThrowsError(try validator.validate(file)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      switch validationError {
      case .firstEnumValueNotZero(let name):
        XCTAssertEqual(name, "TestEnum")
      default:
        XCTFail("Expected firstEnumValueNotZero error, got \(validationError)")
      }
    }
  }

  func testEnumFirstValueIsZero() throws {
    // Create an enum with first value as zero (valid)
    let enumNode = EnumNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "TestEnum",
      values: [
        EnumValueNode(
          location: SourceLocation(line: 2, column: 3),
          leadingComments: [],
          trailingComment: nil,
          name: "FIRST",
          number: 0,  // Correct
          options: []
        ),
        EnumValueNode(
          location: SourceLocation(line: 3, column: 3),
          leadingComments: [],
          trailingComment: nil,
          name: "SECOND",
          number: 1,
          options: []
        ),
      ],
      options: []
    )

    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [enumNode]
    )

    // This should not throw
    XCTAssertNoThrow(try validator.validate(file))
  }

  // MARK: - Enum Name Format Tests

  func testValidEnumNames() throws {
    // Test valid enum name formats (CamelCase)
    let validEnumNames = [
      "TestEnum",
      "Test",
      "T",
      "Test123",
      "TestEnum123",
      "Test123Enum",
      "TestEnumWithVeryLongName",
      "TestEnum_WithUnderscore",  // Valid but not recommended
      "T1",
    ]

    for enumName in validEnumNames {
      let enumNode = EnumNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        trailingComment: nil,
        name: enumName,
        values: [
          EnumValueNode(
            location: SourceLocation(line: 2, column: 3),
            leadingComments: [],
            trailingComment: nil,
            name: "FIRST",
            number: 0,
            options: []
          )
        ],
        options: []
      )

      let file = FileNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        syntax: "proto3",
        package: "test",
        imports: [],
        options: [],
        definitions: [enumNode]
      )

      // This should not throw
      XCTAssertNoThrow(try validator.validate(file), "Enum name '\(enumName)' should be valid")
    }
  }

  func testInvalidEnumNames() throws {
    // Test invalid enum name formats
    let invalidEnumNames = [
      "testEnum",  // Starts with lowercase
      "test_enum",  // snake_case
      "TEST_ENUM",  // SCREAMING_SNAKE_CASE
      "1Test",  // Starts with number
      "_Test",  // Starts with underscore
      "Test-Enum",  // Contains hyphen
      "Test Enum",  // Contains space
      "Test.Enum",  // Contains dot
      "Test:Enum",  // Contains colon
      "Test;Enum",  // Contains semicolon
      "Test,Enum",  // Contains comma
      "Test+Enum",  // Contains plus
      "Test*Enum",  // Contains asterisk
      "Test/Enum",  // Contains slash
      "Test\\Enum",  // Contains backslash
      "Test@Enum",  // Contains at sign
      "Test#Enum",  // Contains hash
      "Test$Enum",  // Contains dollar sign
      "Test%Enum",  // Contains percent
      "Test^Enum",  // Contains caret
      "Test&Enum",  // Contains ampersand
      "Test(Enum",  // Contains opening parenthesis
      "Test)Enum",  // Contains closing parenthesis
      "Test=Enum",  // Contains equals sign
      "Test!Enum",  // Contains exclamation mark
      "Test?Enum",  // Contains question mark
      "",  // Empty name
    ]

    for enumName in invalidEnumNames {
      let enumNode = EnumNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        trailingComment: nil,
        name: enumName,
        values: [
          EnumValueNode(
            location: SourceLocation(line: 2, column: 3),
            leadingComments: [],
            trailingComment: nil,
            name: "FIRST",
            number: 0,
            options: []
          )
        ],
        options: []
      )

      let file = FileNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        syntax: "proto3",
        package: "test",
        imports: [],
        options: [],
        definitions: [enumNode]
      )

      // This should throw an invalidEnumName error
      XCTAssertThrowsError(
        try validator.validate(file),
        "Enum name '\(enumName)' should be invalid"
      ) { error in
        guard let validationError = error as? ValidationError else {
          XCTFail("Expected ValidationError for enum name '\(enumName)'")
          return
        }

        switch validationError {
        case .invalidEnumName(let name):
          XCTAssertEqual(name, enumName)
        default:
          XCTFail("Expected invalidEnumName error for '\(enumName)', got \(validationError)")
        }
      }
    }
  }

  // MARK: - Enum Value Name Format Tests

  func testValidEnumValueNames() throws {
    // Test valid enum value name formats (SCREAMING_SNAKE_CASE)
    let validEnumValueNames = [
      "FIRST",
      "FIRST_VALUE",
      "FIRST_VALUE_WITH_UNDERSCORE",
      "F",
      "VALUE_1",
      "VALUE_123",
      "V1",
      "V_1",
      "V1_VALUE",
      "FIRST_VALUE_WITH_VERY_LONG_NAME",
    ]

    for valueName in validEnumValueNames {
      let enumNode = EnumNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        trailingComment: nil,
        name: "TestEnum",
        values: [
          EnumValueNode(
            location: SourceLocation(line: 2, column: 3),
            leadingComments: [],
            trailingComment: nil,
            name: valueName,
            number: 0,
            options: []
          )
        ],
        options: []
      )

      let file = FileNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        syntax: "proto3",
        package: "test",
        imports: [],
        options: [],
        definitions: [enumNode]
      )

      // This should not throw
      XCTAssertNoThrow(
        try validator.validate(file),
        "Enum value name '\(valueName)' should be valid"
      )
    }
  }

  func testInvalidEnumValueNames() throws {
    // Test invalid enum value name formats
    let invalidEnumValueNames = [
      "first",  // Lowercase
      "First",  // CamelCase
      "first_value",  // snake_case
      "FirstValue",  // CamelCase
      "1FIRST",  // Starts with number
      "_FIRST",  // Starts with underscore
      "FIRST-VALUE",  // Contains hyphen
      "FIRST VALUE",  // Contains space
      "FIRST.VALUE",  // Contains dot
      "FIRST:VALUE",  // Contains colon
      "FIRST;VALUE",  // Contains semicolon
      "FIRST,VALUE",  // Contains comma
      "FIRST+VALUE",  // Contains plus
      "FIRST*VALUE",  // Contains asterisk
      "FIRST/VALUE",  // Contains slash
      "FIRST\\VALUE",  // Contains backslash
      "FIRST@VALUE",  // Contains at sign
      "FIRST#VALUE",  // Contains hash
      "FIRST$VALUE",  // Contains dollar sign
      "FIRST%VALUE",  // Contains percent
      "FIRST^VALUE",  // Contains caret
      "FIRST&VALUE",  // Contains ampersand
      "FIRST(VALUE",  // Contains opening parenthesis
      "FIRST)VALUE",  // Contains closing parenthesis
      "FIRST=VALUE",  // Contains equals sign
      "FIRST!VALUE",  // Contains exclamation mark
      "FIRST?VALUE",  // Contains question mark
      "",  // Empty name
    ]

    for valueName in invalidEnumValueNames {
      let enumNode = EnumNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        trailingComment: nil,
        name: "TestEnum",
        values: [
          EnumValueNode(
            location: SourceLocation(line: 2, column: 3),
            leadingComments: [],
            trailingComment: nil,
            name: valueName,
            number: 0,
            options: []
          )
        ],
        options: []
      )

      let file = FileNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        syntax: "proto3",
        package: "test",
        imports: [],
        options: [],
        definitions: [enumNode]
      )

      // This should throw an invalidEnumValueName error
      XCTAssertThrowsError(
        try validator.validate(file),
        "Enum value name '\(valueName)' should be invalid"
      ) { error in
        guard let validationError = error as? ValidationError else {
          XCTFail("Expected ValidationError for enum value name '\(valueName)'")
          return
        }

        switch validationError {
        case .invalidEnumValueName(let name):
          XCTAssertEqual(name, valueName)
        default:
          XCTFail("Expected invalidEnumValueName error for '\(valueName)', got \(validationError)")
        }
      }
    }
  }

  // MARK: - Enum Value Uniqueness Tests

  func testDuplicateEnumValueNames() throws {
    // Create an enum with duplicate value names
    let enumNode = EnumNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "TestEnum",
      values: [
        EnumValueNode(
          location: SourceLocation(line: 2, column: 3),
          leadingComments: [],
          trailingComment: nil,
          name: "FIRST",
          number: 0,
          options: []
        ),
        EnumValueNode(
          location: SourceLocation(line: 3, column: 3),
          leadingComments: [],
          trailingComment: nil,
          name: "FIRST",  // Duplicate name
          number: 1,
          options: []
        ),
      ],
      options: []
    )

    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [enumNode]
    )

    // This should throw a duplicateEnumValue error
    XCTAssertThrowsError(try validator.validate(file)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      switch validationError {
      case .duplicateEnumValue(let name, _):
        XCTAssertEqual(name, "FIRST")
      default:
        XCTFail("Expected duplicateEnumValue error, got \(validationError)")
      }
    }
  }

  func testDuplicateEnumValueNumbers() throws {
    // Create an enum with duplicate value numbers (without allow_alias)
    let enumNode = EnumNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "TestEnum",
      values: [
        EnumValueNode(
          location: SourceLocation(line: 2, column: 3),
          leadingComments: [],
          trailingComment: nil,
          name: "FIRST",
          number: 0,
          options: []
        ),
        EnumValueNode(
          location: SourceLocation(line: 3, column: 3),
          leadingComments: [],
          trailingComment: nil,
          name: "SECOND",
          number: 0,  // Duplicate number
          options: []
        ),
      ],
      options: []
    )

    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [enumNode]
    )

    // This should throw a duplicateEnumValue error
    XCTAssertThrowsError(try validator.validate(file)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      switch validationError {
      case .duplicateEnumValue(_, let value):
        XCTAssertEqual(value, 0)
      default:
        XCTFail("Expected duplicateEnumValue error, got \(validationError)")
      }
    }
  }

  func testDuplicateEnumValueNumbersWithAllowAlias() throws {
    // Create an enum with duplicate value numbers (with allow_alias)
    // First, create the allow_alias option
    let allowAliasOption = OptionNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "allow_alias",
      value: .identifier("true")
    )

    let enumNode = EnumNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "TestEnum",
      values: [
        EnumValueNode(
          location: SourceLocation(line: 2, column: 3),
          leadingComments: [],
          trailingComment: nil,
          name: "FIRST",
          number: 0,
          options: []
        ),
        EnumValueNode(
          location: SourceLocation(line: 3, column: 3),
          leadingComments: [],
          trailingComment: nil,
          name: "SECOND",
          number: 0,  // Duplicate number, but allowed with allow_alias
          options: []
        ),
      ],
      options: [allowAliasOption],
      allowAlias: true
    )

    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [enumNode]
    )

    // This should not throw because allow_alias is set
    XCTAssertNoThrow(try validator.validate(file))
  }

  // MARK: - Empty Enum Tests

  func testEmptyEnum() throws {
    // Create an empty enum (no values)
    let enumNode = EnumNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      trailingComment: nil,
      name: "TestEnum",
      values: [],
      options: []
    )

    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: [enumNode]
    )

    // This should throw an emptyEnum error
    XCTAssertThrowsError(try validator.validate(file)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      switch validationError {
      case .emptyEnum(let name):
        XCTAssertEqual(name, "TestEnum")
      default:
        XCTFail("Expected emptyEnum error, got \(validationError)")
      }
    }
  }
}
