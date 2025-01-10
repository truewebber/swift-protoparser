import Foundation

/// A location in a source file, tracking line and column numbers
public struct SourceLocation: Equatable {
  /// The line number in the source file (1-based)
  public let line: Int

  /// The column number in the source file (1-based)
  public let column: Int

  /// Creates a new source location
  /// - Parameters:
  ///   - line: The line number (1-based)
  ///   - column: The column number (1-based)
  public init(line: Int, column: Int) {
    self.line = line
    self.column = column
  }
}

/// Represents a token in the proto file
public struct Token: Equatable {
  /// The type of the token
  public let type: TokenType

  /// The literal string value of the token
  public let literal: String

  /// The starting location of the token in the source file
  public let location: SourceLocation

  /// The length of the token in characters
  public let length: Int

  /// Any associated comment that appears before this token
  public let leadingComments: [String]

  /// Any associated comment that appears on the same line after this token
  public let trailingComment: String?

  /// Creates a new token
  /// - Parameters:
  ///   - type: The type of the token
  ///   - literal: The literal string value of the token
  ///   - location: The location of the token in the source file
  ///   - length: The length of the token in characters
  ///   - leadingComments: Any comments that appear before this token
  ///   - trailingComment: Any comment that appears after this token on the same line
  public init(
    type: TokenType,
    literal: String,
    location: SourceLocation,
    length: Int,
    leadingComments: [String] = [],
    trailingComment: String? = nil
  ) {
    self.type = type
    self.literal = literal
    self.location = location
    self.length = length
    self.leadingComments = leadingComments
    self.trailingComment = trailingComment
  }
}

// MARK: - CustomStringConvertible

extension Token: CustomStringConvertible {
  public var description: String {
    return
      "Token(type: \(type), literal: \"\(literal)\", location: (\(location.line):\(location.column)))"
  }
}

// MARK: - Convenience Initializers

extension Token {
  /// Creates a token with an empty location and no comments
  /// Useful for testing and quick token creation
  /// - Parameters:
  ///   - type: The type of the token
  ///   - literal: The literal string value of the token
  public static func simple(type: TokenType, literal: String) -> Token {
    return Token(
      type: type,
      literal: literal,
      location: SourceLocation(line: 1, column: 1),
      length: literal.count
    )
  }
}

// MARK: - Token Comparison

extension Token {
  /// Checks if the token is of the specified type
  /// - Parameter type: The token type to check against
  /// - Returns: True if the token matches the specified type
  public func isType(_ type: TokenType) -> Bool {
    return self.type == type
  }

  /// Checks if the token matches any of the specified types
  /// - Parameter types: The token types to check against
  /// - Returns: True if the token matches any of the specified types
  public func isAny(of types: TokenType...) -> Bool {
    return types.contains(type)
  }
}
