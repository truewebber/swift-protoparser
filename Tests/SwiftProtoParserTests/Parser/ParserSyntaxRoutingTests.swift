import XCTest

@testable import SwiftProtoParser

// MARK: - ParserSyntaxRoutingTests

/// Tests for AC-1 and AC-2 of SPP-1: syntax version routing.
///
/// AC-1: A .proto file with no `syntax` statement is parsed as proto2.
///       FileDescriptorProto.syntax == "". No error, no warning.
/// AC-2: A file with `syntax = "proto2";` produces FileDescriptorProto.syntax == ""
///       (empty string — identical to no-syntax).
final class ParserSyntaxRoutingTests: XCTestCase {

  // MARK: - AC-1: No syntax declaration

  func test_parse_noSyntaxDeclaration_succeeds() {
    let proto = """
      message Foo {
        optional string name = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)

    switch result {
    case .success:
      break
    case .failure(let error):
      XCTFail("Expected success for no-syntax file, got error: \(error)")
    }
  }

  func test_parse_noSyntaxDeclaration_returnsProto2Version() {
    let proto = """
      message Foo {
        optional string name = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)

    guard case .success(let ast) = result else {
      XCTFail("Expected success")
      return
    }
    XCTAssertEqual(ast.syntax, .proto2, "No-syntax file must be treated as proto2")
  }

  func test_parse_noSyntaxDeclaration_descriptorSyntaxIsEmpty() throws {
    let proto = """
      message Foo {
        optional string name = 1;
      }
      """

    guard case .success(let tokens) = Lexer(input: proto).tokenize() else {
      XCTFail("Lexer failed")
      return
    }
    guard case .success(let ast) = Parser(tokens: tokens).parse() else {
      XCTFail("Expected successful parse")
      return
    }

    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    XCTAssertEqual(descriptor.syntax, "", "No-syntax descriptor must have empty syntax string")
  }

  func test_parse_noSyntaxWithPackage_succeeds() {
    let proto = """
      package mypackage;

      message Bar {
        optional int32 id = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)

    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.syntax, .proto2, "Package-only no-syntax file must be proto2")
    case .failure(let error):
      XCTFail("Expected success, got: \(error)")
    }
  }

  func test_parse_emptyFile_succeeds() {
    let proto = ""

    let result = SwiftProtoParser.parseProtoString(proto)

    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.syntax, .proto2, "Empty file must be treated as proto2")
    case .failure(let error):
      XCTFail("Expected success for empty file, got: \(error)")
    }
  }

  // MARK: - AC-2: syntax = "proto2"

  func test_parse_proto2SyntaxDeclaration_succeeds() {
    let proto = """
      syntax = "proto2";

      message Foo {
        optional string name = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)

    switch result {
    case .success:
      break
    case .failure(let error):
      XCTFail("Expected success for proto2 syntax, got error: \(error)")
    }
  }

  func test_parse_proto2SyntaxDeclaration_returnsProto2Version() {
    let proto = """
      syntax = "proto2";

      message Foo {
        optional string name = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)

    guard case .success(let ast) = result else {
      XCTFail("Expected success")
      return
    }
    XCTAssertEqual(ast.syntax, .proto2, "syntax = \"proto2\" must produce .proto2 version")
  }

  func test_parse_proto2SyntaxDeclaration_descriptorSyntaxIsEmpty() throws {
    let proto = """
      syntax = "proto2";

      message Foo {
        optional string name = 1;
      }
      """

    guard case .success(let tokens) = Lexer(input: proto).tokenize() else {
      XCTFail("Lexer failed")
      return
    }
    guard case .success(let ast) = Parser(tokens: tokens).parse() else {
      XCTFail("Expected successful parse")
      return
    }

    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    XCTAssertEqual(
      descriptor.syntax,
      "",
      "proto2 descriptor must have empty syntax string (not \"proto2\")"
    )
  }

  func test_parse_proto2AndNoSyntax_descriptorSyntaxIndistinguishable() throws {
    let proto2 = """
      syntax = "proto2";
      message Foo {}
      """
    let noSyntax = """
      message Foo {}
      """

    guard case .success(let tokens2) = Lexer(input: proto2).tokenize(),
      case .success(let tokensNone) = Lexer(input: noSyntax).tokenize()
    else {
      XCTFail("Lexer failed")
      return
    }
    guard case .success(let ast2) = Parser(tokens: tokens2).parse(),
      case .success(let astNone) = Parser(tokens: tokensNone).parse()
    else {
      XCTFail("Both must parse successfully")
      return
    }

    let desc2 = try DescriptorBuilder.buildFileDescriptor(from: ast2, fileName: "f.proto")
    let descNone = try DescriptorBuilder.buildFileDescriptor(from: astNone, fileName: "f.proto")

    XCTAssertEqual(
      desc2.syntax,
      descNone.syntax,
      "proto2 and no-syntax must produce identical descriptor syntax field"
    )
  }

  // MARK: - proto3 regression

  func test_parse_proto3SyntaxDeclaration_stillWorksCorrectly() {
    let proto = """
      syntax = "proto3";

      message Foo {
        string name = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)

    guard case .success(let ast) = result else {
      XCTFail("Expected success for proto3")
      return
    }
    XCTAssertEqual(ast.syntax, .proto3, "syntax = \"proto3\" must still produce .proto3")
  }

  func test_parse_proto3SyntaxDeclaration_descriptorSyntaxIsProto3() throws {
    let proto = """
      syntax = "proto3";
      message Foo {}
      """

    guard case .success(let tokens) = Lexer(input: proto).tokenize() else {
      XCTFail("Lexer failed")
      return
    }
    guard case .success(let ast) = Parser(tokens: tokens).parse() else {
      XCTFail("Expected successful parse")
      return
    }

    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    XCTAssertEqual(
      descriptor.syntax,
      "proto3",
      "proto3 descriptor must have \"proto3\" syntax string"
    )
  }
}
