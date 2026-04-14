import XCTest

@testable import SwiftProtoParser

/// Tests for sub-field paths in qualified option names.
///
/// Proto grammar: optionName = ( ident | "(" fullIdent ")" ) { "." ident }
///
/// The trailing `{ "." ident }` loop is the bug that was missing.
/// For `(buf.validate.field).int32.gt`:
///   - `OptionNode.name`         = "buf.validate.field"
///   - `OptionNode.subFieldPath` = ["int32", "gt"]
///   - `OptionNode.isCustom`     = true
final class SubFieldOptionNameTests: XCTestCase {

  // MARK: - Context 1: Field options (inline [])

  func test_fieldOption_singleSubField_populatesSubFieldPath() {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.FieldOptions { int32 validate = 50001; }
      message M { int32 age = 1 [(validate).gt = 0]; }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Parse failed: \(result)")
    guard case .success(let ast) = result else { return }

    let opt = ast.messages[0].fields[0].options[0]
    XCTAssertEqual(opt.name, "validate")
    XCTAssertTrue(opt.isCustom)
    XCTAssertEqual(opt.subFieldPath, ["gt"])
  }

  func test_fieldOption_twoSubFields_populatesSubFieldPath() {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.FieldOptions { int32 validate = 50002; }
      message M { string name = 1 [(validate).string.max_len = 255]; }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Parse failed: \(result)")
    guard case .success(let ast) = result else { return }

    let opt = ast.messages[0].fields[0].options[0]
    XCTAssertEqual(opt.name, "validate")
    XCTAssertTrue(opt.isCustom)
    XCTAssertEqual(opt.subFieldPath, ["string", "max_len"])
  }

  func test_fieldOption_qualifiedNameWithSubField_populatesSubFieldPath() {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.FieldOptions { int32 rule = 50003; }
      message M { int32 val = 1 [(pkg.sub.rule).int32.gt = 0]; }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Parse failed: \(result)")
    guard case .success(let ast) = result else { return }

    let opt = ast.messages[0].fields[0].options[0]
    XCTAssertEqual(opt.name, "pkg.sub.rule")
    XCTAssertTrue(opt.isCustom)
    XCTAssertEqual(opt.subFieldPath, ["int32", "gt"])
  }

  func test_fieldOption_multipleOptionsOneWithSubField_parsesAll() {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.FieldOptions {
        int32 rule_a = 50004;
        int32 rule_b = 50005;
      }
      message M {
        int32 x = 1 [(rule_a).min = 0, (rule_b).max = 100];
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Parse failed: \(result)")
    guard case .success(let ast) = result else { return }

    let options = ast.messages[0].fields[0].options
    XCTAssertEqual(options.count, 2)
    XCTAssertEqual(options[0].subFieldPath, ["min"])
    XCTAssertEqual(options[1].subFieldPath, ["max"])
  }

  func test_fieldOption_mixedSubFieldAndPlain_parsesAll() {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.FieldOptions { int32 custom = 50006; }
      message M {
        int32 x = 1 [(custom).sub = 1, deprecated = true];
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Parse failed: \(result)")
    guard case .success(let ast) = result else { return }

    let options = ast.messages[0].fields[0].options
    XCTAssertEqual(options.count, 2)
    XCTAssertEqual(options[0].name, "custom")
    XCTAssertEqual(options[0].subFieldPath, ["sub"])
    XCTAssertEqual(options[1].name, "deprecated")
    XCTAssertEqual(options[1].subFieldPath, [])
  }

  // MARK: - Context 2: Standalone option declaration

  func test_standaloneOption_singleSubField_populatesSubFieldPath() {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.FileOptions { int32 my_file_opt = 50010; }
      option (my_file_opt).sub = 42;
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Parse failed: \(result)")
    guard case .success(let ast) = result else { return }

    XCTAssertEqual(ast.options.count, 1)
    let opt = ast.options[0]
    XCTAssertEqual(opt.name, "my_file_opt")
    XCTAssertTrue(opt.isCustom)
    XCTAssertEqual(opt.subFieldPath, ["sub"])
  }

  func test_standaloneOption_twoSubFields_populatesSubFieldPath() {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.FileOptions { int32 deep_opt = 50011; }
      option (deep_opt).level1.level2 = 7;
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Parse failed: \(result)")
    guard case .success(let ast) = result else { return }

    XCTAssertEqual(ast.options.count, 1)
    XCTAssertEqual(ast.options[0].subFieldPath, ["level1", "level2"])
  }

  // MARK: - Context 3: Message options

  func test_messageOption_subField_populatesSubFieldPath() {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.MessageOptions { int32 msg_rule = 50020; }
      message M {
        option (msg_rule).strict = 1;
        string name = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Parse failed: \(result)")
    guard case .success(let ast) = result else { return }

    XCTAssertEqual(ast.messages[0].options.count, 1)
    let opt = ast.messages[0].options[0]
    XCTAssertEqual(opt.subFieldPath, ["strict"])
  }

  // MARK: - Context 4: Enum options

  func test_enumOption_subField_populatesSubFieldPath() {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.EnumOptions { int32 enum_rule = 50030; }
      enum Color {
        option (enum_rule).validate = 1;
        COLOR_UNSPECIFIED = 0;
        COLOR_RED = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Parse failed: \(result)")
    guard case .success(let ast) = result else { return }

    XCTAssertEqual(ast.enums[0].options.count, 1)
    XCTAssertEqual(ast.enums[0].options[0].subFieldPath, ["validate"])
  }

  // MARK: - Context 5: Enum value options

  func test_enumValueOption_subField_populatesSubFieldPath() {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.EnumValueOptions { int32 val_rule = 50040; }
      enum Status {
        STATUS_UNSPECIFIED = 0;
        STATUS_ACTIVE = 1 [(val_rule).weight = 10];
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Parse failed: \(result)")
    guard case .success(let ast) = result else { return }

    let values = ast.enums[0].values
    let activeOpt = values[1].options[0]
    XCTAssertEqual(activeOpt.subFieldPath, ["weight"])
  }

  // MARK: - Context 6: Service options

  func test_serviceOption_subField_populatesSubFieldPath() {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.ServiceOptions { string svc_rule = 50050; }
      message Req {}
      message Resp {}
      service MyService {
        option (svc_rule).category = "category_value";
        rpc DoIt(Req) returns (Resp);
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Parse failed: \(result)")
    guard case .success(let ast) = result else { return }

    XCTAssertEqual(ast.services[0].options.count, 1)
    XCTAssertEqual(ast.services[0].options[0].subFieldPath, ["category"])
  }

  // MARK: - Context 7: RPC method options

  func test_methodOption_subField_populatesSubFieldPath() {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.MethodOptions { bool meth_rule = 50060; }
      message Req {}
      message Resp {}
      service MyService {
        rpc DoIt(Req) returns (Resp) {
          option (meth_rule).required = true;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Parse failed: \(result)")
    guard case .success(let ast) = result else { return }

    let method = ast.services[0].methods[0]
    XCTAssertEqual(method.options.count, 1)
    XCTAssertEqual(method.options[0].subFieldPath, ["required"])
  }

  // MARK: - Context 8: Oneof options

  func test_oneofOption_subField_populatesSubFieldPath() {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.OneofOptions { int32 oneof_rule = 50070; }
      message M {
        oneof kind {
          option (oneof_rule).strict = 1;
          string text = 1;
          int32 num = 2;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Parse failed: \(result)")
    guard case .success(let ast) = result else { return }

    let oneofGroups = ast.messages[0].oneofGroups
    XCTAssertEqual(oneofGroups[0].options.count, 1)
    XCTAssertEqual(oneofGroups[0].options[0].subFieldPath, ["strict"])
  }

  // MARK: - NamePart structure: subFieldPath contents

  func test_namePartStructure_noSubField_emptySubFieldPath() {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.FieldOptions { string plain = 50100; }
      message M { string s = 1 [(plain) = "val"]; }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess)
    guard case .success(let ast) = result else { return }

    let opt = ast.messages[0].fields[0].options[0]
    XCTAssertEqual(opt.name, "plain")
    XCTAssertTrue(opt.isCustom)
    XCTAssertEqual(opt.subFieldPath, [])
  }

  func test_namePartStructure_threeSubFields_capturesAll() {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.FieldOptions { int32 deep = 50101; }
      message M { int32 x = 1 [(deep).a.b.c = 99]; }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Parse failed: \(result)")
    guard case .success(let ast) = result else { return }

    let opt = ast.messages[0].fields[0].options[0]
    XCTAssertEqual(opt.subFieldPath, ["a", "b", "c"])
  }

  func test_namePartStructure_fullyQualifiedWithSubField_splitCorrectly() {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.FieldOptions { int32 fq_rule = 50102; }
      message M { int32 x = 1 [(pkg.ns.fq_rule).field = 5]; }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Parse failed: \(result)")
    guard case .success(let ast) = result else { return }

    let opt = ast.messages[0].fields[0].options[0]
    XCTAssertEqual(opt.name, "pkg.ns.fq_rule")
    XCTAssertEqual(opt.subFieldPath, ["field"])
  }

  func test_namePartStructure_plainOptionName_noSubField() {
    let proto = """
      syntax = "proto3";
      message M { string s = 1 [deprecated = true]; }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess)
    guard case .success(let ast) = result else { return }

    let opt = ast.messages[0].fields[0].options[0]
    XCTAssertEqual(opt.name, "deprecated")
    XCTAssertFalse(opt.isCustom)
    XCTAssertEqual(opt.subFieldPath, [])
  }

  // MARK: - Real-world patterns

  func test_bufValidateFieldInt32Gt_parsesCorrectly() {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.FieldOptions { int32 buf_validate_field = 1159; }
      message Request {
        int32 user_id = 1 [(buf_validate_field).int32.gt = 0];
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Parse failed: \(result)")
    guard case .success(let ast) = result else { return }

    let opt = ast.messages[0].fields[0].options[0]
    XCTAssertEqual(opt.name, "buf_validate_field")
    XCTAssertEqual(opt.subFieldPath, ["int32", "gt"])
    if case .number(let v) = opt.value {
      XCTAssertEqual(v, 0.0)
    }
    else {
      XCTFail("Expected .number(0), got \(opt.value)")
    }
  }

  func test_bufValidateFieldStringPattern_parsesCorrectly() {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.FieldOptions { int32 field_rule = 1159; }
      message M {
        string campaign_id = 1 [(field_rule).string.pattern = "^\\\\d+$"];
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Parse failed: \(result)")
    guard case .success(let ast) = result else { return }

    let opt = ast.messages[0].fields[0].options[0]
    XCTAssertEqual(opt.subFieldPath, ["string", "pattern"])
    if case .string = opt.value {
      // correct
    }
    else {
      XCTFail("Expected .string, got \(opt.value)")
    }
  }

  // MARK: - Edge cases

  func test_subFieldAfterCustomOptionWithNoSubField_noSubFieldPath() {
    // Ensure (ext) = value (no dot after ')') still produces empty subFieldPath
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.FieldOptions { int32 plain_ext = 50200; }
      message M { int32 x = 1 [(plain_ext) = 7]; }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess)
    guard case .success(let ast) = result else { return }

    XCTAssertEqual(ast.messages[0].fields[0].options[0].subFieldPath, [])
  }

  func test_messageLiteralOptionValue_parsesAsMessageLiteral() {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.FieldOptions { int32 agg_rule = 50300; }
      message M { string s = 1 [(agg_rule) = {max_len: 255}]; }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Parse failed: \(result)")
    guard case .success(let ast) = result else { return }

    let opt = ast.messages[0].fields[0].options[0]
    guard case .messageLiteral(let block) = opt.value else {
      XCTFail("Expected .messageLiteral, got \(opt.value)")
      return
    }
    XCTAssertTrue(block.contains("max_len"))
  }

  func test_messageLiteralInStandaloneOption_parsesAsMessageLiteral() {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.FileOptions { int32 file_agg = 50301; }
      option (file_agg) = {key: "value", num: 42};
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Parse failed: \(result)")
    guard case .success(let ast) = result else { return }

    let opt = ast.options[0]
    guard case .messageLiteral = opt.value else {
      XCTFail("Expected .messageLiteral, got \(opt.value)")
      return
    }
  }
}
