import Foundation

/// The Parser class parses tokens into an AST representing the .proto file structure.
public class Parser {
	private let tokens: [Token]
	private var current: Int = 0
	private var errors: [SyntaxError] = []
	
	/// Initializes the Parser with a list of tokens.
	/// - Parameter tokens: An array of tokens produced by the lexer.
	public init(tokens: [Token]) {
		self.tokens = tokens
	}
	
	/// Parses the tokens and returns a ProtoFile AST node.
	public func parse() throws -> ProtoFile {
		let startToken = peek()
		let syntax = try parseSyntax()
		let imports = try parseImports()
		let package = try parsePackage()
		let options = try parseOptions()
		let definitions = try parseTopLevelDefinitions()
		return ProtoFile(
			syntax: syntax,
			imports: imports,
			package: package,
			options: options,
			definitions: definitions,
			startLine: startToken.line,
			startColumn: startToken.column
		)
	}
	
	// Implement parsing functions...
	// For brevity, I'm providing the parseSyntax() function.
	
	/// Parses the syntax declaration.
	private func parseSyntax() throws -> Syntax {
		let syntaxToken = try consumeKeyword("syntax")
		try consumeSymbol("=")
		let versionToken = try consumeStringLiteral()
		try consumeSymbol(";")
		
		let version = unquote(versionToken.lexeme)
		if version != "proto3" {
			throw SyntaxError(
				message: "Unsupported syntax version: \(version). Only 'proto3' is supported.",
				line: versionToken.line,
				column: versionToken.column
			)
		}
		
		return Syntax(
			version: version,
			startLine: syntaxToken.line,
			startColumn: syntaxToken.column
		)
	}
	
	// Implement other parsing functions like parseImports(), parsePackage(), parseOptions(), parseTopLevelDefinitions(), etc.
	
	// Helper functions for token management:
	
	private func consumeKeyword(_ keyword: String) throws -> Token {
		if checkKeyword(keyword) {
			return advance()
		} else {
			throw SyntaxError(
				message: "Expected keyword '\(keyword)' but found '\(peek().lexeme)'",
				line: peek().line,
				column: peek().column
			)
		}
	}
	
	private func consumeSymbol(_ symbol: String) throws {
		if checkSymbol(symbol) {
			advance()
		} else {
			throw SyntaxError(
				message: "Expected symbol '\(symbol)' but found '\(peek().lexeme)'",
				line: peek().line,
				column: peek().column
			)
		}
	}
	
	private func consumeStringLiteral() throws -> Token {
		if case .stringLiteral(_) = peek().type {
			return advance()
		} else {
			throw SyntaxError(
				message: "Expected string literal but found '\(peek().lexeme)'",
				line: peek().line,
				column: peek().column
			)
		}
	}
	
	private func checkKeyword(_ keyword: String) -> Bool {
		if case let .keyword(lexeme) = peek().type {
			return lexeme == keyword
		}
		return false
	}
	
	private func checkSymbol(_ symbol: String) -> Bool {
		if case let .symbol(lexeme) = peek().type {
			return lexeme == symbol
		}
		return false
	}
	
	private func advance() -> Token {
		let token = tokens[current]
		current += 1
		return token
	}
	
	private func peek() -> Token {
		return tokens[current]
	}
	
	private func unquote(_ string: String) -> String {
		var result = string
		if result.hasPrefix("\"") || result.hasPrefix("'") {
			result.removeFirst()
		}
		if result.hasSuffix("\"") || result.hasSuffix("'") {
			result.removeLast()
		}
		return result
	}
}

