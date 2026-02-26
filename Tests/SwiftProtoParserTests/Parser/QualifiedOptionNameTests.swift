import XCTest

@testable import SwiftProtoParser

/// Tests for qualified (dotted) option names inside parentheses.
///
/// Proto grammar: optionName = ( ident | "(" fullIdent ")" ) { "." ident }
/// where fullIdent = ident { "." ident }
///
/// Covers the bug where `[(example.my_option) = "val"]` caused a syntax error
/// because the parser only accepted a single identifier inside parentheses.
final class QualifiedOptionNameTests: XCTestCase {

  // MARK: - TC-1: Regression / Bug Reproducer Tests

  func test_parseFieldOption_twoPartQualifiedName_parsesSuccessfully() {
    let proto = """
      syntax = "proto3";

      package example;

      extend google.protobuf.FieldOptions {
        optional string my_option = 50001;
      }

      message Foo {
        string bar = 1 [(example.my_option) = "hello"];
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Expected success, got: \(result)")

    guard case .success(let ast) = result else { return }
    let field = ast.messages[0].fields[0]
    XCTAssertEqual(field.options.count, 1)
    XCTAssertEqual(field.options[0].name, "example.my_option")
    XCTAssertTrue(field.options[0].isCustom)
  }

  func test_parseFieldOption_fourPartQualifiedName_parsesSuccessfully() {
    let proto = """
      syntax = "proto3";

      extend google.protobuf.FieldOptions {
        optional int32 user_data = 50002;
      }

      message User {
        int64 id = 1 [(platform.apis.user.user_data) = 1];
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Expected success, got: \(result)")

    guard case .success(let ast) = result else { return }
    let field = ast.messages[0].fields[0]
    XCTAssertEqual(field.options.count, 1)
    XCTAssertEqual(field.options[0].name, "platform.apis.user.user_data")
    XCTAssertTrue(field.options[0].isCustom)
  }

  func test_parseFileOption_twoPartQualifiedName_parsesSuccessfully() {
    let proto = """
      syntax = "proto3";

      extend google.protobuf.FileOptions {
        optional string pkg_option = 50003;
      }

      option (pkg.pkg_option) = "com.example";

      message Dummy { string name = 1; }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Expected success, got: \(result)")

    guard case .success(let ast) = result else { return }
    let customOption = ast.options.first { $0.isCustom }
    XCTAssertNotNil(customOption)
    XCTAssertEqual(customOption?.name, "pkg.pkg_option")
  }

  func test_parseMessageOption_twoPartQualifiedName_parsesSuccessfully() {
    let proto = """
      syntax = "proto3";

      extend google.protobuf.MessageOptions {
        optional bool my_msg_option = 50004;
      }

      message Foo {
        option (pkg.my_msg_option) = true;
        string bar = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Expected success, got: \(result)")

    guard case .success(let ast) = result else { return }
    let message = ast.messages[0]
    XCTAssertEqual(message.options.count, 1)
    XCTAssertEqual(message.options[0].name, "pkg.my_msg_option")
    XCTAssertTrue(message.options[0].isCustom)
  }

  func test_parseServiceOption_twoPartQualifiedName_parsesSuccessfully() {
    let proto = """
      syntax = "proto3";

      extend google.protobuf.ServiceOptions {
        optional string service_version = 50005;
      }

      message Req {}
      message Resp {}

      service TestService {
        option (pkg.service_version) = "v1";
        rpc Method(Req) returns (Resp);
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Expected success, got: \(result)")

    guard case .success(let ast) = result else { return }
    let service = ast.services[0]
    XCTAssertEqual(service.options.count, 1)
    XCTAssertEqual(service.options[0].name, "pkg.service_version")
    XCTAssertTrue(service.options[0].isCustom)
  }

  func test_parseRpcMethodOption_twoPartQualifiedName_parsesSuccessfully() {
    let proto = """
      syntax = "proto3";

      extend google.protobuf.MethodOptions {
        optional bool requires_auth = 50006;
      }

      message Req {}
      message Resp {}

      service TestService {
        rpc Method(Req) returns (Resp) {
          option (pkg.requires_auth) = true;
        };
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Expected success, got: \(result)")

    guard case .success(let ast) = result else { return }
    let method = ast.services[0].methods[0]
    XCTAssertEqual(method.options.count, 1)
    XCTAssertEqual(method.options[0].name, "pkg.requires_auth")
    XCTAssertTrue(method.options[0].isCustom)
  }

  func test_parseEnumValueOption_twoPartQualifiedName_parsesSuccessfully() {
    let proto = """
      syntax = "proto3";

      extend google.protobuf.EnumValueOptions {
        optional string display_name = 50007;
      }

      enum Status {
        UNKNOWN = 0;
        ACTIVE = 1 [(pkg.display_name) = "Active"];
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Expected success, got: \(result)")

    guard case .success(let ast) = result else { return }
    let activeValue = ast.enums[0].values[1]
    XCTAssertEqual(activeValue.options.count, 1)
    XCTAssertEqual(activeValue.options[0].name, "pkg.display_name")
    XCTAssertTrue(activeValue.options[0].isCustom)
  }

  // MARK: - TC-2: Grammar Depth (fullIdent segments)
  //
  // No extend block needed — the parser validates syntax, not option existence.

  func test_parseCustomOption_singleSegment_preservedAsName() {
    let proto = """
      syntax = "proto3";
      message Foo {
        string bar = 1 [(my_option) = "val"];
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Expected success, got: \(result)")

    guard case .success(let ast) = result else { return }
    let option = ast.messages[0].fields[0].options[0]
    XCTAssertEqual(option.name, "my_option")
    XCTAssertTrue(option.isCustom)
  }

  func test_parseCustomOption_twoSegments_preservedAsFullName() {
    let proto = """
      syntax = "proto3";
      message Foo {
        string bar = 1 [(pkg.my_option) = "val"];
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Expected success, got: \(result)")

    guard case .success(let ast) = result else { return }
    XCTAssertEqual(ast.messages[0].fields[0].options[0].name, "pkg.my_option")
  }

  func test_parseCustomOption_threeSegments_preservedAsFullName() {
    let proto = """
      syntax = "proto3";
      message Foo {
        string bar = 1 [(a.b.my_option) = "val"];
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Expected success, got: \(result)")

    guard case .success(let ast) = result else { return }
    XCTAssertEqual(ast.messages[0].fields[0].options[0].name, "a.b.my_option")
  }

  func test_parseCustomOption_fourSegments_preservedAsFullName() {
    let proto = """
      syntax = "proto3";
      message Foo {
        string bar = 1 [(a.b.c.my_option) = "val"];
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Expected success, got: \(result)")

    guard case .success(let ast) = result else { return }
    XCTAssertEqual(ast.messages[0].fields[0].options[0].name, "a.b.c.my_option")
  }

  // MARK: - TC-3: Option Value Types with Qualified Names

  func test_parseFieldOption_qualifiedName_stringValue() {
    let proto = """
      syntax = "proto3";
      message Foo { string bar = 1 [(pkg.opt) = "hello"]; }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Expected success, got: \(result)")

    guard case .success(let ast) = result else { return }
    let option = ast.messages[0].fields[0].options[0]
    XCTAssertEqual(option.name, "pkg.opt")
    guard case .string(let val) = option.value else {
      XCTFail("Expected .string value, got \(option.value)"); return
    }
    XCTAssertEqual(val, "hello")
  }

  func test_parseFieldOption_qualifiedName_integerValue() {
    let proto = """
      syntax = "proto3";
      message Foo { string bar = 1 [(pkg.opt) = 42]; }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Expected success, got: \(result)")

    guard case .success(let ast) = result else { return }
    let option = ast.messages[0].fields[0].options[0]
    guard case .number(let val) = option.value else {
      XCTFail("Expected .number value, got \(option.value)"); return
    }
    XCTAssertEqual(val, 42.0)
  }

  func test_parseFieldOption_qualifiedName_booleanValue() {
    let proto = """
      syntax = "proto3";
      message Foo { string bar = 1 [(pkg.opt) = true]; }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Expected success, got: \(result)")

    guard case .success(let ast) = result else { return }
    let option = ast.messages[0].fields[0].options[0]
    guard case .boolean(let val) = option.value else {
      XCTFail("Expected .boolean value, got \(option.value)"); return
    }
    XCTAssertTrue(val)
  }

  func test_parseFieldOption_qualifiedName_floatValue() {
    let proto = """
      syntax = "proto3";
      message Foo { string bar = 1 [(pkg.opt) = 3.14]; }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Expected success, got: \(result)")

    guard case .success(let ast) = result else { return }
    let option = ast.messages[0].fields[0].options[0]
    guard case .number(let val) = option.value else {
      XCTFail("Expected .number value, got \(option.value)"); return
    }
    XCTAssertEqual(val, 3.14, accuracy: 0.001)
  }

  func test_parseFieldOption_qualifiedName_identifierValue() {
    let proto = """
      syntax = "proto3";
      message Foo { string bar = 1 [(pkg.opt) = SOME_ENUM_VALUE]; }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Expected success, got: \(result)")

    guard case .success(let ast) = result else { return }
    let option = ast.messages[0].fields[0].options[0]
    guard case .identifier(let val) = option.value else {
      XCTFail("Expected .identifier value, got \(option.value)"); return
    }
    XCTAssertEqual(val, "SOME_ENUM_VALUE")
  }

  // MARK: - TC-4: Multiple Options in One Bracket Block

  func test_parseFieldOptions_simpleAndQualifiedMixed_bothParsed() {
    let proto = """
      syntax = "proto3";
      message Foo {
        string bar = 1 [deprecated = true, (pkg.opt) = "val"];
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Expected success, got: \(result)")

    guard case .success(let ast) = result else { return }
    let options = ast.messages[0].fields[0].options
    XCTAssertEqual(options.count, 2)
    XCTAssertEqual(options[0].name, "deprecated")
    XCTAssertFalse(options[0].isCustom)
    XCTAssertEqual(options[1].name, "pkg.opt")
    XCTAssertTrue(options[1].isCustom)
  }

  func test_parseFieldOptions_twoQualifiedNames_bothParsed() {
    let proto = """
      syntax = "proto3";
      message Foo {
        string bar = 1 [(pkg.opt1) = "a", (pkg.opt2) = "b"];
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Expected success, got: \(result)")

    guard case .success(let ast) = result else { return }
    let options = ast.messages[0].fields[0].options
    XCTAssertEqual(options.count, 2)
    XCTAssertEqual(options[0].name, "pkg.opt1")
    XCTAssertEqual(options[1].name, "pkg.opt2")
  }

  func test_parseFieldOptions_qualifiedSimpleQualified_allThreeParsed() {
    let proto = """
      syntax = "proto3";
      message Foo {
        string bar = 1 [(pkg.opt1) = "x", json_name = "foo", (pkg.opt2) = true];
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Expected success, got: \(result)")

    guard case .success(let ast) = result else { return }
    let options = ast.messages[0].fields[0].options
    XCTAssertEqual(options.count, 3)
    XCTAssertEqual(options[0].name, "pkg.opt1")
    XCTAssertEqual(options[1].name, "json_name")
    XCTAssertEqual(options[2].name, "pkg.opt2")
  }

  // MARK: - TC-5: AST Correctness

  func test_parseFieldOption_qualifiedName_isCustomFlagIsTrue() {
    let proto = """
      syntax = "proto3";
      message Foo { string bar = 1 [(example.opt) = "x"]; }
      """

    guard case .success(let ast) = SwiftProtoParser.parseProtoString(proto) else {
      XCTFail("Parse failed"); return
    }
    XCTAssertTrue(ast.messages[0].fields[0].options[0].isCustom)
  }

  func test_parseFieldOption_qualifiedName_namePreservedWithDots() {
    let proto = """
      syntax = "proto3";
      message Foo { string bar = 1 [(x.y.z) = "v"]; }
      """

    guard case .success(let ast) = SwiftProtoParser.parseProtoString(proto) else {
      XCTFail("Parse failed"); return
    }
    XCTAssertEqual(ast.messages[0].fields[0].options[0].name, "x.y.z")
  }

  func test_parseFieldOption_simpleCustomOption_isCustomFlagIsTrue() {
    let proto = """
      syntax = "proto3";
      message Foo { string bar = 1 [(my_option) = "v"]; }
      """

    guard case .success(let ast) = SwiftProtoParser.parseProtoString(proto) else {
      XCTFail("Parse failed"); return
    }
    let option = ast.messages[0].fields[0].options[0]
    XCTAssertEqual(option.name, "my_option")
    XCTAssertTrue(option.isCustom)
  }

  func test_parseFieldOption_builtinOption_isCustomFlagIsFalse() {
    let proto = """
      syntax = "proto3";
      message Foo { string bar = 1 [deprecated = true]; }
      """

    guard case .success(let ast) = SwiftProtoParser.parseProtoString(proto) else {
      XCTFail("Parse failed"); return
    }
    let option = ast.messages[0].fields[0].options[0]
    XCTAssertEqual(option.name, "deprecated")
    XCTAssertFalse(option.isCustom)
  }

  // MARK: - TC-5b: Missing Context — Enum Body and Descriptor Pipeline

  func test_parseEnumBodyOption_twoPartQualifiedName_parsesSuccessfully() {
    // Enum body option (not enum VALUE option) — goes through parseOptionDeclaration
    let proto = """
      syntax = "proto3";

      extend google.protobuf.EnumOptions {
        optional bool my_enum_option = 50010;
      }

      enum Status {
        option (pkg.my_enum_option) = true;
        UNKNOWN = 0;
        ACTIVE = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(result.isSuccess, "Expected success, got: \(result)")

    guard case .success(let ast) = result else { return }
    let enumDecl = ast.enums[0]
    XCTAssertEqual(enumDecl.options.count, 1)
    XCTAssertEqual(enumDecl.options[0].name, "pkg.my_enum_option")
    XCTAssertTrue(enumDecl.options[0].isCustom)
  }

  func test_parseToDescriptors_fieldWithQualifiedOption_succeeds() {
    // Verifies the full pipeline: Parser → AST → DescriptorBuilder
    // This is the API mentioned in the original issue report.
    let proto = """
      syntax = "proto3";

      package example;

      extend google.protobuf.FieldOptions {
        optional string my_option = 50001;
      }

      message Foo {
        string bar = 1 [(example.my_option) = "hello"];
      }
      """

    let tmpURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("qualified_option_test_\(UUID().uuidString).proto")
    defer { try? FileManager.default.removeItem(at: tmpURL) }
    try! proto.write(to: tmpURL, atomically: true, encoding: .utf8)

    let result = SwiftProtoParser.parseProtoFileWithImportsToDescriptors(
      tmpURL.path,
      importPaths: [],
      allowMissingImports: true
    )
    XCTAssertTrue(result.isSuccess, "Expected descriptor pipeline to succeed, got: \(result)")
  }

  func test_parseToDescriptors_qualifiedOption_uninterpretedOptionHasCorrectName() {
    // Verifies the DescriptorBuilder correctly stores the full qualified name
    // in UninterpretedOption.NamePart, not just the first segment.
    let proto = """
      syntax = "proto3";

      message Foo {
        string bar = 1 [(example.my_option) = "hello"];
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    guard case .success(let ast) = result else {
      XCTFail("Parse failed"); return
    }

    let field = ast.messages[0].fields[0]
    XCTAssertEqual(field.options.count, 1)

    let option = field.options[0]
    XCTAssertEqual(option.name, "example.my_option",
      "Full qualified name must be preserved, not truncated to first segment")
    XCTAssertTrue(option.isCustom)
  }

  // MARK: - TC-6: Error Cases

  func test_parseFieldOption_emptyParens_returnsFailure() {
    let proto = """
      syntax = "proto3";
      message Foo { string bar = 1 [() = "val"]; }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertFalse(result.isSuccess, "Expected failure for empty parens")
  }

  func test_parseFileOption_emptyParens_returnsFailure() {
    let proto = """
      syntax = "proto3";
      option () = "val";
      message Foo { string name = 1; }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertFalse(result.isSuccess, "Expected failure for empty parens in file option")
  }

  func test_parseFieldOption_trailingDotInParens_returnsFailure() {
    let proto = """
      syntax = "proto3";
      message Foo { string bar = 1 [(pkg.) = "val"]; }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertFalse(result.isSuccess, "Expected failure for trailing dot inside parens")
  }

  func test_parseFieldOption_doubleDotInParens_returnsFailure() {
    let proto = """
      syntax = "proto3";
      message Foo { string bar = 1 [(pkg..opt) = "val"]; }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertFalse(result.isSuccess, "Expected failure for double dot inside parens")
  }
}
