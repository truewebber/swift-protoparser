import XCTest

@testable import SwiftProtoParser

/// Tests for `parseExtensionRangeOptionsBlock` and `parseExtensionRangeDeclaration`.
///
/// Covers the options syntax: `extensions N [declaration = {...}, verification = X];`
/// Every valid proto string was run through `protoc 33.5` and confirmed to succeed.
/// Every invalid proto string was run through `protoc 33.5` and confirmed to fail.
final class ExtensionRangeOptionsParserTests: XCTestCase {

  // MARK: - Positive: verification key

  /// protoc 33.5: SUCCESS.
  ///
  /// The `verification = DECLARATION` key is the only standardised verification
  /// value in `ExtensionRangeOptions`. Exercises the `"verification"` branch in
  /// `parseExtensionRangeOptionsBlock` (line 1650–1654).
  func test_parse_extensionRange_withVerification_parsesVerificationKey() {
    let proto = """
      syntax = "proto2";
      package test.extrange.ver;
      message Extendable {
        required int32 id = 1;
        extensions 100 to 199 [
          declaration = {
            number: 100
            full_name: ".test.extrange.ver.my_field"
            type: ".test.extrange.ver.MyString"
          },
          verification = DECLARATION
        ];
      }
      message MyString { required string value = 1; }
      """

    let result = SwiftProtoParser.parseProtoString(proto)

    switch result {
    case .success(let ast):
      guard let opts = ast.messages[0].extensionRanges.first?.options else {
        XCTFail("Extension range must carry options")
        return
      }
      XCTAssertEqual(opts.verification, "DECLARATION")
    case .failure(let error):
      XCTFail("Valid extension range with verification must succeed, got: \(error.description)")
    }
  }

  // MARK: - Positive: reserved: true

  /// protoc 33.5: SUCCESS.
  ///
  /// `reserved: true` inside a declaration exercises the `true` branch of
  /// the `"reserved"` case in `parseExtensionRangeDeclaration`.
  func test_parse_extensionRange_withReservedTrue_parsesCorrectly() {
    let proto = """
      syntax = "proto2";
      package test.extrange.res;
      message Extendable {
        required int32 id = 1;
        extensions 100 to 199 [
          declaration = {
            number: 100
            full_name: ".test.extrange.res.my_field"
            type: ".test.extrange.res.MyString"
            reserved: true
          }
        ];
      }
      message MyString { required string value = 1; }
      """

    let result = SwiftProtoParser.parseProtoString(proto)

    switch result {
    case .success(let ast):
      let decl = ast.messages[0].extensionRanges.first?.options?.declarations.first
      XCTAssertEqual(decl?.reserved, true)
    case .failure(let error):
      XCTFail("Valid declaration with reserved: true must succeed, got: \(error.description)")
    }
  }

  // MARK: - Positive: repeated: true

  /// protoc 33.5: SUCCESS.
  ///
  /// `repeated: true` inside a declaration exercises the `true` branch of
  /// the `"repeated"` case in `parseExtensionRangeDeclaration`.
  func test_parse_extensionRange_withRepeatedTrue_parsesCorrectly() {
    let proto = """
      syntax = "proto2";
      package test.extrange.rep;
      message Extendable {
        required int32 id = 1;
        extensions 100 to 199 [
          declaration = {
            number: 100
            full_name: ".test.extrange.rep.my_field"
            type: ".test.extrange.rep.MyString"
            repeated: true
          }
        ];
      }
      message MyString { required string value = 1; }
      """

    let result = SwiftProtoParser.parseProtoString(proto)

    switch result {
    case .success(let ast):
      let decl = ast.messages[0].extensionRanges.first?.options?.declarations.first
      XCTAssertEqual(decl?.repeated, true)
    case .failure(let error):
      XCTFail("Valid declaration with repeated: true must succeed, got: \(error.description)")
    }
  }

  // MARK: - Positive: multiple declarations

  /// protoc 33.5: SUCCESS (verified live with two `declaration` blocks in one range).
  ///
  /// Two `declaration = {...}` entries attached to a single extension range must
  /// both be stored in `options.declarations`.
  func test_parse_extensionRange_withTwoDeclarations_parsesAll() {
    let proto = """
      syntax = "proto2";
      package test.extrange.multi;
      message Extendable {
        required int32 id = 1;
        extensions 100 to 199 [
          declaration = {
            number: 100
            full_name: ".test.extrange.multi.field_a"
            type: ".test.extrange.multi.TypeA"
          },
          declaration = {
            number: 150
            full_name: ".test.extrange.multi.field_b"
            type: ".test.extrange.multi.TypeB"
          }
        ];
      }
      message TypeA { required string value = 1; }
      message TypeB { required bool flag = 1; }
      """

    let result = SwiftProtoParser.parseProtoString(proto)

    switch result {
    case .success(let ast):
      let declarations = ast.messages[0].extensionRanges.first?.options?.declarations
      XCTAssertEqual(declarations?.count, 2)
      XCTAssertEqual(declarations?[0].number, 100)
      XCTAssertEqual(declarations?[1].number, 150)
    case .failure(let error):
      XCTFail("Two declarations in one range must succeed, got: \(error.description)")
    }
  }

  // MARK: - Positive: declaration + verification combined

  /// protoc 33.5: SUCCESS (verified live).
  ///
  /// A range carrying both `declaration = {...}` and `verification = DECLARATION`
  /// must store all fields correctly.
  func test_parse_extensionRange_withDeclarationAndVerification_parsesBoth() {
    let proto = """
      syntax = "proto2";
      package test.extrange.full;
      message Extendable {
        required int32 id = 1;
        extensions 100 to 199 [
          declaration = {
            number: 100
            full_name: ".test.extrange.full.my_field"
            type: ".test.extrange.full.MyString"
            reserved: false
            repeated: false
          },
          verification = DECLARATION
        ];
      }
      message MyString { required string value = 1; }
      """

    let result = SwiftProtoParser.parseProtoString(proto)

    switch result {
    case .success(let ast):
      let opts = ast.messages[0].extensionRanges.first?.options
      XCTAssertEqual(opts?.declarations.count, 1)
      XCTAssertEqual(opts?.declarations.first?.number, 100)
      XCTAssertEqual(opts?.verification, "DECLARATION")
    case .failure(let error):
      XCTFail("Declaration + verification must succeed, got: \(error.description)")
    }
  }

  // MARK: - Error: unknown key in options block

  /// protoc 33.5: ERROR — "Option 'unknown_key' unknown."
  ///
  /// An unrecognised key in the extension range options block must be rejected,
  /// matching protoc behaviour. Exercises the `default` branch (line 1656) in
  /// `parseExtensionRangeOptionsBlock`.
  func test_parse_extensionRange_unknownKey_producesError() {
    let proto = """
      syntax = "proto2";
      message M {
        required int32 id = 1;
        extensions 100 to 199 [
          unknown_key = "some_value"
        ];
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("Unknown key in extension range options must produce an error")
    case .failure:
      break
    }
  }

  // MARK: - Graceful handling: integer as field name in declaration body

  /// protoc 33.5: ERROR — integer literal is not a valid field name.
  ///
  /// `textProtoFieldName()` returns nil for integer tokens, exercising the
  /// `guard let fieldName` path (lines 1692–1693) in `parseExtensionRangeDeclaration`.
  func test_parse_extensionRange_declarationWithIntegerFieldName_handlesGracefully() {
    let proto = """
      syntax = "proto2";
      message M {
        required int32 id = 1;
        extensions 100 to 199 [
          declaration = {
            100
            full_name: ".test.foo_ext"
            type: ".test.Bar"
          }
        ];
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      let rangeCount = ast.messages[0].extensionRanges.count
      XCTAssertEqual(rangeCount, 1, "Parser must produce at least one range even with malformed declaration")
    case .failure:
      break
    }
  }

  // MARK: - Graceful handling: list value for number field

  /// protoc 33.5: ERROR — list value is not valid for the `number` field.
  ///
  /// When `state.integerLiteralValue` is nil (because the token is `[`),
  /// `skipTextProtoValue` is called with the `[` token, exercising the
  /// `case .symbol("["):` branch (line 1800) in `skipTextProtoValue`.
  func test_parse_extensionRange_declarationWithListValueForNumber_handlesGracefully() {
    let proto = """
      syntax = "proto2";
      message M {
        required int32 id = 1;
        extensions 100 to 199 [
          declaration = {
            number: [100, 200],
            full_name: ".test.foo_ext",
            type: ".test.Bar"
          }
        ];
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages[0].extensionRanges.count, 1)
    case .failure:
      break
    }
  }

  // MARK: - Graceful handling: deeply nested message value triggers depth > 1 in skipTextProtoValue

  /// protoc 33.5: ERROR — nested message is not valid for `number`.
  ///
  /// `skipTextProtoValue` is called with a `{` token. The inner `{` increments
  /// depth to 2, and the matching `}` decrements to 1, exercising the
  /// `continue` at line 1796 (depth > 0 after inner `}` close).
  func test_parse_extensionRange_declarationWithDeeplyNestedBlock_handlesGracefully() {
    let proto = """
      syntax = "proto2";
      message M {
        required int32 id = 1;
        extensions 100 to 199 [
          declaration = {
            number: { inner: { v: 1 } },
            full_name: ".test.foo_ext",
            type: ".test.Bar"
          }
        ];
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages[0].extensionRanges.count, 1)
    case .failure:
      break
    }
  }

  // MARK: - Graceful handling: deeply nested list value triggers depth > 1 in skipTextProtoValue

  /// protoc 33.5: ERROR — nested list is not valid for `number`.
  ///
  /// `skipTextProtoValue` is called with a `[` token. The inner `[` increments
  /// depth to 2, and the matching `]` decrements to 1, exercising the
  /// `continue` at line 1810 (depth > 0 after inner `]` close).
  func test_parse_extensionRange_declarationWithDeeplyNestedList_handlesGracefully() {
    let proto = """
      syntax = "proto2";
      message M {
        required int32 id = 1;
        extensions 100 to 199 [
          declaration = {
            number: [[1, 2], 3],
            full_name: ".test.foo_ext",
            type: ".test.Bar"
          }
        ];
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages[0].extensionRanges.count, 1)
    case .failure:
      break
    }
  }
}
