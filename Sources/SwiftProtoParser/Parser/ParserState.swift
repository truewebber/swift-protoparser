import Foundation

/// Manages the state of the parser during parsing.
public struct ParserState {
  /// The input tokens being parsed.
  public private(set) var tokens: [Token]

  /// Current position in the token stream.
  public private(set) var currentIndex: Int

  /// Accumulated errors during parsing.
  public private(set) var errors: [ParserError]

  /// Maximum number of errors to collect before stopping.
  public let maxErrors: Int

  /// Whether to collect multiple errors or stop at first error.
  public let continueOnError: Bool

  public init(
    tokens: [Token],
    maxErrors: Int = 100,
    continueOnError: Bool = true
  ) {
    self.tokens = tokens
    self.currentIndex = 0
    self.errors = []
    self.maxErrors = maxErrors
    self.continueOnError = continueOnError
  }

  /// Returns the current token, or nil if at end of input.
  public var currentToken: Token? {
    guard currentIndex < tokens.count else { return nil }
    return tokens[currentIndex]
  }

  /// Returns the next token without advancing, or nil if at end of input.
  public var peekToken: Token? {
    guard currentIndex + 1 < tokens.count else { return nil }
    return tokens[currentIndex + 1]
  }

  /// Returns true if we're at the end of input.
  public var isAtEnd: Bool {
    return currentIndex >= tokens.count
  }

  /// Returns true if we've reached the maximum number of errors.
  public var hasMaxErrors: Bool {
    return errors.count >= maxErrors
  }

  /// Returns true if parsing should continue.
  public var shouldContinue: Bool {
    return continueOnError && !hasMaxErrors
  }

  /// Advances to the next token and returns the previous token.
  @discardableResult
  public mutating func advance() -> Token? {
    guard currentIndex < tokens.count else { return nil }
    let token = tokens[currentIndex]
    currentIndex += 1
    return token
  }

  /// Advances to the next token if it matches the given predicate.
  @discardableResult
  public mutating func advanceIf(_ predicate: (Token) -> Bool) -> Token? {
    guard let token = currentToken, predicate(token) else { return nil }
    return advance()
  }

  /// Advances to the next token if it matches the given token type.
  @discardableResult
  public mutating func advanceIf(_ tokenType: TokenType) -> Token? {
    return advanceIf { $0.type == tokenType }
  }

  /// Advances to the next token if it's a keyword with the given value.
  @discardableResult
  public mutating func advanceIfKeyword(_ keyword: ProtoKeyword) -> Token? {
    return advanceIf {
      if case .keyword(let k) = $0.type {
        return k == keyword
      }
      return false
    }
  }

  /// Advances to the next token if it's an identifier.
  @discardableResult
  public mutating func advanceIfIdentifier() -> Token? {
    return advanceIf {
      if case .identifier = $0.type {
        return true
      }
      return false
    }
  }

  /// Advances to the next token if it's a symbol with the given value.
  @discardableResult
  public mutating func advanceIfSymbol(_ symbol: String) -> Token? {
    return advanceIf {
      if case .symbol(let s) = $0.type {
        return String(s) == symbol
      }
      return false
    }
  }

  /// Expects and consumes a token of the given type, adding an error if not found.
  @discardableResult
  public mutating func expect(_ tokenType: TokenType, expected: String) -> Token? {
    guard let token = currentToken else {
      addError(.unexpectedEndOfInput(expected: expected))
      return nil
    }

    if token.type == tokenType {
      return advance()
    }
    else {
      addError(.unexpectedToken(token, expected: expected))
      return nil
    }
  }

  /// Expects and consumes a keyword token, adding an error if not found.
  @discardableResult
  public mutating func expectKeyword(_ keyword: ProtoKeyword) -> Token? {
    return expect(TokenType.keyword(keyword), expected: keyword.rawValue)
  }

  /// Expects and consumes an identifier token, adding an error if not found.
  @discardableResult
  public mutating func expectIdentifier() -> Token? {
    return expect(TokenType.identifier(""), expected: "identifier")
  }

  /// Expects and consumes a symbol token, adding an error if not found.
  @discardableResult
  public mutating func expectSymbol(_ symbol: String) -> Token? {
    guard let symbolChar = symbol.first, symbol.count == 1 else {
      addError(.internalError("Invalid symbol: \(symbol)"))
      return nil
    }
    return expect(TokenType.symbol(symbolChar), expected: "'\(symbol)'")
  }

  /// Checks if the current token matches the given type.
  public func check(_ tokenType: TokenType) -> Bool {
    return currentToken?.type == tokenType
  }

  /// Checks if the current token is a keyword with the given value.
  public func checkKeyword(_ keyword: ProtoKeyword) -> Bool {
    if let token = currentToken,
      case .keyword(let k) = token.type
    {
      return k == keyword
    }
    return false
  }

  /// Checks if the current token is an identifier.
  public func checkIdentifier() -> Bool {
    if let token = currentToken,
      case .identifier = token.type
    {
      return true
    }
    return false
  }

  /// Checks if the current token is a symbol with the given value.
  public func checkSymbol(_ symbol: String) -> Bool {
    if let token = currentToken,
      case .symbol(let s) = token.type
    {
      return String(s) == symbol
    }
    return false
  }

  /// Adds an error to the error list.
  public mutating func addError(_ error: ParserError) {
    errors.append(error)
  }

  /// Skips tokens until finding a synchronization point.
  public mutating func synchronize() {
    while !isAtEnd {
      guard let token = currentToken else { break }

      // Skip to next statement-like token
      if case .keyword(let keyword) = token.type {
        switch keyword {
        case .message, .enum, .service, .rpc, .syntax, .package, .import, .option:
          return
        default:
          break
        }
      }

      if case .symbol(let symbol) = token.type, symbol == ";" {
        advance()
        return
      }

      advance()
    }
  }

  /// Returns the current position for error reporting.
  public var currentPosition: Token.Position {
    return currentToken?.position ?? Token.Position(line: 0, column: 0)
  }

  /// Gets the identifier name from the current token, if it's an identifier.
  public var identifierName: String? {
    guard let token = currentToken,
      case .identifier(let name) = token.type
    else {
      return nil
    }
    return name
  }

  /// Gets the string literal value from the current token, if it's a string literal.
  public var stringLiteralValue: String? {
    guard let token = currentToken,
      case .stringLiteral(let value) = token.type
    else {
      return nil
    }
    return value
  }

  /// Gets the integer literal value from the current token, if it's an integer literal.
  public var integerLiteralValue: Int64? {
    guard let token = currentToken,
      case .integerLiteral(let value) = token.type
    else {
      return nil
    }
    return value
  }

  /// Gets the float literal value from the current token, if it's a float literal.
  public var floatLiteralValue: Double? {
    guard let token = currentToken,
      case .floatLiteral(let value) = token.type
    else {
      return nil
    }
    return value
  }

  /// Gets the boolean literal value from the current token, if it's a boolean literal.
  public var booleanLiteralValue: Bool? {
    guard let token = currentToken,
      case .boolLiteral(let value) = token.type
    else {
      return nil
    }
    return value
  }
}
