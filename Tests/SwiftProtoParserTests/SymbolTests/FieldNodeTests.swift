import XCTest

@testable import SwiftProtoParser

/// Test suite for FieldNode.
///
/// This test suite verifies the functionality of the FieldNode component
/// according to the acceptance criteria defined in ACCEPTANCE_CRITERIA.md.
///
/// Acceptance Criteria:.
/// - Create fields with various types (scalar, message, enum, map).
/// - Validate field names and numbers.
/// - Validate field options.
/// - Handle repeated and optional fields.
/// - Handle oneof fields.
/// - Validate proto3 specific rules.
final class FieldNodeTests: XCTestCase {

  // MARK: - Basic Field Tests

  /// Test creating a basic field with scalar type.
  ///
  /// This test verifies that a basic field with a scalar type can be created and validated.
  func testBasicScalarField() throws {
    // Create a basic field with scalar type
    let fieldNode = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "user_name",
      type: .scalar(.string),
      number: 1
    )

    // Verify properties
    XCTAssertEqual(fieldNode.name, "user_name", "Field name should match")
    XCTAssertEqual(fieldNode.number, 1, "Field number should match")

    if case .scalar(let scalarType) = fieldNode.type {
      XCTAssertEqual(scalarType, .string, "Field type should be string")
    }
    else {
      XCTFail("Field type should be scalar")
    }

    XCTAssertFalse(fieldNode.isRepeated, "Field should not be repeated by default")
    XCTAssertFalse(fieldNode.isOptional, "Field should not be optional by default")
    XCTAssertNil(fieldNode.oneof, "Field should not belong to a oneof by default")
    XCTAssertEqual(fieldNode.options.count, 0, "Field should have no options by default")
    XCTAssertNil(fieldNode.jsonName, "Field should have no JSON name by default")

    // Validation should not throw
    XCTAssertNoThrow(try fieldNode.validate(), "Valid field should pass validation")
  }

  /// Test creating a field with a message type.
  ///
  /// This test verifies that a field with a message type can be created and validated.
  func testMessageTypeField() throws {
    // Create a field with message type
    let fieldNode = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "user",
      type: .named("User"),
      number: 1
    )

    // Verify properties
    if case .named(let typeName) = fieldNode.type {
      XCTAssertEqual(typeName, "User", "Field type should be User")
    }
    else {
      XCTFail("Field type should be named")
    }

    // Validation should not throw
    XCTAssertNoThrow(try fieldNode.validate(), "Valid field should pass validation")
  }

  /// Test creating a field with a map type.
  ///
  /// This test verifies that a field with a map type can be created and validated.
  func testMapTypeField() throws {
    // Create a field with map type
    let fieldNode = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "metadata",
      type: .map(key: .string, value: .scalar(.string)),
      number: 1
    )

    // Verify properties
    if case .map(let keyType, let valueType) = fieldNode.type {
      XCTAssertEqual(keyType, .string, "Map key type should be string")

      if case .scalar(let scalarType) = valueType {
        XCTAssertEqual(scalarType, .string, "Map value type should be string")
      }
      else {
        XCTFail("Map value type should be scalar")
      }
    }
    else {
      XCTFail("Field type should be map")
    }

    // Validation should not throw
    XCTAssertNoThrow(try fieldNode.validate(), "Valid map field should pass validation")
  }

  // MARK: - Field Modifier Tests

  /// Test creating a repeated field.
  ///
  /// This test verifies that a repeated field can be created and validated.
  func testRepeatedField() throws {
    // Create a repeated field
    let fieldNode = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "tags",
      type: .scalar(.string),
      number: 1,
      isRepeated: true
    )

    // Verify properties
    XCTAssertTrue(fieldNode.isRepeated, "Field should be repeated")

    // Validation should not throw
    XCTAssertNoThrow(try fieldNode.validate(), "Valid repeated field should pass validation")
  }

  /// Test creating an optional field.
  ///
  /// This test verifies that an optional field can be created and validated.
  func testOptionalField() throws {
    // Create an optional field
    let fieldNode = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "nickname",
      type: .scalar(.string),
      number: 1,
      isOptional: true
    )

    // Verify properties
    XCTAssertTrue(fieldNode.isOptional, "Field should be optional")

    // Validation should not throw
    XCTAssertNoThrow(try fieldNode.validate(), "Valid optional field should pass validation")
  }

  // MARK: - Field Option Tests

  /// Test creating a field with options.
  ///
  /// This test verifies that a field with options can be created and validated.
  func testFieldWithOptions() throws {
    // Create options
    let deprecatedOption = OptionNode(
      location: SourceLocation(line: 2, column: 3),
      name: "deprecated",
      value: .identifier("true"),
      pathParts: []
    )

    let jsonNameOption = OptionNode(
      location: SourceLocation(line: 3, column: 3),
      name: "json_name",
      value: .string("userName"),
      pathParts: []
    )

    // Create a field with options
    let fieldNode = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "user_name",
      type: .scalar(.string),
      number: 1,
      options: [deprecatedOption, jsonNameOption],
      jsonName: "userName"
    )

    // Verify properties
    XCTAssertEqual(fieldNode.options.count, 2, "Field should have 2 options")
    XCTAssertEqual(fieldNode.options[0].name, "deprecated", "First option name should match")
    XCTAssertEqual(fieldNode.options[1].name, "json_name", "Second option name should match")
    XCTAssertEqual(fieldNode.jsonName, "userName", "JSON name should match")

    // Verify option values
    if case .identifier(let value) = fieldNode.options[0].value {
      XCTAssertEqual(value, "true", "Deprecated option value should be true")
    }
    else {
      XCTFail("Expected identifier value")
    }

    if case .string(let value) = fieldNode.options[1].value {
      XCTAssertEqual(value, "userName", "JSON name option value should match")
    }
    else {
      XCTFail("Expected string value")
    }

    // Validation should not throw
    XCTAssertNoThrow(try fieldNode.validate(), "Valid field with options should pass validation")
  }

  /// Test creating a field with packed option.
  ///
  /// This test verifies that a field with packed option can be created and validated.
  func testFieldWithPackedOption() throws {
    // Create packed option
    let packedOption = OptionNode(
      location: SourceLocation(line: 2, column: 3),
      name: "packed",
      value: .identifier("true"),
      pathParts: []
    )

    // Create a repeated field with packed option
    let fieldNode = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "values",
      type: .scalar(.int32),
      number: 1,
      isRepeated: true,
      options: [packedOption]
    )

    // Verify properties
    XCTAssertEqual(fieldNode.options.count, 1, "Field should have 1 option")
    XCTAssertEqual(fieldNode.options[0].name, "packed", "Option name should be packed")

    // Validation should not throw
    XCTAssertNoThrow(
      try fieldNode.validate(),
      "Valid field with packed option should pass validation"
    )
  }

  // MARK: - Oneof Field Tests

  /// Test creating a field in a oneof.
  ///
  /// This test verifies that a field in a oneof can be created and validated.
  func testOneofField() throws {
    // Create a oneof
    let oneofNode = OneofNode(
      location: SourceLocation(line: 1, column: 1),
      name: "contact",
      fields: []
    )

    // Create a field in the oneof
    let fieldNode = FieldNode(
      location: SourceLocation(line: 2, column: 3),
      name: "email",
      type: .scalar(.string),
      number: 1,
      oneof: oneofNode
    )

    // Verify properties
    XCTAssertNotNil(fieldNode.oneof, "Field should belong to a oneof")
    XCTAssertEqual(fieldNode.oneof?.name, "contact", "Oneof name should match")

    // Validation should not throw
    XCTAssertNoThrow(try fieldNode.validate(), "Valid field in oneof should pass validation")
  }

  // MARK: - Validation Error Tests

  /// Test validating a field with an invalid name.
  ///
  /// This test verifies that a field with an invalid name fails validation.
  func testInvalidFieldNameValidation() throws {
    // Test invalid field names
    let invalidFieldName1 = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "123invalid",  // Invalid: starts with a number
      type: .scalar(.int32),
      number: 1
    )

    XCTAssertThrowsError(try invalidFieldName1.validate()) { error in
      XCTAssertTrue(error is ParserError)
      if let parserError = error as? ParserError {
        switch parserError {
        case .invalidFieldName(let name):
          XCTAssertEqual(name, "123invalid")
        default:
          XCTFail("Expected invalidFieldName error but got \(parserError)")
        }
      }
    }

    let invalidFieldName2 = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Invalid-Name",  // Invalid: contains hyphen
      type: .scalar(.int32),
      number: 1
    )

    XCTAssertThrowsError(try invalidFieldName2.validate()) { error in
      XCTAssertTrue(error is ParserError)
      if let parserError = error as? ParserError {
        switch parserError {
        case .invalidFieldName(let name):
          XCTAssertEqual(name, "Invalid-Name")
        default:
          XCTFail("Expected invalidFieldName error but got \(parserError)")
        }
      }
    }

    let invalidFieldName3 = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "",  // Invalid: empty name
      type: .scalar(.int32),
      number: 1
    )

    XCTAssertThrowsError(try invalidFieldName3.validate()) { error in
      XCTAssertTrue(error is ParserError)
      if let parserError = error as? ParserError {
        switch parserError {
        case .invalidFieldName(let name):
          XCTAssertEqual(name, "")
        default:
          XCTFail("Expected invalidFieldName error but got \(parserError)")
        }
      }
    }

    let invalidFieldName4 = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Invalid.Name",  // Invalid: contains period
      type: .scalar(.int32),
      number: 1
    )

    XCTAssertThrowsError(try invalidFieldName4.validate()) { error in
      XCTAssertTrue(error is ParserError)
      if let parserError = error as? ParserError {
        switch parserError {
        case .invalidFieldName(let name):
          XCTAssertEqual(name, "Invalid.Name")
        default:
          XCTFail("Expected invalidFieldName error but got \(parserError)")
        }
      }
    }
  }

  /// Test validating a field with an invalid number.
  ///
  /// This test verifies that a field with an invalid number fails validation.
  func testInvalidFieldNumberValidation() throws {
    // Test negative field number
    let negativeFieldNumber = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "valid_field",
      type: .scalar(.int32),
      number: -1
    )

    XCTAssertThrowsError(try negativeFieldNumber.validate()) { error in
      XCTAssertTrue(error is ParserError)
      if let parserError = error as? ParserError {
        switch parserError {
        case .invalidFieldNumber(let num, _):
          XCTAssertEqual(num, -1)
        default:
          XCTFail("Expected invalidFieldNumber error but got \(parserError)")
        }
      }
    }

    // Test zero field number
    let zeroFieldNumber = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "valid_field",
      type: .scalar(.int32),
      number: 0
    )

    XCTAssertThrowsError(try zeroFieldNumber.validate()) { error in
      XCTAssertTrue(error is ParserError)
      if let parserError = error as? ParserError {
        switch parserError {
        case .invalidFieldNumber(let num, _):
          XCTAssertEqual(num, 0)
        default:
          XCTFail("Expected invalidFieldNumber error but got \(parserError)")
        }
      }
    }

    // Test too large field number
    let tooLargeFieldNumber = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "valid_field",
      type: .scalar(.int32),
      number: 536_870_912  // One more than max allowed
    )

    XCTAssertThrowsError(try tooLargeFieldNumber.validate()) { error in
      XCTAssertTrue(error is ParserError)
      if let parserError = error as? ParserError {
        switch parserError {
        case .invalidFieldNumber(let num, _):
          XCTAssertEqual(num, 536_870_912)
        default:
          XCTFail("Expected invalidFieldNumber error but got \(parserError)")
        }
      }
    }

    // Test reserved field number
    let reservedFieldNumber = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "valid_field",
      type: .scalar(.int32),
      number: 19000  // In reserved range
    )

    XCTAssertThrowsError(try reservedFieldNumber.validate()) { error in
      XCTAssertTrue(error is ParserError)
      if let parserError = error as? ParserError {
        switch parserError {
        case .custom(let message):
          XCTAssertTrue(message.contains("19000"), "Error should mention the reserved number")
        default:
          XCTFail("Expected custom error for reserved field number but got \(parserError)")
        }
      }
    }
  }

  /// Test validating a field with an invalid map key type.
  ///
  /// This test verifies that a field with an invalid map key type fails validation.
  func testInvalidMapKeyTypeValidation() throws {
    // Test invalid map key types
    let invalidMapKeyTypes = [
      TypeNode.ScalarType.bytes,
      TypeNode.ScalarType.float,
      TypeNode.ScalarType.double,
    ]

    for invalidKeyType in invalidMapKeyTypes {
      let invalidMapField = FieldNode(
        location: SourceLocation(line: 1, column: 1),
        name: "invalid_map",
        type: .map(key: invalidKeyType, value: .scalar(.string)),
        number: 1
      )

      XCTAssertThrowsError(try invalidMapField.validate()) { error in
        XCTAssertTrue(error is ParserError)
        if let parserError = error as? ParserError {
          switch parserError {
          case .invalidMapKeyType(let type):
            XCTAssertTrue(
              type.contains(String(describing: invalidKeyType)),
              "Error should mention the invalid key type"
            )
          default:
            XCTFail("Expected invalidMapKeyType error but got \(parserError)")
          }
        }
      }
    }
  }

  /// Test validating a repeated map field.
  ///
  /// This test verifies that a repeated map field fails validation.
  func testRepeatedMapFieldValidation() throws {
    // Test repeated map field (not allowed)
    let repeatedMapField = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "repeated_map",
      type: .map(key: .int32, value: .scalar(.string)),
      number: 1,
      isRepeated: true
    )

    XCTAssertThrowsError(try repeatedMapField.validate()) { error in
      XCTAssertTrue(error is ParserError)
      if let parserError = error as? ParserError {
        switch parserError {
        case .custom(let message):
          XCTAssertTrue(message.contains("repeated_map"), "Error should mention the field name")
          XCTAssertTrue(
            message.contains("cannot be repeated"),
            "Error should mention that maps cannot be repeated"
          )
        default:
          XCTFail("Expected custom error for repeated map field but got \(parserError)")
        }
      }
    }
  }

  /// Test validating a field with invalid options.
  ///
  /// This test verifies that a field with invalid options fails validation.
  func testInvalidFieldOptionsValidation() throws {
    // Test invalid deprecated option (non-boolean)
    let invalidDeprecatedOption = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "field_with_invalid_option",
      type: .scalar(.int32),
      number: 1,
      options: [
        OptionNode(
          location: SourceLocation(line: 1, column: 1),
          name: "deprecated",
          value: .string("not_a_boolean")
        )
      ]
    )

    XCTAssertThrowsError(try invalidDeprecatedOption.validate()) { error in
      XCTAssertTrue(error is ParserError)
      if let parserError = error as? ParserError {
        switch parserError {
        case .custom(let message):
          XCTAssertTrue(message.contains("deprecated"), "Error should mention the option name")
          XCTAssertTrue(message.contains("boolean"), "Error should mention boolean requirement")
        default:
          XCTFail("Expected custom error for invalid option but got \(parserError)")
        }
      }
    }

    // Test invalid packed option (non-boolean)
    let invalidPackedOption = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "field_with_invalid_option",
      type: .scalar(.int32),
      number: 1,
      isRepeated: true,
      options: [
        OptionNode(
          location: SourceLocation(line: 1, column: 1),
          name: "packed",
          value: .string("not_a_boolean")
        )
      ]
    )

    XCTAssertThrowsError(try invalidPackedOption.validate()) { error in
      XCTAssertTrue(error is ParserError)
      if let parserError = error as? ParserError {
        switch parserError {
        case .custom(let message):
          XCTAssertTrue(message.contains("packed"), "Error should mention the option name")
          XCTAssertTrue(message.contains("boolean"), "Error should mention boolean requirement")
        default:
          XCTFail("Expected custom error for invalid option but got \(parserError)")
        }
      }
    }

    // Test packed option on non-repeated field
    let packedNonRepeatedField = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "non_repeated_with_packed",
      type: .scalar(.int32),
      number: 1,
      options: [
        OptionNode(
          location: SourceLocation(line: 1, column: 1),
          name: "packed",
          value: .identifier("true")
        )
      ]
    )

    XCTAssertThrowsError(try packedNonRepeatedField.validate()) { error in
      XCTAssertTrue(error is ParserError)
      if let parserError = error as? ParserError {
        switch parserError {
        case .custom(let message):
          XCTAssertTrue(message.contains("packed"), "Error should mention the option name")
          XCTAssertTrue(message.contains("repeated"), "Error should mention repeated requirement")
        default:
          XCTFail("Expected custom error for invalid option but got \(parserError)")
        }
      }
    }

    // Test packed option on non-scalar field
    let packedNonScalarField = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "non_scalar_with_packed",
      type: .named("Message"),
      number: 1,
      isRepeated: true,
      options: [
        OptionNode(
          location: SourceLocation(line: 1, column: 1),
          name: "packed",
          value: .identifier("true")
        )
      ]
    )

    XCTAssertThrowsError(try packedNonScalarField.validate()) { error in
      XCTAssertTrue(error is ParserError)
      if let parserError = error as? ParserError {
        switch parserError {
        case .custom(let message):
          XCTAssertTrue(message.contains("packed"), "Error should mention the option name")
          XCTAssertTrue(message.contains("scalar"), "Error should mention scalar requirement")
        default:
          XCTFail("Expected custom error for invalid option but got \(parserError)")
        }
      }
    }

    // Test invalid json_name option (non-string)
    let invalidJsonNameOption = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "field_with_invalid_json_name",
      type: .scalar(.int32),
      number: 1,
      options: [
        OptionNode(
          location: SourceLocation(line: 1, column: 1),
          name: "json_name",
          value: .identifier("not_a_string")
        )
      ]
    )

    XCTAssertThrowsError(try invalidJsonNameOption.validate()) { error in
      XCTAssertTrue(error is ParserError)
      if let parserError = error as? ParserError {
        switch parserError {
        case .custom(let message):
          XCTAssertTrue(message.contains("json_name"), "Error should mention the option name")
          XCTAssertTrue(message.contains("string"), "Error should mention string requirement")
        default:
          XCTFail("Expected custom error for invalid option but got \(parserError)")
        }
      }
    }
  }

  /// Test validating a field with proto3 specific rules.
  ///
  /// This test verifies that a field with proto3 specific rules fails validation.
  func testProto3RulesValidation() throws {
    // Test required option (not allowed in proto3)
    let requiredField = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "required_field",
      type: .scalar(.int32),
      number: 1,
      options: [
        OptionNode(
          location: SourceLocation(line: 1, column: 1),
          name: "required",
          value: .identifier("true")
        )
      ]
    )

    XCTAssertThrowsError(try requiredField.validate()) { error in
      XCTAssertTrue(error is ParserError)
      if let parserError = error as? ParserError {
        switch parserError {
        case .custom(let message):
          XCTAssertTrue(message.contains("required"), "Error should mention the option name")
          XCTAssertTrue(message.contains("proto3"), "Error should mention proto3")
        default:
          XCTFail("Expected custom error for required field in proto3 but got \(parserError)")
        }
      }
    }

    // Test optional option without optional keyword
    let optionalWithoutKeyword = FieldNode(
      location: SourceLocation(line: 1, column: 1),
      name: "optional_field",
      type: .scalar(.int32),
      number: 1,
      isOptional: false,
      options: [
        OptionNode(
          location: SourceLocation(line: 1, column: 1),
          name: "optional",
          value: .identifier("true")
        )
      ]
    )

    XCTAssertThrowsError(try optionalWithoutKeyword.validate()) { error in
      XCTAssertTrue(error is ParserError)
      if let parserError = error as? ParserError {
        switch parserError {
        case .custom(let message):
          XCTAssertTrue(message.contains("optional"), "Error should mention the option name")
          XCTAssertTrue(message.contains("keyword"), "Error should mention keyword")
        default:
          XCTFail("Expected custom error for optional without keyword but got \(parserError)")
        }
      }
    }
  }
}
