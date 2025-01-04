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
    private var column: Int = 1
    
    /// Accumulated comments that appear before the next token
    private var pendingComments: [String] = []
    
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
		case ":":
			token = makeToken(.colon, String(ch))
        case ";":
            token = makeToken(.semicolon, String(ch))
        case "(":
            token = makeToken(.leftParen, String(ch))
        case ")":
            token = makeToken(.rightParen, String(ch))
        case "{":
            token = makeToken(.leftBrace, String(ch))
        case "}":
            token = makeToken(.rightBrace, String(ch))
        case "[":
            token = makeToken(.leftBracket, String(ch))
        case "]":
            token = makeToken(.rightBracket, String(ch))
        case "<":
            token = makeToken(.leftAngle, String(ch))
        case ">":
            token = makeToken(.rightAngle, String(ch))
        case ",":
            token = makeToken(.comma, String(ch))
        case ".":
            token = makeToken(.period, String(ch))
        case "-":
            token = makeToken(.minus, String(ch))
        case "+":
            token = makeToken(.plus, String(ch))
        case "\0":
            token = makeToken(.eof, "")
        case "\"", "'":
            let stringLocation = startLocation
            token = try makeStringToken(stringLocation)
        default:
            if ch.isLetter || ch == "_" {
                return makeIdentifierToken(startLocation)
            } else if ch.isNumber || ch == "-" || ch == "+" {
                return try makeNumberToken(startLocation)
            } else {
                throw LexerError.invalidCharacter(ch, location: startLocation)
            }
        }
        
        readChar()
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
        }
    }
    
    private func peekChar() -> Character {
        if readPosition < input.endIndex {
            return input[readPosition]
        }
        return "\0"
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
        while ch.isWhitespace {
            if ch == "\n" {
                line += 1
                column = 1
            }
            readChar()
        }
    }

    private func processComment() throws -> String? {
        guard ch == "/" else { return nil }
        
        readChar()

        switch ch {
        case "/":  // Single-line comment
            readChar()
            let start = position
            while ch != "\n" && ch != "\0" {
                readChar()
            }
            let comment = String(input[start..<position]).trimmingCharacters(in: .whitespaces)
            if ch == "\n" {
                line += 1
                column = 1
                readChar()
            }
            return comment
            
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
                    column = 1
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
    
    private func makeIdentifierToken(_ startLocation: SourceLocation) -> Token {
        let startPos = position
        while ch.isLetter || ch.isNumber || ch == "_" {
            readChar()
        }
        
        let literal = String(input[startPos..<position])
        let type = TokenType.keyword(from: literal) ?? .identifier
        
        return Token(
            type: type,
            literal: literal,
            location: startLocation,
            length: input.distance(from: startPos, to: position),
            leadingComments: pendingComments
        )
    }
    
    private func makeNumberToken(_ startLocation: SourceLocation) throws -> Token {
        let startPos = position
        var sawDot = false
        var isFloat = false
        
        // Handle sign
        if ch == "-" || ch == "+" {
            readChar()
        }
        
        while ch.isNumber || ch == "." || ch.lowercased() == "e" {
            if ch == "." {
                if sawDot {
                    throw LexerError.invalidNumber(
                        String(input[startPos..<position]),
                        location: startLocation
                    )
                }
                sawDot = true
                isFloat = true
            } else if ch.lowercased() == "e" {
                isFloat = true
                readChar()
                if ch == "+" || ch == "-" {
                    readChar()
                }
                if !peekChar().isNumber {
                    throw LexerError.invalidNumber(
                        String(input[startPos..<position]),
                        location: startLocation
                    )
                }
            }
            readChar()
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
    
    private func makeStringToken(_ startLocation: SourceLocation) throws -> Token {
        let quote = ch
        readChar()  // consume opening quote
        
        let startPos = position
        var value = ""
        
        while ch != quote && ch != "\0" {
            if ch == "\\" {
                readChar()
                try value.append(parseEscapeSequence())
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
        
        return Token(
            type: .stringLiteral,
            literal: value,
            location: startLocation,
            length: input.distance(from: startPos, to: position),
            leadingComments: pendingComments
        )
    }
    
    private func parseEscapeSequence() throws -> Character {
        let escapeLocation = SourceLocation(line: line, column: column)
        
        switch ch {
        case "\"": return "\""
        case "\\": return "\\"
        case "/": return "/"
        case "b": return "\u{8}"
        case "f": return "\u{12}"
        case "n": return "\n"
        case "r": return "\r"
        case "t": return "\t"
        case "u":
            // Unicode escape sequence
            var hexString = ""
            for _ in 0..<4 {
                readChar()
                if ch.isHexDigit {
                    hexString.append(ch)
                } else {
                    throw LexerError.invalidEscapeSequence("\\u" + hexString, location: escapeLocation)
                }
            }
            guard let unicode = UInt32(hexString, radix: 16),
                  let scalar = UnicodeScalar(unicode) else {
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
