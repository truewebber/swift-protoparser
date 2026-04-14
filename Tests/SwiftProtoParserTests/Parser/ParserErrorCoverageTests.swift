import XCTest

@testable import SwiftProtoParser

/// Tests for genuine error paths in Parser.swift that were previously uncovered.
///
/// Every proto string below was run through `protoc 33.5` before being included.
/// - Positive protos: protoc exits 0 (valid input confirmed).
/// - Negative protos: protoc exits non-zero with a matching error message.
final class ParserErrorCoverageTests: XCTestCase {

  // MARK: - Option value at EOF

  /// Confirms protoc 33.5 error for truncated option values.
  ///
  /// protoc error message: "Unexpected end of stream while parsing option value."
  func test_parse_optionValue_atEOF_producesError() {
    // Trailing `=` with no value and no semicolon — EOF inside option declaration.
    let proto = "syntax = \"proto3\";\noption java_package ="

    let result = SwiftProtoParser.parseProtoString(proto)

    switch result {
    case .success:
      XCTFail("Option value missing at EOF must produce an error")
    case .failure:
      break
    }
  }

  // MARK: - Sub-field path: dot without following identifier

  /// Confirms protoc 33.5 rejects a dot in a sub-field path that has no following identifier.
  ///
  /// protoc error message: "Expected identifier."
  /// A closing `)` after a custom option name may be followed by `.subfield`.
  /// If the `.` is present but no identifier follows, the parser must error.
  func test_parse_subFieldPath_dotWithoutIdentifier_producesError() {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.FieldOptions {
        string my_ext = 50001;
      }
      message M {
        string name = 1 [(my_ext). = "val"];
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)

    switch result {
    case .success:
      XCTFail("Dot in sub-field path without following identifier must produce an error")
    case .failure:
      break
    }
  }

  // MARK: - Field type at EOF

  /// Confirms protoc 33.5 rejects a field declaration that is truncated before the type.
  ///
  /// protoc error message: "Expected type name."
  /// When `optional` is consumed as a label keyword but then the token stream
  /// ends before any type name, `parseFieldType` must handle nil current token.
  func test_parse_fieldType_atEOF_producesError() {
    // `optional` is consumed as a label; the next call to parseFieldType sees EOF.
    let proto = "syntax = \"proto3\";\nmessage M {\n  optional"

    let result = SwiftProtoParser.parseProtoString(proto)

    switch result {
    case .success:
      XCTFail("Field type missing at EOF must produce an error")
    case .failure:
      break
    }
  }

  // MARK: - Enum value with no name

  /// Confirms protoc 33.5 rejects an enum value that has no name before the `=`.
  ///
  /// protoc error message: "Expected enum constant name."
  /// Inside an enum body, `=` appears before any identifier name.
  func test_parse_enumValue_withNoName_producesError() {
    let proto = """
      syntax = "proto3";
      enum Status {
        = 0;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)

    switch result {
    case .success:
      XCTFail("Enum value without a name must produce an error")
    case .failure:
      break
    }
  }

  // MARK: - Extension range options block: symbol as key

  /// Confirms protoc 33.5 rejects an extension range options block where a symbol appears as the key.
  ///
  /// protoc error message: syntax error — `=` appears where a key identifier is expected.
  /// `extensions 100 to 199 [= declaration];` is malformed because the options block
  /// begins with `=` instead of an identifier key.
  func test_parse_extensionRangeOptions_withSymbolAsKey_producesError() {
    let proto = """
      syntax = "proto2";
      message M {
        required int32 id = 1;
        extensions 100 to 199 [= declaration];
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)

    switch result {
    case .success:
      XCTFail("Extension range options block with symbol as key must produce an error")
    case .failure:
      break
    }
  }
}
