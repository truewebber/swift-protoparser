import Foundation

/// Represents the different types of tokens in a .proto file.
public enum TokenType: Equatable {
	case keyword(String)
	case identifier(String)
	case stringLiteral(String)
	case numericLiteral(String)
	case booleanLiteral(Bool)
	case symbol(String)
	case eof
	case unknown(String)
}

/// Represents a token with its type, lexeme, and position.
public struct Token: Equatable {
	public let type: TokenType
	public let lexeme: String
	public let line: Int
	public let column: Int
}
