import XCTest

@testable import SwiftProtoParser

// MARK: - Proto2ParserTests

/// Tests for proto2 enum semantics (AC-8 and AC-15).
///
/// - AC-8: Enum without zero value is valid in proto2 (zero-value check is proto3-only).
/// - AC-15: Duplicate enum values without `allow_alias = true` produce a protoc-compatible error.
final class Proto2ParserTests: XCTestCase {

  // MARK: - AC-8: Proto2 enum without zero value

  func test_parse_proto2EnumWithoutZeroValue_succeeds() {
    let proto = """
      syntax = "proto2";
      enum Status {
        STARTED = 1;
        RUNNING = 2;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.enums.count, 1)
      XCTAssertEqual(ast.enums[0].name, "Status")
    case .failure(let error):
      XCTFail("proto2 enum without zero value must not produce an error, got: \(error.description)")
    }
  }

  func test_parse_noSyntaxEnumWithoutZeroValue_succeeds() {
    let proto = """
      enum Status {
        STARTED = 1;
        RUNNING = 2;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.enums.count, 1)
    case .failure(let error):
      XCTFail("No-syntax (proto2) enum without zero value must not produce an error, got: \(error.description)")
    }
  }

  func test_parse_proto2EnumWithZeroValue_succeeds() {
    let proto = """
      syntax = "proto2";
      enum Status {
        UNKNOWN = 0;
        STARTED = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      break
    case .failure(let error):
      XCTFail("proto2 enum with zero value must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto2NestedEnumWithoutZeroValue_succeeds() {
    let proto = """
      syntax = "proto2";
      message Request {
        enum Type {
          QUERY = 1;
          MUTATION = 2;
        }
        required Type type = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages[0].nestedEnums.count, 1)
    case .failure(let error):
      XCTFail("proto2 nested enum without zero value must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto3EnumWithoutZeroValue_producesError() {
    let proto = """
      syntax = "proto3";
      enum Status {
        STARTED = 1;
        RUNNING = 2;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("proto3 enum without zero value must produce an error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("missing") || error.description.contains("zero"),
        "Expected missing zero value error, got: \(error.description)"
      )
    }
  }

  // MARK: - AC-15: allow_alias enum option

  func test_parse_proto3EnumWithAllowAlias_duplicateValues_succeeds() {
    let proto = """
      syntax = "proto3";
      enum Status {
        option allow_alias = true;
        UNKNOWN = 0;
        STARTED = 1;
        RUNNING = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.enums.count, 1)
    case .failure(let error):
      XCTFail("Enum with allow_alias = true must allow duplicate values, got: \(error.description)")
    }
  }

  func test_parse_proto2EnumWithAllowAlias_duplicateValues_succeeds() {
    let proto = """
      syntax = "proto2";
      enum Status {
        option allow_alias = true;
        STARTED = 1;
        RUNNING = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.enums.count, 1)
    case .failure(let error):
      XCTFail("proto2 enum with allow_alias = true must allow duplicate values, got: \(error.description)")
    }
  }

  func test_parse_proto3EnumWithoutAllowAlias_duplicateValues_producesError() {
    let proto = """
      syntax = "proto3";
      enum Status {
        UNKNOWN = 0;
        STARTED = 1;
        RUNNING = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("Enum with duplicate values and no allow_alias must produce an error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("allow_alias"),
        "Expected allow_alias error message, got: \(error.description)"
      )
    }
  }

  func test_parse_proto2EnumWithoutAllowAlias_duplicateValues_producesError() {
    let proto = """
      syntax = "proto2";
      enum Status {
        STARTED = 1;
        RUNNING = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("proto2 enum with duplicate values and no allow_alias must produce an error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("allow_alias"),
        "Expected allow_alias error message, got: \(error.description)"
      )
    }
  }

  func test_parse_noSyntaxEnumWithoutAllowAlias_duplicateValues_producesError() {
    let proto = """
      enum Status {
        STARTED = 1;
        RUNNING = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("No-syntax enum with duplicate values and no allow_alias must produce an error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("allow_alias"),
        "Expected allow_alias error message, got: \(error.description)"
      )
    }
  }

  func test_parse_duplicateEnumValue_errorContainsExactProtocFormat() {
    let proto = """
      syntax = "proto3";
      package test.pkg;
      enum Status {
        UNKNOWN = 0;
        STARTED = 1;
        RUNNING = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("Duplicate enum values without allow_alias must produce an error")
    case .failure(let error):
      let desc = error.description
      XCTAssertTrue(
        desc.contains("RUNNING") && desc.contains("STARTED"),
        "Error must reference both duplicate and original value names, got: \(desc)"
      )
      XCTAssertTrue(
        desc.contains("allow_alias"),
        "Error must mention allow_alias, got: \(desc)"
      )
      XCTAssertTrue(
        desc.contains("next available"),
        "Error must mention next available enum value, got: \(desc)"
      )
    }
  }

  func test_parse_duplicateEnumValue_errorMentionsNextAvailableValue() {
    let proto = """
      syntax = "proto3";
      enum Status {
        UNKNOWN = 0;
        STARTED = 1;
        RUNNING = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("Duplicate enum values without allow_alias must produce an error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("2"),
        "Next available value should be 2 (max 1 + 1), got: \(error.description)"
      )
    }
  }

  func test_parse_allowAliasSetFalse_duplicateValues_producesError() {
    let proto = """
      syntax = "proto3";
      enum Status {
        option allow_alias = false;
        UNKNOWN = 0;
        STARTED = 1;
        RUNNING = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("allow_alias = false must not suppress the duplicate error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("allow_alias"),
        "Expected allow_alias error, got: \(error.description)"
      )
    }
  }

  // MARK: - AC-4: Extension ranges (proto2 only)

  func test_parse_proto2ExtensionRangeSingle_succeeds() {
    let proto = """
      syntax = "proto2";
      message Extendable {
        required int32 id = 1;
        extensions 100 to 199;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages.count, 1)
      let msg = ast.messages[0]
      XCTAssertEqual(msg.extensionRanges.count, 1)
      XCTAssertEqual(msg.extensionRanges[0].start, 100)
      XCTAssertEqual(msg.extensionRanges[0].end, 200, "End must be stored exclusive (199 + 1 = 200)")
    case .failure(let error):
      XCTFail("proto2 single extension range must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto2ExtensionRangeMax_succeeds() {
    let proto = """
      syntax = "proto2";
      message Extendable {
        required int32 id = 1;
        extensions 1000 to max;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages.count, 1)
      let msg = ast.messages[0]
      XCTAssertEqual(msg.extensionRanges.count, 1)
      XCTAssertEqual(msg.extensionRanges[0].start, 1000)
      XCTAssertEqual(msg.extensionRanges[0].end, 536_870_912, "'max' must map to exclusive end 536870912")
    case .failure(let error):
      XCTFail("proto2 extension range to max must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto2ExtensionRangeCommaSeparated_yieldsThreeRanges() {
    let proto = """
      syntax = "proto2";
      message Extendable {
        required int32 id = 1;
        extensions 100 to 199, 300 to 399, 500 to max;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      let ranges = ast.messages[0].extensionRanges
      XCTAssertEqual(ranges.count, 3)
      XCTAssertEqual(ranges[0].start, 100)
      XCTAssertEqual(ranges[0].end, 200)
      XCTAssertEqual(ranges[1].start, 300)
      XCTAssertEqual(ranges[1].end, 400)
      XCTAssertEqual(ranges[2].start, 500)
      XCTAssertEqual(ranges[2].end, 536_870_912)
    case .failure(let error):
      XCTFail("Comma-separated extension ranges must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto3ExtensionRange_producesExactError() {
    let proto = """
      syntax = "proto3";
      message Extendable {
        int32 id = 1;
        extensions 100 to 199;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("proto3 with extension ranges must produce an error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("Extension ranges are not allowed in proto3."),
        "Expected exact protoc error, got: \(error.description)"
      )
    }
  }

  func test_parse_proto2ExtensionRangeSingleNumber_succeeds() {
    let proto = """
      syntax = "proto2";
      message Extendable {
        required int32 id = 1;
        extensions 100 to 100;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      let ranges = ast.messages[0].extensionRanges
      XCTAssertEqual(ranges.count, 1)
      XCTAssertEqual(ranges[0].start, 100)
      XCTAssertEqual(ranges[0].end, 101, "Single-number range end is exclusive (100 + 1 = 101)")
    case .failure(let error):
      XCTFail("Single-number extension range must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto2MessageNoExtensionRanges_returnsEmpty() {
    let proto = """
      syntax = "proto2";
      message Plain {
        required int32 id = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages[0].extensionRanges.count, 0)
    case .failure(let error):
      XCTFail("Plain proto2 message must succeed, got: \(error.description)")
    }
  }

  // MARK: - AC-13: Oneof label validation

  func test_parse_proto3OneofWithOptionalLabel_producesExactError() {
    let proto = """
      syntax = "proto3";
      message Msg {
        oneof value {
          optional string name = 1;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("oneof field with 'optional' label must produce an error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("Fields in oneofs must not have labels (required / optional / repeated)."),
        "Expected exact protoc error message, got: \(error.description)"
      )
    }
  }

  func test_parse_proto3OneofWithRepeatedLabel_producesExactError() {
    let proto = """
      syntax = "proto3";
      message Msg {
        oneof value {
          repeated string name = 1;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("oneof field with 'repeated' label must produce an error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("Fields in oneofs must not have labels (required / optional / repeated)."),
        "Expected exact protoc error message, got: \(error.description)"
      )
    }
  }

  func test_parse_proto3OneofWithRequiredLabel_producesOneofError_notProto3Error() {
    let proto = """
      syntax = "proto3";
      message Msg {
        oneof value {
          required string name = 1;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("oneof field with 'required' label must produce an error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("Fields in oneofs must not have labels (required / optional / repeated)."),
        "Expected oneof-specific error, not proto3 required error. Got: \(error.description)"
      )
      XCTAssertFalse(
        error.description.contains("Required fields are not allowed in proto3"),
        "Should not produce proto3 required error for oneof context. Got: \(error.description)"
      )
    }
  }

  func test_parse_proto2OneofWithRequiredLabel_producesExactError() {
    let proto = """
      syntax = "proto2";
      message Msg {
        oneof value {
          required string name = 1;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("oneof field with 'required' label must produce an error in proto2")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("Fields in oneofs must not have labels (required / optional / repeated)."),
        "Expected exact protoc error message, got: \(error.description)"
      )
    }
  }

  func test_parse_proto2OneofWithOptionalLabel_producesExactError() {
    let proto = """
      syntax = "proto2";
      message Msg {
        oneof value {
          optional string name = 1;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("oneof field with 'optional' label must produce an error in proto2")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("Fields in oneofs must not have labels (required / optional / repeated)."),
        "Expected exact protoc error message, got: \(error.description)"
      )
    }
  }

  func test_parse_proto3ValidOneofWithoutLabels_succeeds() {
    let proto = """
      syntax = "proto3";
      message Msg {
        oneof value {
          string name = 1;
          int32 number = 2;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages[0].oneofGroups.count, 1)
      XCTAssertEqual(ast.messages[0].oneofGroups[0].fields.count, 2)
    case .failure(let error):
      XCTFail("Valid oneof without labels must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto2ValidOneofWithoutLabels_succeeds() {
    let proto = """
      syntax = "proto2";
      message Msg {
        oneof value {
          string name = 1;
          int32 number = 2;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages[0].oneofGroups.count, 1)
      XCTAssertEqual(ast.messages[0].oneofGroups[0].fields.count, 2)
    case .failure(let error):
      XCTFail("Valid proto2 oneof without labels must succeed, got: \(error.description)")
    }
  }
}
