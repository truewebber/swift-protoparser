import Foundation

// MARK: - Lexer

/// Main tokenizer class for Protocol Buffers source code.
///
/// The lexer performs character-by-character analysis of proto3 source files,.
/// converting the input string into a sequence of tokens while preserving.
/// position information for error reporting.
public final class Lexer {

  // MARK: - Private Properties

  /// The input string being tokenized.
  private let input: String

  /// Current position in the input string.
  private var currentIndex: String.Index

  /// Current line number (1-based).
  private var currentLine: Int = 1

  /// Current column number (1-based).
  private var currentColumn: Int = 1

  /// Array to collect tokens.
  private var tokens: [Token] = []

  /// File name for error reporting (optional).
  private let fileName: String?

  // MARK: - Initialization

  /// Creates a new lexer for the given input.
  ///
  /// - Parameters:.
  ///   - input: The proto3 source code to tokenize.
  ///   - fileName: Optional file name for error reporting.
  public init(input: String, fileName: String? = nil) {
    self.input = input
    self.currentIndex = input.startIndex
    self.fileName = fileName
  }

  // MARK: - Public Methods

  /// Tokenizes the input string into a sequence of tokens.
  ///
  /// - Returns: A `Result` containing either the array of tokens or a lexer error.
  internal func tokenize() -> Result<[Token], LexerError> {
    do {
      tokens.removeAll()
      currentIndex = input.startIndex
      currentLine = 1
      currentColumn = 1

      try tokenizeInput()

      // Add EOF token at the end
      let eofPosition = Token.Position(line: currentLine, column: currentColumn)
      tokens.append(Token(type: .eof, position: eofPosition))

      return .success(tokens)

    }
    catch let error as LexerError {
      return .failure(error)
    }
    catch {
      // Unexpected error - wrap it
      return .failure(.unexpectedEndOfInput(line: currentLine, column: currentColumn))
    }
  }

  // MARK: - Private Tokenization Methods

  /// Main tokenization loop.
  private func tokenizeInput() throws {
    while !isAtEnd() {
      try tokenizeNext()
    }
  }

  /// Tokenizes the next token from current position.
  private func tokenizeNext() throws {
    let char = currentCharacter()

    switch char {
    // Whitespace
    case " ", "\t", "\r":
      try tokenizeWhitespace()

    // Newlines
    case "\n":
      try tokenizeNewline()

    // Comments
    case "/":
      try tokenizeCommentOrSymbol()

    // String literals
    case "\"", "'":
      try tokenizeStringLiteral()

    // Numbers
    case "0"..."9":
      try tokenizeNumber()

    // Identifiers and keywords (including leading underscore)
    case "a"..."z", "A"..."Z", "_":
      try tokenizeIdentifierOrKeyword()

    // Symbols
    case "{", "}", "[", "]", "(", ")", "=", ";", ",", ".", "<", ">", "+", "-":
      try tokenizeSymbol()

    default:
      throw LexerError.invalidCharacter(char, line: currentLine, column: currentColumn)
    }
  }

  // MARK: - Whitespace Tokenization

  private func tokenizeWhitespace() throws {
    let position = Token.Position(line: currentLine, column: currentColumn)
    advanceIndex()
    tokens.append(Token(type: .whitespace, position: position))
  }

  private func tokenizeNewline() throws {
    let position = Token.Position(line: currentLine, column: currentColumn)
    advanceIndex()
    currentLine += 1
    currentColumn = 1
    tokens.append(Token(type: .newline, position: position))
  }

  // MARK: - Comment Tokenization

  private func tokenizeCommentOrSymbol() throws {
    // Look ahead to see if it's a comment
    let nextIndex = input.index(after: currentIndex)

    if nextIndex < input.endIndex {
      let nextChar = input[nextIndex]

      if nextChar == "/" {
        // Single-line comment
        try tokenizeSingleLineComment()
      }
      else if nextChar == "*" {
        // Multi-line comment
        try tokenizeMultiLineComment()
      }
      else {
        // Just a "/" symbol
        try tokenizeSymbol()
      }
    }
    else {
      // End of input, just a "/" symbol
      try tokenizeSymbol()
    }
  }

  private func tokenizeSingleLineComment() throws {
    let startIndex = currentIndex

    // Skip "//"
    advanceIndex()  // /
    advanceIndex()  // /

    // Read until end of line or end of input
    while !isAtEnd() && currentCharacter() != "\n" {
      advanceIndex()
    }

    let commentText = String(input[startIndex..<currentIndex])
    let position = Token.Position(line: currentLine, column: currentColumn - commentText.count)
    tokens.append(Token(type: .comment(commentText), position: position))
  }

  private func tokenizeMultiLineComment() throws {
    let startIndex = currentIndex
    let startLine = currentLine
    let startColumn = currentColumn

    // Skip "/*"
    advanceIndex()  // /
    advanceIndex()  // *

    // Read until "*/" or end of input
    while !isAtEnd() {
      if currentCharacter() == "*" {
        let nextIndex = input.index(after: currentIndex)
        if nextIndex < input.endIndex && input[nextIndex] == "/" {
          // Found "*/"
          advanceIndex()  // *
          advanceIndex()  // /

          let commentText = String(input[startIndex..<currentIndex])
          let position = Token.Position(line: startLine, column: startColumn)
          tokens.append(Token(type: .comment(commentText), position: position))
          return
        }
      }

      if currentCharacter() == "\n" {
        currentLine += 1
        currentColumn = 1
      }
      advanceIndex()
    }

    // Reached end of input without closing comment
    throw LexerError.unterminatedComment(line: startLine, column: startColumn)
  }

  // MARK: - String Literal Tokenization

  private func tokenizeStringLiteral() throws {
    let quote = currentCharacter()
    let startLine = currentLine
    let startColumn = currentColumn

    advanceIndex()  // Skip opening quote

    var stringValue = ""

    while !isAtEnd() && currentCharacter() != quote {
      if currentCharacter() == "\\" {
        // Handle escape sequences
        let escapedChar = try tokenizeEscapeSequence()
        stringValue.append(escapedChar)
      }
      else if currentCharacter() == "\n" {
        // Newlines are not allowed in string literals
        currentLine += 1
        currentColumn = 1
        throw LexerError.unterminatedString(line: startLine, column: startColumn)
      }
      else {
        stringValue.append(currentCharacter())
        advanceIndex()
      }
    }

    if isAtEnd() {
      throw LexerError.unterminatedString(line: startLine, column: startColumn)
    }

    // Skip closing quote
    advanceIndex()

    let position = Token.Position(line: startLine, column: startColumn)
    tokens.append(Token(type: .stringLiteral(stringValue), position: position))
  }

  private func tokenizeEscapeSequence() throws -> Character {
    advanceIndex()  // Skip backslash

    if isAtEnd() {
      throw LexerError.invalidEscapeSequence("\\", line: currentLine, column: currentColumn - 1)
    }

    let escapeChar = currentCharacter()
    advanceIndex()

    switch escapeChar {
    case "n":
      return "\n"
    case "t":
      return "\t"
    case "r":
      return "\r"
    case "\\":
      return "\\"
    case "\"":
      return "\""
    case "'":
      return "'"
    case "0":
      return "\0"
    default:
      throw LexerError.invalidEscapeSequence("\\\(escapeChar)", line: currentLine, column: currentColumn - 2)
    }
  }

  // MARK: - Number Tokenization

  private func tokenizeNumber() throws {
    let startIndex = currentIndex
    let startLine = currentLine
    let startColumn = currentColumn

    var isFloat = false
    var hasSign = false

    // Handle optional leading sign (for negative numbers)
    if currentCharacter() == "-" || currentCharacter() == "+" {
      hasSign = true
      advanceIndex()
    }

    // Read integer part
    if !isAtEnd() && currentCharacter().isWholeNumber {
      while !isAtEnd() && currentCharacter().isWholeNumber {
        advanceIndex()
      }
    }
    else if hasSign {
      // Sign without digits
      throw LexerError.invalidIntegerLiteral(
        String(input[startIndex..<currentIndex]),
        line: startLine,
        column: startColumn
      )
    }

    // Check for decimal point
    if !isAtEnd() && currentCharacter() == "." {
      let nextIndex = input.index(after: currentIndex)
      if nextIndex < input.endIndex && input[nextIndex].isWholeNumber {
        isFloat = true
        advanceIndex()  // Skip "."

        // Read fractional part
        while !isAtEnd() && currentCharacter().isWholeNumber {
          advanceIndex()
        }
      }
    }

    // Check for scientific notation
    if !isAtEnd() && (currentCharacter() == "e" || currentCharacter() == "E") {
      isFloat = true
      advanceIndex()  // Skip "e" or "E"

      // Handle optional sign in exponent
      if !isAtEnd() && (currentCharacter() == "+" || currentCharacter() == "-") {
        advanceIndex()
      }

      // Read exponent digits
      if isAtEnd() || !currentCharacter().isWholeNumber {
        throw LexerError.invalidFloatLiteral(
          String(input[startIndex..<currentIndex]),
          line: startLine,
          column: startColumn
        )
      }

      while !isAtEnd() && currentCharacter().isWholeNumber {
        advanceIndex()
      }
    }

    let numberString = String(input[startIndex..<currentIndex])

    let position = Token.Position(line: startLine, column: startColumn)

    if isFloat {
      if let floatValue = Double(numberString) {
        tokens.append(Token(type: .floatLiteral(floatValue), position: position))
      }
      else {
        throw LexerError.invalidFloatLiteral(numberString, line: startLine, column: startColumn)
      }
    }
    else {
      if let intValue = Int64(numberString) {
        tokens.append(Token(type: .integerLiteral(intValue), position: position))
      }
      else {
        throw LexerError.numberOutOfRange(numberString, line: startLine, column: startColumn)
      }
    }
  }

  // MARK: - Identifier and Keyword Tokenization

  private func tokenizeIdentifierOrKeyword() throws {
    let startIndex = currentIndex
    let startLine = currentLine
    let startColumn = currentColumn

    // Read identifier characters (letters, digits, underscores)
    while !isAtEnd() {
      let char = currentCharacter()
      if char.isLetter || char.isWholeNumber || char == "_" {
        advanceIndex()
      }
      else {
        break
      }
    }

    let identifier = String(input[startIndex..<currentIndex])
    let position = Token.Position(line: startLine, column: startColumn)

    // Check for boolean literals
    if identifier == "true" {
      tokens.append(Token(type: .boolLiteral(true), position: position))
      return
    }
    else if identifier == "false" {
      tokens.append(Token(type: .boolLiteral(false), position: position))
      return
    }

    // Use KeywordRecognizer to determine if it's a keyword or identifier
    let tokenType = KeywordRecognizer.recognizeType(identifier)
    tokens.append(Token(type: tokenType, position: position))
  }

  // MARK: - Symbol Tokenization

  private func tokenizeSymbol() throws {
    let symbol = currentCharacter()
    let position = Token.Position(line: currentLine, column: currentColumn)
    advanceIndex()
    tokens.append(Token(type: .symbol(symbol), position: position))
  }

  // MARK: - Helper Methods

  /// Returns the current character without advancing.
  private func currentCharacter() -> Character {
    return input[currentIndex]
  }

  /// Checks if we've reached the end of input.
  private func isAtEnd() -> Bool {
    return currentIndex >= input.endIndex
  }

  /// Advances the current index and updates column position.
  private func advanceIndex() {
    if !isAtEnd() {
      currentIndex = input.index(after: currentIndex)
      currentColumn += 1
    }
  }
}

// MARK: - Lexer + Public API Integration

extension Lexer {

  /// Tokenizes input and converts errors to public API format.
  ///
  /// - Returns: A `Result` containing tokens or a public API error.
  public func tokenizeForPublicAPI() -> Result<[Token], ProtoParseError> {
    return tokenize().mapError { lexerError in
      lexerError.toProtoParseError(file: fileName ?? "<unknown>")
    }
  }
}

// MARK: - Lexer + Convenience Methods

extension Lexer {

  /// Creates a lexer and immediately tokenizes the input.
  ///
  /// - Parameters:.
  ///   - input: The proto3 source code to tokenize.
  ///   - fileName: Optional file name for error reporting.
  /// - Returns: A `Result` containing tokens or a lexer error.
  internal static func tokenize(_ input: String, fileName: String? = nil) -> Result<[Token], LexerError> {
    let lexer = Lexer(input: input, fileName: fileName)
    return lexer.tokenize()
  }

}
