import SwiftProtobuf
import XCTest

@testable import SwiftProtoParser

/// Unit tests for proto3 optional field descriptor generation in `MessageDescriptorBuilder`.
///
/// Per the protobuf spec, each proto3 `optional` field must result in:
///   1. `FieldDescriptorProto.proto3_optional = true`
///   2. A **synthetic oneof** named `_<fieldName>` appended to `oneofDecl`.
///   3. `FieldDescriptorProto.oneof_index` pointing to that synthetic oneof.
///
/// Synthetic oneofs are always appended **after** all explicit oneofs, so that existing
/// `oneof_index` values for explicit oneof fields remain valid.
final class Proto3OptionalDescriptorTests: XCTestCase {

  // MARK: - Single proto3 optional field

  func test_singleProto3Optional_setsProto3OptionalFlag() throws {
    let msg = MessageNode(
      name: "M",
      fields: [FieldNode(name: "value", type: .int32, number: 1, label: .optional, isProto3Optional: true)]
    )
    let descriptor = try MessageDescriptorBuilder.build(from: msg)

    XCTAssertEqual(descriptor.field.count, 1)
    XCTAssertTrue(descriptor.field[0].proto3Optional)
  }

  func test_singleProto3Optional_createsSyntheticOneof() throws {
    let msg = MessageNode(
      name: "M",
      fields: [FieldNode(name: "value", type: .int32, number: 1, label: .optional, isProto3Optional: true)]
    )
    let descriptor = try MessageDescriptorBuilder.build(from: msg)

    XCTAssertEqual(descriptor.oneofDecl.count, 1)
    XCTAssertEqual(descriptor.oneofDecl[0].name, "_value")
  }

  func test_singleProto3Optional_fieldPointsToSyntheticOneof() throws {
    let msg = MessageNode(
      name: "M",
      fields: [FieldNode(name: "value", type: .int32, number: 1, label: .optional, isProto3Optional: true)]
    )
    let descriptor = try MessageDescriptorBuilder.build(from: msg)

    XCTAssertEqual(descriptor.field[0].oneofIndex, 0)
  }

  // MARK: - Multiple proto3 optional fields

  func test_twoProto3Optional_twoSyntheticOneofs() throws {
    let msg = MessageNode(
      name: "M",
      fields: [
        FieldNode(name: "a", type: .string, number: 1, label: .optional, isProto3Optional: true),
        FieldNode(name: "b", type: .int32, number: 2, label: .optional, isProto3Optional: true),
      ]
    )
    let descriptor = try MessageDescriptorBuilder.build(from: msg)

    XCTAssertEqual(descriptor.oneofDecl.count, 2)
    XCTAssertEqual(descriptor.oneofDecl[0].name, "_a")
    XCTAssertEqual(descriptor.oneofDecl[1].name, "_b")
  }

  func test_twoProto3Optional_fieldIndicesAreDistinct() throws {
    let msg = MessageNode(
      name: "M",
      fields: [
        FieldNode(name: "a", type: .string, number: 1, label: .optional, isProto3Optional: true),
        FieldNode(name: "b", type: .int32, number: 2, label: .optional, isProto3Optional: true),
      ]
    )
    let descriptor = try MessageDescriptorBuilder.build(from: msg)

    XCTAssertTrue(descriptor.field[0].proto3Optional)
    XCTAssertTrue(descriptor.field[1].proto3Optional)
    XCTAssertEqual(descriptor.field[0].oneofIndex, 0)
    XCTAssertEqual(descriptor.field[1].oneofIndex, 1)
  }

  // MARK: - Mixed: explicit oneof + proto3 optional fields

  func test_mixedExplicitOneofAndProto3Optional_syntheticAppendedAfterExplicit() throws {
    let oneofGroup = OneofNode(
      name: "kind",
      fields: [
        FieldNode(name: "text_val", type: .string, number: 10),
        FieldNode(name: "int_val", type: .int32, number: 11),
      ]
    )
    let msg = MessageNode(
      name: "M",
      fields: [
        FieldNode(name: "regular", type: .string, number: 1),
        FieldNode(name: "opt_field", type: .int32, number: 2, label: .optional, isProto3Optional: true),
      ],
      oneofGroups: [oneofGroup]
    )
    let descriptor = try MessageDescriptorBuilder.build(from: msg)

    // oneofDecl[0] = explicit "kind", oneofDecl[1] = synthetic "_opt_field"
    XCTAssertEqual(descriptor.oneofDecl.count, 2)
    XCTAssertEqual(descriptor.oneofDecl[0].name, "kind")
    XCTAssertEqual(descriptor.oneofDecl[1].name, "_opt_field")
  }

  func test_mixedExplicitOneofAndProto3Optional_explicitFieldsHaveCorrectIndex() throws {
    let oneofGroup = OneofNode(
      name: "kind",
      fields: [
        FieldNode(name: "text_val", type: .string, number: 10),
        FieldNode(name: "int_val", type: .int32, number: 11),
      ]
    )
    let msg = MessageNode(
      name: "M",
      fields: [
        FieldNode(name: "opt_field", type: .int32, number: 2, label: .optional, isProto3Optional: true)
      ],
      oneofGroups: [oneofGroup]
    )
    let descriptor = try MessageDescriptorBuilder.build(from: msg)

    // text_val and int_val must reference oneof index 0 ("kind")
    let oneofFields = descriptor.field.filter { $0.name == "text_val" || $0.name == "int_val" }
    XCTAssertEqual(oneofFields.count, 2)
    for f in oneofFields {
      XCTAssertEqual(f.oneofIndex, 0, "Explicit oneof field '\(f.name)' must point to index 0")
    }
  }

  func test_mixedExplicitOneofAndProto3Optional_syntheticFieldHasCorrectIndex() throws {
    let oneofGroup = OneofNode(
      name: "kind",
      fields: [FieldNode(name: "text_val", type: .string, number: 10)]
    )
    let msg = MessageNode(
      name: "M",
      fields: [
        FieldNode(name: "opt_field", type: .int32, number: 2, label: .optional, isProto3Optional: true)
      ],
      oneofGroups: [oneofGroup]
    )
    let descriptor = try MessageDescriptorBuilder.build(from: msg)

    // Synthetic oneof is at index 1 (after explicit "kind" at index 0)
    let optField = descriptor.field.first(where: { $0.name == "opt_field" })
    XCTAssertNotNil(optField)
    XCTAssertTrue(optField!.proto3Optional)
    XCTAssertEqual(optField!.oneofIndex, 1)
  }

  func test_multipleExplicitOneofs_syntheticAppendedAfterAll() throws {
    let oneof1 = OneofNode(name: "first", fields: [FieldNode(name: "f1", type: .string, number: 10)])
    let oneof2 = OneofNode(name: "second", fields: [FieldNode(name: "f2", type: .int32, number: 11)])
    let msg = MessageNode(
      name: "M",
      fields: [
        FieldNode(name: "opt_a", type: .string, number: 1, label: .optional, isProto3Optional: true),
        FieldNode(name: "opt_b", type: .bool, number: 2, label: .optional, isProto3Optional: true),
      ],
      oneofGroups: [oneof1, oneof2]
    )
    let descriptor = try MessageDescriptorBuilder.build(from: msg)

    // oneofDecl: [0]=first, [1]=second, [2]=_opt_a, [3]=_opt_b
    XCTAssertEqual(descriptor.oneofDecl.count, 4)
    XCTAssertEqual(descriptor.oneofDecl[0].name, "first")
    XCTAssertEqual(descriptor.oneofDecl[1].name, "second")
    XCTAssertEqual(descriptor.oneofDecl[2].name, "_opt_a")
    XCTAssertEqual(descriptor.oneofDecl[3].name, "_opt_b")

    let optA = descriptor.field.first(where: { $0.name == "opt_a" })!
    let optB = descriptor.field.first(where: { $0.name == "opt_b" })!
    XCTAssertEqual(optA.oneofIndex, 2)
    XCTAssertEqual(optB.oneofIndex, 3)
  }

  // MARK: - Non-optional fields are not affected

  func test_regularField_noSyntheticOneofCreated() throws {
    let msg = MessageNode(
      name: "M",
      fields: [FieldNode(name: "name", type: .string, number: 1)]
    )
    let descriptor = try MessageDescriptorBuilder.build(from: msg)

    XCTAssertEqual(descriptor.oneofDecl.count, 0)
    XCTAssertFalse(descriptor.field[0].proto3Optional)
  }

  func test_repeatedField_noSyntheticOneofCreated() throws {
    let msg = MessageNode(
      name: "M",
      fields: [FieldNode(name: "tags", type: .string, number: 1, label: .repeated)]
    )
    let descriptor = try MessageDescriptorBuilder.build(from: msg)

    XCTAssertEqual(descriptor.oneofDecl.count, 0)
    XCTAssertFalse(descriptor.field[0].proto3Optional)
  }

  // MARK: - End-to-end: parse → build descriptor

  func test_endToEnd_proto3Optional_fieldAndOneofInDescriptor() throws {
    let proto = """
      syntax = "proto3";
      message M {
        string regular = 1;
        optional int32 opt_int = 2;
        optional string opt_str = 3;
      }
      """
    let result = SwiftProtoParser.parseProtoStringToDescriptors(proto)
    guard case .success(let fileDesc) = result else {
      XCTFail("parseProtoStringToDescriptors failed: \(result)")
      return
    }
    let msg = fileDesc.messageType.first(where: { $0.name == "M" })
    XCTAssertNotNil(msg)

    // 3 fields total
    XCTAssertEqual(msg!.field.count, 3)

    let regularField = msg!.field.first(where: { $0.name == "regular" })!
    let optIntField = msg!.field.first(where: { $0.name == "opt_int" })!
    let optStrField = msg!.field.first(where: { $0.name == "opt_str" })!

    // regular field: no proto3Optional, no synthetic oneof
    XCTAssertFalse(regularField.proto3Optional)

    // optional fields: proto3Optional=true
    XCTAssertTrue(optIntField.proto3Optional)
    XCTAssertTrue(optStrField.proto3Optional)

    // two synthetic oneofs: _opt_int, _opt_str
    XCTAssertEqual(msg!.oneofDecl.count, 2)
    XCTAssertEqual(msg!.oneofDecl[0].name, "_opt_int")
    XCTAssertEqual(msg!.oneofDecl[1].name, "_opt_str")

    // oneofIndex values
    XCTAssertEqual(optIntField.oneofIndex, 0)
    XCTAssertEqual(optStrField.oneofIndex, 1)
  }

  func test_endToEnd_proto3Optional_mixedWithExplicitOneof() throws {
    let proto = """
      syntax = "proto3";
      message M {
        optional string name = 1;
        oneof kind {
          string text = 10;
          int32 number = 11;
        }
        optional bool active = 2;
      }
      """
    let result = SwiftProtoParser.parseProtoStringToDescriptors(proto)
    guard case .success(let fileDesc) = result else {
      XCTFail("parseProtoStringToDescriptors failed: \(result)")
      return
    }
    let msg = fileDesc.messageType.first(where: { $0.name == "M" })
    XCTAssertNotNil(msg)

    // oneofDecl: [0]=kind (explicit), [1]=_name, [2]=_active (synthetic)
    XCTAssertEqual(msg!.oneofDecl.count, 3)
    XCTAssertEqual(msg!.oneofDecl[0].name, "kind")
    XCTAssertEqual(msg!.oneofDecl[1].name, "_name")
    XCTAssertEqual(msg!.oneofDecl[2].name, "_active")

    // Explicit oneof fields must point to index 0
    let textField = msg!.field.first(where: { $0.name == "text" })!
    let numberField = msg!.field.first(where: { $0.name == "number" })!
    XCTAssertEqual(textField.oneofIndex, 0)
    XCTAssertEqual(numberField.oneofIndex, 0)

    // Synthetic optional fields
    let nameField = msg!.field.first(where: { $0.name == "name" })!
    let activeField = msg!.field.first(where: { $0.name == "active" })!
    XCTAssertTrue(nameField.proto3Optional)
    XCTAssertTrue(activeField.proto3Optional)
    XCTAssertEqual(nameField.oneofIndex, 1)
    XCTAssertEqual(activeField.oneofIndex, 2)
  }
}
