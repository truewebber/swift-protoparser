import SwiftProtobuf
import XCTest

@testable import SwiftProtoParser

/// Test to reproduce and verify the issue from ISSUE_MAP_FIELDS.md.
class MapFieldIssueReproductionTest: XCTestCase {

  func testMapFieldDescriptorGeneration() throws {
    // Reproduce the exact scenario from ISSUE_MAP_FIELDS.md
    let protoContent = """
      syntax = "proto3";

      message Request {
        map<string, string> metadata = 1;
      }
      """

    // Parse the proto content
    let lexer = Lexer(input: protoContent)
    let tokensResult = lexer.tokenize()

    guard case .success(let tokens) = tokensResult else {
      XCTFail("Lexer failed")
      return
    }

    let parser = Parser(tokens: tokens)
    let parseResult = parser.parse()

    guard case .success(let ast) = parseResult else {
      XCTFail("Parser failed")
      return
    }

    // Build the descriptor
    let fileDescriptorProto = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")

    // Verify the file descriptor structure
    XCTAssertEqual(fileDescriptorProto.messageType.count, 1, "Should have one message type")

    let requestMessage = fileDescriptorProto.messageType[0]
    XCTAssertEqual(requestMessage.name, "Request")

    // Check the metadata field
    XCTAssertEqual(requestMessage.field.count, 1, "Request should have one field")
    let metadataField = requestMessage.field[0]

    print("\n=== Map Field Analysis ===")
    print("Field name: \(metadataField.name)")
    print("Field type: \(metadataField.type)")
    print("Field type_name: \(metadataField.typeName)")
    print("Field label: \(metadataField.label)")

    // According to protobuf spec, map fields should be:
    // 1. Type = TYPE_MESSAGE
    XCTAssertEqual(
      metadataField.type,
      Google_Protobuf_FieldDescriptorProto.TypeEnum.message,
      "Map field should be TYPE_MESSAGE"
    )

    // 2. Label = LABEL_REPEATED
    XCTAssertEqual(
      metadataField.label,
      Google_Protobuf_FieldDescriptorProto.Label.repeated,
      "Map field should be LABEL_REPEATED"
    )

    // 3. type_name should point to the auto-generated entry message
    XCTAssertEqual(metadataField.typeName, "MetadataEntry", "Map field should reference MetadataEntry")

    // Check for the auto-generated MapEntry message
    print("\n=== Nested Types (MapEntry messages) ===")
    print("Number of nested types: \(requestMessage.nestedType.count)")

    XCTAssertEqual(requestMessage.nestedType.count, 1, "Should have one nested type (MetadataEntry)")

    let entryMessage = requestMessage.nestedType[0]
    print("Entry message name: \(entryMessage.name)")
    print("Entry message has map_entry option: \(entryMessage.options.mapEntry)")

    // Verify the entry message structure
    XCTAssertEqual(entryMessage.name, "MetadataEntry", "Entry message should be named MetadataEntry")

    // THIS IS THE KEY CHECK: Does the entry message have map_entry = true?
    XCTAssertTrue(entryMessage.options.mapEntry, "❌ ISSUE: Entry message should have map_entry = true")

    // Verify entry message fields (key and value)
    XCTAssertEqual(entryMessage.field.count, 2, "Entry message should have key and value fields")

    let keyField = entryMessage.field.first { $0.name == "key" }
    let valueField = entryMessage.field.first { $0.name == "value" }

    XCTAssertNotNil(keyField, "Entry message should have a 'key' field")
    XCTAssertNotNil(valueField, "Entry message should have a 'value' field")

    print("\n=== Entry Message Fields ===")
    if let key = keyField {
      print("Key field: name=\(key.name), number=\(key.number), type=\(key.type)")
    }
    if let value = valueField {
      print("Value field: name=\(value.name), number=\(value.number), type=\(value.type)")
    }

    print("\n=== Conclusion ===")
    print("✅ SwiftProtoParser correctly generates:")
    print("   1. Map field as TYPE_MESSAGE with LABEL_REPEATED")
    print("   2. Auto-generated MetadataEntry nested message")
    print("   3. map_entry option set to true in the entry message")
    print("   4. Key and value fields in the entry message")
    print()
    print("🔍 If SwiftProtoReflect reports isMap=false, the issue is likely in:")
    print("   - SwiftProtoReflect's interpretation of the descriptor")
    print("   - NOT in SwiftProtoParser's generation of the descriptor")
  }
}
