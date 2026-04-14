import SwiftProtobuf
import XCTest

@testable import SwiftProtoParser

/// Tests for `buildUninterpretedOption(from:)` — the unified helper that converts
/// an `OptionNode` into a `Google_Protobuf_UninterpretedOption`.
///
/// Verifies:
///   1. NamePart array construction for all syntactic forms.
///   2. All five value types: string, positive int, negative int, double, bool, aggregate.
///   3. That enum options, service options, oneof options and enum-value options
///      all use the helper and no longer silently drop custom options.
final class UninterpretedOptionBuilderTests: XCTestCase {

  // MARK: - NamePart construction

  func test_buildUninterpretedOption_plainName_singleNamePartNotExtension() {
    let opt = OptionNode(name: "deprecated", subFieldPath: [], value: .boolean(true), isCustom: false)
    let result = DescriptorBuilder.buildUninterpretedOption(from: opt)

    XCTAssertEqual(result.name.count, 1)
    XCTAssertEqual(result.name[0].namePart, "deprecated")
    XCTAssertFalse(result.name[0].isExtension)
  }

  func test_buildUninterpretedOption_customNoSubField_singleExtensionNamePart() {
    let opt = OptionNode(name: "my_ext", subFieldPath: [], value: .number(42), isCustom: true)
    let result = DescriptorBuilder.buildUninterpretedOption(from: opt)

    XCTAssertEqual(result.name.count, 1)
    XCTAssertEqual(result.name[0].namePart, "my_ext")
    XCTAssertTrue(result.name[0].isExtension)
  }

  func test_buildUninterpretedOption_customOneSubField_twoNameParts() {
    let opt = OptionNode(name: "validate", subFieldPath: ["gt"], value: .number(0), isCustom: true)
    let result = DescriptorBuilder.buildUninterpretedOption(from: opt)

    XCTAssertEqual(result.name.count, 2)
    XCTAssertEqual(result.name[0].namePart, "validate")
    XCTAssertTrue(result.name[0].isExtension)
    XCTAssertEqual(result.name[1].namePart, "gt")
    XCTAssertFalse(result.name[1].isExtension)
  }

  func test_buildUninterpretedOption_customTwoSubFields_threeNameParts() {
    let opt = OptionNode(
      name: "buf.validate.field",
      subFieldPath: ["int32", "gt"],
      value: .number(0),
      isCustom: true
    )
    let result = DescriptorBuilder.buildUninterpretedOption(from: opt)

    XCTAssertEqual(result.name.count, 3)
    XCTAssertEqual(result.name[0].namePart, "buf.validate.field")
    XCTAssertTrue(result.name[0].isExtension)
    XCTAssertEqual(result.name[1].namePart, "int32")
    XCTAssertFalse(result.name[1].isExtension)
    XCTAssertEqual(result.name[2].namePart, "gt")
    XCTAssertFalse(result.name[2].isExtension)
  }

  func test_buildUninterpretedOption_threeSubFields_fourNameParts() {
    let opt = OptionNode(
      name: "pkg.ext",
      subFieldPath: ["a", "b", "c"],
      value: .number(1),
      isCustom: true
    )
    let result = DescriptorBuilder.buildUninterpretedOption(from: opt)

    XCTAssertEqual(result.name.count, 4)
    for (i, part) in result.name.enumerated() {
      XCTAssertEqual(part.isExtension, i == 0)
    }
    XCTAssertEqual(result.name[3].namePart, "c")
  }

  // MARK: - Value types

  func test_buildUninterpretedOption_stringValue_setsStringValue() {
    let opt = OptionNode(name: "pkg", subFieldPath: [], value: .string("hello"), isCustom: true)
    let result = DescriptorBuilder.buildUninterpretedOption(from: opt)

    XCTAssertEqual(result.stringValue, Data("hello".utf8))
    XCTAssertFalse(result.hasPositiveIntValue)
    XCTAssertFalse(result.hasNegativeIntValue)
    XCTAssertFalse(result.hasDoubleValue)
    XCTAssertFalse(result.hasIdentifierValue)
    XCTAssertFalse(result.hasAggregateValue)
  }

  func test_buildUninterpretedOption_positiveInteger_setsPositiveIntValue() {
    let opt = OptionNode(name: "e", subFieldPath: [], value: .number(42), isCustom: true)
    let result = DescriptorBuilder.buildUninterpretedOption(from: opt)

    XCTAssertTrue(result.hasPositiveIntValue)
    XCTAssertEqual(result.positiveIntValue, 42)
  }

  func test_buildUninterpretedOption_negativeInteger_setsNegativeIntValue() {
    let opt = OptionNode(name: "e", subFieldPath: [], value: .number(-7), isCustom: true)
    let result = DescriptorBuilder.buildUninterpretedOption(from: opt)

    XCTAssertTrue(result.hasNegativeIntValue)
    XCTAssertEqual(result.negativeIntValue, -7)
  }

  func test_buildUninterpretedOption_positiveFloat_setsDoubleValue() {
    let opt = OptionNode(name: "e", subFieldPath: [], value: .number(3.14), isCustom: true)
    let result = DescriptorBuilder.buildUninterpretedOption(from: opt)

    XCTAssertTrue(result.hasDoubleValue)
    XCTAssertEqual(result.doubleValue, 3.14, accuracy: 0.0001)
  }

  func test_buildUninterpretedOption_negativeFloat_setsDoubleValue() {
    let opt = OptionNode(name: "e", subFieldPath: [], value: .number(-2.718), isCustom: true)
    let result = DescriptorBuilder.buildUninterpretedOption(from: opt)

    XCTAssertTrue(result.hasDoubleValue)
    XCTAssertEqual(result.doubleValue, -2.718, accuracy: 0.0001)
  }

  func test_buildUninterpretedOption_boolTrue_setsIdentifierValueTrue() {
    let opt = OptionNode(name: "e", subFieldPath: [], value: .boolean(true), isCustom: true)
    let result = DescriptorBuilder.buildUninterpretedOption(from: opt)

    XCTAssertTrue(result.hasIdentifierValue)
    XCTAssertEqual(result.identifierValue, "true")
  }

  func test_buildUninterpretedOption_boolFalse_setsIdentifierValueFalse() {
    let opt = OptionNode(name: "e", subFieldPath: [], value: .boolean(false), isCustom: true)
    let result = DescriptorBuilder.buildUninterpretedOption(from: opt)

    XCTAssertTrue(result.hasIdentifierValue)
    XCTAssertEqual(result.identifierValue, "false")
  }

  func test_buildUninterpretedOption_identifierValue_setsIdentifierValue() {
    let opt = OptionNode(name: "e", subFieldPath: [], value: .identifier("MY_ENUM_VALUE"), isCustom: true)
    let result = DescriptorBuilder.buildUninterpretedOption(from: opt)

    XCTAssertTrue(result.hasIdentifierValue)
    XCTAssertEqual(result.identifierValue, "MY_ENUM_VALUE")
  }

  func test_buildUninterpretedOption_messageLiteral_setsAggregateValue() {
    let opt = OptionNode(
      name: "e",
      subFieldPath: [],
      value: .messageLiteral("{max_len: 255}"),
      isCustom: true
    )
    let result = DescriptorBuilder.buildUninterpretedOption(from: opt)

    XCTAssertTrue(result.hasAggregateValue)
    XCTAssertEqual(result.aggregateValue, "{max_len: 255}")
  }

  func test_buildUninterpretedOption_zeroInt_setsPositiveIntValue() {
    let opt = OptionNode(name: "e", subFieldPath: [], value: .number(0), isCustom: true)
    let result = DescriptorBuilder.buildUninterpretedOption(from: opt)

    XCTAssertTrue(result.hasPositiveIntValue)
    XCTAssertEqual(result.positiveIntValue, 0)
  }

  // MARK: - End-to-end: custom options in enum, service, oneof contexts

  func test_enumOptions_customOption_appearsInDescriptor() throws {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.EnumOptions { string enum_tag = 50500; }
      enum Color {
        option (enum_tag) = "colors";
        COLOR_UNSPECIFIED = 0;
        COLOR_RED = 1;
      }
      """
    let ast = try parseOrFail(proto)
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    let enumDesc = descriptor.enumType[0]

    XCTAssertEqual(enumDesc.options.uninterpretedOption.count, 1)
    let u = enumDesc.options.uninterpretedOption[0]
    XCTAssertEqual(u.name[0].namePart, "enum_tag")
    XCTAssertTrue(u.name[0].isExtension)
    XCTAssertEqual(u.stringValue, Data("colors".utf8))
  }

  func test_enumValueOptions_customOption_appearsInDescriptor() throws {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.EnumValueOptions { int32 weight = 50501; }
      enum Size {
        SIZE_UNSPECIFIED = 0;
        SIZE_SMALL = 1 [(weight) = 10];
        SIZE_LARGE = 2 [(weight) = 100];
      }
      """
    let ast = try parseOrFail(proto)
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    let enumValues = descriptor.enumType[0].value

    let smallOpts = enumValues[1].options.uninterpretedOption
    XCTAssertEqual(smallOpts.count, 1)
    XCTAssertEqual(smallOpts[0].positiveIntValue, 10)

    let largeOpts = enumValues[2].options.uninterpretedOption
    XCTAssertEqual(largeOpts.count, 1)
    XCTAssertEqual(largeOpts[0].positiveIntValue, 100)
  }

  func test_serviceOptions_customOption_appearsInDescriptor() throws {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.ServiceOptions { string svc_tag = 50502; }
      message Req {}
      message Resp {}
      service MyService {
        option (svc_tag) = "my_service";
        rpc Do(Req) returns (Resp);
      }
      """
    let ast = try parseOrFail(proto)
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    let svcOpts = descriptor.service[0].options.uninterpretedOption

    XCTAssertEqual(svcOpts.count, 1)
    XCTAssertEqual(svcOpts[0].name[0].namePart, "svc_tag")
    XCTAssertEqual(svcOpts[0].stringValue, Data("my_service".utf8))
  }

  func test_methodOptions_customOption_appearsInDescriptor() throws {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.MethodOptions { bool auth_required = 50503; }
      message Req {}
      message Resp {}
      service MyService {
        rpc Do(Req) returns (Resp) {
          option (auth_required) = true;
        }
      }
      """
    let ast = try parseOrFail(proto)
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    let methodOpts = descriptor.service[0].method[0].options.uninterpretedOption

    XCTAssertEqual(methodOpts.count, 1)
    XCTAssertEqual(methodOpts[0].identifierValue, "true")
  }

  func test_oneofOptions_customOption_appearsInDescriptor() throws {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.OneofOptions { int32 oneof_priority = 50504; }
      message M {
        oneof kind {
          option (oneof_priority) = 5;
          string text = 1;
          int32 num = 2;
        }
      }
      """
    let ast = try parseOrFail(proto)
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    let oneofOpts = descriptor.messageType[0].oneofDecl[0].options.uninterpretedOption

    XCTAssertEqual(oneofOpts.count, 1)
    XCTAssertEqual(oneofOpts[0].positiveIntValue, 5)
  }

  func test_subFieldPath_producesCorrectNamePartsInDescriptor() throws {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.FieldOptions { int32 rule = 50505; }
      message M {
        int32 age = 1 [(rule).int32.gt = 0];
        string name = 2 [(rule).string.max_len = 255];
      }
      """
    let ast = try parseOrFail(proto)
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")

    let ageOpts = descriptor.messageType[0].field[0].options.uninterpretedOption
    XCTAssertEqual(ageOpts.count, 1)
    XCTAssertEqual(ageOpts[0].name.count, 3)
    XCTAssertEqual(ageOpts[0].name[0].namePart, "rule")
    XCTAssertTrue(ageOpts[0].name[0].isExtension)
    XCTAssertEqual(ageOpts[0].name[1].namePart, "int32")
    XCTAssertFalse(ageOpts[0].name[1].isExtension)
    XCTAssertEqual(ageOpts[0].name[2].namePart, "gt")
    XCTAssertFalse(ageOpts[0].name[2].isExtension)
    XCTAssertEqual(ageOpts[0].positiveIntValue, 0)

    let nameOpts = descriptor.messageType[0].field[1].options.uninterpretedOption
    XCTAssertEqual(nameOpts.count, 1)
    XCTAssertEqual(nameOpts[0].name.count, 3)
    XCTAssertEqual(nameOpts[0].name[2].namePart, "max_len")
    XCTAssertEqual(nameOpts[0].positiveIntValue, 255)
  }

  func test_messageLiteralOption_setsAggregateValueInDescriptor() throws {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.FieldOptions { string agg = 50506; }
      message M {
        string name = 1 [(agg) = {max_len: 100}];
      }
      """
    let ast = try parseOrFail(proto)
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")

    let opts = descriptor.messageType[0].field[0].options.uninterpretedOption
    XCTAssertEqual(opts.count, 1)
    XCTAssertTrue(opts[0].hasAggregateValue)
    XCTAssertTrue(opts[0].aggregateValue.contains("max_len"))
  }

  // MARK: - Helpers

  private func parseOrFail(_ proto: String) throws -> ProtoAST {
    let result = SwiftProtoParser.parseProtoString(proto)
    guard case .success(let ast) = result else {
      throw TestError.parseFailed("\(result)")
    }
    return ast
  }

  enum TestError: Error {
    case parseFailed(String)
  }
}
