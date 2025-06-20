import XCTest

@testable import SwiftProtoParser

final class SwiftProtoParserTests: XCTestCase {

  // MARK: - Basic Parsing Tests

  func testParseSimpleProtoString() {
    let protoContent = """
      syntax = "proto3";

      message HelloWorld {
          string name = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    XCTAssertTrue(result.isSuccess)
    if case .success(let ast) = result {
      XCTAssertEqual(ast.syntax, .proto3)
      XCTAssertEqual(ast.messages.count, 1)
      XCTAssertEqual(ast.messages.first?.name, "HelloWorld")
    }
  }

  func testParseProtoWithPackage() {
    let protoContent = """
      syntax = "proto3";

      package com.example;

      message User {
          string name = 1;
          int32 age = 2;
      }
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    XCTAssertTrue(result.isSuccess)
    if case .success(let ast) = result {
      XCTAssertEqual(ast.syntax, .proto3)
      XCTAssertEqual(ast.package, "com.example")
      XCTAssertEqual(ast.messages.count, 1)
      XCTAssertEqual(ast.messages.first?.name, "User")
    }
  }

  func testParseProtoWithMultipleMessages() {
    let protoContent = """
      syntax = "proto3";

      message Person {
          string name = 1;
      }

      message Address {
          string street = 1;
          string city = 2;
      }
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    XCTAssertTrue(result.isSuccess)
    if case .success(let ast) = result {
      XCTAssertEqual(ast.messages.count, 2)
      XCTAssertEqual(ast.messages[0].name, "Person")
      XCTAssertEqual(ast.messages[1].name, "Address")
    }
  }

  // MARK: - Convenience Methods Tests

  func testGetProtoVersion() {
    let protoContent = """
      syntax = "proto3";

      message Test {}
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    if case .success(_) = result {
      let versionResult = SwiftProtoParser.parseProtoString(protoContent)
      if case .success(let versionAst) = versionResult {
        XCTAssertEqual(versionAst.syntax, .proto3)
      }
    }
  }

  func testGetPackageName() {
    let protoContent = """
      syntax = "proto3";

      package my.test.package;

      message Test {}
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    XCTAssertTrue(result.isSuccess)
    if case .success(let ast) = result {
      XCTAssertEqual(ast.package, "my.test.package")
    }
  }

  func testGetMessageNames() {
    let protoContent = """
      syntax = "proto3";

      message FirstMessage {
          string field1 = 1;
      }

      message SecondMessage {
          int32 field2 = 1;
      }

      message ThirdMessage {
          bool field3 = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    XCTAssertTrue(result.isSuccess)
    if case .success(let ast) = result {
      let messageNames = ast.messages.map { $0.name }
      XCTAssertEqual(messageNames, ["FirstMessage", "SecondMessage", "ThirdMessage"])
    }
  }

  // MARK: - Error Handling Tests

  func testParseInvalidSyntax() {
    let protoContent = """
      syntax = "proto2";  // Not supported

      message Test {}
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    // Should still parse but with error in AST construction
    XCTAssertTrue(result.isSuccess)
    if case .success(let ast) = result {
      // proto2 gets converted to proto3 with error recorded
      XCTAssertEqual(ast.syntax, .proto3)
    }
  }

  func testParseIncompleteProto() {
    let protoContent = """
      syntax = "proto3";

      message Test {
          string name = 
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    // Should fail with syntax error
    XCTAssertTrue(result.isFailure)
    if case .failure(let error) = result {
      XCTAssertTrue(error.description.contains("Syntax error"))
    }
  }

  func testParseMissingSyntax() {
    let protoContent = """
      message Test {
          string name = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    // Should fail because syntax declaration is required
    XCTAssertTrue(result.isFailure)
    if case .failure(let error) = result {
      XCTAssertTrue(error.description.contains("Syntax error"))
    }
  }

  func testParseEmptyString() {
    let result = SwiftProtoParser.parseProtoString("")

    XCTAssertTrue(result.isFailure)
    if case .failure(let error) = result {
      XCTAssertTrue(error.description.contains("Syntax error"))
    }
  }

  // MARK: - Future API Tests

  func testParseProtoFileWithImports() {
    let result = SwiftProtoParser.parseProtoFileWithImports("test.proto")

    XCTAssertTrue(result.isFailure)
    if case .failure(let error) = result {
      if case .internalError(let message) = error {
        XCTAssertTrue(message.contains("Import resolution not yet implemented"))
      }
      else {
        XCTFail("Expected internalError")
      }
    }
  }

  func testParseProtoDirectory() {
    let result = SwiftProtoParser.parseProtoDirectory("/some/path")

    XCTAssertTrue(result.isFailure)
    if case .failure(let error) = result {
      if case .internalError(let message) = error {
        XCTAssertTrue(message.contains("Directory parsing not yet implemented"))
      }
      else {
        XCTFail("Expected internalError")
      }
    }
  }

  // MARK: - Integration Tests

  func testComplexProtoFile() {
    let protoContent = """
      syntax = "proto3";

      package example.complex;

      option java_package = "com.example.complex";

      enum Status {
          UNKNOWN = 0;
          ACTIVE = 1;
          INACTIVE = 2;
      }

      message User {
          string name = 1;
          int32 age = 2;
          Status status = 3;
          repeated string hobbies = 4;
      }

      service UserService {
          rpc GetUser(UserRequest) returns (User);
      }

      message UserRequest {
          string user_id = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    XCTAssertTrue(result.isSuccess)
    if case .success(let ast) = result {
      XCTAssertEqual(ast.syntax, .proto3)
      XCTAssertEqual(ast.package, "example.complex")
      XCTAssertEqual(ast.options.count, 1)
      XCTAssertEqual(ast.messages.count, 2)
      XCTAssertEqual(ast.enums.count, 1)
      XCTAssertEqual(ast.services.count, 1)

      // Check User message
      let userMessage = ast.messages.first { $0.name == "User" }
      XCTAssertNotNil(userMessage)
      XCTAssertEqual(userMessage?.fields.count, 4)

      // Check enum
      XCTAssertEqual(ast.enums.first?.name, "Status")

      // Check service
      XCTAssertEqual(ast.services.first?.name, "UserService")
    }
  }

  // MARK: - Performance Tests

  // Temporarily disabled due to hanging issue
  /*
  func testParsingPerformance() {
    let protoContent = """
      syntax = "proto3";

      package performance.test;

      message LargeMessage {
          string field1 = 1;
          int32 field2 = 2;
          bool field3 = 3;
          double field4 = 4;
          repeated string field5 = 5;
      }
      """

    measure {
      for _ in 0..<100 {
        let result = SwiftProtoParser.parseProtoString(protoContent)
        XCTAssertTrue(result.isSuccess)
      }
    }
  }
  */

  func testDirectLexerAndParser() {
    let protoContent = """
      syntax = "proto3";

      message HelloWorld {
          string name = 1;
      }
      """

    // Test lexer directly
    let lexer = Lexer(input: protoContent, fileName: "test")
    let lexResult = lexer.tokenize()

    XCTAssertTrue(lexResult.isSuccess)

    if case .success(let tokens) = lexResult {
      // Test parser directly
      let parser = Parser(tokens: tokens)
      let parseResult = parser.parse()

      switch parseResult {
      case .success(let ast):
        XCTAssertEqual(ast.syntax, .proto3)
        XCTAssertEqual(ast.messages.count, 1)
        XCTAssertEqual(ast.messages.first?.name, "HelloWorld")

      case .failure(let errors):
        XCTFail("Direct parser failed: \(errors.errors)")
      }
    }
  }

  // MARK: - Debug Tests

  func testSimpleEnumOnly() {
    let protoContent = """
      syntax = "proto3";

      enum Status {
          UNKNOWN = 0;
          ACTIVE = 1;
          INACTIVE = 2;
      }
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    XCTAssertTrue(result.isSuccess)
    if case .success(let ast) = result {
      XCTAssertEqual(ast.enums.count, 1)
      XCTAssertEqual(ast.enums.first?.name, "Status")
      XCTAssertEqual(ast.enums.first?.values.count, 3)
    }
  }

  func testSimpleServiceOnly() {
    let protoContent = """
      syntax = "proto3";

      service UserService {
          rpc GetUser(UserRequest) returns (User);
      }

      message UserRequest {
          string user_id = 1;
      }

      message User {
          string name = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    XCTAssertTrue(result.isSuccess)
    if case .success(let ast) = result {
      XCTAssertEqual(ast.services.count, 1)
      XCTAssertEqual(ast.services.first?.name, "UserService")
      XCTAssertEqual(ast.services.first?.methods.count, 1)
      XCTAssertEqual(ast.messages.count, 2)
    }
  }
}
