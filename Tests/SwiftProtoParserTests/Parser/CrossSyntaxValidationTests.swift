import XCTest

@testable import SwiftProtoParser

/// Cross-syntax validation tests.
///
/// Verifies that every cross-syntax error case produces the correct
/// protoc-matching error message.
///
/// Dependency status at the time of writing:
/// - Tests marked EXPECTED PASS: implementation already exists.
/// - Tests marked EXPECTED FAIL: depend on implementation tasks
///   (SPP-1 through SPP-8, SPP-12, SPP-13) not yet complete.
final class CrossSyntaxValidationTests: XCTestCase {

  // MARK: - Proto2: forbidden proto3 constructs

  /// Proto2 field without a label must be rejected.
  ///
  /// protoc error: `Expected "required", "optional", or "repeated".`
  ///
  /// EXPECTED FAIL until proto2 missing-label validation is implemented.
  func test_proto2_fieldWithoutLabel_rejectsWithExpectedMessage() {
    let proto = """
      syntax = "proto2";
      message M {
        string name = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    guard case .failure(let error) = result else {
      XCTFail(
        "Expected parse failure for proto2 field without label, got success"
      )
      return
    }
    XCTAssertTrue(
      error.localizedDescription.contains("required")
        || error.localizedDescription.contains("optional")
        || error.localizedDescription.contains("repeated"),
      "Expected label-missing error, got: \(error.localizedDescription)"
    )
  }

  // MARK: - Proto3: forbidden proto2 constructs

  /// `required` field in a proto3 file must be rejected.
  ///
  /// protoc error: `Required fields are not allowed in proto3.`
  ///
  /// EXPECTED PASS.
  func test_proto3_requiredField_rejectsWithExpectedMessage() {
    let proto = """
      syntax = "proto3";
      message M {
        required int32 foo = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    guard case .failure(let error) = result else {
      XCTFail(
        "Expected parse failure for required field in proto3, got success"
      )
      return
    }
    XCTAssertTrue(
      error.localizedDescription.contains("Required fields are not allowed in proto3"),
      "Expected 'Required fields are not allowed in proto3', got: \(error.localizedDescription)"
    )
  }

  /// `extensions` range declaration in a proto3 message must be rejected.
  ///
  /// protoc error: `Extension ranges are not allowed in proto3.`
  ///
  /// EXPECTED PASS.
  func test_proto3_extensionRange_rejectsWithExpectedMessage() {
    let proto = """
      syntax = "proto3";
      message M {
        string name = 1;
        extensions 100 to 199;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    guard case .failure(let error) = result else {
      XCTFail(
        "Expected parse failure for extension range in proto3, got success"
      )
      return
    }
    XCTAssertTrue(
      error.localizedDescription.contains("Extension ranges are not allowed in proto3"),
      "Expected 'Extension ranges are not allowed in proto3', got: \(error.localizedDescription)"
    )
  }

  /// `group` field in a proto3 file must be rejected.
  ///
  /// protoc error: `Groups are not supported in proto3 syntax.`
  ///
  /// EXPECTED PASS.
  func test_proto3_groupField_rejectsWithExpectedMessage() {
    let proto = """
      syntax = "proto3";
      message M {
        optional group Foo = 1 {
          required string value = 2;
        }
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    guard case .failure(let error) = result else {
      XCTFail(
        "Expected parse failure for group field in proto3, got success"
      )
      return
    }
    XCTAssertTrue(
      error.localizedDescription.contains("Groups are not supported in proto3 syntax"),
      "Expected 'Groups are not supported in proto3 syntax', got: \(error.localizedDescription)"
    )
  }

  /// `[default = value]` on a field in a proto3 file must be rejected.
  ///
  /// protoc error: `Explicit default values are not allowed in proto3.`
  ///
  /// EXPECTED PASS (validated at descriptor-builder level).
  func test_proto3_explicitDefaultValue_rejectsWithExpectedMessage() {
    let proto = """
      syntax = "proto3";
      message M {
        int32 foo = 1 [default = 42];
      }
      """

    // This error surfaces during descriptor building, not parsing.
    let result = SwiftProtoParser.parseProtoStringToDescriptors(proto)
    guard case .failure(let error) = result else {
      XCTFail(
        "Expected failure for explicit default value in proto3, got success"
      )
      return
    }
    XCTAssertTrue(
      error.localizedDescription.contains("Explicit default values are not allowed in proto3"),
      "Expected 'Explicit default values are not allowed in proto3', got: \(error.localizedDescription)"
    )
  }

  /// Unknown syntax identifier must be rejected with the protoc-matching message.
  ///
  /// protoc error (two spaces before "This"):
  /// `Unrecognized syntax identifier "proto4".  This parser only recognizes "proto2" and "proto3".`
  ///
  /// EXPECTED FAIL until the syntax-error message is updated to match protoc exactly.
  func test_unknownSyntax_rejectsWithExpectedMessage() {
    let proto = """
      syntax = "proto4";
      message M {
        string name = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    guard case .failure(let error) = result else {
      XCTFail(
        "Expected parse failure for unknown syntax 'proto4', got success"
      )
      return
    }
    XCTAssertTrue(
      error.localizedDescription.contains("Unrecognized syntax identifier"),
      "Expected 'Unrecognized syntax identifier', got: \(error.localizedDescription)"
    )
  }

  // MARK: - Proto3: extend errors

  /// In proto3, extending a message that declares no extension numbers must be rejected.
  ///
  /// protoc error: `"pkg.SomeMsg" does not declare 1 as an extension number.`
  ///
  /// EXPECTED FAIL until extend-target validation against declared ranges is implemented.
  func test_proto3_extendMessageWithNoExtensionRanges_rejectsWithExpectedMessage() {
    let proto = """
      syntax = "proto3";
      package pkg;
      message SomeMsg {
        string name = 1;
      }
      extend SomeMsg {
        string val = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    guard case .failure(let error) = result else {
      XCTFail(
        "Expected parse failure for extend without declared extension ranges, got success"
      )
      return
    }
    XCTAssertTrue(
      error.localizedDescription.contains("does not declare")
        && error.localizedDescription.contains("extension number"),
      "Expected 'does not declare N as an extension number', got: \(error.localizedDescription)"
    )
  }

  /// In proto3, extending a non-`google.protobuf.*` message that has extension ranges
  /// must be rejected with the options-only message.
  ///
  /// protoc error: `Extensions in proto3 are only allowed for defining options.`
  ///
  /// EXPECTED PASS.
  func test_proto3_extendNonOptionTarget_rejectsWithExpectedMessage() {
    let proto = """
      syntax = "proto3";
      package test;
      extend other.pkg.MyProto2Message {
        string val = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    guard case .failure(let error) = result else {
      XCTFail(
        "Expected parse failure for non-options extend in proto3, got success"
      )
      return
    }
    XCTAssertTrue(
      error.localizedDescription.contains("Extensions in proto3 are only allowed for defining options"),
      "Expected 'Extensions in proto3 are only allowed for defining options', got: \(error.localizedDescription)"
    )
  }

  // MARK: - Oneof: labeled fields

  /// A field with a label inside a `oneof` block must be rejected (proto2 and proto3).
  ///
  /// protoc error: `Fields in oneofs must not have labels (required / optional / repeated).`
  ///
  /// EXPECTED PASS.
  func test_oneof_labeledField_proto3_rejectsWithExpectedMessage() {
    let proto = """
      syntax = "proto3";
      message M {
        oneof kind {
          string normal = 1;
          required string labeled = 2;
        }
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    guard case .failure(let error) = result else {
      XCTFail(
        "Expected parse failure for labeled field in proto3 oneof, got success"
      )
      return
    }
    XCTAssertTrue(
      error.localizedDescription.contains("Fields in oneofs must not have labels"),
      "Expected 'Fields in oneofs must not have labels', got: \(error.localizedDescription)"
    )
  }

  /// A field with a label inside a `oneof` block must also be rejected in proto2.
  ///
  /// EXPECTED PASS.
  func test_oneof_labeledField_proto2_rejectsWithExpectedMessage() {
    let proto = """
      syntax = "proto2";
      message M {
        oneof kind {
          optional string a = 1;
        }
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    guard case .failure(let error) = result else {
      XCTFail(
        "Expected parse failure for labeled field in proto2 oneof, got success"
      )
      return
    }
    XCTAssertTrue(
      error.localizedDescription.contains("Fields in oneofs must not have labels"),
      "Expected 'Fields in oneofs must not have labels', got: \(error.localizedDescription)"
    )
  }

  // MARK: - allow_alias: duplicate enum values

  /// Duplicate enum numeric values without `allow_alias = true` must be rejected.
  ///
  /// protoc error format:
  /// `"fqn" uses the same enum value as "fqn". If this is intended, set 'option allow_alias = true;'...`
  ///
  /// EXPECTED PASS.
  func test_enum_duplicateValuesWithoutAllowAlias_proto3_rejectsWithExpectedMessage() {
    let proto = """
      syntax = "proto3";
      enum Direction {
        NORTH = 0;
        UP    = 0;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    guard case .failure(let error) = result else {
      XCTFail(
        "Expected parse failure for duplicate enum values without allow_alias, got success"
      )
      return
    }
    XCTAssertTrue(
      error.localizedDescription.contains("uses the same enum value as"),
      "Expected 'uses the same enum value as', got: \(error.localizedDescription)"
    )
    XCTAssertTrue(
      error.localizedDescription.contains("If this is intended"),
      "Expected 'If this is intended', got: \(error.localizedDescription)"
    )
  }

  /// Duplicate enum values without `allow_alias = true` must also be rejected in proto2.
  ///
  /// EXPECTED PASS.
  func test_enum_duplicateValuesWithoutAllowAlias_proto2_rejectsWithExpectedMessage() {
    let proto = """
      syntax = "proto2";
      enum Status {
        UNKNOWN  = 0;
        PENDING  = 1;
        WAITING  = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    guard case .failure(let error) = result else {
      XCTFail(
        "Expected parse failure for duplicate enum values without allow_alias in proto2, got success"
      )
      return
    }
    XCTAssertTrue(
      error.localizedDescription.contains("uses the same enum value as"),
      "Expected 'uses the same enum value as', got: \(error.localizedDescription)"
    )
    XCTAssertTrue(
      error.localizedDescription.contains("If this is intended"),
      "Expected 'If this is intended', got: \(error.localizedDescription)"
    )
  }

  /// With `allow_alias = true`, duplicate enum values must be accepted.
  ///
  /// EXPECTED PASS.
  func test_enum_duplicateValuesWithAllowAlias_isAccepted() {
    let proto = """
      syntax = "proto3";
      enum Direction {
        option allow_alias = true;
        NORTH = 0;
        UP    = 0;
        SOUTH = 1;
        DOWN  = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)
    XCTAssertTrue(
      result.isSuccess,
      "Expected success for duplicate enum values with allow_alias = true"
    )
  }
}
