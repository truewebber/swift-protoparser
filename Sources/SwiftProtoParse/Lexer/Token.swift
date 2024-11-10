import Foundation

public enum Token: Equatable {
	case keyword(String)
	case identifier(String)
	case stringLiteral(String)
	case numericLiteral(String)
	case symbol(String)
	case comment(String)
	case endOfFile
	case unknown(String)
	case booleanLiteral(Bool)
}

