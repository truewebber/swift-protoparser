import Foundation

/// Enum representing the different types of tokens that can be identified in a .proto file.
enum TokenType: Equatable {
	case keyword(String)
	case identifier(String)
	case stringLiteral(String)
	case numericLiteral(String)
	case symbol(String)
	case eof
}

/// Struct representing a token with its type, lexeme, and position in the source code.
struct Token: Equatable {
	let type: TokenType
	let lexeme: String
	let line: Int
	let column: Int
}

/// Class responsible for converting the input .proto file content into a sequence of tokens.
class Lexer {
	private let source: String
	private var currentIndex: String.Index
	private var line: Int = 1
	private var column: Int = 1
	private var currentChar: Character? {
		return currentIndex < source.endIndex ? source[currentIndex] : nil
	}
	
	/// Initializes the lexer with the source content.
	/// - Parameter source: The .proto file content as a string.
	init(source: String) {
		self.source = source
		self.currentIndex = source.startIndex
	}
	
	/// Tokenizes the input source and returns an array of tokens.
	/// - Returns: An array of tokens representing the input source.
	/// - Throws: `LexerError` if an invalid token is encountered.
	func tokenize() throws -> [Token] {
		var tokens = [Token]()
		while true {
			let token = try nextToken()
			tokens.append(token)
			if token.type == .eof {
				break
			}
		}
		return tokens
	}
	
	/// Retrieves the next token from the input source.
	/// - Returns: The next token.
	/// - Throws: `LexerError` if an invalid token is encountered.
	private func nextToken() throws -> Token {
		skipWhitespaceAndComments()
		guard let char = currentChar else {
			return Token(type: .eof, lexeme: "", line: line, column: column)
		}
		
		let startLine = line
		let startColumn = column
		
		if isLetter(char) || char == "_" {
			return identifierOrKeyword()
		} else if isDigit(char) || (char == "-" && peekNext()?.isDigit == true) {
			return try numericLiteral()
		} else if char == "\"" || char == "'" {
			return try stringLiteral()
		} else if isSymbol(char) {
			let lexeme = String(char)
			advance()
			return Token(type: .symbol(lexeme), lexeme: lexeme, line: startLine, column: startColumn)
		} else {
			throw LexerError(
				message: "Unexpected character '\(char)'",
				line: line,
				column: column
			)
		}
	}
	
	// MARK: - Helper Methods
	
	/// Advances the current index and updates line and column numbers.
	@discardableResult
	private func advance() -> Character? {
		guard currentIndex < source.endIndex else {
			return nil
		}
		let char = source[currentIndex]
		currentIndex = source.index(after: currentIndex)
		if char == "\n" {
			line += 1
			column = 1
		} else {
			column += 1
		}
		return char
	}
	
	/// Peeks at the next character without advancing.
	private func peek() -> Character? {
		guard currentIndex < source.endIndex else {
			return nil
		}
		return source[currentIndex]
	}
	
	/// Peeks at the character after the next character without advancing.
	private func peekNext() -> Character? {
		let nextIndex = source.index(after: currentIndex)
		guard nextIndex < source.endIndex else {
			return nil
		}
		return source[nextIndex]
	}
	
	/// Skips whitespace and comments in the input.
	private func skipWhitespaceAndComments() {
		while let char = currentChar {
			if char.isWhitespace {
				advance()
			} else if char == "/" {
				if peekNext() == "/" {
					skipSingleLineComment()
				} else if peekNext() == "*" {
					skipMultiLineComment()
				} else {
					break
				}
			} else {
				break
			}
		}
	}
	
	/// Skips a single-line comment.
	private func skipSingleLineComment() {
		while let char = currentChar, char != "\n" {
			advance()
		}
		// Consume the newline character
		if currentChar == "\n" {
			advance()
		}
	}
	
	/// Skips a multi-line comment.
	private func skipMultiLineComment() {
		// Consume '/*'
		advance() // '/'
		advance() // '*'
		while let char = currentChar {
			if char == "*" && peekNext() == "/" {
				// Consume '*/'
				advance() // '*'
				advance() // '/'
				break
			} else {
				advance()
			}
		}
	}
	
	/// Checks if the character is a letter.
	private func isLetter(_ char: Character) -> Bool {
		return char.isLetter
	}
	
	/// Checks if the character is a digit.
	private func isDigit(_ char: Character) -> Bool {
		return char.isNumber
	}
	
	/// Checks if the character is a symbol.
	private func isSymbol(_ char: Character) -> Bool {
		let symbols: Set<Character> = [
			"{", "}", "(", ")", "[", "]", "<", ">", "=", ";", ".", ",", ":", "/", "-", "+", "*", "!", "~", "&", "|", "^", "%", "?", "@", "#"
		]
		return symbols.contains(char)
	}
	
	/// Parses an identifier or keyword token.
	private func identifierOrKeyword() -> Token {
		let startLine = line
		let startColumn = column
		var lexeme = ""
		while let char = currentChar, isLetter(char) || isDigit(char) || char == "_" {
			lexeme.append(char)
			advance()
		}
		
		if isKeyword(lexeme) {
			return Token(type: .keyword(lexeme), lexeme: lexeme, line: startLine, column: startColumn)
		} else {
			return Token(type: .identifier(lexeme), lexeme: lexeme, line: startLine, column: startColumn)
		}
	}
	
	/// Parses a numeric literal token.
	private func numericLiteral() throws -> Token {
		let startLine = line
		let startColumn = column
		var lexeme = ""
		
		if currentChar == "-" {
			lexeme.append("-")
			advance()
		}
		
		var hasDigits = false
		var isHex = false
		var isOctal = false
		var isBinary = false
		
		if currentChar == "0" {
			lexeme.append("0")
			advance()
			if let char = currentChar {
				if char == "x" || char == "X" {
					lexeme.append(char)
					advance()
					isHex = true
				} else if char == "b" || char == "B" {
					lexeme.append(char)
					advance()
					isBinary = true
				} else if char.isDigit {
					isOctal = true
				}
			}
		}
		
		while let char = currentChar {
			if isHex && (char.isHexDigit) {
				lexeme.append(char)
				advance()
				hasDigits = true
			} else if isBinary && (char == "0" || char == "1") {
				lexeme.append(char)
				advance()
				hasDigits = true
			} else if isOctal && ("0"..."7").contains(char) {
				lexeme.append(char)
				advance()
				hasDigits = true
			} else if char.isNumber {
				lexeme.append(char)
				advance()
				hasDigits = true
			} else if char == "." || char == "e" || char == "E" {
				// Handle floating-point numbers
				lexeme.append(char)
				advance()
				while let nextChar = currentChar, nextChar.isNumber || nextChar == "." || nextChar == "e" || nextChar == "E" || nextChar == "-" || nextChar == "+" {
					lexeme.append(nextChar)
					advance()
				}
				break
			} else {
				break
			}
		}
		
		if !hasDigits {
			throw LexerError(
				message: "Invalid numeric literal",
				line: startLine,
				column: startColumn
			)
		}
		
		return Token(type: .numericLiteral(lexeme), lexeme: lexeme, line: startLine, column: startColumn)
	}
	
	/// Parses a string literal token.
	private func stringLiteral() throws -> Token {
		let startLine = line
		let startColumn = column
		let quoteChar = currentChar!
		advance()
		
		var lexeme = ""
		while let char = currentChar {
			if char == quoteChar {
				advance()
				return Token(type: .stringLiteral(lexeme), lexeme: lexeme, line: startLine, column: startColumn)
			} else if char == "\\" {
				advance()
				if let escapedChar = parseEscapeSequence() {
					lexeme.append(escapedChar)
				} else {
					throw LexerError(
						message: "Invalid escape sequence",
						line: line,
						column: column
					)
				}
			} else if char == "\n" {
				throw LexerError(
					message: "Unterminated string literal",
					line: startLine,
					column: startColumn
				)
			} else {
				lexeme.append(char)
				advance()
			}
		}
		
		throw LexerError(
			message: "Unterminated string literal",
			line: startLine,
			column: startColumn
		)
	}
	
	/// Parses an escape sequence in a string literal.
	private func parseEscapeSequence() -> Character? {
		guard let char = currentChar else {
			return nil
		}
		advance()
		switch char {
		case "a":
			return "\u{0007}" // Alert/bell
		case "b":
			return "\u{0008}" // Backspace
		case "f":
			return "\u{000C}" // Form feed
		case "n":
			return "\n"
		case "r":
			return "\r"
		case "t":
			return "\t"
		case "v":
			return "\u{000B}" // Vertical tab
		case "\\", "\'", "\"":
			return char
		case "x":
			// Hexadecimal escape sequence
			var hexDigits = ""
			for _ in 0..<2 {
				if let hexChar = currentChar, hexChar.isHexDigit {
					hexDigits.append(hexChar)
					advance()
				} else {
					break
				}
			}
			if let codePoint = UInt8(hexDigits, radix: 16) {
				return Character(UnicodeScalar(codePoint))
			} else {
				return nil
			}
		default:
			if char.isDigit {
				// Octal escape sequence
				var octDigits = String(char)
				for _ in 0..<2 {
					if let nextChar = currentChar, nextChar.isDigit {
						octDigits.append(nextChar)
						advance()
					} else {
						break
					}
				}
				if let codePoint = UInt8(octDigits, radix: 8) {
					return Character(UnicodeScalar(codePoint))
				} else {
					return nil
				}
			} else {
				return nil
			}
		}
	}
	
	/// Checks if the given string is a keyword.
	private func isKeyword(_ lexeme: String) -> Bool {
		let keywords: Set<String> = [
			"syntax", "package", "import", "option", "message", "enum", "service", "rpc", "returns", "stream",
			"map", "repeated", "oneof", "extensions", "reserved", "extend", "optional", "required", "public", "weak",
			"to", "max", "true", "false"
		]
		return keywords.contains(lexeme)
	}
	
	/// Checks if we have reached the end of the source.
	private func isAtEnd() -> Bool {
		return currentIndex >= source.endIndex
	}
}

// MARK: - Lexer Error

/// Error type representing a lexical analysis error.
struct LexerError: Error, CustomStringConvertible {
	let message: String
	let line: Int
	let column: Int
	
	var description: String {
		return "[Line \(line), Column \(column)] Lexer Error: \(message)"
	}
}

// MARK: - Character Extensions

private extension Character {
	/// Checks if the character is a hexadecimal digit.
	var isHexDigit: Bool {
		return isDigit || ("a"..."f").contains(lowercased()) || ("A"..."F").contains(self)
	}
	
	/// Checks if the character is a whitespace character.
	var isWhitespace: Bool {
		return unicodeScalars.allSatisfy(CharacterSet.whitespacesAndNewlines.contains)
	}
	
	/// Converts the character to lowercase.
	func lowercased() -> Character {
		return Character(String(self).lowercased())
	}
	
	/// Checks if the character is a letter.
	var isLetter: Bool {
		return unicodeScalars.allSatisfy(CharacterSet.letters.contains)
	}
	
	/// Checks if the character is a digit.
	var isDigit: Bool {
		return unicodeScalars.allSatisfy(CharacterSet.decimalDigits.contains)
	}
}
