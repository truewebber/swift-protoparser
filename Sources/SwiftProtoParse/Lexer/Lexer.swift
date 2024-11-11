import Foundation

/// The Lexer class tokenizes the input .proto file content into a sequence of tokens.
public class Lexer {
	private let input: String
	private var currentIndex: String.Index
	private var line: Int
	private var column: Int
	
	private var currentChar: Character? {
		return currentIndex < input.endIndex ? input[currentIndex] : nil
	}
	
	/// Initializes the Lexer with the input string.
	/// - Parameter input: The content of the .proto file as a string.
	public init(input: String) {
		self.input = input
		self.currentIndex = input.startIndex
		self.line = 1
		self.column = 1
	}
	
	/// Tokenizes the input string and returns an array of tokens.
	public func tokenize() throws -> [Token] {
		var tokens = [Token]()
		while let _ = currentChar {
			// Skip whitespace and comments
			skipWhitespaceAndComments()
			if isAtEnd() { break }

			// Scan next token
			if let token = try scanToken() {
				tokens.append(token)
			}
		}
		tokens.append(Token(type: .eof, lexeme: "", line: line, column: column))
		return tokens
	}
	
	/// Scans and returns the next token from the input.
	private func scanToken() throws -> Token? {
		guard let char = currentChar else { return nil }

		let startLine = line
		let startColumn = column

		if isLetter(char) || char == "_" {
			return scanIdentifierOrKeyword(startLine: startLine, startColumn: startColumn)
		} else if isDigit(char) || (char == "-" && nextIsDigit()) {
			return scanNumericLiteral(startLine: startLine, startColumn: startColumn)
		} else if char == "\"" || char == "'" {
			return try scanStringLiteral(startLine: startLine, startColumn: startColumn)
		} else if isSymbol(char) {
			return scanSymbol(startLine: startLine, startColumn: startColumn)
		} else {
			// Unknown character
			advance()
			let lexeme = String(char)
			return Token(type: .unknown(lexeme), lexeme: lexeme, line: startLine, column: startColumn)
		}
	}
	
	/// Advances the current index and updates the line and column numbers.
	@discardableResult
	private func advance() -> Character? {
		guard currentIndex < input.endIndex else { return nil }
		let char = input[currentIndex]
		currentIndex = input.index(after: currentIndex)
		if char == "\n" {
			line += 1
			column = 1
		} else {
			column += 1
		}
		return char
	}
	
	/// Peeks at the next character without advancing the current index.
	private func peek() -> Character? {
		let nextIndex = input.index(after: currentIndex)
		return nextIndex < input.endIndex ? input[nextIndex] : nil
	}
	
	/// Checks if the current character and the next character start a comment.
	private func isCommentStart() -> Bool {
		if let char = currentChar {
			if char == "/" {
				if let nextChar = peek() {
					return nextChar == "/" || nextChar == "*"
				}
			}
		}
		return false
	}
	
	/// Skips over whitespace characters.
	private func skipWhitespaceAndComments() {
		while let char = currentChar {
			if isWhitespace(char) || isNewline(char) {
				advance()
			} else if isCommentStart() {
				skipComment()
			} else {
				break
			}
		}
	}
	
	/// Skips over comments (both single-line and multi-line).
	private func skipComment() {
		guard let char = currentChar else { return }
		advance() // Consume '/'
		
		if char == "/" && currentChar == "/" {
			// Single-line comment
			while let char = currentChar, !isNewline(char) {
				advance()
			}
		} else if char == "/" && currentChar == "*" {
			// Multi-line comment
			advance() // Consume '*'
			while let char = currentChar {
				if char == "*" && peek() == "/" {
					advance() // Consume '*'
					advance() // Consume '/'
					break
				} else {
					advance()
				}
			}
		}
	}
	
	/// Scans an identifier or keyword.
	private func scanIdentifierOrKeyword(startLine: Int, startColumn: Int) -> Token {
		var lexeme = ""
		while let char = currentChar, isLetterOrDigit(char) || char == "_" || char == "." {
			lexeme.append(char)
			advance()
		}
		
		if isKeyword(lexeme) {
			return Token(type: .keyword(lexeme), lexeme: lexeme, line: startLine, column: startColumn)
		} else if lexeme == "true" || lexeme == "false" {
			return Token(type: .booleanLiteral(lexeme == "true"), lexeme: lexeme, line: startLine, column: startColumn)
		} else {
			return Token(type: .identifier(lexeme), lexeme: lexeme, line: startLine, column: startColumn)
		}
	}
	
	/// Scans a numeric literal.
	private func scanNumericLiteral(startLine: Int, startColumn: Int) -> Token {
		var lexeme = ""
		if currentChar == "-" {
			lexeme.append("-")
			advance()
		}
		while let char = currentChar, isDigit(char) || char == "." || char == "e" || char == "E" || char == "+" || char == "-" {
			lexeme.append(char)
			advance()
		}
		return Token(type: .numericLiteral(lexeme), lexeme: lexeme, line: startLine, column: startColumn)
	}
	
	/// Scans a string literal.
	private func scanStringLiteral(startLine: Int, startColumn: Int) throws -> Token? {
		guard let quoteChar = currentChar else { return nil }
		var lexeme = ""
		lexeme.append(quoteChar)
		advance()
		
		while let char = currentChar {
			if char == quoteChar {
				lexeme.append(char)
				advance()
				let token = Token(type: .stringLiteral(lexeme), lexeme: lexeme, line: startLine, column: startColumn)
				return token
			} else if char == "\\" {
				// Handle escape sequences
				lexeme.append(char)
				advance()
				if let nextChar = currentChar {
					lexeme.append(nextChar)
					advance()
				} else {
					// Handle the case where the escape character is at the end of input
					// You can throw an error or return nil
					throw LexicalError(
						message: "Unterminated string literal at end of input.",
						line: line,
						column: column
					)
				}
			} else {
				lexeme.append(char)
				advance()
			}
		}
		
		// If we reach here, the string literal was not terminated
		throw LexicalError(
			message: "Unterminated string literal.",
			line: startLine,
			column: startColumn
		)
	}
	
	/// Scans a symbol token.
	private func scanSymbol(startLine: Int, startColumn: Int) -> Token? {
		guard let char = currentChar else { return nil }
		let lexeme = String(char)
		advance()
		let token = Token(type: .symbol(lexeme), lexeme: lexeme, line: startLine, column: startColumn)
		return token
	}
	
	/// Helper functions to identify character types.
	private func isWhitespace(_ char: Character) -> Bool {
		return char == " " || char == "\t" || char == "\r"
	}
	
	private func isNewline(_ char: Character) -> Bool {
		return char == "\n"
	}
	
	private func isLetter(_ char: Character) -> Bool {
		return char.isLetter
	}
	
	private func isDigit(_ char: Character) -> Bool {
		return char.isNumber
	}
	
	private func isLetterOrDigit(_ char: Character) -> Bool {
		return char.isLetter || char.isNumber
	}
	
	private func isSymbol(_ char: Character) -> Bool {
		let symbols = "{}[]()<>;=,.:"
		return symbols.contains(char)
	}
	
	private func isKeyword(_ lexeme: String) -> Bool {
		let keywords = [
			"syntax", "import", "package", "option", "message", "enum", "service", "rpc",
			"map", "oneof", "repeated", "returns", "stream", "reserved", "extend", "true", "false"
		]
		return keywords.contains(lexeme)
	}
	
	private func nextIsDigit() -> Bool {
		if let nextChar = peek() {
			return isDigit(nextChar)
		}
		return false
	}
	
	private func isAtEnd() -> Bool {
		return currentIndex >= input.endIndex
	}
}

