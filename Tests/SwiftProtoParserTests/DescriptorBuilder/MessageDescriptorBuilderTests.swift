import XCTest
import SwiftProtobuf
@testable import SwiftProtoParser

class MessageDescriptorBuilderTests: XCTestCase {
  
  func testBuildSimpleMessage() throws {
    // Create simple message
    let field = FieldNode(name: "id", type: .int32, number: 1)
    let message = MessageNode(name: "SimpleMessage", fields: [field])
    
    // Build descriptor
    let descriptor = try MessageDescriptorBuilder.build(from: message)
    
    // Verify basic properties
    XCTAssertEqual(descriptor.name, "SimpleMessage")
    XCTAssertEqual(descriptor.field.count, 1)
    XCTAssertEqual(descriptor.field[0].name, "id")
    XCTAssertEqual(descriptor.field[0].number, 1)
    XCTAssertEqual(descriptor.nestedType.count, 0)
    XCTAssertEqual(descriptor.enumType.count, 0)
    XCTAssertEqual(descriptor.oneofDecl.count, 0)
  }
  
  func testBuildMessageWithMultipleFields() throws {
    let fields = [
      FieldNode(name: "id", type: .int32, number: 1),
      FieldNode(name: "name", type: .string, number: 2),
      FieldNode(name: "active", type: .bool, number: 3)
    ]
    
    let message = MessageNode(name: "MultiFieldMessage", fields: fields)
    let descriptor = try MessageDescriptorBuilder.build(from: message)
    
    XCTAssertEqual(descriptor.name, "MultiFieldMessage")
    XCTAssertEqual(descriptor.field.count, 3)
    
    // Check all fields
    XCTAssertEqual(descriptor.field[0].name, "id")
    XCTAssertEqual(descriptor.field[1].name, "name")
    XCTAssertEqual(descriptor.field[2].name, "active")
  }
  
  func testBuildMessageWithNestedMessage() throws {
    // Create nested message
    let innerField = FieldNode(name: "value", type: .string, number: 1)
    let innerMessage = MessageNode(name: "InnerMessage", fields: [innerField])
    
    // Create outer message
    let outerField = FieldNode(name: "id", type: .int32, number: 1)
    let outerMessage = MessageNode(
      name: "OuterMessage",
      fields: [outerField],
      nestedMessages: [innerMessage]
    )
    
    let descriptor = try MessageDescriptorBuilder.build(from: outerMessage)
    
    XCTAssertEqual(descriptor.name, "OuterMessage")
    XCTAssertEqual(descriptor.field.count, 1)
    XCTAssertEqual(descriptor.nestedType.count, 1)
    XCTAssertEqual(descriptor.nestedType[0].name, "InnerMessage")
    XCTAssertEqual(descriptor.nestedType[0].field.count, 1)
    XCTAssertEqual(descriptor.nestedType[0].field[0].name, "value")
  }
  
  func testBuildMessageWithNestedEnum() throws {
    // Create nested enum
    let enumValue = EnumValueNode(name: "UNKNOWN", number: 0)
    let nestedEnum = EnumNode(name: "Status", values: [enumValue])
    
    // Create message
    let field = FieldNode(name: "status", type: .enumType("Status"), number: 1)
    let message = MessageNode(
      name: "MessageWithEnum",
      fields: [field],
      nestedEnums: [nestedEnum]
    )
    
    let descriptor = try MessageDescriptorBuilder.build(from: message)
    
    XCTAssertEqual(descriptor.name, "MessageWithEnum")
    XCTAssertEqual(descriptor.field.count, 1)
    XCTAssertEqual(descriptor.enumType.count, 1)
    XCTAssertEqual(descriptor.enumType[0].name, "Status")
    XCTAssertEqual(descriptor.enumType[0].value.count, 1)
    XCTAssertEqual(descriptor.enumType[0].value[0].name, "UNKNOWN")
  }
  
  func testBuildMessageWithOneof() throws {
    // Create oneof group
    let oneofFields = [
      FieldNode(name: "text_value", type: .string, number: 1),
      FieldNode(name: "number_value", type: .int32, number: 2)
    ]
    let oneof = OneofNode(name: "value", fields: oneofFields)
    
    let message = MessageNode(
      name: "MessageWithOneof",
      oneofGroups: [oneof]
    )
    
    let descriptor = try MessageDescriptorBuilder.build(from: message)
    
    XCTAssertEqual(descriptor.name, "MessageWithOneof")
    XCTAssertEqual(descriptor.oneofDecl.count, 1)
    XCTAssertEqual(descriptor.oneofDecl[0].name, "value")
  }
  
  func testBuildEmptyMessage() throws {
    let message = MessageNode(name: "EmptyMessage")
    let descriptor = try MessageDescriptorBuilder.build(from: message)
    
    XCTAssertEqual(descriptor.name, "EmptyMessage")
    XCTAssertEqual(descriptor.field.count, 0)
    XCTAssertEqual(descriptor.nestedType.count, 0)
    XCTAssertEqual(descriptor.enumType.count, 0)
    XCTAssertEqual(descriptor.oneofDecl.count, 0)
  }
  
  // MARK: - Tests for New Functionality
  
  func testBuildMessageWithReservedNumbers() throws {
    // Create message with reserved numbers
    let field = FieldNode(name: "id", type: .int32, number: 1)
    let message = MessageNode(
      name: "MessageWithReserved", 
      fields: [field],
      reservedNumbers: [5, 6, 7, 10, 15, 16, 17]
    )
    
    let descriptor = try MessageDescriptorBuilder.build(from: message)
    
    XCTAssertEqual(descriptor.name, "MessageWithReserved")
    XCTAssertEqual(descriptor.field.count, 1)
    
    // Check reserved ranges (numbers should be converted to ranges)
    XCTAssertTrue(descriptor.reservedRange.count > 0)
    
    // Verify ranges: [5,8), [10,11), [15,18)
    XCTAssertEqual(descriptor.reservedRange[0].start, 5)
    XCTAssertEqual(descriptor.reservedRange[0].end, 8)  // end is exclusive
    XCTAssertEqual(descriptor.reservedRange[1].start, 10)
    XCTAssertEqual(descriptor.reservedRange[1].end, 11)
    XCTAssertEqual(descriptor.reservedRange[2].start, 15)
    XCTAssertEqual(descriptor.reservedRange[2].end, 18)
  }
  
  func testBuildMessageWithReservedNames() throws {
    // Create message with reserved names
    let field = FieldNode(name: "id", type: .int32, number: 1)
    let message = MessageNode(
      name: "MessageWithReservedNames", 
      fields: [field],
      reservedNames: ["foo", "bar", "deprecated_field"]
    )
    
    let descriptor = try MessageDescriptorBuilder.build(from: message)
    
    XCTAssertEqual(descriptor.name, "MessageWithReservedNames")
    XCTAssertEqual(descriptor.field.count, 1)
    XCTAssertEqual(descriptor.reservedName.count, 3)
    XCTAssertEqual(descriptor.reservedName[0], "foo")
    XCTAssertEqual(descriptor.reservedName[1], "bar")
    XCTAssertEqual(descriptor.reservedName[2], "deprecated_field")
  }
  
  func testBuildMessageWithOptions() throws {
    // Create message with options
    let field = FieldNode(name: "id", type: .int32, number: 1)
    let options = [
      OptionNode(name: "deprecated", value: .boolean(true)),
      OptionNode(name: "map_entry", value: .boolean(false)),
      OptionNode(name: "custom_option", value: .string("test_value"), isCustom: true)
    ]
    let message = MessageNode(
      name: "MessageWithOptions", 
      fields: [field],
      options: options
    )
    
    let descriptor = try MessageDescriptorBuilder.build(from: message)
    
    XCTAssertEqual(descriptor.name, "MessageWithOptions")
    XCTAssertEqual(descriptor.field.count, 1)
    
    // Check that options were set
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertTrue(descriptor.options.deprecated)
    XCTAssertFalse(descriptor.options.mapEntry)
    
    // Custom options should be in uninterpreted_option
    XCTAssertEqual(descriptor.options.uninterpretedOption.count, 1)
    XCTAssertEqual(descriptor.options.uninterpretedOption[0].name[0].namePart, "custom_option")
  }
  
  func testBuildMessageWithOneofOptions() throws {
    // Create oneof group with options
    let oneofFields = [
      FieldNode(name: "text_value", type: .string, number: 1),
      FieldNode(name: "number_value", type: .int32, number: 2)
    ]
    let oneofOptions = [
      OptionNode(name: "custom_oneof_option", value: .string("oneof_test"), isCustom: true)
    ]
    let oneof = OneofNode(name: "value", fields: oneofFields, options: oneofOptions)
    
    let message = MessageNode(
      name: "MessageWithOneofOptions",
      oneofGroups: [oneof]
    )
    
    let descriptor = try MessageDescriptorBuilder.build(from: message)
    
    XCTAssertEqual(descriptor.name, "MessageWithOneofOptions")
    XCTAssertEqual(descriptor.oneofDecl.count, 1)
    XCTAssertEqual(descriptor.oneofDecl[0].name, "value")
    
    // Check that oneof has options
    XCTAssertTrue(descriptor.oneofDecl[0].hasOptions)
    XCTAssertEqual(descriptor.oneofDecl[0].options.uninterpretedOption.count, 1)
    XCTAssertEqual(descriptor.oneofDecl[0].options.uninterpretedOption[0].name[0].namePart, "custom_oneof_option")
  }
  
  func testBuildMessageWithSingleReservedNumber() throws {
    // Test single reserved number
    let field = FieldNode(name: "id", type: .int32, number: 1)
    let message = MessageNode(
      name: "MessageWithSingleReserved", 
      fields: [field],
      reservedNumbers: [42]
    )
    
    let descriptor = try MessageDescriptorBuilder.build(from: message)
    
    XCTAssertEqual(descriptor.reservedRange.count, 1)
    XCTAssertEqual(descriptor.reservedRange[0].start, 42)
    XCTAssertEqual(descriptor.reservedRange[0].end, 43)  // end is exclusive
  }
  
  func testBuildMessageWithComplexReservedRanges() throws {
    // Test complex reserved numbers that should create multiple ranges
    let field = FieldNode(name: "id", type: .int32, number: 1)
    let message = MessageNode(
      name: "MessageWithComplexReserved", 
      fields: [field],
      reservedNumbers: [5, 7, 8, 9, 15, 20, 21, 22, 100]
    )
    
    let descriptor = try MessageDescriptorBuilder.build(from: message)
    
    // Should create ranges: [5,6), [7,10), [15,16), [20,23), [100,101)
    XCTAssertEqual(descriptor.reservedRange.count, 5)
    
    XCTAssertEqual(descriptor.reservedRange[0].start, 5)
    XCTAssertEqual(descriptor.reservedRange[0].end, 6)
    
    XCTAssertEqual(descriptor.reservedRange[1].start, 7)
    XCTAssertEqual(descriptor.reservedRange[1].end, 10)
    
    XCTAssertEqual(descriptor.reservedRange[2].start, 15)
    XCTAssertEqual(descriptor.reservedRange[2].end, 16)
    
    XCTAssertEqual(descriptor.reservedRange[3].start, 20)
    XCTAssertEqual(descriptor.reservedRange[3].end, 23)
    
    XCTAssertEqual(descriptor.reservedRange[4].start, 100)
    XCTAssertEqual(descriptor.reservedRange[4].end, 101)
  }
}
