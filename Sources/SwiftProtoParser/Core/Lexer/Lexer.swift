import Foundation

/// Errors that can occur during lexical analysis
public enum LexerError: Error, CustomStringConvertible {
    /// Encountered an invalid character
    case invalidCharacter(Character, location: SourceLocation)
    /// Unterminated string literal
    case unterminatedString(location: SourceLocation)
    /// Invalid escape sequence in string
    case invalidEscapeSequence(String, location: SourceLocation)
    /// Invalid number format
    case invalidNumber(String, location: SourceLocation)
    
    public var description: String {
        switch self {
        case .invalidCharacter(let char, let loc):
            return "Invalid character '\(char)' at \(loc.line):\(loc.column)"
        case .unterminatedString(let loc):
            return "Unterminated string literal at \(loc.line):\(loc.column)"
        case .invalidEscapeSequence(let seq, let loc):
            return "Invalid escape sequence '\(seq)' at \(loc.line):\(loc.column)"
        case .invalidNumber(let num, let loc):
            return "Invalid number format '\(num)' at \(loc.line):\(loc.column)"
        }
    }
}

/// A lexical analyzer for proto3 files
public final class Lexer {
    /// The input string being tokenized
    private let input: String
    
    /// The current position in input (points to current char)
    private var position: String.Index
    
    /// Current reading position in input (after current char)
    private var readPosition: String.Index
    
    /// Current character under examination
    private var ch: Character
    
    /// Current line number (1-based)
    private var line: Int = 1
    
    /// Current column number (1-based)
    private var column: Int = 0
    
    /// Accumulated comments that appear before the next token
    private var pendingComments: [String] = []

	// Add token history
	private var lastToken: Token?

    /// Creates a new lexer with the given input
    /// - Parameter input: The proto file content to tokenize
    public init(input: String) {
        self.input = input
        self.position = input.startIndex
        self.readPosition = input.startIndex
        self.ch = "\0"  // Initialize with null character
        readChar()  // Read the first character
    }
    
    /// Returns the next token from the input
    /// - Throws: LexerError if invalid input is encountered
    /// - Returns: The next token
    public func nextToken() throws -> Token {
        skipWhitespace()
        
        // Process any comments before the token
        while ch == "/" {
            if let comment = try processComment() {
                pendingComments.append(comment)
                skipWhitespace()
            } else {
                break
            }
        }
        
        let startLocation = SourceLocation(line: line, column: column)

        var token: Token
        
        switch ch {
        case "=":
            token = makeToken(.equals, String(ch))
			readChar()
		case ":":
			token = makeToken(.colon, String(ch))
			readChar()
        case ";":
            token = makeToken(.semicolon, String(ch))
			readChar()
        case "(":
            token = makeToken(.leftParen, String(ch))
			readChar()
        case ")":
            token = makeToken(.rightParen, String(ch))
			readChar()
        case "{":
            token = makeToken(.leftBrace, String(ch))
			readChar()
        case "}":
            token = makeToken(.rightBrace, String(ch))
			readChar()
        case "[":
            token = makeToken(.leftBracket, String(ch))
			readChar()
        case "]":
            token = makeToken(.rightBracket, String(ch))
			readChar()
        case "<":
            token = makeToken(.leftAngle, String(ch))
			readChar()
        case ">":
            token = makeToken(.rightAngle, String(ch))
			readChar()
        case ",":
            token = makeToken(.comma, String(ch))
			readChar()
        case ".":
            token = makeToken(.period, String(ch))
			readChar()
        case "\0":
            token = makeToken(.eof, "")
			readChar()
        case "\"", "'":
            let stringLocation = startLocation
            token = try makeStringToken(stringLocation)
        default:
			if ch.isNumber ||
			   // Only treat minus/plus as start of number if at beginning or after certain tokens
			   ((ch == "-" || ch == "+") && (lastToken == nil ||
				 lastToken?.type == .equals ||
				 lastToken?.type == .leftParen ||
				 lastToken?.type == .comma ||
				 lastToken?.type == .colon)) {
				return try makeNumberToken(startLocation)
			} else if ch == "-" {
				token = makeToken(.minus, String(ch))
				readChar()
			} else if ch == "+" {
				token = makeToken(.plus, String(ch))
				readChar()
			} else if ch.isLetter || ch == "_" {
				token = makeIdentifierToken(startLocation)
			} else {
                throw LexerError.invalidCharacter(ch, location: startLocation)
            }
        }
		
		lastToken = token

        return token
    }
    
    // MARK: - Private Helper Methods
    
	private func readChar() {
		if readPosition < input.endIndex {
			ch = input[readPosition]
			position = readPosition
			readPosition = input.index(after: readPosition)
			column += 1
		} else {
			ch = "\0"
			position = input.endIndex  // <-- Add this line
		}
	}
    
    private func peekChar() -> Character {
        if readPosition < input.endIndex {
            return input[readPosition]
        }
        return "\0"
    }

	private func peekPrevious() -> Character? {
		if position > input.startIndex {
			return input[input.index(before: position)]
		}
		return nil
	}

    private func makeToken(_ type: TokenType, _ literal: String, trailingComment: String? = nil) -> Token {
        let token = Token(
            type: type,
            literal: literal,
            location: SourceLocation(line: line, column: column),
            length: literal.count,
            leadingComments: pendingComments,
            trailingComment: trailingComment
        )
        pendingComments = []
        return token
    }
    
    private func skipWhitespace() {
        while ch.isWhitespace || ch.isNewline {
			if ch.isNewline {
                line += 1
                column = 0
            }
            readChar()
        }
    }

    private func processComment() throws -> String? {
        guard ch == "/" else { return nil }
        
        readChar()

        switch ch {
        case "/":  // Single-line comment
			return self.processOneLineDoubleSlashComment()
        case "*":  // Multi-line comment
            readChar()
            let start = position
            var depth = 1
            
            while depth > 0 && ch != "\0" {
                if ch == "/" && peekChar() == "*" {
                    depth += 1
                    readChar()
                } else if ch == "*" && peekChar() == "/" {
                    depth -= 1
                    readChar()
                } else if ch == "\n" {
                    line += 1
                    column = 0
                }
                readChar()
            }
            
            if depth > 0 {
                throw LexerError.unterminatedString(location: SourceLocation(line: line, column: column))
            }
            
            let comment = String(input[start..<position]).trimmingCharacters(in: .whitespaces)
            readChar()  // consume the final '/'
            return comment
            
        default:
            return nil
        }
    }

	private func processOneLineDoubleSlashComment() -> String? {
		guard ch == "/" else { return nil }

		readChar()
		let start = position

		while ch != "\n" && ch != "\0" {
			readChar()
		}

		let comment = String(input[start..<position]).trimmingCharacters(in: .whitespaces)
		if ch == "\n" {
			line += 1
			column = 0
			readChar()
		}

		return comment
	}

    private func makeIdentifierToken(_ startLocation: SourceLocation) -> Token {
        let startPos = position
        while ch.isLetter || ch.isNumber || ch == "_" {
            readChar()
        }
        
        let literal = String(input[startPos..<position])
		let type = shouldTreatAsIdentifier() ? .identifier : (TokenType.keyword(from: literal) ?? .identifier)

		defer {
			pendingComments = []
		}

        return Token(
            type: type,
            literal: literal,
            location: startLocation,
            length: input.distance(from: startPos, to: position),
            leadingComments: pendingComments
        )
    }

	private func shouldTreatAsIdentifier() -> Bool {
		// Check if last token was a period
		return lastToken?.type == .period
	}

	private func makeNumberToken(_ startLocation: SourceLocation) throws -> Token {
		let startPos = position
		var sawDot = false
		var sawExponent = false
		var isFloat = false

		// Handle sign at start
//		if lastToken == nil || shouldParseAsNumberStart() {
			if ch == "-" || ch == "+" {
				readChar()
			}
//		}

		// Must have at least one digit
		if !ch.isNumber {
			throw LexerError.invalidNumber(
				String(input[startPos..<position]),
				location: startLocation
			)
		}

		while ch.isNumber || ch == "." || ch.lowercased() == "e" {
			if ch == "." {
				if sawDot {
					throw LexerError.invalidNumber(
						String(input[startPos..<position]),
						location: startLocation
					)
				}
				readChar()
				// Must have at least one digit after decimal point
				if !ch.isNumber {
					throw LexerError.invalidNumber(
						String(input[startPos..<position]),
						location: startLocation
					)
				}
				sawDot = true
				isFloat = true
			} else if ch.lowercased() == "e" {
				if sawExponent {
					throw LexerError.invalidNumber(
						String(input[startPos..<position]),
						location: startLocation
					)
				}
				readChar()
				if ch == "+" || ch == "-" {
					readChar()
				}
				if !ch.isNumber {
					throw LexerError.invalidNumber(
						String(input[startPos..<position]),
						location: startLocation
					)
				}
				sawExponent = true
				isFloat = true
			} else {
				readChar()
			}
		}
		
		// After we've finished parsing the number, check what follows
		// If it's a letter or underscore, this is an invalid number format
		if ch.isLetter || ch == "_" {
			throw LexerError.invalidNumber(
				String(input[startPos..<position]),
				location: startLocation
			)
		}

		let literal = String(input[startPos..<position])

		return Token(
			type: isFloat ? .floatLiteral : .intLiteral,
			literal: literal,
			location: startLocation,
			length: input.distance(from: startPos, to: position),
			leadingComments: pendingComments
		)
	}

	private func shouldParseAsNumberStart() -> Bool {
		return lastToken?.type == .equals ||
			   lastToken?.type == .leftParen ||
			   lastToken?.type == .comma ||
			   lastToken?.type == .colon
	}

	private func makeStringToken(_ startLocation: SourceLocation) throws -> Token {
		let quote = ch
		readChar()  // consume opening quote
		
		var value = ""
		
		while ch != quote && ch != "\0" {
			if ch == "\\" {
				readChar()  // consume backslash
				value.append(try parseEscapeSequence())
			} else {
				value.append(ch)
				readChar()
			}
			
			if ch == "\n" {
				throw LexerError.unterminatedString(location: startLocation)
			}
		}
		
		if ch == "\0" {
			throw LexerError.unterminatedString(location: startLocation)
		}
		
		readChar()  // consume closing quote
		
		return Token(
			type: .stringLiteral,
			literal: value,
			location: startLocation,
			length: value.count,
			leadingComments: pendingComments
		)
	}

	private func parseEscapeSequence() throws -> Character {
		let escapeLocation = SourceLocation(line: line, column: column)
		
		switch ch {
		case "\"":
			readChar()
			return "\""
		case "\\":
			readChar()
			return "\\"
		case "/":
			readChar()
			return "/"
		case "b":
			readChar()
			return "\u{8}"  // backspace
		case "f":
			readChar()
			return "\u{12}" // form feed
		case "n":
			readChar()
			return "\n"     // newline
		case "r":
			readChar()
			return "\r"     // carriage return
		case "t":
			readChar()
			return "\t"     // tab
		case "u":
			readChar()      // consume 'u'
			var hexString = ""
			for _ in 0..<4 {
				if ch.isHexDigit {
					hexString.append(ch)
					readChar()
				} else {
					throw LexerError.invalidEscapeSequence("\\u" + hexString, location: escapeLocation)
				}
			}
			guard let codePoint = UInt32(hexString, radix: 16),
				  let scalar = Unicode.Scalar(codePoint) else {
				throw LexerError.invalidEscapeSequence("\\u" + hexString, location: escapeLocation)
			}
			return Character(scalar)
		default:
			throw LexerError.invalidEscapeSequence(String(ch), location: escapeLocation)
		}
	}
}

// MARK: - Character Extensions

private extension Character {
    var isLetter: Bool {
		return Character.isLetter(self)
    }
    
    var isNumber: Bool {
		return Character.isNumber(self)
    }
    
	var isHexDigit: Bool {
		return isNumber || ("a"..."f").contains(lowercased()) || ("A"..."F").contains(uppercased())
	}
    
    static func isLetter(_ ch: Character) -> Bool {
        return (ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z")
    }
    
    static func isNumber(_ ch: Character) -> Bool {
        return ch >= "0" && ch <= "9"
    }
}
