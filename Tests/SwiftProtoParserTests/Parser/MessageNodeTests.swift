import XCTest

@testable import SwiftProtoParser

final class MessageNodeTests: XCTestCase {

  // MARK: - MessageNode Basic Tests

  func testMessageNodeBasicInitialization() {
    let message = MessageNode(name: "TestMessage")

    XCTAssertEqual(message.name, "TestMessage")
    XCTAssertTrue(message.fields.isEmpty)
    XCTAssertTrue(message.nestedMessages.isEmpty)
    XCTAssertTrue(message.nestedEnums.isEmpty)
    XCTAssertTrue(message.oneofGroups.isEmpty)
    XCTAssertTrue(message.options.isEmpty)
    XCTAssertTrue(message.reservedNumbers.isEmpty)
    XCTAssertTrue(message.reservedNames.isEmpty)

    XCTAssertTrue(message.usedFieldNumbers.isEmpty)
    XCTAssertTrue(message.usedFieldNames.isEmpty)
  }

  func testMessageNodeWithAllComponents() {
    let field1 = FieldNode(name: "field1", type: .string, number: 1)
    let field2 = FieldNode(name: "field2", type: .int32, number: 2)

    let nestedField = FieldNode(name: "nested_field", type: .bool, number: 1)
    let nestedMessage = MessageNode(name: "NestedMessage", fields: [nestedField])

    let enumValue = EnumValueNode(name: "VALUE_ONE", number: 1)
    let nestedEnum = EnumNode(name: "NestedEnum", values: [enumValue])

    let oneofField1 = FieldNode(name: "oneof_field1", type: .string, number: 10)
    let oneofField2 = FieldNode(name: "oneof_field2", type: .int32, number: 11)
    let oneofGroup = OneofNode(name: "test_oneof", fields: [oneofField1, oneofField2])

    let option = OptionNode(name: "deprecated", value: .boolean(true))

    let message = MessageNode(
      name: "ComplexMessage",
      fields: [field1, field2],
      nestedMessages: [nestedMessage],
      nestedEnums: [nestedEnum],
      oneofGroups: [oneofGroup],
      options: [option],
      reservedNumbers: [5, 6, 7],
      reservedNames: ["old_field1", "old_field2"]
    )

    XCTAssertEqual(message.name, "ComplexMessage")
    XCTAssertEqual(message.fields.count, 2)
    XCTAssertEqual(message.nestedMessages.count, 1)
    XCTAssertEqual(message.nestedEnums.count, 1)
    XCTAssertEqual(message.oneofGroups.count, 1)
    XCTAssertEqual(message.options.count, 1)
    XCTAssertEqual(message.reservedNumbers, [5, 6, 7])
    XCTAssertEqual(message.reservedNames, ["old_field1", "old_field2"])
  }

  // MARK: - Field Number and Name Tracking Tests

  func testUsedFieldNumbers() {
    let field1 = FieldNode(name: "field1", type: .string, number: 1)
    let field2 = FieldNode(name: "field2", type: .int32, number: 3)

    let oneofField1 = FieldNode(name: "oneof_field1", type: .string, number: 10)
    let oneofField2 = FieldNode(name: "oneof_field2", type: .int32, number: 11)
    let oneofGroup = OneofNode(name: "test_oneof", fields: [oneofField1, oneofField2])

    let message = MessageNode(
      name: "TestMessage",
      fields: [field1, field2],
      oneofGroups: [oneofGroup]
    )

    let expectedNumbers: Set<Int32> = [1, 3, 10, 11]
    XCTAssertEqual(message.usedFieldNumbers, expectedNumbers)
  }

  func testUsedFieldNames() {
    let field1 = FieldNode(name: "field1", type: .string, number: 1)
    let field2 = FieldNode(name: "field2", type: .int32, number: 3)

    let oneofField1 = FieldNode(name: "oneof_field1", type: .string, number: 10)
    let oneofField2 = FieldNode(name: "oneof_field2", type: .int32, number: 11)
    let oneofGroup = OneofNode(name: "test_oneof", fields: [oneofField1, oneofField2])

    let message = MessageNode(
      name: "TestMessage",
      fields: [field1, field2],
      oneofGroups: [oneofGroup]
    )

    let expectedNames: Set<String> = ["field1", "field2", "oneof_field1", "oneof_field2"]
    XCTAssertEqual(message.usedFieldNames, expectedNames)
  }

  func testUsedFieldNumbersAndNamesEmpty() {
    let message = MessageNode(name: "EmptyMessage")

    XCTAssertTrue(message.usedFieldNumbers.isEmpty)
    XCTAssertTrue(message.usedFieldNames.isEmpty)
  }

  // MARK: - Field Lookup Tests

  func testFieldLookupByName() {
    let field1 = FieldNode(name: "regular_field", type: .string, number: 1)
    let field2 = FieldNode(name: "another_field", type: .int32, number: 2)

    let oneofField = FieldNode(name: "oneof_field", type: .bool, number: 10)
    let oneofGroup = OneofNode(name: "test_oneof", fields: [oneofField])

    let message = MessageNode(
      name: "TestMessage",
      fields: [field1, field2],
      oneofGroups: [oneofGroup]
    )

    // Test finding regular fields
    XCTAssertEqual(message.field(named: "regular_field"), field1)
    XCTAssertEqual(message.field(named: "another_field"), field2)

    // Test finding oneof fields
    XCTAssertEqual(message.field(named: "oneof_field"), oneofField)

    // Test not found
    XCTAssertNil(message.field(named: "nonexistent_field"))
  }

  func testFieldLookupByNumber() {
    let field1 = FieldNode(name: "regular_field", type: .string, number: 1)
    let field2 = FieldNode(name: "another_field", type: .int32, number: 2)

    let oneofField = FieldNode(name: "oneof_field", type: .bool, number: 10)
    let oneofGroup = OneofNode(name: "test_oneof", fields: [oneofField])

    let message = MessageNode(
      name: "TestMessage",
      fields: [field1, field2],
      oneofGroups: [oneofGroup]
    )

    // Test finding regular fields
    XCTAssertEqual(message.field(withNumber: 1), field1)
    XCTAssertEqual(message.field(withNumber: 2), field2)

    // Test finding oneof fields
    XCTAssertEqual(message.field(withNumber: 10), oneofField)

    // Test not found
    XCTAssertNil(message.field(withNumber: 999))
  }

  func testFieldLookupEmptyMessage() {
    let message = MessageNode(name: "EmptyMessage")

    XCTAssertNil(message.field(named: "any_name"))
    XCTAssertNil(message.field(withNumber: 1))
  }

  // MARK: - MessageNode Equality Tests

  func testMessageNodeEquality() {
    let field = FieldNode(name: "field1", type: .string, number: 1)
    let option = OptionNode(name: "deprecated", value: .boolean(true))

    let message1 = MessageNode(
      name: "TestMessage",
      fields: [field],
      options: [option],
      reservedNumbers: [5],
      reservedNames: ["old_field"]
    )

    let message2 = MessageNode(
      name: "TestMessage",
      fields: [field],
      options: [option],
      reservedNumbers: [5],
      reservedNames: ["old_field"]
    )

    let message3 = MessageNode(
      name: "DifferentMessage",
      fields: [field],
      options: [option],
      reservedNumbers: [5],
      reservedNames: ["old_field"]
    )

    XCTAssertEqual(message1, message2)
    XCTAssertNotEqual(message1, message3)
  }

  // MARK: - MessageNode Description Tests

  func testMessageNodeSimpleDescription() {
    let field = FieldNode(name: "name", type: .string, number: 1)
    let message = MessageNode(name: "SimpleMessage", fields: [field])

    let description = message.description
    XCTAssertTrue(description.contains("message SimpleMessage"))
    XCTAssertTrue(description.contains("string name = 1"))
    XCTAssertTrue(description.hasPrefix("message SimpleMessage {"))
    XCTAssertTrue(description.hasSuffix("}"))
  }

  func testMessageNodeDescriptionWithOptions() {
    let field = FieldNode(name: "name", type: .string, number: 1)
    let option = OptionNode(name: "deprecated", value: .boolean(true))
    let message = MessageNode(name: "MessageWithOptions", fields: [field], options: [option])

    let description = message.description
    XCTAssertTrue(description.contains("message MessageWithOptions"))
    XCTAssertTrue(description.contains("option deprecated = true"))
    XCTAssertTrue(description.contains("string name = 1"))
  }

  func testMessageNodeDescriptionWithReservedNumbers() {
    let field = FieldNode(name: "name", type: .string, number: 1)
    let message = MessageNode(
      name: "MessageWithReserved",
      fields: [field],
      reservedNumbers: [5, 6, 7]
    )

    let description = message.description
    XCTAssertTrue(description.contains("reserved 5, 6, 7;"))
  }

  func testMessageNodeDescriptionWithReservedNames() {
    let field = FieldNode(name: "name", type: .string, number: 1)
    let message = MessageNode(
      name: "MessageWithReservedNames",
      fields: [field],
      reservedNames: ["old_field1", "old_field2"]
    )

    let description = message.description
    XCTAssertTrue(description.contains("reserved \"old_field1\", \"old_field2\";"))
  }

  func testMessageNodeDescriptionWithNestedEnum() {
    let field = FieldNode(name: "status", type: .enumType("Status"), number: 1)
    let enumValue = EnumValueNode(name: "ACTIVE", number: 1)
    let nestedEnum = EnumNode(name: "Status", values: [enumValue])

    let message = MessageNode(
      name: "MessageWithEnum",
      fields: [field],
      nestedEnums: [nestedEnum]
    )

    let description = message.description
    XCTAssertTrue(description.contains("message MessageWithEnum"))
    XCTAssertTrue(description.contains("enum Status"))
    XCTAssertTrue(description.contains("ACTIVE = 1"))
    XCTAssertTrue(description.contains("Status status = 1"))
  }

  func testMessageNodeDescriptionWithNestedMessage() {
    let nestedField = FieldNode(name: "street", type: .string, number: 1)
    let nestedMessage = MessageNode(name: "Address", fields: [nestedField])

    let field = FieldNode(name: "address", type: .message("Address"), number: 1)
    let message = MessageNode(
      name: "User",
      fields: [field],
      nestedMessages: [nestedMessage]
    )

    let description = message.description
    XCTAssertTrue(description.contains("message User"))
    XCTAssertTrue(description.contains("message Address"))
    XCTAssertTrue(description.contains("string street = 1"))
    XCTAssertTrue(description.contains("Address address = 1"))
  }

  func testMessageNodeDescriptionWithOneof() {
    let oneofField1 = FieldNode(name: "name", type: .string, number: 1)
    let oneofField2 = FieldNode(name: "id", type: .int32, number: 2)
    let oneofGroup = OneofNode(name: "identifier", fields: [oneofField1, oneofField2])

    let message = MessageNode(
      name: "MessageWithOneof",
      oneofGroups: [oneofGroup]
    )

    let description = message.description
    XCTAssertTrue(description.contains("message MessageWithOneof"))
    XCTAssertTrue(description.contains("oneof identifier"))
    XCTAssertTrue(description.contains("string name = 1"))
    XCTAssertTrue(description.contains("int32 id = 2"))
  }

  // MARK: - OneofNode Tests

  func testOneofNodeInitialization() {
    let oneof = OneofNode(name: "test_oneof")

    XCTAssertEqual(oneof.name, "test_oneof")
    XCTAssertTrue(oneof.fields.isEmpty)
    XCTAssertTrue(oneof.options.isEmpty)
  }

  func testOneofNodeWithFields() {
    let field1 = FieldNode(name: "string_value", type: .string, number: 1)
    let field2 = FieldNode(name: "int_value", type: .int32, number: 2)
    let oneof = OneofNode(name: "value", fields: [field1, field2])

    XCTAssertEqual(oneof.name, "value")
    XCTAssertEqual(oneof.fields.count, 2)
    XCTAssertEqual(oneof.fields[0].name, "string_value")
    XCTAssertEqual(oneof.fields[1].name, "int_value")
  }

  func testOneofNodeWithOptions() {
    let option = OptionNode(name: "deprecated", value: .boolean(true))
    let field = FieldNode(name: "value", type: .string, number: 1)
    let oneof = OneofNode(name: "test_oneof", fields: [field], options: [option])

    XCTAssertEqual(oneof.options.count, 1)
    XCTAssertEqual(oneof.options.first?.name, "deprecated")
  }

  func testOneofNodeEquality() {
    let field = FieldNode(name: "value", type: .string, number: 1)
    let option = OptionNode(name: "deprecated", value: .boolean(true))

    let oneof1 = OneofNode(name: "test_oneof", fields: [field], options: [option])
    let oneof2 = OneofNode(name: "test_oneof", fields: [field], options: [option])
    let oneof3 = OneofNode(name: "other_oneof", fields: [field], options: [option])

    XCTAssertEqual(oneof1, oneof2)
    XCTAssertNotEqual(oneof1, oneof3)
  }

  func testOneofNodeDescription() {
    let field1 = FieldNode(name: "string_value", type: .string, number: 1)
    let field2 = FieldNode(name: "int_value", type: .int32, number: 2)
    let oneof = OneofNode(name: "value", fields: [field1, field2])

    let description = oneof.description
    XCTAssertTrue(description.contains("oneof value"))
    XCTAssertTrue(description.contains("string string_value = 1"))
    XCTAssertTrue(description.contains("int32 int_value = 2"))
    XCTAssertTrue(description.hasPrefix("oneof value {"))
    XCTAssertTrue(description.hasSuffix("}"))
  }

  func testOneofNodeDescriptionWithOptions() {
    let option = OptionNode(name: "deprecated", value: .boolean(true))
    let field = FieldNode(name: "value", type: .string, number: 1)
    let oneof = OneofNode(name: "test_oneof", fields: [field], options: [option])

    let description = oneof.description
    XCTAssertTrue(description.contains("oneof test_oneof"))
    XCTAssertTrue(description.contains("option deprecated = true"))
    XCTAssertTrue(description.contains("string value = 1"))
  }

  // MARK: - Complex Integration Tests

  func testComplexMessageWithAllFeatures() {
    // Create a complex message with all possible features
    let regularField = FieldNode(name: "id", type: .string, number: 1)
    let repeatedField = FieldNode(name: "tags", type: .string, number: 2, label: .repeated)

    // Nested message
    let nestedField = FieldNode(name: "value", type: .string, number: 1)
    let nestedMessage = MessageNode(name: "Metadata", fields: [nestedField])

    // Nested enum
    let enumValue1 = EnumValueNode(name: "UNKNOWN", number: 0)
    let enumValue2 = EnumValueNode(name: "ACTIVE", number: 1)
    let nestedEnum = EnumNode(name: "Status", values: [enumValue1, enumValue2])

    // Oneof group
    let oneofField1 = FieldNode(name: "email", type: .string, number: 10)
    let oneofField2 = FieldNode(name: "phone", type: .string, number: 11)
    let oneofOption = OptionNode(name: "deprecated", value: .boolean(false))
    let oneofGroup = OneofNode(name: "contact", fields: [oneofField1, oneofField2], options: [oneofOption])

    // Message options
    let messageOption = OptionNode(name: "deprecated", value: .boolean(false))

    let complexMessage = MessageNode(
      name: "ComplexUser",
      fields: [regularField, repeatedField],
      nestedMessages: [nestedMessage],
      nestedEnums: [nestedEnum],
      oneofGroups: [oneofGroup],
      options: [messageOption],
      reservedNumbers: [3, 4, 5],
      reservedNames: ["old_name", "legacy_field"]
    )

    // Test all functionality
    XCTAssertEqual(complexMessage.name, "ComplexUser")
    XCTAssertEqual(complexMessage.fields.count, 2)
    XCTAssertEqual(complexMessage.nestedMessages.count, 1)
    XCTAssertEqual(complexMessage.nestedEnums.count, 1)
    XCTAssertEqual(complexMessage.oneofGroups.count, 1)
    XCTAssertEqual(complexMessage.options.count, 1)
    XCTAssertEqual(complexMessage.reservedNumbers.count, 3)
    XCTAssertEqual(complexMessage.reservedNames.count, 2)

    // Test field tracking
    let expectedNumbers: Set<Int32> = [1, 2, 10, 11]
    XCTAssertEqual(complexMessage.usedFieldNumbers, expectedNumbers)

    let expectedNames: Set<String> = ["id", "tags", "email", "phone"]
    XCTAssertEqual(complexMessage.usedFieldNames, expectedNames)

    // Test field lookup
    XCTAssertEqual(complexMessage.field(named: "id"), regularField)
    XCTAssertEqual(complexMessage.field(named: "email"), oneofField1)
    XCTAssertEqual(complexMessage.field(withNumber: 2), repeatedField)
    XCTAssertEqual(complexMessage.field(withNumber: 11), oneofField2)
    XCTAssertNil(complexMessage.field(named: "nonexistent"))
    XCTAssertNil(complexMessage.field(withNumber: 999))

    // Test description contains all elements
    let description = complexMessage.description
    XCTAssertTrue(description.contains("message ComplexUser"))
    XCTAssertTrue(description.contains("reserved 3, 4, 5;"))
    XCTAssertTrue(description.contains("reserved \"old_name\", \"legacy_field\";"))
    XCTAssertTrue(description.contains("enum Status"))
    XCTAssertTrue(description.contains("message Metadata"))
    XCTAssertTrue(description.contains("oneof contact"))
    XCTAssertTrue(description.contains("string id = 1"))
    XCTAssertTrue(description.contains("repeated string tags = 2"))
  }

  func testMessageNodeDescriptionOrderAndFormatting() {
    // Test the specific order and formatting of description output
    let field = FieldNode(name: "name", type: .string, number: 1)
    let option = OptionNode(name: "deprecated", value: .boolean(true))
    let enumValue = EnumValueNode(name: "ACTIVE", number: 1)
    let nestedEnum = EnumNode(name: "Status", values: [enumValue])
    let nestedField = FieldNode(name: "value", type: .string, number: 1)
    let nestedMessage = MessageNode(name: "Inner", fields: [nestedField])
    let oneofField = FieldNode(name: "choice", type: .int32, number: 10)
    let oneofGroup = OneofNode(name: "options", fields: [oneofField])

    let message = MessageNode(
      name: "OrderTest",
      fields: [field],
      nestedMessages: [nestedMessage],
      nestedEnums: [nestedEnum],
      oneofGroups: [oneofGroup],
      options: [option],
      reservedNumbers: [5],
      reservedNames: ["old_field"]
    )

    let description = message.description
    let lines = description.components(separatedBy: "\n")

    // Check order: message declaration, options, reserved numbers, reserved names,
    // nested enums, nested messages, oneof groups, fields, closing brace
    XCTAssertTrue(lines[0].contains("message OrderTest {"))
    XCTAssertTrue(lines.contains { $0.contains("option deprecated") })
    XCTAssertTrue(lines.contains { $0.contains("reserved 5;") })
    XCTAssertTrue(lines.contains { $0.contains("reserved \"old_field\";") })
    XCTAssertTrue(lines.contains { $0.contains("enum Status") })
    XCTAssertTrue(lines.contains { $0.contains("message Inner") })
    XCTAssertTrue(lines.contains { $0.contains("oneof options") })
    XCTAssertTrue(lines.contains { $0.contains("string name = 1;") })
    XCTAssertTrue(lines.last?.contains("}") == true)
  }
}
