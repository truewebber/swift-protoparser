import XCTest

@testable import SwiftProtoParser

/// Tests for trailing semicolon after closing brace (};).
///
/// protoc accepts `};` as an optional empty statement after message/enum/service/oneof/extend/rpc blocks.
/// SwiftProtoParser must match this behaviour.
final class ParserTrailingSemicolonTests: XCTestCase {

  // MARK: - Helpers

  private func parse(_ content: String) -> Result<ProtoAST, ProtoParseError> {
    SwiftProtoParser.parseProtoString(content)
  }

  private func assertSuccess(_ content: String, file: StaticString = #file, line: UInt = #line) {
    let result = parse(content)
    if case .failure(let error) = result {
      XCTFail("Expected success but got error: \(error)", file: file, line: line)
    }
  }

  private func assertFailure(_ content: String, file: StaticString = #file, line: UInt = #line) {
    let result = parse(content)
    if case .success = result {
      XCTFail("Expected failure but parsing succeeded", file: file, line: line)
    }
  }

  // MARK: - message

  func test_message_trailingSemicolon_succeeds() {
    assertSuccess(
      """
      syntax = "proto3";

      message Foo {
        string bar = 1;
      };
      """
    )
  }

  func test_message_trailingSemicolon_twoMessages_bothParsed() {
    let result = parse(
      """
      syntax = "proto3";

      message Foo {
        string bar = 1;
      };

      message Baz {
        int32 count = 1;
      }
      """
    )
    guard case .success(let ast) = result else {
      XCTFail("Expected success")
      return
    }
    XCTAssertEqual(ast.messages.count, 2)
    XCTAssertEqual(ast.messages[0].name, "Foo")
    XCTAssertEqual(ast.messages[1].name, "Baz")
  }

  func test_message_trailingSemicolon_bothMessages_bothParsed() {
    let result = parse(
      """
      syntax = "proto3";

      message Foo {
        string bar = 1;
      };

      message Baz {
        int32 count = 1;
      };
      """
    )
    guard case .success(let ast) = result else {
      XCTFail("Expected success")
      return
    }
    XCTAssertEqual(ast.messages.count, 2)
  }

  // MARK: - Nested message

  func test_nestedMessage_trailingSemicolon_outerWithout_succeeds() {
    assertSuccess(
      """
      syntax = "proto3";

      message Outer {
        message Inner {
          string value = 1;
        };
        string name = 2;
      }
      """
    )
  }

  func test_nestedMessage_trailingSemicolon_bothLevels_succeeds() {
    assertSuccess(
      """
      syntax = "proto3";

      message Outer {
        message Inner {
          string value = 1;
        };
      };
      """
    )
  }

  func test_nestedMessage_trailingSemicolon_twoNestedMessages_succeeds() {
    let result = parse(
      """
      syntax = "proto3";

      message Outer {
        message InnerA {
          string a = 1;
        };
        message InnerB {
          int32 b = 1;
        };
      }
      """
    )
    guard case .success(let ast) = result else {
      XCTFail("Expected success")
      return
    }
    XCTAssertEqual(ast.messages[0].nestedMessages.count, 2)
  }

  func test_threeNestedLevels_allTrailingSemicolons_succeeds() {
    assertSuccess(
      """
      syntax = "proto3";

      message A {
        message B {
          message C {
            string x = 1;
          };
        };
      };
      """
    )
  }

  // MARK: - enum

  func test_enum_trailingSemicolon_topLevel_succeeds() {
    assertSuccess(
      """
      syntax = "proto3";

      enum Status {
        STATUS_UNKNOWN = 0;
        STATUS_OK = 1;
      };
      """
    )
  }

  func test_enum_trailingSemicolon_twoEnums_bothParsed() {
    let result = parse(
      """
      syntax = "proto3";

      enum Status {
        STATUS_UNKNOWN = 0;
      };

      enum Role {
        ROLE_UNKNOWN = 0;
      };
      """
    )
    guard case .success(let ast) = result else {
      XCTFail("Expected success")
      return
    }
    XCTAssertEqual(ast.enums.count, 2)
  }

  func test_enum_trailingSemicolon_nestedInMessage_succeeds() {
    assertSuccess(
      """
      syntax = "proto3";

      message Foo {
        enum Bar {
          BAR_UNKNOWN = 0;
        };
        string name = 1;
      }
      """
    )
  }

  // MARK: - oneof

  func test_oneof_trailingSemicolon_succeeds() {
    assertSuccess(
      """
      syntax = "proto3";

      message Foo {
        oneof payload {
          string text = 1;
          int32 code = 2;
        };
      }
      """
    )
  }

  func test_oneof_trailingSemicolon_twoOneofs_succeeds() {
    let result = parse(
      """
      syntax = "proto3";

      message Foo {
        oneof a {
          string text = 1;
        };
        oneof b {
          int32 code = 2;
        };
      }
      """
    )
    guard case .success(let ast) = result else {
      XCTFail("Expected success")
      return
    }
    XCTAssertEqual(ast.messages[0].oneofGroups.count, 2)
  }

  // MARK: - service

  func test_service_trailingSemicolon_succeeds() {
    assertSuccess(
      """
      syntax = "proto3";

      message Req {}
      message Resp {}

      service Greeter {
        rpc Hello (Req) returns (Resp);
      };
      """
    )
  }

  func test_service_trailingSemicolon_parsedCorrectly() {
    let result = parse(
      """
      syntax = "proto3";

      message Req {}
      message Resp {}

      service Greeter {
        rpc Hello (Req) returns (Resp);
      };
      """
    )
    guard case .success(let ast) = result else {
      XCTFail("Expected success")
      return
    }
    XCTAssertEqual(ast.services.count, 1)
    XCTAssertEqual(ast.services[0].name, "Greeter")
  }

  // MARK: - rpc with options block

  func test_rpc_optionsBlock_trailingSemicolon_succeeds() {
    assertSuccess(
      """
      syntax = "proto3";

      message Req {}
      message Resp {}

      service Greeter {
        rpc Hello (Req) returns (Resp) {
          option deprecated = true;
        };
      }
      """
    )
  }

  func test_rpc_optionsBlock_trailingSemicolon_twoRpcs_succeeds() {
    let result = parse(
      """
      syntax = "proto3";

      message Req {}
      message Resp {}

      service Greeter {
        rpc Hello (Req) returns (Resp) {
          option deprecated = true;
        };
        rpc Bye (Req) returns (Resp) {
          option deprecated = false;
        };
      }
      """
    )
    guard case .success(let ast) = result else {
      XCTFail("Expected success")
      return
    }
    XCTAssertEqual(ast.services[0].methods.count, 2)
  }

  // MARK: - extend

  func test_extend_trailingSemicolon_succeeds() {
    assertSuccess(
      """
      syntax = "proto3";

      extend google.protobuf.MessageOptions {
        optional string my_option = 50001;
      };
      """
    )
  }

  // MARK: - Mixed combinations

  func test_mixed_messageAndEnum_bothTrailingSemicolons_succeeds() {
    let result = parse(
      """
      syntax = "proto3";

      enum Status {
        STATUS_UNKNOWN = 0;
      };

      message Foo {
        string name = 1;
      };
      """
    )
    guard case .success(let ast) = result else {
      XCTFail("Expected success")
      return
    }
    XCTAssertEqual(ast.enums.count, 1)
    XCTAssertEqual(ast.messages.count, 1)
  }

  func test_mixed_allBlockTypes_trailingSemicolons_succeeds() {
    assertSuccess(
      """
      syntax = "proto3";

      message Req {}
      message Resp {}

      enum Status {
        STATUS_UNKNOWN = 0;
      };

      message Foo {
        enum Inner {
          INNER_UNKNOWN = 0;
        };
        oneof payload {
          string text = 1;
        };
        string name = 2;
      };

      service Greeter {
        rpc Hello (Req) returns (Resp);
      };
      """
    )
  }

  // MARK: - Negative: `;` without preceding block is still an error

  func test_standaloneSemicolon_atTopLevel_fails() {
    assertFailure(
      """
      syntax = "proto3";

      ;
      """
    )
  }
}
