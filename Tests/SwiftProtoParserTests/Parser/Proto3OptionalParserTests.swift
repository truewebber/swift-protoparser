import XCTest

@testable import SwiftProtoParser

/// Unit tests for proto3 `optional` field parsing.
///
/// In proto3 syntax the `optional` keyword signals **explicit field presence** (proto3 optional).
/// The parser must:
///   1. Set `FieldNode.label = .optional`
///   2. Set `FieldNode.isProto3Optional = true`
///
/// In proto2 syntax `optional` is a normal label and must **not** set `isProto3Optional`.
///
/// `EnumFieldTypeResolver` (the post-parse AST pass) must also preserve `isProto3Optional`
/// unchanged — this was a previously-fixed bug that must not regress.
final class Proto3OptionalParserTests: XCTestCase {

  // MARK: - Proto3: isProto3Optional = true

  func test_proto3Optional_singleScalarField_setsFlag() {
    let proto = """
      syntax = "proto3";
      message M {
        optional uint32 age = 1;
      }
      """
    guard let fields = parseFields(proto) else { return }

    XCTAssertEqual(fields.count, 1)
    XCTAssertEqual(fields[0].name, "age")
    XCTAssertEqual(fields[0].label, .optional)
    XCTAssertTrue(fields[0].isProto3Optional)
  }

  func test_proto3Optional_multipleFields_allFlagged() {
    let proto = """
      syntax = "proto3";
      message M {
        optional string name = 1;
        optional int32  count = 2;
        optional bool   active = 3;
      }
      """
    guard let fields = parseFields(proto) else { return }

    XCTAssertEqual(fields.count, 3)
    for field in fields {
      XCTAssertTrue(field.isProto3Optional, "field '\(field.name)' should have isProto3Optional=true")
      XCTAssertEqual(field.label, .optional)
    }
  }

  func test_proto3Optional_messageTypeField_setsFlag() {
    let proto = """
      syntax = "proto3";
      message Inner {}
      message Outer {
        optional Inner inner = 1;
      }
      """
    guard let ast = parse(proto) else { return }

    let fields = ast.messages.first(where: { $0.name == "Outer" })?.fields ?? []
    XCTAssertEqual(fields.count, 1)
    XCTAssertTrue(fields[0].isProto3Optional)
  }

  func test_proto3Optional_mixedWithRegularFields_onlyOptionalFlagged() {
    let proto = """
      syntax = "proto3";
      message M {
        string regular = 1;
        optional string optional_field = 2;
        repeated int32 items = 3;
      }
      """
    guard let fields = parseFields(proto) else { return }

    XCTAssertEqual(fields.count, 3)
    XCTAssertFalse(fields[0].isProto3Optional, "regular field must not be flagged")
    XCTAssertTrue(fields[1].isProto3Optional, "optional field must be flagged")
    XCTAssertFalse(fields[2].isProto3Optional, "repeated field must not be flagged")
  }

  func test_proto3Optional_repeatedNotFlagged() {
    let proto = """
      syntax = "proto3";
      message M {
        repeated string tags = 1;
      }
      """
    guard let fields = parseFields(proto) else { return }

    XCTAssertEqual(fields.count, 1)
    XCTAssertFalse(fields[0].isProto3Optional)
  }

  func test_proto3Optional_singularFieldNoLabel_notFlagged() {
    let proto = """
      syntax = "proto3";
      message M {
        string name = 1;
      }
      """
    guard let fields = parseFields(proto) else { return }

    XCTAssertEqual(fields.count, 1)
    XCTAssertFalse(fields[0].isProto3Optional)
  }

  // MARK: - Proto2: isProto3Optional = false

  func test_proto2Optional_regularLabel_doesNotSetFlag() {
    let proto = """
      syntax = "proto2";
      message M {
        optional string name = 1;
        optional int32 count = 2;
        required bool active = 3;
      }
      """
    guard let fields = parseFields(proto) else { return }

    XCTAssertEqual(fields.count, 3)
    for field in fields {
      XCTAssertFalse(field.isProto3Optional, "proto2 field '\(field.name)' must not set isProto3Optional")
    }
  }

  // MARK: - EnumFieldTypeResolver does not lose the flag (regression guard)

  func test_proto3Optional_enumTypeField_flagPreservedAfterTypeResolution() {
    // The field type is an enum — EnumFieldTypeResolver will rewrite the FieldNode.
    // It must preserve isProto3Optional when creating the new node.
    let proto = """
      syntax = "proto3";
      enum Status { STATUS_UNSPECIFIED = 0; STATUS_OK = 1; }
      message M {
        optional Status status = 1;
      }
      """
    guard let fields = parseFields(proto) else { return }

    XCTAssertEqual(fields.count, 1)
    XCTAssertTrue(fields[0].isProto3Optional, "isProto3Optional must survive EnumFieldTypeResolver pass")
    if case .enumType(let name) = fields[0].type {
      XCTAssertEqual(name, "Status")
    }
    else {
      XCTFail("Field type should be .enumType after resolver pass, got \(fields[0].type)")
    }
  }

  func test_proto3Optional_messageTypeField_flagPreservedAfterTypeResolution() {
    // A non-enum message type field — resolver leaves .message, but must preserve the flag.
    let proto = """
      syntax = "proto3";
      message Inner {}
      message Outer {
        optional Inner inner = 1;
      }
      """
    guard let ast = parse(proto) else { return }
    let fields = ast.messages.first(where: { $0.name == "Outer" })?.fields ?? []

    XCTAssertEqual(fields.count, 1)
    XCTAssertTrue(fields[0].isProto3Optional)
  }

  // MARK: - Helpers

  private func parse(_ proto: String, file: StaticString = #file, line: UInt = #line) -> ProtoAST? {
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast): return ast
    case .failure(let e):
      XCTFail("Parse failed: \(e)", file: file, line: line)
      return nil
    }
  }

  private func parseFields(
    _ proto: String,
    messageIndex: Int = 0,
    file: StaticString = #file,
    line: UInt = #line
  ) -> [FieldNode]? {
    guard let ast = parse(proto, file: file, line: line) else { return nil }
    guard messageIndex < ast.messages.count else {
      XCTFail("No message at index \(messageIndex)", file: file, line: line)
      return nil
    }
    return ast.messages[messageIndex].fields
  }
}
