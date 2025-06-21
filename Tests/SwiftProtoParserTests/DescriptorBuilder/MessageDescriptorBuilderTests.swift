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
}
