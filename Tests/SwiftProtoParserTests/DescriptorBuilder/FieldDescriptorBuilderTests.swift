import XCTest
import SwiftProtobuf
@testable import SwiftProtoParser

final class FieldDescriptorBuilderTests: XCTestCase {

  // MARK: - Basic Field Tests

  func testBuildBasicStringField() throws {
    let fieldNode = FieldNode(name: "name", type: .string, number: 1)
    
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.name, "name")
    XCTAssertEqual(fieldProto.number, 1)
    XCTAssertEqual(fieldProto.type, .string)
    XCTAssertEqual(fieldProto.label, .optional)
    XCTAssertFalse(fieldProto.hasOptions)
  }
  
  func testBuildFieldWithRepeatedLabel() throws {
    let fieldNode = FieldNode(name: "items", type: .string, number: 2, label: .repeated)
    
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 2)
    
    XCTAssertEqual(fieldProto.name, "items")
    XCTAssertEqual(fieldProto.number, 2)
    XCTAssertEqual(fieldProto.label, .repeated)
  }
  
  func testBuildFieldWithOptionalLabel() throws {
    let fieldNode = FieldNode(name: "optional_field", type: .string, number: 3, label: .optional)
    
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 3)
    
    XCTAssertEqual(fieldProto.label, .optional)
  }
  
  func testBuildFieldWithSingularLabel() throws {
    let fieldNode = FieldNode(name: "singular_field", type: .string, number: 4, label: .singular)
    
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 4)
    
    XCTAssertEqual(fieldProto.label, .optional) // Proto3 singular becomes optional
  }

  // MARK: - All Scalar Types Tests

  func testBuildDoubleField() throws {
    let fieldNode = FieldNode(name: "double_field", type: .double, number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.type, .double)
    XCTAssertFalse(fieldProto.hasTypeName)
  }
  
  func testBuildFloatField() throws {
    let fieldNode = FieldNode(name: "float_field", type: .float, number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.type, .float)
  }
  
  func testBuildInt32Field() throws {
    let fieldNode = FieldNode(name: "int32_field", type: .int32, number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.type, .int32)
  }
  
  func testBuildInt64Field() throws {
    let fieldNode = FieldNode(name: "int64_field", type: .int64, number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.type, .int64)
  }
  
  func testBuildUint32Field() throws {
    let fieldNode = FieldNode(name: "uint32_field", type: .uint32, number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.type, .uint32)
  }
  
  func testBuildUint64Field() throws {
    let fieldNode = FieldNode(name: "uint64_field", type: .uint64, number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.type, .uint64)
  }
  
  func testBuildSint32Field() throws {
    let fieldNode = FieldNode(name: "sint32_field", type: .sint32, number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.type, .sint32)
  }
  
  func testBuildSint64Field() throws {
    let fieldNode = FieldNode(name: "sint64_field", type: .sint64, number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.type, .sint64)
  }
  
  func testBuildFixed32Field() throws {
    let fieldNode = FieldNode(name: "fixed32_field", type: .fixed32, number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.type, .fixed32)
  }
  
  func testBuildFixed64Field() throws {
    let fieldNode = FieldNode(name: "fixed64_field", type: .fixed64, number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.type, .fixed64)
  }
  
  func testBuildSfixed32Field() throws {
    let fieldNode = FieldNode(name: "sfixed32_field", type: .sfixed32, number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.type, .sfixed32)
  }
  
  func testBuildSfixed64Field() throws {
    let fieldNode = FieldNode(name: "sfixed64_field", type: .sfixed64, number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.type, .sfixed64)
  }
  
  func testBuildBoolField() throws {
    let fieldNode = FieldNode(name: "bool_field", type: .bool, number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.type, .bool)
  }
  
  func testBuildStringField() throws {
    let fieldNode = FieldNode(name: "string_field", type: .string, number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.type, .string)
  }
  
  func testBuildBytesField() throws {
    let fieldNode = FieldNode(name: "bytes_field", type: .bytes, number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.type, .bytes)
  }

  // MARK: - Complex Types Tests

  func testBuildMessageField() throws {
    let fieldNode = FieldNode(name: "message_field", type: .message("TestMessage"), number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.type, .message)
    XCTAssertEqual(fieldProto.typeName, ".TestMessage")
  }
  
  func testBuildMessageFieldWithPackage() throws {
    let fieldNode = FieldNode(name: "message_field", type: .message("TestMessage"), number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1, packageName: "com.example")
    
    XCTAssertEqual(fieldProto.type, .message)
    XCTAssertEqual(fieldProto.typeName, ".com.example.TestMessage")
  }
  
  func testBuildMessageFieldWithFullyQualifiedName() throws {
    let fieldNode = FieldNode(name: "message_field", type: .message(".other.package.TestMessage"), number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1, packageName: "com.example")
    
    XCTAssertEqual(fieldProto.type, .message)
    XCTAssertEqual(fieldProto.typeName, ".other.package.TestMessage") // Should not add package prefix
  }
  
  func testBuildEnumField() throws {
    let fieldNode = FieldNode(name: "enum_field", type: .enumType("Status"), number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.type, .enum)
    XCTAssertEqual(fieldProto.typeName, ".Status")
  }
  
  func testBuildEnumFieldWithPackage() throws {
    let fieldNode = FieldNode(name: "enum_field", type: .enumType("Status"), number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1, packageName: "com.example")
    
    XCTAssertEqual(fieldProto.type, .enum)
    XCTAssertEqual(fieldProto.typeName, ".com.example.Status")
  }
  
  func testBuildMapField() throws {
    let fieldNode = FieldNode(name: "map_field", type: .map(key: .string, value: .int32), number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.type, .message)
    XCTAssertEqual(fieldProto.typeName, "Map_fieldEntry") // Only first letter capitalized + "Entry"
    XCTAssertEqual(fieldProto.label, .repeated)
  }
  
  func testBuildMapFieldWithMessageValue() throws {
    let fieldNode = FieldNode(name: "complex_map", type: .map(key: .string, value: .message("Value")), number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.type, .message)
    XCTAssertEqual(fieldProto.typeName, "Complex_mapEntry") // Only first letter capitalized + "Entry"
    XCTAssertEqual(fieldProto.label, .repeated)
  }

  // MARK: - Package Name Handling Tests

  func testBuildFieldWithEmptyPackage() throws {
    let fieldNode = FieldNode(name: "message_field", type: .message("TestMessage"), number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1, packageName: "")
    
    XCTAssertEqual(fieldProto.typeName, ".TestMessage")
  }
  
  func testBuildFieldWithNilPackage() throws {
    let fieldNode = FieldNode(name: "message_field", type: .message("TestMessage"), number: 1)
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1, packageName: nil)
    
    XCTAssertEqual(fieldProto.typeName, ".TestMessage")
  }

  // MARK: - Field Options Tests

  func testBuildFieldWithDeprecatedOption() throws {
    let option = OptionNode(name: "deprecated", value: .boolean(true))
    let fieldNode = FieldNode(name: "old_field", type: .string, number: 1, options: [option])
    
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertTrue(fieldProto.hasOptions)
    XCTAssertTrue(fieldProto.options.deprecated)
  }
  
  func testBuildFieldWithPackedOption() throws {
    let option = OptionNode(name: "packed", value: .boolean(true))
    let fieldNode = FieldNode(name: "packed_field", type: .int32, number: 1, label: .repeated, options: [option])
    
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertTrue(fieldProto.hasOptions)
    XCTAssertTrue(fieldProto.options.packed)
  }
  
  func testBuildFieldWithLazyOption() throws {
    let option = OptionNode(name: "lazy", value: .boolean(true))
    let fieldNode = FieldNode(name: "lazy_field", type: .message("LazyMessage"), number: 1, options: [option])
    
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertTrue(fieldProto.hasOptions)
    XCTAssertTrue(fieldProto.options.lazy)
  }
  
  func testBuildFieldWithWeakOption() throws {
    let option = OptionNode(name: "weak", value: .boolean(true))
    let fieldNode = FieldNode(name: "weak_field", type: .message("WeakMessage"), number: 1, options: [option])
    
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertTrue(fieldProto.hasOptions)
    XCTAssertTrue(fieldProto.options.weak)
  }
  
  func testBuildFieldWithJSTypeOptions() throws {
    // Test JS_NORMAL
    let option1 = OptionNode(name: "jstype", value: .identifier("JS_NORMAL"))
    let fieldNode1 = FieldNode(name: "js_normal", type: .int64, number: 1, options: [option1])
    let fieldProto1 = try FieldDescriptorBuilder.build(from: fieldNode1, index: 1)
    
    XCTAssertTrue(fieldProto1.hasOptions)
    XCTAssertEqual(fieldProto1.options.jstype, .jsNormal)
    
    // Test JS_STRING
    let option2 = OptionNode(name: "jstype", value: .identifier("JS_STRING"))
    let fieldNode2 = FieldNode(name: "js_string", type: .int64, number: 2, options: [option2])
    let fieldProto2 = try FieldDescriptorBuilder.build(from: fieldNode2, index: 2)
    
    XCTAssertEqual(fieldProto2.options.jstype, .jsString)
    
    // Test JS_NUMBER
    let option3 = OptionNode(name: "jstype", value: .identifier("JS_NUMBER"))
    let fieldNode3 = FieldNode(name: "js_number", type: .int64, number: 3, options: [option3])
    let fieldProto3 = try FieldDescriptorBuilder.build(from: fieldNode3, index: 3)
    
    XCTAssertEqual(fieldProto3.options.jstype, .jsNumber)
    
    // Test unknown jstype (should default to JS_NORMAL)
    let option4 = OptionNode(name: "jstype", value: .identifier("UNKNOWN"))
    let fieldNode4 = FieldNode(name: "js_unknown", type: .int64, number: 4, options: [option4])
    let fieldProto4 = try FieldDescriptorBuilder.build(from: fieldNode4, index: 4)
    
    XCTAssertEqual(fieldProto4.options.jstype, .jsNormal)
  }
  
  func testBuildFieldWithCTypeOptions() throws {
    // Test STRING
    let option1 = OptionNode(name: "ctype", value: .identifier("STRING"))
    let fieldNode1 = FieldNode(name: "ctype_string", type: .string, number: 1, options: [option1])
    let fieldProto1 = try FieldDescriptorBuilder.build(from: fieldNode1, index: 1)
    
    XCTAssertTrue(fieldProto1.hasOptions)
    XCTAssertEqual(fieldProto1.options.ctype, .string)
    
    // Test CORD
    let option2 = OptionNode(name: "ctype", value: .identifier("CORD"))
    let fieldNode2 = FieldNode(name: "ctype_cord", type: .string, number: 2, options: [option2])
    let fieldProto2 = try FieldDescriptorBuilder.build(from: fieldNode2, index: 2)
    
    XCTAssertEqual(fieldProto2.options.ctype, .cord)
    
    // Test STRING_PIECE
    let option3 = OptionNode(name: "ctype", value: .identifier("STRING_PIECE"))
    let fieldNode3 = FieldNode(name: "ctype_piece", type: .string, number: 3, options: [option3])
    let fieldProto3 = try FieldDescriptorBuilder.build(from: fieldNode3, index: 3)
    
    XCTAssertEqual(fieldProto3.options.ctype, .stringPiece)
    
    // Test unknown ctype (should default to STRING)
    let option4 = OptionNode(name: "ctype", value: .identifier("UNKNOWN"))
    let fieldNode4 = FieldNode(name: "ctype_unknown", type: .string, number: 4, options: [option4])
    let fieldProto4 = try FieldDescriptorBuilder.build(from: fieldNode4, index: 4)
    
    XCTAssertEqual(fieldProto4.options.ctype, .string)
  }
  
  func testBuildFieldWithCustomStringOption() throws {
    let option = OptionNode(name: "custom_option", value: .string("test_value"), isCustom: true)
    let fieldNode = FieldNode(name: "field_with_custom", type: .string, number: 1, options: [option])
    
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertTrue(fieldProto.hasOptions)
    XCTAssertEqual(fieldProto.options.uninterpretedOption.count, 1)
    
    let uninterpreted = fieldProto.options.uninterpretedOption[0]
    XCTAssertEqual(uninterpreted.name.count, 1)
    XCTAssertEqual(uninterpreted.name[0].namePart, "custom_option")
    XCTAssertTrue(uninterpreted.name[0].isExtension)
    XCTAssertEqual(uninterpreted.stringValue, Data("test_value".utf8))
  }
  
  func testBuildFieldWithCustomNumberOption() throws {
    let option = OptionNode(name: "custom_number", value: .number(42), isCustom: true)
    let fieldNode = FieldNode(name: "field_with_custom_number", type: .int32, number: 1, options: [option])
    
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertTrue(fieldProto.hasOptions)
    XCTAssertEqual(fieldProto.options.uninterpretedOption.count, 1)
    
    let uninterpreted = fieldProto.options.uninterpretedOption[0]
    XCTAssertEqual(uninterpreted.name[0].namePart, "custom_number")
    XCTAssertTrue(uninterpreted.name[0].isExtension)
    XCTAssertEqual(uninterpreted.positiveIntValue, 42)
  }
  
  func testBuildFieldWithCustomBooleanOption() throws {
    let option = OptionNode(name: "custom_bool", value: .boolean(true), isCustom: true)
    let fieldNode = FieldNode(name: "field_with_custom_bool", type: .bool, number: 1, options: [option])
    
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertTrue(fieldProto.hasOptions)
    XCTAssertEqual(fieldProto.options.uninterpretedOption.count, 1)
    
    let uninterpreted = fieldProto.options.uninterpretedOption[0]
    XCTAssertEqual(uninterpreted.name[0].namePart, "custom_bool")
    XCTAssertTrue(uninterpreted.name[0].isExtension)
    XCTAssertEqual(uninterpreted.identifierValue, "true")
  }
  
  func testBuildFieldWithCustomBooleanFalseOption() throws {
    let option = OptionNode(name: "custom_bool_false", value: .boolean(false), isCustom: true)
    let fieldNode = FieldNode(name: "field_with_custom_bool_false", type: .bool, number: 1, options: [option])
    
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    let uninterpreted = fieldProto.options.uninterpretedOption[0]
    XCTAssertEqual(uninterpreted.identifierValue, "false")
  }
  
  func testBuildFieldWithCustomIdentifierOption() throws {
    let option = OptionNode(name: "custom_id", value: .identifier("SOME_VALUE"), isCustom: true)
    let fieldNode = FieldNode(name: "field_with_custom_id", type: .string, number: 1, options: [option])
    
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertTrue(fieldProto.hasOptions)
    XCTAssertEqual(fieldProto.options.uninterpretedOption.count, 1)
    
    let uninterpreted = fieldProto.options.uninterpretedOption[0]
    XCTAssertEqual(uninterpreted.name[0].namePart, "custom_id")
    XCTAssertTrue(uninterpreted.name[0].isExtension)
    XCTAssertEqual(uninterpreted.identifierValue, "SOME_VALUE")
  }
  
  func testBuildFieldWithNonCustomOption() throws {
    let option = OptionNode(name: "non_custom", value: .string("value"), isCustom: false)
    let fieldNode = FieldNode(name: "field_with_non_custom", type: .string, number: 1, options: [option])
    
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertTrue(fieldProto.hasOptions)
    XCTAssertEqual(fieldProto.options.uninterpretedOption.count, 1)
    
    let uninterpreted = fieldProto.options.uninterpretedOption[0]
    XCTAssertEqual(uninterpreted.name[0].namePart, "non_custom")
    XCTAssertFalse(uninterpreted.name[0].isExtension) // Should be false for non-custom
  }
  
  func testBuildFieldWithMultipleOptions() throws {
    let options = [
      OptionNode(name: "deprecated", value: .boolean(true)),
      OptionNode(name: "packed", value: .boolean(true)),
      OptionNode(name: "custom_option", value: .string("test"), isCustom: true)
    ]
    let fieldNode = FieldNode(name: "multi_option_field", type: .int32, number: 1, label: .repeated, options: options)
    
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertTrue(fieldProto.hasOptions)
    XCTAssertTrue(fieldProto.options.deprecated)
    XCTAssertTrue(fieldProto.options.packed)
    XCTAssertEqual(fieldProto.options.uninterpretedOption.count, 1)
    XCTAssertEqual(fieldProto.options.uninterpretedOption[0].name[0].namePart, "custom_option")
  }

  // MARK: - Edge Cases and Error Handling Tests

  func testBuildFieldWithEmptyOptions() throws {
    let fieldNode = FieldNode(name: "no_options", type: .string, number: 1, options: [])
    
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertFalse(fieldProto.hasOptions)
  }
  
  func testBuildFieldWithLargeFieldNumber() throws {
    let fieldNode = FieldNode(name: "large_number", type: .string, number: 536870911) // Max field number
    
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.number, 536870911)
  }
  
  func testBuildFieldWithSpecialCharactersInName() throws {
    let fieldNode = FieldNode(name: "field_with_underscores_123", type: .string, number: 1)
    
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.name, "field_with_underscores_123")
  }
  
  func testBuildFieldCapitalizationForMapEntry() throws {
    // Test that map field names are properly capitalized for entry type
    let fieldNode = FieldNode(name: "my_map_field", type: .map(key: .string, value: .int32), number: 1)
    
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.typeName, "My_map_fieldEntry") // Only first letter capitalized + "Entry"
  }
  
  func testBuildFieldMapWithSingleLetterName() throws {
    let fieldNode = FieldNode(name: "m", type: .map(key: .string, value: .int32), number: 1)
    
    let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: 1)
    
    XCTAssertEqual(fieldProto.typeName, "MEntry")
  }
}
