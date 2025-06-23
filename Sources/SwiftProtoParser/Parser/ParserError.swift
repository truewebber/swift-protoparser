import Foundation

/// Errors that can occur during parsing of .proto files.
public enum ParserError: Error, Equatable {
  /// Unexpected token encountered.
  case unexpectedToken(Token, expected: String, line: Int, column: Int)

  /// Missing required element.
  case missingRequiredElement(String, line: Int, column: Int)

  /// Duplicate element found.
  case duplicateElement(String, line: Int, column: Int)

  /// Invalid field number.
  case invalidFieldNumber(Int32, line: Int, column: Int)

  /// Unexpected end of input.
  case unexpectedEndOfInput(expected: String)

  /// Invalid syntax declaration.
  case invalidSyntax(String, line: Int, column: Int)

  /// Reserved field number used.
  case reservedFieldNumber(Int32, line: Int, column: Int)

  /// Field number out of range.
  case fieldNumberOutOfRange(Int32, line: Int, column: Int)

  /// Duplicate field number.
  case duplicateFieldNumber(Int32, line: Int, column: Int)

  /// Invalid message definition.
  case invalidMessageDefinition(String, line: Int, column: Int)

  /// Invalid enum definition.
  case invalidEnumDefinition(String, line: Int, column: Int)

  /// Invalid service definition.
  case invalidServiceDefinition(String, line: Int, column: Int)

  /// Invalid option value.
  case invalidOptionValue(String, line: Int, column: Int)

  /// Missing zero value in enum (required in proto3).
  case missingEnumZeroValue(String, line: Int, column: Int)

  /// Invalid extend target (proto3 only allows google.protobuf.* extensions).
  case invalidExtendTarget(String, line: Int, column: Int)

  /// Missing field label in extend statement.
  case missingFieldLabel(String, line: Int, column: Int)

  /// Internal parser error.
  case internalError(String)

  /// The line number where the error occurred.
  public var line: Int {
    switch self {
    case .unexpectedToken(_, _, let line, _),
      .missingRequiredElement(_, let line, _),
      .duplicateElement(_, let line, _),
      .invalidFieldNumber(_, let line, _),
      .invalidSyntax(_, let line, _),
      .reservedFieldNumber(_, let line, _),
      .fieldNumberOutOfRange(_, let line, _),
      .duplicateFieldNumber(_, let line, _),
      .invalidMessageDefinition(_, let line, _),
      .invalidEnumDefinition(_, let line, _),
      .invalidServiceDefinition(_, let line, _),
      .invalidOptionValue(_, let line, _),
      .missingEnumZeroValue(_, let line, _),
      .invalidExtendTarget(_, let line, _),
      .missingFieldLabel(_, let line, _):
      return line
    case .unexpectedEndOfInput, .internalError:
      return 0
    }
  }

  /// The column number where the error occurred.
  public var column: Int {
    switch self {
    case .unexpectedToken(_, _, _, let column),
      .missingRequiredElement(_, _, let column),
      .duplicateElement(_, _, let column),
      .invalidFieldNumber(_, _, let column),
      .invalidSyntax(_, _, let column),
      .reservedFieldNumber(_, _, let column),
      .fieldNumberOutOfRange(_, _, let column),
      .duplicateFieldNumber(_, _, let column),
      .invalidMessageDefinition(_, _, let column),
      .invalidEnumDefinition(_, _, let column),
      .invalidServiceDefinition(_, _, let column),
      .invalidOptionValue(_, _, let column),
      .missingEnumZeroValue(_, _, let column),
      .invalidExtendTarget(_, _, let column),
      .missingFieldLabel(_, _, let column):
      return column
    case .unexpectedEndOfInput, .internalError:
      return 0
    }
  }

  /// A user-friendly description of the error.
  public var description: String {
    switch self {
    case .unexpectedToken(let token, let expected, let line, let column):
      return "Unexpected token '\(token.description)' at line \(line), column \(column). Expected: \(expected)"

    case .missingRequiredElement(let element, let line, let column):
      return "Missing required element '\(element)' at line \(line), column \(column)"

    case .duplicateElement(let element, let line, let column):
      return "Duplicate element '\(element)' at line \(line), column \(column)"

    case .invalidFieldNumber(let number, let line, let column):
      return "Invalid field number \(number) at line \(line), column \(column)"

    case .unexpectedEndOfInput(let expected):
      return "Unexpected end of input. Expected: \(expected)"

    case .invalidSyntax(let message, let line, let column):
      return "Invalid syntax at line \(line), column \(column): \(message)"

    case .reservedFieldNumber(let number, let line, let column):
      return "Reserved field number \(number) used at line \(line), column \(column). Reserved range: 19000-19999"

    case .fieldNumberOutOfRange(let number, let line, let column):
      return "Field number \(number) out of range at line \(line), column \(column). Valid range: 1-536870911"

    case .duplicateFieldNumber(let number, let line, let column):
      return "Duplicate field number \(number) at line \(line), column \(column)"

    case .invalidMessageDefinition(let message, let line, let column):
      return "Invalid message definition at line \(line), column \(column): \(message)"

    case .invalidEnumDefinition(let message, let line, let column):
      return "Invalid enum definition at line \(line), column \(column): \(message)"

    case .invalidServiceDefinition(let message, let line, let column):
      return "Invalid service definition at line \(line), column \(column): \(message)"

    case .invalidOptionValue(let message, let line, let column):
      return "Invalid option value at line \(line), column \(column): \(message)"

    case .missingEnumZeroValue(let enumName, let line, let column):
      return "Enum '\(enumName)' at line \(line), column \(column) is missing a zero value (required in proto3)"

    case .invalidExtendTarget(let message, let line, let column):
      return "Invalid extend target at line \(line), column \(column): \(message)"

    case .missingFieldLabel(let message, let line, let column):
      return "Missing field label at line \(line), column \(column): \(message)"

    case .internalError(let message):
      return "Internal parser error: \(message)"
    }
  }
}

// MARK: - CustomStringConvertible
extension ParserError: CustomStringConvertible {
  public var localizedDescription: String {
    return description
  }
}

// MARK: - Convenience constructors
extension ParserError {
  /// Creates an unexpected token error with token position.
  public static func unexpectedToken(_ token: Token, expected: String) -> ParserError {
    return .unexpectedToken(token, expected: expected, line: token.position.line, column: token.position.column)
  }

  /// Creates a missing required element error.
  public static func missingElement(_ element: String, at position: Token.Position) -> ParserError {
    return .missingRequiredElement(element, line: position.line, column: position.column)
  }

  /// Creates a duplicate element error.
  public static func duplicateElement(_ element: String, at position: Token.Position) -> ParserError {
    return .duplicateElement(element, line: position.line, column: position.column)
  }

  /// Creates an invalid field number error.
  public static func invalidFieldNumber(_ number: Int32, at position: Token.Position) -> ParserError {
    return .invalidFieldNumber(number, line: position.line, column: position.column)
  }

  /// Creates a reserved field number error.
  public static func reservedFieldNumber(_ number: Int32, at position: Token.Position) -> ParserError {
    return .reservedFieldNumber(number, line: position.line, column: position.column)
  }

  /// Creates a field number out of range error.
  public static func fieldNumberOutOfRange(_ number: Int32, at position: Token.Position) -> ParserError {
    return .fieldNumberOutOfRange(number, line: position.line, column: position.column)
  }

  /// Creates a duplicate field number error.
  public static func duplicateFieldNumber(_ number: Int32, at position: Token.Position) -> ParserError {
    return .duplicateFieldNumber(number, line: position.line, column: position.column)
  }

  /// Creates a missing enum zero value error.
  public static func missingEnumZeroValue(_ enumName: String, at position: Token.Position) -> ParserError {
    return .missingEnumZeroValue(enumName, line: position.line, column: position.column)
  }
}
