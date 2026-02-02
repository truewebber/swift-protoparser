import SwiftProtobuf
import XCTest

@testable import SwiftProtoParser

/// Unit tests for map field descriptor generation in MessageDescriptorBuilder.
///
/// These tests verify that synthetic map entry messages are correctly generated
/// according to the Protocol Buffers specification.
class MessageDescriptorBuilderMapTests: XCTestCase {

  // MARK: - Basic Map Field Tests

  func testBuildMessageWithSimpleMapField() throws {
    // Create message with map<string, int32> counts = 1;
    let mapField = FieldNode(name: "counts", type: .map(key: .string, value: .int32), number: 1)
    let message = MessageNode(name: "TestMessage", fields: [mapField])

    // Build descriptor
    let descriptor = try MessageDescriptorBuilder.build(from: message)

    // Verify basic properties
    XCTAssertEqual(descriptor.name, "TestMessage")
    XCTAssertEqual(descriptor.field.count, 1)

    // Verify map field is converted to repeated message
    let countsField = descriptor.field[0]
    XCTAssertEqual(countsField.name, "counts")
    XCTAssertEqual(countsField.type, .message)
    XCTAssertEqual(countsField.typeName, "CountsEntry")
    XCTAssertEqual(countsField.label, .repeated)

    // Verify synthetic entry message was generated
    XCTAssertEqual(descriptor.nestedType.count, 1, "Should generate CountsEntry message")

    let entryMessage = descriptor.nestedType[0]
    XCTAssertEqual(entryMessage.name, "CountsEntry")
    XCTAssertTrue(entryMessage.options.mapEntry, "Entry message should have map_entry = true")

    // Verify entry message has key and value fields
    XCTAssertEqual(entryMessage.field.count, 2, "Entry message should have key and value fields")

    let keyField = entryMessage.field.first { $0.name == "key" }
    XCTAssertNotNil(keyField)
    XCTAssertEqual(keyField?.number, 1)
    XCTAssertEqual(keyField?.type, .string)
    XCTAssertEqual(keyField?.label, .optional)

    let valueField = entryMessage.field.first { $0.name == "value" }
    XCTAssertNotNil(valueField)
    XCTAssertEqual(valueField?.number, 2)
    XCTAssertEqual(valueField?.type, .int32)
    XCTAssertEqual(valueField?.label, .optional)
  }

  func testBuildMessageWithMultipleMapFields() throws {
    // Create message with multiple map fields
    let fields = [
      FieldNode(name: "string_map", type: .map(key: .string, value: .string), number: 1),
      FieldNode(name: "int_map", type: .map(key: .string, value: .int32), number: 2),
      FieldNode(name: "bool_map", type: .map(key: .string, value: .bool), number: 3),
    ]
    let message = MessageNode(name: "MultiMapMessage", fields: fields)

    // Build descriptor
    let descriptor = try MessageDescriptorBuilder.build(from: message)

    // Verify all map fields
    XCTAssertEqual(descriptor.field.count, 3)

    // Verify all entry messages generated
    XCTAssertEqual(descriptor.nestedType.count, 3, "Should generate 3 entry messages")

    let entryNames = Set(descriptor.nestedType.map { $0.name })
    XCTAssertTrue(entryNames.contains("String_mapEntry"))
    XCTAssertTrue(entryNames.contains("Int_mapEntry"))
    XCTAssertTrue(entryNames.contains("Bool_mapEntry"))

    // Verify each entry has map_entry option
    for entry in descriptor.nestedType {
      XCTAssertTrue(entry.options.mapEntry, "\(entry.name) should have map_entry = true")
      XCTAssertEqual(entry.field.count, 2, "\(entry.name) should have 2 fields")
    }
  }

  func testBuildMessageWithMapAndNestedMessage() throws {
    // Create message with both map field and explicit nested message
    let innerField = FieldNode(name: "value", type: .string, number: 1)
    let innerMessage = MessageNode(name: "InnerMessage", fields: [innerField])

    let mapField = FieldNode(name: "data", type: .map(key: .string, value: .int32), number: 1)
    let outerMessage = MessageNode(
      name: "OuterMessage",
      fields: [mapField],
      nestedMessages: [innerMessage]
    )

    // Build descriptor
    let descriptor = try MessageDescriptorBuilder.build(from: outerMessage)

    // Verify both nested types exist
    XCTAssertEqual(descriptor.nestedType.count, 2, "Should have DataEntry and InnerMessage")

    let entryMessage = descriptor.nestedType.first { $0.name == "DataEntry" }
    XCTAssertNotNil(entryMessage, "Should have synthetic DataEntry")
    XCTAssertTrue(entryMessage?.options.mapEntry ?? false)

    let innerNested = descriptor.nestedType.first { $0.name == "InnerMessage" }
    XCTAssertNotNil(innerNested, "Should have explicit InnerMessage")
    XCTAssertFalse(innerNested?.options.mapEntry ?? true, "Explicit nested messages should not have map_entry")
  }

  // MARK: - Complex Value Type Tests

  func testBuildMessageWithMapOfMessages() throws {
    // Create message with map<string, UserInfo> users = 1;
    let mapField = FieldNode(name: "users", type: .map(key: .string, value: .message("UserInfo")), number: 1)
    let message = MessageNode(name: "TestMessage", fields: [mapField])

    // Build descriptor
    let descriptor = try MessageDescriptorBuilder.build(from: message)

    // Verify entry message
    XCTAssertEqual(descriptor.nestedType.count, 1)
    let entryMessage = descriptor.nestedType[0]
    XCTAssertEqual(entryMessage.name, "UsersEntry")

    // Verify value field is message type
    let valueField = entryMessage.field.first { $0.name == "value" }
    XCTAssertNotNil(valueField)
    XCTAssertEqual(valueField?.type, .message)
    XCTAssertEqual(valueField?.typeName, ".UserInfo")
  }

  func testBuildMessageWithMapOfEnums() throws {
    // Create message with map<string, Status> statuses = 1;
    let mapField = FieldNode(name: "statuses", type: .map(key: .string, value: .enumType("Status")), number: 1)
    let message = MessageNode(name: "TestMessage", fields: [mapField])

    // Build descriptor
    let descriptor = try MessageDescriptorBuilder.build(from: message)

    // Verify entry message
    XCTAssertEqual(descriptor.nestedType.count, 1)
    let entryMessage = descriptor.nestedType[0]
    XCTAssertEqual(entryMessage.name, "StatusesEntry")

    // Verify value field is enum type
    let valueField = entryMessage.field.first { $0.name == "value" }
    XCTAssertNotNil(valueField)
    XCTAssertEqual(valueField?.type, .enum)
    XCTAssertEqual(valueField?.typeName, ".Status")
  }

  // MARK: - Different Key Type Tests

  func testBuildMessageWithDifferentKeyTypes() throws {
    let testCases: [(String, String, Google_Protobuf_FieldDescriptorProto.TypeEnum)] = [
      ("int32_key", "int32", .int32),
      ("int64_key", "int64", .int64),
      ("uint32_key", "uint32", .uint32),
      ("uint64_key", "uint64", .uint64),
      ("sint32_key", "sint32", .sint32),
      ("sint64_key", "sint64", .sint64),
      ("fixed32_key", "fixed32", .fixed32),
      ("fixed64_key", "fixed64", .fixed64),
      ("sfixed32_key", "sfixed32", .sfixed32),
      ("sfixed64_key", "sfixed64", .sfixed64),
      ("bool_key", "bool", .bool),
      ("string_key", "string", .string),
    ]

    for (fieldName, keyTypeStr, expectedProtoType) in testCases {
      // Create map field dynamically based on key type
      let mapField: FieldNode
      switch keyTypeStr {
      case "int32": mapField = FieldNode(name: fieldName, type: .map(key: .int32, value: .string), number: 1)
      case "int64": mapField = FieldNode(name: fieldName, type: .map(key: .int64, value: .string), number: 1)
      case "uint32": mapField = FieldNode(name: fieldName, type: .map(key: .uint32, value: .string), number: 1)
      case "uint64": mapField = FieldNode(name: fieldName, type: .map(key: .uint64, value: .string), number: 1)
      case "sint32": mapField = FieldNode(name: fieldName, type: .map(key: .sint32, value: .string), number: 1)
      case "sint64": mapField = FieldNode(name: fieldName, type: .map(key: .sint64, value: .string), number: 1)
      case "fixed32": mapField = FieldNode(name: fieldName, type: .map(key: .fixed32, value: .string), number: 1)
      case "fixed64": mapField = FieldNode(name: fieldName, type: .map(key: .fixed64, value: .string), number: 1)
      case "sfixed32": mapField = FieldNode(name: fieldName, type: .map(key: .sfixed32, value: .string), number: 1)
      case "sfixed64": mapField = FieldNode(name: fieldName, type: .map(key: .sfixed64, value: .string), number: 1)
      case "bool": mapField = FieldNode(name: fieldName, type: .map(key: .bool, value: .string), number: 1)
      case "string": mapField = FieldNode(name: fieldName, type: .map(key: .string, value: .string), number: 1)
      default: fatalError("Unknown key type: \(keyTypeStr)")
      }

      let message = MessageNode(name: "TestMessage", fields: [mapField])

      let descriptor = try MessageDescriptorBuilder.build(from: message)

      XCTAssertEqual(descriptor.nestedType.count, 1, "Failed for key type: \(keyTypeStr)")
      let entryMessage = descriptor.nestedType[0]

      let keyField = entryMessage.field.first { $0.name == "key" }
      XCTAssertEqual(keyField?.type, expectedProtoType, "Key type mismatch for: \(keyTypeStr)")
    }
  }

  // MARK: - Package Name Tests

  func testBuildMessageWithMapInPackage() throws {
    // Create message with map<string, UserInfo> users in "com.example" package
    let mapField = FieldNode(name: "users", type: .map(key: .string, value: .message("UserInfo")), number: 1)
    let message = MessageNode(name: "TestMessage", fields: [mapField])

    // Build descriptor with package name
    let descriptor = try MessageDescriptorBuilder.build(from: message, packageName: "com.example")

    // Verify entry message
    let entryMessage = descriptor.nestedType[0]

    // Verify value field has fully qualified type name
    let valueField = entryMessage.field.first { $0.name == "value" }
    XCTAssertNotNil(valueField)
    XCTAssertEqual(valueField?.typeName, ".com.example.UserInfo")
  }

  func testBuildMessageWithMapOfQualifiedType() throws {
    // Create message with map<string, google.protobuf.Timestamp> timestamps
    let mapField = FieldNode(
      name: "timestamps",
      type: .map(key: .string, value: .qualifiedType("google.protobuf.Timestamp")),
      number: 1
    )
    let message = MessageNode(name: "TestMessage", fields: [mapField])

    // Build descriptor
    let descriptor = try MessageDescriptorBuilder.build(from: message)

    // Verify entry message
    let entryMessage = descriptor.nestedType[0]

    // Verify value field has fully qualified type name
    let valueField = entryMessage.field.first { $0.name == "value" }
    XCTAssertNotNil(valueField)
    XCTAssertEqual(valueField?.type, .message)
    XCTAssertTrue(
      valueField?.typeName == ".google.protobuf.Timestamp" || valueField?.typeName == "google.protobuf.Timestamp"
    )
  }

  // MARK: - Field Name Capitalization Tests

  func testMapFieldNameCapitalization() throws {
    let testCases = [
      ("my_map_field", "My_map_fieldEntry"),
      ("data", "DataEntry"),
      ("m", "MEntry"),
      ("map_with_underscores", "Map_with_underscoresEntry"),
      ("MAP", "MAPEntry"),
    ]

    for (fieldName, expectedEntryName) in testCases {
      let mapField = FieldNode(name: fieldName, type: .map(key: .string, value: .int32), number: 1)
      let message = MessageNode(name: "TestMessage", fields: [mapField])

      let descriptor = try MessageDescriptorBuilder.build(from: message)

      XCTAssertEqual(descriptor.nestedType.count, 1, "Failed for field: \(fieldName)")
      XCTAssertEqual(descriptor.nestedType[0].name, expectedEntryName, "Capitalization incorrect for: \(fieldName)")
    }
  }

  // MARK: - Edge Cases

  func testEmptyMessageNoMapEntries() throws {
    // Message with no fields should generate no entry messages
    let message = MessageNode(name: "EmptyMessage")

    let descriptor = try MessageDescriptorBuilder.build(from: message)

    XCTAssertEqual(descriptor.nestedType.count, 0, "Empty message should have no nested types")
  }

  func testMessageWithOnlyMaps() throws {
    // Message with only map fields
    let fields = [
      FieldNode(name: "map1", type: .map(key: .string, value: .int32), number: 1),
      FieldNode(name: "map2", type: .map(key: .int32, value: .string), number: 2),
    ]
    let message = MessageNode(name: "OnlyMapsMessage", fields: fields)

    let descriptor = try MessageDescriptorBuilder.build(from: message)

    // Should only have entry messages, no explicit nested types
    XCTAssertEqual(descriptor.nestedType.count, 2)
    XCTAssertTrue(descriptor.nestedType.allSatisfy { $0.options.mapEntry })
  }

  func testMessageWithNonMapFields() throws {
    // Message with both map and non-map fields
    let fields = [
      FieldNode(name: "id", type: .int32, number: 1),
      FieldNode(name: "name", type: .string, number: 2),
      FieldNode(name: "data", type: .map(key: .string, value: .int32), number: 3),
      FieldNode(name: "tags", type: .string, number: 4, label: .repeated),
    ]
    let message = MessageNode(name: "MixedMessage", fields: fields)

    let descriptor = try MessageDescriptorBuilder.build(from: message)

    // Should have 4 fields
    XCTAssertEqual(descriptor.field.count, 4)

    // Should only have 1 entry message (for the map field)
    XCTAssertEqual(descriptor.nestedType.count, 1)
    XCTAssertEqual(descriptor.nestedType[0].name, "DataEntry")
  }

  // MARK: - All Scalar Value Types

  func testAllScalarValueTypes() throws {
    let scalarTypes: [(String, Google_Protobuf_FieldDescriptorProto.TypeEnum)] = [
      ("double", .double),
      ("float", .float),
      ("int32", .int32),
      ("int64", .int64),
      ("uint32", .uint32),
      ("uint64", .uint64),
      ("sint32", .sint32),
      ("sint64", .sint64),
      ("fixed32", .fixed32),
      ("fixed64", .fixed64),
      ("sfixed32", .sfixed32),
      ("sfixed64", .sfixed64),
      ("bool", .bool),
      ("string", .string),
      ("bytes", .bytes),
    ]

    for (valueTypeStr, expectedProtoType) in scalarTypes {
      // Create map field dynamically based on value type
      let mapField: FieldNode
      switch valueTypeStr {
      case "double": mapField = FieldNode(name: "test_map", type: .map(key: .string, value: .double), number: 1)
      case "float": mapField = FieldNode(name: "test_map", type: .map(key: .string, value: .float), number: 1)
      case "int32": mapField = FieldNode(name: "test_map", type: .map(key: .string, value: .int32), number: 1)
      case "int64": mapField = FieldNode(name: "test_map", type: .map(key: .string, value: .int64), number: 1)
      case "uint32": mapField = FieldNode(name: "test_map", type: .map(key: .string, value: .uint32), number: 1)
      case "uint64": mapField = FieldNode(name: "test_map", type: .map(key: .string, value: .uint64), number: 1)
      case "sint32": mapField = FieldNode(name: "test_map", type: .map(key: .string, value: .sint32), number: 1)
      case "sint64": mapField = FieldNode(name: "test_map", type: .map(key: .string, value: .sint64), number: 1)
      case "fixed32": mapField = FieldNode(name: "test_map", type: .map(key: .string, value: .fixed32), number: 1)
      case "fixed64": mapField = FieldNode(name: "test_map", type: .map(key: .string, value: .fixed64), number: 1)
      case "sfixed32": mapField = FieldNode(name: "test_map", type: .map(key: .string, value: .sfixed32), number: 1)
      case "sfixed64": mapField = FieldNode(name: "test_map", type: .map(key: .string, value: .sfixed64), number: 1)
      case "bool": mapField = FieldNode(name: "test_map", type: .map(key: .string, value: .bool), number: 1)
      case "string": mapField = FieldNode(name: "test_map", type: .map(key: .string, value: .string), number: 1)
      case "bytes": mapField = FieldNode(name: "test_map", type: .map(key: .string, value: .bytes), number: 1)
      default: fatalError("Unknown value type: \(valueTypeStr)")
      }

      let message = MessageNode(name: "TestMessage", fields: [mapField])

      let descriptor = try MessageDescriptorBuilder.build(from: message)

      XCTAssertEqual(descriptor.nestedType.count, 1, "Failed for value type: \(valueTypeStr)")
      let entryMessage = descriptor.nestedType[0]

      let valueField = entryMessage.field.first { $0.name == "value" }
      XCTAssertEqual(valueField?.type, expectedProtoType, "Value type mismatch for: \(valueTypeStr)")
    }
  }

  // MARK: - Error Cases

  func testMapWithMapValue() throws {
    // Maps with map values are invalid in proto3
    // This should throw an error
    let invalidMapField = FieldNode(
      name: "nested_map",
      type: .map(key: .string, value: .map(key: .string, value: .int32)),
      number: 1
    )
    let message = MessageNode(name: "InvalidMessage", fields: [invalidMapField])

    XCTAssertThrowsError(try MessageDescriptorBuilder.build(from: message)) { error in
      guard let descriptorError = error as? DescriptorError else {
        XCTFail("Expected DescriptorError, got \(type(of: error))")
        return
      }

      if case .invalidMapType(let message) = descriptorError {
        XCTAssertTrue(message.contains("Map cannot be used"))
      }
      else {
        XCTFail("Expected invalidMapType error, got \(descriptorError)")
      }
    }
  }
}
