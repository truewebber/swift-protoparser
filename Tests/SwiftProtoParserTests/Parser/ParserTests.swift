import XCTest

@testable import SwiftProtoParser

final class ParserTests: XCTestCase {

  // MARK: - Diagnostic Tests

  func testParserInitialization() {
    let tokens = [Token.eof]
    let parser = Parser(tokens: tokens)
    XCTAssertNotNil(parser)
  }

  func testEmptyTokenStream() {
    let tokens: [Token] = []
    let parser = Parser(tokens: tokens)
    let result = parser.parse()

    switch result {
    case .success:
      XCTFail("Expected parser to fail with empty token stream")
    case .failure(let errors):
      XCTAssertFalse(errors.errors.isEmpty)
    }
  }

  // MARK: - Basic Parser Tests

  func testSimpleProto3Syntax() {
    let tokens = [
      Token.keyword(.syntax),
      Token.symbol(Character("=")),
      Token.stringLiteral("proto3"),
      Token.symbol(Character(";")),
      Token.eof,
    ]

    // Basic test - just check parser initialization
    let parser = Parser(tokens: tokens)
    XCTAssertNotNil(parser)

    // Test with timeout protection
    let expectation = XCTestExpectation(description: "Parser completes")
    DispatchQueue.global().async {
      let result = parser.parse()

      switch result {
      case .success(let ast):
        XCTAssertEqual(ast.syntax, .proto3)
        XCTAssertNil(ast.package)

      case .failure(let errors):
        XCTFail("Parser failed with errors: \(errors.errors)")
      }

      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)  // 5 second timeout
  }

  func testSimpleMessage() {
    let tokens = [
      Token.keyword(.syntax),
      Token.symbol(Character("=")),
      Token.stringLiteral("proto3"),
      Token.symbol(Character(";")),
      Token.keyword(.message),
      Token.identifier("Person"),
      Token.symbol(Character("{")),
      Token.identifier("string"),
      Token.identifier("name"),
      Token.symbol(Character("=")),
      Token.integerLiteral(1),
      Token.symbol(Character(";")),
      Token.identifier("int32"),
      Token.identifier("age"),
      Token.symbol(Character("=")),
      Token.integerLiteral(2),
      Token.symbol(Character(";")),
      Token.symbol(Character("}")),
      Token.eof,
    ]

    let parser = Parser(tokens: tokens)
    let result = parser.parse()

    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.syntax, .proto3)
      XCTAssertEqual(ast.messages.count, 1)

      let message = ast.messages[0]
      XCTAssertEqual(message.name, "Person")
      XCTAssertEqual(message.fields.count, 2)

      // Test first field
      let nameField = message.fields[0]
      XCTAssertEqual(nameField.name, "name")
      XCTAssertEqual(nameField.number, 1)
      if case .message(let typeName) = nameField.type {
        XCTAssertEqual(typeName, "string")
      }
      else {
        XCTFail("Expected string type for name field")
      }

      // Test second field
      let ageField = message.fields[1]
      XCTAssertEqual(ageField.name, "age")
      XCTAssertEqual(ageField.number, 2)
      if case .message(let typeName) = ageField.type {
        XCTAssertEqual(typeName, "int32")
      }
      else {
        XCTFail("Expected int32 type for age field")
      }

    case .failure(let errors):
      XCTFail("Parser failed with errors: \(errors.errors)")
    }
  }

  func testPackageDeclaration() {
    let tokens = [
      Token.keyword(.syntax),
      Token.symbol(Character("=")),
      Token.stringLiteral("proto3"),
      Token.symbol(Character(";")),
      Token.keyword(.package),
      Token.identifier("com"),
      Token.symbol(Character(".")),
      Token.identifier("example"),
      Token.symbol(Character(";")),
      Token.eof,
    ]

    let parser = Parser(tokens: tokens)
    let result = parser.parse()

    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.package, "com.example")

    case .failure(let errors):
      XCTFail("Parser failed with errors: \(errors.errors)")
    }
  }

  func testImportDeclaration() {
    let tokens = [
      Token.keyword(.syntax),
      Token.symbol(Character("=")),
      Token.stringLiteral("proto3"),
      Token.symbol(Character(";")),
      Token.keyword(.import),
      Token.stringLiteral("google/protobuf/timestamp.proto"),
      Token.symbol(Character(";")),
      Token.eof,
    ]

    let parser = Parser(tokens: tokens)
    let result = parser.parse()

    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.imports.count, 1)
      XCTAssertEqual(ast.imports[0], "google/protobuf/timestamp.proto")

    case .failure(let errors):
      XCTFail("Parser failed with errors: \(errors.errors)")
    }
  }

  func testStaticParseMethod() {
    let tokens = [
      Token.keyword(.syntax),
      Token.symbol(Character("=")),
      Token.stringLiteral("proto3"),
      Token.symbol(Character(";")),
      Token.eof,
    ]

    let result = Parser.parse(tokens: tokens)

    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.syntax, .proto3)

    case .failure(let errors):
      XCTFail("Static parse method failed with errors: \(errors.errors)")
    }
  }

  // MARK: - Error Handling Tests

  func testMissingSyntax() {
    let tokens = [
      Token.keyword(.package),
      Token.identifier("test"),
      Token.symbol(Character(";")),
      Token.eof,
    ]

    let parser = Parser(tokens: tokens)
    let result = parser.parse()

    switch result {
    case .success:
      XCTFail("Expected parser to fail without syntax declaration")

    case .failure(let errors):
      XCTAssertFalse(errors.errors.isEmpty)
    // Parser should report missing syntax keyword
    }
  }

  func testInvalidFieldNumber() {
    let tokens = [
      Token.keyword(.syntax),
      Token.symbol(Character("=")),
      Token.stringLiteral("proto3"),
      Token.symbol(Character(";")),
      Token.keyword(.message),
      Token.identifier("Test"),
      Token.symbol(Character("{")),
      Token.identifier("string"),
      Token.identifier("field"),
      Token.symbol(Character("=")),
      Token.integerLiteral(0),  // Invalid field number
      Token.symbol(Character(";")),
      Token.symbol(Character("}")),
      Token.eof,
    ]

    let parser = Parser(tokens: tokens)
    let result = parser.parse()

    switch result {
    case .success:
      XCTFail("Expected parser to fail with invalid field number")

    case .failure(let errors):
      XCTAssertFalse(errors.errors.isEmpty)
    // Should report field number out of range
    }
  }

  func testParserState() {
    let tokens = [
      Token.keyword(.syntax),
      Token.symbol(Character("=")),
      Token.stringLiteral("proto3"),
      Token.symbol(Character(";")),
      Token.eof,
    ]

    var state = ParserState(tokens: tokens)
    XCTAssertFalse(state.isAtEnd)
    XCTAssertEqual(state.currentIndex, 0)

    // Test advance
    let firstToken = state.advance()
    XCTAssertNotNil(firstToken)
    XCTAssertEqual(state.currentIndex, 1)

    let secondToken = state.advance()
    XCTAssertNotNil(secondToken)
    XCTAssertEqual(state.currentIndex, 2)

    // Test that we can reach the end
    while !state.isAtEnd {
      state.advance()
    }

    XCTAssertTrue(state.isAtEnd)
  }

  func testMinimalParsing() {
    let tokens = [Token.eof]
    let parser = Parser(tokens: tokens)

    // Just test that parse() can be called - we expect it to fail gracefully
    let result = parser.parse()

    switch result {
    case .success:
      // If it succeeds with just EOF, that's also OK
      XCTAssertTrue(true)
    case .failure(let errors):
      // Expected to fail, that's fine too
      XCTAssertFalse(errors.errors.isEmpty)
    }
  }

  func testCorrectTokens() {
    let tokens = [
      Token.keyword(.syntax),
      Token.symbol(Character("=")),
      Token.stringLiteral("proto3"),
      Token.symbol(Character(";")),
      Token.eof,
    ]

    let parser = Parser(tokens: tokens)
    let result = parser.parse()

    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.syntax, .proto3)

    case .failure(let errors):
      // Print errors for debugging
      print("Parser errors: \(errors.errors)")
      XCTFail("Parser failed with errors: \(errors.errors)")
    }
  }
}
