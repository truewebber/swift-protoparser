import Foundation

/// Protocol for parse errors.
public protocol ParseError: Error {
    var message: String { get }
    var line: Int { get }
    var column: Int { get }
}

/// Represents a syntax error encountered during parsing.
public struct SyntaxError: ParseError {
    public let message: String
    public let line: Int
    public let column: Int
}

/// Represents a semantic error encountered during analysis.
public struct SemanticError: ParseError {
    public let message: String
    public let line: Int
    public let column: Int
}
