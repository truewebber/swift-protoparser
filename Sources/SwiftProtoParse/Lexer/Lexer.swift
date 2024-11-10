import Foundation

public class Lexer {
	private let input: String
	private var currentIndex: String.Index
	private var currentChar: Character? {
		currentIndex < input.endIndex ? input[currentIndex] : nil
	}
	private var line: Int = 1
	private var column: Int = 1

	private let keywords: Set<String> = [
		"syntax", "import", "weak", "public", "package", "option",
		"message", "enum", "service", "rpc", "returns", "stream",
		"oneof", "map", "repeated", "reserved", "extensions", "to",
		"max", "true", "false"
	]

	public init(input: String) {
		self.input = input
		self.currentIndex = input.startIndex
	}

	public func nextToken() -> Token {
		skipWhitespaceAndComments()

		guard let char = currentChar else {
			return .endOfFile
		}

		// Identifiers or keywords
		if isAlpha(char) || char == "_" {
			return readIdentifierOrKeyword()
		}

		// Numbers
		if isDigit(char) || (char == "-" && peekNextChar().map(isDigit) == true) {
			return readNumber()
		}

		// String Literals
		if char == "\"" || char == "'" {
			return readStringLiteral()
		}

		// Symbols
		if isSymbol(char) {
			let symbolString = String(char)
			advance()
			return .symbol(symbolString)
		}

		// Unknown character
		let unknownChar = String(char)
		advance()
		return .unknown(unknownChar)
	}

	// MARK: - Helper Methods

	private func advance() {
		if currentChar == "\n" {
			line += 1
			column = 1
		} else {
			column += 1
		}
		currentIndex = input.index(after: currentIndex)
	}

	private func peekNextChar() -> Character? {
		let nextIndex = input.index(after: currentIndex)
		return nextIndex < input.endIndex ? input[nextIndex] : nil
	}

	private func skipWhitespaceAndComments() {
		while let char = currentChar {
			if char.isWhitespace {
				advance()
			} else if char == "/" {
				if peekNextChar() == "/" {
					skipSingleLineComment()
				} else if peekNextChar() == "*" {
					skipMultiLineComment()
				} else {
					break
				}
			} else {
				break
			}
		}
	}

	private func skipSingleLineComment() {
		while let char = currentChar, char != "\n" {
			advance()
		}
	}

	private func skipMultiLineComment() {
		advance() // Skip '/'
		advance() // Skip '*'
		while let char = currentChar {
			if char == "*" && peekNextChar() == "/" {
				advance() // Skip '*'
				advance() // Skip '/'
				break
			}
			advance()
		}
	}

	private func readIdentifierOrKeyword() -> Token {
		var identifier = ""
		while let char = currentChar, isAlphaNumeric(char) || char == "_" {
			identifier.append(char)
			advance()
		}
		if keywords.contains(identifier) {
			if identifier == "true" || identifier == "false" {
				return .booleanLiteral(identifier == "true")
			}
			return .keyword(identifier)
		}
		return .identifier(identifier)
	}

	private func readNumber() -> Token {
		var number = ""
		if currentChar == "-" {
			number.append("-")
			advance()
		}
		while let char = currentChar, isDigit(char) || char == "." {
			number.append(char)
			advance()
		}
		return .numericLiteral(number)
	}

	private func readStringLiteral() -> Token {
		let quoteChar = currentChar!
		advance()
		var stringContent = ""
		while let char = currentChar {
			if char == quoteChar {
				advance()
				break
			} else if char == "\\" {
				advance()
				if let escapedChar = currentChar {
					stringContent.append(escapedChar)
					advance()
				}
			} else {
				stringContent.append(char)
				advance()
			}
		}
		return .stringLiteral(stringContent)
	}

	private func isAlpha(_ char: Character) -> Bool {
		char.isLetter
	}

	private func isDigit(_ char: Character) -> Bool {
		char.isNumber
	}

	private func isAlphaNumeric(_ char: Character) -> Bool {
		isAlpha(char) || isDigit(char)
	}

	private func isSymbol(_ char: Character) -> Bool {
		let symbols: Set<Character> = ["{", "}", "=", ";", "[", "]", "(", ")", ",", ".", ":", "<", ">", "/"]
		return symbols.contains(char)
	}
}

