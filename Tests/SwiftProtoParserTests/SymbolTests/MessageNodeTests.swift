import XCTest

@testable import SwiftProtoParser

/// Test suite for MessageNode.
///
/// This test suite verifies the functionality of the MessageNode component
/// according to the acceptance criteria defined in ACCEPTANCE_CRITERIA.md.
///
/// Acceptance Criteria:
/// - Create messages with various fields and nested types
/// - Validate message names
/// - Handle message options
/// - Support nested messages and enums
/// - Track field numbers and names
/// - Validate reserved fields
/// - Manage type references
final class MessageNodeTests: XCTestCase {

  // MARK: - Basic Message Tests

  /// Test creating a basic message.
  ///
  /// This test verifies that a basic message can be created and validated.
  func testBasicMessage() throws {
    // Create a basic message
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage",
      fields: []
    )

    // Verify properties
    XCTAssertEqual(messageNode.name, "TestMessage", "Message name should match")
    XCTAssertEqual(messageNode.location.line, 1, "Message location line should match")
    XCTAssertEqual(messageNode.location.column, 1, "Message location column should match")
    XCTAssertTrue(messageNode.fields.isEmpty, "Message should have no fields by default")
    XCTAssertTrue(messageNode.oneofs.isEmpty, "Message should have no oneofs by default")
    XCTAssertTrue(messageNode.options.isEmpty, "Message should have no options by default")
    XCTAssertTrue(messageNode.reserved.isEmpty, "Message should have no reserved fields by default")
    XCTAssertTrue(messageNode.messages.isEmpty, "Message should have no nested messages by default")
    XCTAssertTrue(messageNode.enums.isEmpty, "Message should have no nested enums by default")

    // Validation should not throw
    XCTAssertNoThrow(try messageNode.validate(), "Valid message should pass validation")
  }

  /// Test creating a message with fields.
  ///
  /// This test verifies that a message with fields can be created and validated.
  func testMessageWithFields() throws {
    // Create fields
    let field1 = FieldNode(
      location: SourceLocation(line: 2, column: 3),
      name: "field1",
      type: .scalar(.string),
      number: 1
    )

    let field2 = FieldNode(
      location: SourceLocation(line: 3, column: 3),
      name: "field2",
      type: .scalar(.int32),
      number: 2,
      isRepeated: true
    )

    // Create a message with fields
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage",
      fields: [field1, field2]
    )

    // Verify properties
    XCTAssertEqual(messageNode.fields.count, 2, "Message should have 2 fields")
    XCTAssertEqual(messageNode.fields[0].name, "field1", "First field name should match")
    XCTAssertEqual(messageNode.fields[1].name, "field2", "Second field name should match")
    XCTAssertEqual(messageNode.fields[0].number, 1, "First field number should match")
    XCTAssertEqual(messageNode.fields[1].number, 2, "Second field number should match")

    // Test usedFieldNumbers
    let usedNumbers = messageNode.usedFieldNumbers
    XCTAssertEqual(usedNumbers.count, 2, "Should have 2 used field numbers")
    XCTAssertTrue(usedNumbers.contains(1), "Should contain field number 1")
    XCTAssertTrue(usedNumbers.contains(2), "Should contain field number 2")

    // Test usedFieldNames
    let usedNames = messageNode.usedFieldNames
    XCTAssertEqual(usedNames.count, 2, "Should have 2 used field names")
    XCTAssertTrue(usedNames.contains("field1"), "Should contain field name 'field1'")
    XCTAssertTrue(usedNames.contains("field2"), "Should contain field name 'field2'")

    // Validation should not throw
    XCTAssertNoThrow(try messageNode.validate(), "Valid message should pass validation")
  }

  /// Test creating a message with oneofs.
  ///
  /// This test verifies that a message with oneofs can be created and validated.
  func testMessageWithOneofs() throws {
    // Create oneof fields
    let oneofField1 = FieldNode(
      location: SourceLocation(line: 3, column: 5),
      name: "oneof_field1",
      type: .scalar(.string),
      number: 1
    )

    let oneofField2 = FieldNode(
      location: SourceLocation(line: 4, column: 5),
      name: "oneof_field2",
      type: .scalar(.int32),
      number: 2
    )

    // Create a oneof
    let oneof = OneofNode(
      location: SourceLocation(line: 2, column: 3),
      name: "test_oneof",
      fields: [oneofField1, oneofField2]
    )

    // Create a message with oneof
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage",
      fields: [],
      oneofs: [oneof]
    )

    // Verify properties
    XCTAssertEqual(messageNode.oneofs.count, 1, "Message should have 1 oneof")
    XCTAssertEqual(messageNode.oneofs[0].name, "test_oneof", "Oneof name should match")
    XCTAssertEqual(messageNode.oneofs[0].fields.count, 2, "Oneof should have 2 fields")

    // Test usedFieldNumbers (should include oneof fields)
    let usedNumbers = messageNode.usedFieldNumbers
    XCTAssertEqual(usedNumbers.count, 2, "Should have 2 used field numbers")
    XCTAssertTrue(usedNumbers.contains(1), "Should contain field number 1")
    XCTAssertTrue(usedNumbers.contains(2), "Should contain field number 2")

    // Test usedFieldNames (should include oneof fields)
    let usedNames = messageNode.usedFieldNames
    XCTAssertEqual(usedNames.count, 2, "Should have 2 used field names")
    XCTAssertTrue(usedNames.contains("oneof_field1"), "Should contain field name 'oneof_field1'")
    XCTAssertTrue(usedNames.contains("oneof_field2"), "Should contain field name 'oneof_field2'")

    // Validation should not throw
    XCTAssertNoThrow(try messageNode.validate(), "Valid message should pass validation")
  }

  /// Test creating a message with options.
  ///
  /// This test verifies that a message with options can be created and validated.
  func testMessageWithOptions() throws {
    // Create options
    let option1 = OptionNode(
      location: SourceLocation(line: 2, column: 3),
      name: "deprecated",
      value: .identifier("true")
    )

    let option2 = OptionNode(
      location: SourceLocation(line: 3, column: 3),
      name: "message_set_wire_format",
      value: .identifier("false")
    )

    // Create a message with options
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage",
      fields: [],
      oneofs: [],
      options: [option1, option2]
    )

    // Verify properties
    XCTAssertEqual(messageNode.options.count, 2, "Message should have 2 options")
    XCTAssertEqual(messageNode.options[0].name, "deprecated", "First option name should match")
    XCTAssertEqual(messageNode.options[1].name, "message_set_wire_format", "Second option name should match")

    // Validation should not throw
    XCTAssertNoThrow(try messageNode.validate(), "Valid message should pass validation")
  }

  /// Test creating a message with reserved fields.
  ///
  /// This test verifies that a message with reserved fields can be created and validated.
  func testMessageWithReservedFields() throws {
    // Create reserved ranges
    let reserved1 = ReservedNode(
      location: SourceLocation(line: 2, column: 3),
      ranges: [.single(1), .range(start: 3, end: 5)]
    )

    let reserved2 = ReservedNode(
      location: SourceLocation(line: 3, column: 3),
      ranges: [.name("old_field"), .name("deprecated_field")]
    )

    // Create a message with reserved fields
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage",
      fields: [],
      oneofs: [],
      options: [],
      reserved: [reserved1, reserved2]
    )

    // Verify properties
    XCTAssertEqual(messageNode.reserved.count, 2, "Message should have 2 reserved nodes")

    // Test reservedNumbers
    let reservedNumbers = messageNode.reservedNumbers
    XCTAssertEqual(reservedNumbers.count, 4, "Should have 4 reserved numbers")
    XCTAssertTrue(reservedNumbers.contains(1), "Should contain reserved number 1")
    XCTAssertTrue(reservedNumbers.contains(3), "Should contain reserved number 3")
    XCTAssertTrue(reservedNumbers.contains(4), "Should contain reserved number 4")
    XCTAssertTrue(reservedNumbers.contains(5), "Should contain reserved number 5")

    // Test reservedNames
    let reservedNames = messageNode.reservedNames
    XCTAssertEqual(reservedNames.count, 2, "Should have 2 reserved names")
    XCTAssertTrue(reservedNames.contains("old_field"), "Should contain reserved name 'old_field'")
    XCTAssertTrue(reservedNames.contains("deprecated_field"), "Should contain reserved name 'deprecated_field'")

    // Validation should not throw
    XCTAssertNoThrow(try messageNode.validate(), "Valid message should pass validation")
  }

  // MARK: - Nested Type Tests

  /// Test creating a message with nested messages.
  ///
  /// This test verifies that a message with nested messages can be created and validated.
  func testMessageWithNestedMessages() throws {
    // Create nested message
    let nestedMessage = MessageNode(
      location: SourceLocation(line: 2, column: 3),
      name: "NestedMessage",
      fields: [
        FieldNode(
          location: SourceLocation(line: 3, column: 5),
          name: "nested_field",
          type: .scalar(.string),
          number: 1
        )
      ]
    )

    // Create a message with nested message
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage",
      fields: [],
      oneofs: [],
      options: [],
      reserved: [],
      messages: [nestedMessage]
    )

    // Verify properties
    XCTAssertEqual(messageNode.messages.count, 1, "Message should have 1 nested message")
    XCTAssertEqual(messageNode.messages[0].name, "NestedMessage", "Nested message name should match")
    XCTAssertEqual(messageNode.messages[0].fields.count, 1, "Nested message should have 1 field")

    // Test findNestedType
    let foundType = messageNode.findNestedType("NestedMessage")
    XCTAssertNotNil(foundType, "Should find nested message by name")
    XCTAssertEqual(foundType?.name, "NestedMessage", "Found nested type name should match")

    // Test allNestedDefinitions
    let allNestedDefs = messageNode.allNestedDefinitions
    XCTAssertEqual(allNestedDefs.count, 1, "Should have 1 nested definition")
    XCTAssertEqual(allNestedDefs[0].name, "NestedMessage", "Nested definition name should match")

    // Validation should not throw
    XCTAssertNoThrow(try messageNode.validate(), "Valid message should pass validation")
  }

  /// Test creating a message with nested enums.
  ///
  /// This test verifies that a message with nested enums can be created and validated.
  func testMessageWithNestedEnums() throws {
    // Create nested enum
    let nestedEnum = EnumNode(
      location: SourceLocation(line: 2, column: 3),
      name: "NestedEnum",
      values: [
        EnumValueNode(
          location: SourceLocation(line: 3, column: 5),
          name: "UNKNOWN",
          number: 0
        ),
        EnumValueNode(
          location: SourceLocation(line: 4, column: 5),
          name: "VALUE1",
          number: 1
        ),
      ]
    )

    // Create a message with nested enum
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage",
      fields: [],
      oneofs: [],
      options: [],
      reserved: [],
      messages: [],
      enums: [nestedEnum]
    )

    // Verify properties
    XCTAssertEqual(messageNode.enums.count, 1, "Message should have 1 nested enum")
    XCTAssertEqual(messageNode.enums[0].name, "NestedEnum", "Nested enum name should match")
    XCTAssertEqual(messageNode.enums[0].values.count, 2, "Nested enum should have 2 values")

    // Test findNestedType
    let foundType = messageNode.findNestedType("NestedEnum")
    XCTAssertNotNil(foundType, "Should find nested enum by name")
    XCTAssertEqual(foundType?.name, "NestedEnum", "Found nested type name should match")

    // Test allNestedDefinitions
    let allNestedDefs = messageNode.allNestedDefinitions
    XCTAssertEqual(allNestedDefs.count, 1, "Should have 1 nested definition")
    XCTAssertEqual(allNestedDefs[0].name, "NestedEnum", "Nested definition name should match")

    // Validation should not throw
    XCTAssertNoThrow(try messageNode.validate(), "Valid message should pass validation")
  }

  /// Test creating a message with deeply nested types.
  ///
  /// This test verifies that a message with deeply nested types can be created and validated.
  func testMessageWithDeeplyNestedTypes() throws {
    // Create deeply nested message
    let deeplyNestedMessage = MessageNode(
      location: SourceLocation(line: 4, column: 7),
      name: "DeeplyNestedMessage",
      fields: [
        FieldNode(
          location: SourceLocation(line: 5, column: 9),
          name: "deeply_nested_field",
          type: .scalar(.string),
          number: 1
        )
      ]
    )

    // Create nested message with deeply nested message
    let nestedMessage = MessageNode(
      location: SourceLocation(line: 2, column: 3),
      name: "NestedMessage",
      fields: [],
      oneofs: [],
      options: [],
      reserved: [],
      messages: [deeplyNestedMessage]
    )

    // Create a message with nested message
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage",
      fields: [],
      oneofs: [],
      options: [],
      reserved: [],
      messages: [nestedMessage]
    )

    // Verify properties
    XCTAssertEqual(messageNode.messages.count, 1, "Message should have 1 nested message")
    XCTAssertEqual(messageNode.messages[0].name, "NestedMessage", "Nested message name should match")
    XCTAssertEqual(messageNode.messages[0].messages.count, 1, "Nested message should have 1 nested message")
    XCTAssertEqual(
      messageNode.messages[0].messages[0].name,
      "DeeplyNestedMessage",
      "Deeply nested message name should match"
    )

    // Test allNestedDefinitions (should include deeply nested types)
    let allNestedDefs = messageNode.allNestedDefinitions
    XCTAssertEqual(allNestedDefs.count, 2, "Should have 2 nested definitions")

    let nestedNames = allNestedDefs.map { $0.name }
    XCTAssertTrue(nestedNames.contains("NestedMessage"), "Should contain NestedMessage")
    XCTAssertTrue(nestedNames.contains("DeeplyNestedMessage"), "Should contain DeeplyNestedMessage")

    // Validation should not throw
    XCTAssertNoThrow(try messageNode.validate(), "Valid message should pass validation")
  }

  // MARK: - Type Reference Tests

  /// Test type references in message fields.
  ///
  /// This test verifies that type references in message fields are correctly tracked.
  func testTypeReferences() throws {
    // Create fields with type references
    let field1 = FieldNode(
      location: SourceLocation(line: 2, column: 3),
      name: "user",
      type: .named("User"),
      number: 1
    )

    let field2 = FieldNode(
      location: SourceLocation(line: 3, column: 3),
      name: "addresses",
      type: .named("Address"),
      number: 2,
      isRepeated: true
    )

    let field3 = FieldNode(
      location: SourceLocation(line: 4, column: 3),
      name: "metadata",
      type: .map(key: .string, value: .named("Metadata")),
      number: 3
    )

    // Create a message with type references
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage",
      fields: [field1, field2, field3]
    )

    // Test typeReferences
    let references = messageNode.typeReferences
    XCTAssertEqual(references.count, 3, "Should have 3 type references")
    XCTAssertTrue(references.contains("User"), "Should reference User type")
    XCTAssertTrue(references.contains("Address"), "Should reference Address type")
    XCTAssertTrue(references.contains("Metadata"), "Should reference Metadata type")
  }

  /// Test type references in oneof fields.
  ///
  /// This test verifies that type references in oneof fields are correctly tracked.
  func testTypeReferencesInOneofs() throws {
    // Create oneof fields with type references
    let oneofField1 = FieldNode(
      location: SourceLocation(line: 3, column: 5),
      name: "user_data",
      type: .named("UserData"),
      number: 1
    )

    let oneofField2 = FieldNode(
      location: SourceLocation(line: 4, column: 5),
      name: "company_data",
      type: .named("CompanyData"),
      number: 2
    )

    // Create a oneof
    let oneof = OneofNode(
      location: SourceLocation(line: 2, column: 3),
      name: "data",
      fields: [oneofField1, oneofField2]
    )

    // Create a message with oneof
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage",
      fields: [],
      oneofs: [oneof]
    )

    // Test typeReferences (should include oneof field references)
    let references = messageNode.typeReferences
    XCTAssertEqual(references.count, 2, "Should have 2 type references")
    XCTAssertTrue(references.contains("UserData"), "Should reference UserData type")
    XCTAssertTrue(references.contains("CompanyData"), "Should reference CompanyData type")
  }

  // MARK: - Validation Tests

  /// Test validation of invalid message name.
  ///
  /// This test verifies that validation fails for a message with an invalid name.
  func testInvalidMessageNameValidation() throws {
    // Create a message with invalid name (lowercase)
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "invalidName",
      fields: []
    )

    // Validation should throw
    XCTAssertThrowsError(try messageNode.validate()) { error in
      guard let parserError = error as? ParserError else {
        XCTFail("Expected ParserError")
        return
      }

      if case .invalidMessageName(let name) = parserError {
        XCTAssertEqual(name, "invalidName", "Error should contain the invalid name")
      }
      else {
        XCTFail("Expected invalidMessageName error")
      }
    }
  }

  /// Test validation of duplicate field numbers.
  ///
  /// This test verifies that validation fails for a message with duplicate field numbers.
  func testDuplicateFieldNumberValidation() throws {
    // Create fields with duplicate numbers
    let field1 = FieldNode(
      location: SourceLocation(line: 2, column: 3),
      name: "field1",
      type: .scalar(.string),
      number: 1
    )

    let field2 = FieldNode(
      location: SourceLocation(line: 3, column: 3),
      name: "field2",
      type: .scalar(.int32),
      number: 1  // Duplicate number
    )

    // Create a message with duplicate field numbers
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage",
      fields: [field1, field2]
    )

    // Check that usedFieldNumbers correctly identifies the duplicate
    let usedNumbers = messageNode.usedFieldNumbers
    XCTAssertEqual(usedNumbers.count, 1, "Should have 1 unique field number")
    XCTAssertTrue(usedNumbers.contains(1), "Should contain field number 1")

    // Create a field with a different number to verify the test is working correctly
    let field3 = FieldNode(
      location: SourceLocation(line: 4, column: 3),
      name: "field3",
      type: .scalar(.int32),
      number: 2  // Different number
    )

    let messageNodeWithUniqueNumbers = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage",
      fields: [field1, field3]
    )

    let uniqueNumbers = messageNodeWithUniqueNumbers.usedFieldNumbers
    XCTAssertEqual(uniqueNumbers.count, 2, "Should have 2 unique field numbers")
  }

  /// Test validation of invalid field numbers.
  ///
  /// This test verifies that validation fails for a message with invalid field numbers.
  func testInvalidFieldNumberValidation() throws {
    // Test cases for invalid field numbers
    let invalidNumbers = [0, -1, 537_000_000, 19_500]  // 0, negative, too large, reserved range

    for invalidNumber in invalidNumbers {
      // Create field with invalid number
      let field = FieldNode(
        location: SourceLocation(line: 2, column: 3),
        name: "field",
        type: .scalar(.string),
        number: invalidNumber
      )

      // Create a message with invalid field number
      let messageNode = MessageNode(
        location: SourceLocation(line: 1, column: 1),
        name: "TestMessage",
        fields: [field]
      )

      // Validation should throw
      XCTAssertThrowsError(try messageNode.validate(), "Field number \(invalidNumber) should be invalid")
    }
  }

  /// Test validation of reserved field conflicts.
  ///
  /// This test verifies that validation fails for a message with fields that conflict with reserved fields.
  func testReservedFieldConflictValidation() throws {
    // Create reserved ranges
    let reserved = ReservedNode(
      location: SourceLocation(line: 2, column: 3),
      ranges: [.single(1), .name("reserved_field")]
    )

    // Create fields that conflict with reserved fields
    let field1 = FieldNode(
      location: SourceLocation(line: 3, column: 3),
      name: "field1",
      type: .scalar(.string),
      number: 1  // Conflicts with reserved number
    )

    let field2 = FieldNode(
      location: SourceLocation(line: 4, column: 3),
      name: "reserved_field",  // Conflicts with reserved name
      type: .scalar(.int32),
      number: 2
    )

    // Test number conflict
    let messageWithNumberConflict = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage",
      fields: [field1],
      reserved: [reserved]
    )

    // Validation should throw for number conflict
    XCTAssertThrowsError(try messageWithNumberConflict.validate(), "Reserved number conflict should be invalid")

    // Test name conflict
    let messageWithNameConflict = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage",
      fields: [field2],
      reserved: [reserved]
    )

    // Validation should throw for name conflict
    XCTAssertThrowsError(try messageWithNameConflict.validate(), "Reserved name conflict should be invalid")
  }

  /// Test validation of duplicate nested type names.
  ///
  /// This test verifies that validation fails for a message with duplicate nested type names.
  func testDuplicateNestedTypeNameValidation() throws {
    // Create nested message and enum with the same name
    let nestedMessage = MessageNode(
      location: SourceLocation(line: 2, column: 3),
      name: "Nested",
      fields: []
    )

    let nestedEnum = EnumNode(
      location: SourceLocation(line: 3, column: 3),
      name: "Nested",  // Duplicate name
      values: [
        EnumValueNode(
          location: SourceLocation(line: 4, column: 5),
          name: "VALUE",
          number: 0
        )
      ]
    )

    // Create a message with duplicate nested type names
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage",
      fields: [],
      oneofs: [],
      options: [],
      reserved: [],
      messages: [nestedMessage],
      enums: [nestedEnum]
    )

    // Validation should throw
    XCTAssertThrowsError(try messageNode.validate(), "Expected validation to fail with duplicate nested type name")
  }

  /// Test validation of nested types.
  ///
  /// This test verifies that validation of a message includes validation of nested types.
  func testNestedTypeValidation() throws {
    // Create nested message with invalid name
    let nestedMessage = MessageNode(
      location: SourceLocation(line: 2, column: 3),
      name: "invalidName",  // Invalid name (lowercase)
      fields: []
    )

    // Create a message with invalid nested message
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage",
      fields: [],
      oneofs: [],
      options: [],
      reserved: [],
      messages: [nestedMessage]
    )

    // Validation should throw due to invalid nested message
    XCTAssertThrowsError(try messageNode.validate())
  }
}
