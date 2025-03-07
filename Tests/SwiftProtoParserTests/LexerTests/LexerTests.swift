import XCTest

@testable import SwiftProtoParser

/**
 * Test suite for Lexer
 *
 * This test suite verifies the functionality of the Lexer component
 * according to the acceptance criteria defined in ACCEPTANCE_CRITERIA.md.
 *
 * Acceptance Criteria:
 * - Correctly tokenize all valid proto3 syntax elements
 * - Handle whitespace and comments correctly
 * - Recognize all proto3 keywords
 * - Recognize all proto3 literals (string, number, boolean)
 * - Recognize all proto3 operators and punctuation
 * - Track line and column information for each token
 * - Provide meaningful error messages for invalid input
 * - Include line and column information in error messages
 */
final class LexerTests: XCTestCase {
  // Helper method to create a lexer and get all tokens
  private func getAllTokens(from input: String) throws -> [Token] {
    let lexer = Lexer(input: input)
    var tokens: [Token] = []

    repeat {
      let token = try lexer.nextToken()
      tokens.append(token)
      if token.type == .eof {
        break
      }
    } while true

    return tokens
  }

  // MARK: - Positive Tests

  /**
   * Test tokenization of keywords
   *
   * This test verifies that the lexer correctly tokenizes all proto3 keywords.
   *
   * Acceptance Criteria:
   * - Recognize all proto3 keywords
   */
  func testKeywords() throws {
    let input = """
    syntax package import message enum service rpc option
    returns stream oneof map reserved extend repeated
    optional
    """
    
    let lexer = Lexer(input: input)
    
    let expectedTokenTypes: [TokenType] = [
        .syntax, .package, .import, .message, 
        .enum, .service, .rpc, .option,
        .returns, .stream, .oneof, .map, 
        .reserved, .extend, .repeated,
        .optional, .eof
    ]
    
    var tokens: [Token] = []
    
    while true {
      let token = try lexer.nextToken()
      tokens.append(token)
      if token.type == .eof {
        break
      }
    }
    
    XCTAssertEqual(tokens.count, expectedTokenTypes.count)
    
    for (index, token) in tokens.enumerated() {
      XCTAssertEqual(token.type, expectedTokenTypes[index], "Token at index \(index) should be \(expectedTokenTypes[index]), but got \(token.type)")
    }
  }

  /**
   * Test tokenization of identifiers
   *
   * This test verifies that the lexer correctly tokenizes identifiers.
   *
   * Acceptance Criteria:
   * - Correctly tokenize all valid proto3 syntax elements
   */
  func testIdentifiers() throws {
    let input = """
    identifier camelCase snake_case PascalCase with_123_numbers
    _underscore_prefix a1b2c3 very_long_identifier_with_many_words
    """
    
    let lexer = Lexer(input: input)
    
    let expectedIdentifiers = [
        "identifier", "camelCase", "snake_case", "PascalCase", "with_123_numbers",
        "_underscore_prefix", "a1b2c3", "very_long_identifier_with_many_words"
    ]
    
    var identifiers: [String] = []
    
    while true {
      let token = try lexer.nextToken()
      if token.type == .eof {
        break
      }
      if token.type == .identifier {
        identifiers.append(token.literal)
      }
    }
    
    XCTAssertEqual(identifiers.count, expectedIdentifiers.count)
    
    for (index, identifier) in identifiers.enumerated() {
      XCTAssertEqual(identifier, expectedIdentifiers[index], "Identifier at index \(index) should be \(expectedIdentifiers[index]), but got \(identifier)")
    }
  }

  /**
   * Test tokenization of string literals
   *
   * This test verifies that the lexer correctly tokenizes string literals.
   *
   * Acceptance Criteria:
   * - Recognize all proto3 literals (string, number, boolean)
   */
  func testStringLiterals() throws {
    let input = """
    "simple string"
    "string with \\"escaped quotes\\""
    "string with \\n newline"
    "string with \\r carriage return"
    "string with \\t tab"
    "string with \\\\ backslash"
    ""
    """
    
    let lexer = Lexer(input: input)
    
    let expectedStrings = [
        "simple string",
        "string with \"escaped quotes\"",
        "string with \n newline",
        "string with \r carriage return",
        "string with \t tab",
        "string with \\ backslash",
        ""
    ]
    
    var strings: [String] = []
    
    while true {
      let token = try lexer.nextToken()
      if token.type == .eof {
        break
      }
      if token.type == .stringLiteral {
        strings.append(token.literal)
      }
    }
    
    XCTAssertEqual(strings.count, expectedStrings.count)
    
    for (index, string) in strings.enumerated() {
      XCTAssertEqual(string, expectedStrings[index], "String at index \(index) should be \(expectedStrings[index]), but got \(string)")
    }
  }

  /**
   * Test tokenization of number literals
   *
   * This test verifies that the lexer correctly tokenizes number literals.
   *
   * Acceptance Criteria:
   * - Recognize all proto3 literals (string, number, boolean)
   */
  func testNumberLiterals() throws {
    let input = """
    0 123 -456 0.123 -0.456 1e10 1.2e-10 -1.2e+10
    """
    
    let lexer = Lexer(input: input)
    
    let expectedNumbers = [
        "0", "123", "-456", "0.123", "-0.456", "1e10", "1.2e-10", "-1.2e+10"
    ]
    
    var numbers: [String] = []
    
    while true {
      let token = try lexer.nextToken()
      if token.type == .eof {
        break
      }
      if token.type == .intLiteral || token.type == .floatLiteral {
        numbers.append(token.literal)
      }
    }
    
    XCTAssertEqual(numbers.count, expectedNumbers.count)
    
    for (index, number) in numbers.enumerated() {
      XCTAssertEqual(number, expectedNumbers[index], "Number at index \(index) should be \(expectedNumbers[index]), but got \(number)")
    }
  }

  /**
   * Test tokenization of operators and punctuation
   *
   * This test verifies that the lexer correctly tokenizes operators and punctuation.
   *
   * Acceptance Criteria:
   * - Recognize all proto3 operators and punctuation
   */
  func testOperatorsAndPunctuation() throws {
    let input = """
    { } [ ] ( ) < > = ; . , :
    """
    
    let lexer = Lexer(input: input)
    
    let expectedTokenTypes: [TokenType] = [
        .leftBrace, .rightBrace, .leftBracket, .rightBracket, .leftParen, .rightParen,
        .leftAngle, .rightAngle, .equals, .semicolon, .period, .comma, .colon,
        .eof
    ]
    
    var tokens: [Token] = []
    
    while true {
      let token = try lexer.nextToken()
      tokens.append(token)
      if token.type == .eof {
        break
      }
    }
    
    XCTAssertEqual(tokens.count, expectedTokenTypes.count)
    
    for (index, token) in tokens.enumerated() {
      XCTAssertEqual(token.type, expectedTokenTypes[index], "Token at index \(index) should be \(expectedTokenTypes[index]), but got \(token.type)")
    }
  }

  /**
   * Test handling of whitespace and comments
   *
   * This test verifies that the lexer correctly handles whitespace and comments.
   *
   * Acceptance Criteria:
   * - Handle whitespace and comments correctly
   */
  func testWhitespaceAndComments() throws {
    let input = """
    // This is a line comment
    message /* This is a block comment */ Test {
      // Another line comment
      string name = 1; /* Another block comment */
    }
    """
    
    let lexer = Lexer(input: input)
    
    let expectedTokenTypes: [TokenType] = [
        .message, .identifier, .leftBrace,
        .string, .identifier, .equals, .intLiteral, .semicolon,
        .rightBrace, .eof
    ]
    
    var tokens: [Token] = []
    
    while true {
      let token = try lexer.nextToken()
      tokens.append(token)
      if token.type == .eof {
        break
      }
    }
    
    XCTAssertEqual(tokens.count, expectedTokenTypes.count)
    
    for (index, token) in tokens.enumerated() {
      XCTAssertEqual(token.type, expectedTokenTypes[index], "Token at index \(index) should be \(expectedTokenTypes[index]), but got \(token.type)")
    }
  }

  /**
   * Test tracking of line and column information
   *
   * This test verifies that the lexer correctly tracks line and column information.
   *
   * Acceptance Criteria:
   * - Track line and column information for each token
   */
  func testLineAndColumnTracking() throws {
    let input = """
    message Test {
      string name = 1;
    }
    """
    
    let lexer = Lexer(input: input)
    
    let expectedPositions: [(line: Int, column: Int)] = [
        (1, 1), // message
        (1, 9), // Test
        (1, 14), // {
        (2, 3), // string
        (2, 10), // name
        (2, 15), // =
        (2, 17), // 1
        (2, 18), // ;
        (3, 1), // }
    ]
    
    var tokens: [Token] = []
    
    while true {
      let token = try lexer.nextToken()
      if token.type == .eof {
        break
      }
      tokens.append(token)
    }
    
    XCTAssertEqual(tokens.count, expectedPositions.count)
    
    for (index, token) in tokens.enumerated() {
      let expectedPosition = expectedPositions[index]
      XCTAssertEqual(token.location.line, expectedPosition.line, "Token at index \(index) should be at line \(expectedPosition.line), but got \(token.location.line)")
      XCTAssertEqual(token.location.column, expectedPosition.column, "Token at index \(index) should be at column \(expectedPosition.column), but got \(token.location.column)")
    }
  }

  // MARK: - Negative Tests

  /**
   * Test error handling for unterminated string literals
   *
   * This test verifies that the lexer correctly handles unterminated string literals.
   *
   * Acceptance Criteria:
   * - Provide meaningful error messages for invalid input
   * - Include line and column information in error messages
   */
  func testUnterminatedStringLiteral() {
    let input = """
    message Test {
      string name = "unterminated string;
    }
    """
    
    let lexer = Lexer(input: input)
    
    do {
      while true {
        let token = try lexer.nextToken()
        if token.type == .eof {
          break
        }
      }
      XCTFail("Lexer should have thrown an error for unterminated string literal")
    } catch let error as LexerError {
      if case .unterminatedString(let location) = error {
        XCTAssertEqual(location.line, 2, "Error should be at line 2")
        XCTAssertEqual(location.column, 17, "Error should be at column 17")
      } else {
        XCTFail("Expected unterminatedString error, but got \(error)")
      }
    } catch {
      XCTFail("Expected LexerError, but got \(error)")
    }
  }

  /**
   * Test error handling for invalid escape sequences
   *
   * This test verifies that the lexer correctly handles invalid escape sequences.
   *
   * Acceptance Criteria:
   * - Provide meaningful error messages for invalid input
   * - Include line and column information in error messages
   */
  func testInvalidEscapeSequence() {
    let input = """
    message Test {
      string name = "invalid \\z escape";
    }
    """
    
    let lexer = Lexer(input: input)
    
    do {
      while true {
        let token = try lexer.nextToken()
        if token.type == .eof {
          break
        }
      }
      XCTFail("Lexer should have thrown an error for invalid escape sequence")
    } catch let error as LexerError {
      if case .invalidEscapeSequence(let seq, let location) = error {
        XCTAssertEqual(seq, "z", "Error should be for escape sequence 'z'")
        XCTAssertEqual(location.line, 2, "Error should be at line 2")
      } else {
        XCTFail("Expected invalidEscapeSequence error, but got \(error)")
      }
    } catch {
      XCTFail("Expected LexerError, but got \(error)")
    }
  }

  /**
   * Test error handling for invalid number format
   *
   * This test verifies that the lexer correctly handles invalid number formats.
   *
   * Acceptance Criteria:
   * - Provide meaningful error messages for invalid input
   * - Include line and column information in error messages
   */
  func testInvalidNumberFormat() {
    let input = """
    message Test {
      int32 value = 123.456.789;
    }
    """
    
    let lexer = Lexer(input: input)
    
    do {
      while true {
        let token = try lexer.nextToken()
        if token.type == .eof {
          break
        }
      }
      XCTFail("Lexer should have thrown an error for invalid number format")
    } catch let error as LexerError {
      if case .invalidNumber(_, let location) = error {
        XCTAssertEqual(location.line, 2, "Error should be at line 2")
      } else {
        XCTFail("Expected invalidNumber error, but got \(error)")
      }
    } catch {
      XCTFail("Expected LexerError, but got \(error)")
    }
  }

  // MARK: - Corner Cases

  /**
   * Test handling of empty input
   *
   * This test verifies that the lexer correctly handles empty input.
   *
   * Acceptance Criteria:
   * - Correctly tokenize all valid proto3 syntax elements
   */
  func testEmptyInput() throws {
    let input = ""
    
    let lexer = Lexer(input: input)
    
    let token = try lexer.nextToken()
    XCTAssertEqual(token.type, .eof, "Expected EOF token for empty input")
  }

  /**
   * Test handling of input with only whitespace and comments
   *
   * This test verifies that the lexer correctly handles input with only whitespace and comments.
   *
   * Acceptance Criteria:
   * - Handle whitespace and comments correctly
   */
  func testWhitespaceAndCommentsOnly() throws {
    let input = """
    // This is a line comment
    
    /* This is a block comment */
    
    // Another line comment
    """
    
    let lexer = Lexer(input: input)
    
    let token = try lexer.nextToken()
    XCTAssertEqual(token.type, .eof, "Expected EOF token for input with only whitespace and comments")
  }

  /**
   * Test handling of extremely long identifiers
   *
   * This test verifies that the lexer correctly handles extremely long identifiers.
   *
   * Acceptance Criteria:
   * - Correctly tokenize all valid proto3 syntax elements
   */
  func testExtremelyLongIdentifier() throws {
    let longIdentifier = String(repeating: "a", count: 1000)
    let input = "message \(longIdentifier) {}"
    
    let lexer = Lexer(input: input)
    
    var tokens: [Token] = []
    
    while true {
      let token = try lexer.nextToken()
      tokens.append(token)
      if token.type == .eof {
        break
      }
    }
    
    XCTAssertEqual(tokens.count, 5, "Expected 5 tokens (message, identifier, {, }, EOF)")
    
    XCTAssertEqual(tokens[0].type, .message)
    XCTAssertEqual(tokens[1].type, .identifier)
    XCTAssertEqual(tokens[1].literal, longIdentifier, "Identifier should match the long identifier")
    XCTAssertEqual(tokens[2].type, .leftBrace)
    XCTAssertEqual(tokens[3].type, .rightBrace)
  }

  /**
   * Test handling of adjacent punctuation
   *
   * This test verifies that the lexer correctly handles adjacent punctuation.
   *
   * Acceptance Criteria:
   * - Correctly tokenize all valid proto3 syntax elements
   */
  func testAdjacentPunctuation() throws {
    let input = "{}[]()<>:;,.="
    
    let lexer = Lexer(input: input)
    
    let expectedTokenTypes: [TokenType] = [
        .leftBrace, .rightBrace, .leftBracket, .rightBracket, .leftParen, .rightParen,
        .leftAngle, .rightAngle, .colon, .semicolon, .comma, .period, .equals, .eof
    ]
    
    var tokens: [Token] = []
    
    while true {
      let token = try lexer.nextToken()
      tokens.append(token)
      if token.type == .eof {
        break
      }
    }
    
    XCTAssertEqual(tokens.count, expectedTokenTypes.count)
    
    for (index, token) in tokens.enumerated() {
      XCTAssertEqual(token.type, expectedTokenTypes[index], "Token at index \(index) should be \(expectedTokenTypes[index]), but got \(token.type)")
    }
  }
}
