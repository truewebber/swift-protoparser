import Foundation

/// Represents all possible token types in a proto3 file
public enum TokenType: Equatable {
  // MARK: - Special Tokens

  /// End of file marker
  case eof
  /// Invalid token
  case illegal

  // MARK: - Identifiers and Literals

  /// An identifier token (variable names, type names, etc.)
  case identifier
  /// An integer literal
  case intLiteral
  /// A floating point literal
  case floatLiteral
  /// A string literal
  case stringLiteral

  // MARK: - Operators and Punctuation

  /// Equal sign '='
  case equals
  /// Colon ':'
  case colon
  /// Semicolon ';'
  case semicolon
  /// Left brace '{'
  case leftBrace
  /// Right brace '}'
  case rightBrace
  /// Left parenthesis '('
  case leftParen
  /// Right parenthesis ')'
  case rightParen
  /// Left angle bracket '<'
  case leftAngle
  /// Right angle bracket '>'
  case rightAngle
  /// Left square bracket '['
  case leftBracket
  /// Right square bracket ']'
  case rightBracket
  /// Comma ','
  case comma
  /// Period '.'
  case period
  /// Minus sign '-'
  case minus
  /// Plus sign '+'
  case plus

  // MARK: - Keywords

  /// 'syntax' keyword
  case syntax
  /// 'import' keyword
  case `import`
  /// 'weak' keyword
  case weak
  /// 'public' keyword
  case `public`
  /// 'package' keyword
  case package
  /// 'option' keyword
  case option
  /// 'message' keyword
  case message
  /// 'enum' keyword
  case `enum`
  /// 'service' keyword
  case service
  /// 'rpc' keyword
  case rpc
  /// 'returns' keyword
  case returns
  /// 'stream' keyword
  case stream
  /// 'repeated' keyword
  case repeated
  /// 'optional' keyword
  case optional
  /// 'reserved' keyword
  case reserved
  /// 'to' keyword (used in ranges)
  case to
  /// 'map' keyword
  case map
  /// 'oneof' keyword
  case oneof

  // MARK: - Built-in Types

  /// 'double' type
  case double
  /// 'float' type
  case float
  /// 'int32' type
  case int32
  /// 'int64' type
  case int64
  /// 'uint32' type
  case uint32
  /// 'uint64' type
  case uint64
  /// 'sint32' type
  case sint32
  /// 'sint64' type
  case sint64
  /// 'fixed32' type
  case fixed32
  /// 'fixed64' type
  case fixed64
  /// 'sfixed32' type
  case sfixed32
  /// 'sfixed64' type
  case sfixed64
  /// 'bool' type
  case bool
  /// 'string' type
  case string
  /// 'bytes' type
  case bytes
}

// MARK: - Keyword Mapping

extension TokenType {
  /// Maps string literals to their corresponding keyword token types
  static let keywords: [String: TokenType] = [
    "syntax": .syntax,
    "import": .import,
    "weak": .weak,
    "public": .public,
    "package": .package,
    "option": .option,
    "message": .message,
    "enum": .enum,
    "service": .service,
    "rpc": .rpc,
    "returns": .returns,
    "stream": .stream,
    "repeated": .repeated,
    "optional": .optional,
    "reserved": .reserved,
    "to": .to,
    "map": .map,
    "oneof": .oneof,

    // Built-in types
    "double": .double,
    "float": .float,
    "int32": .int32,
    "int64": .int64,
    "uint32": .uint32,
    "uint64": .uint64,
    "sint32": .sint32,
    "sint64": .sint64,
    "fixed32": .fixed32,
    "fixed64": .fixed64,
    "sfixed32": .sfixed32,
    "sfixed64": .sfixed64,
    "bool": .bool,
    "string": .string,
    "bytes": .bytes,
  ]

  /// Checks if a string is a keyword
  /// - Parameter identifier: The string to check
  /// - Returns: The corresponding token type if it's a keyword, nil otherwise
  static func keyword(from identifier: String) -> TokenType? {
    return keywords[identifier]
  }
}

// MARK: - CustomStringConvertible

extension TokenType: CustomStringConvertible {
  public var description: String {
    switch self {
    // Special Tokens
    case .eof: return "EOF"
    case .illegal: return "ILLEGAL"

    // Identifiers and Literals
    case .identifier: return "IDENTIFIER"
    case .intLiteral: return "INT_LITERAL"
    case .floatLiteral: return "FLOAT_LITERAL"
    case .stringLiteral: return "STRING_LITERAL"

    // Operators and Punctuation
    case .equals: return "="
    case .colon: return ":"
    case .semicolon: return ";"
    case .leftBrace: return "{"
    case .rightBrace: return "}"
    case .leftParen: return "("
    case .rightParen: return ")"
    case .leftAngle: return "<"
    case .rightAngle: return ">"
    case .leftBracket: return "["
    case .rightBracket: return "]"
    case .comma: return ","
    case .period: return "."
    case .minus: return "-"
    case .plus: return "+"

    // Keywords
    case .syntax: return "syntax"
    case .import: return "import"
    case .weak: return "weak"
    case .public: return "public"
    case .package: return "package"
    case .option: return "option"
    case .message: return "message"
    case .enum: return "enum"
    case .service: return "service"
    case .rpc: return "rpc"
    case .returns: return "returns"
    case .stream: return "stream"
    case .repeated: return "repeated"
    case .optional: return "optional"
    case .reserved: return "reserved"
    case .to: return "to"
    case .map: return "map"
    case .oneof: return "oneof"

    // Built-in Types
    case .double: return "double"
    case .float: return "float"
    case .int32: return "int32"
    case .int64: return "int64"
    case .uint32: return "uint32"
    case .uint64: return "uint64"
    case .sint32: return "sint32"
    case .sint64: return "sint64"
    case .fixed32: return "fixed32"
    case .fixed64: return "fixed64"
    case .sfixed32: return "sfixed32"
    case .sfixed64: return "sfixed64"
    case .bool: return "bool"
    case .string: return "string"
    case .bytes: return "bytes"
    }
  }
}

extension TokenType {
  /// Checks if this token type represents an absolutely reserved keyword
  /// .extend - has to be added
  var isAbsolutelyReserved: Bool {
    switch self {
    case .syntax, .import, .package, .option,
      .service, .rpc, .returns, .reserved,
      .oneof, .repeated:
      return true
    default:
      return false
    }
  }
}
