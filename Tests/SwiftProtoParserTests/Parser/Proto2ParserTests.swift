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
}
