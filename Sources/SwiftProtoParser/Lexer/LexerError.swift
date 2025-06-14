import Foundation

// MARK: - LexerError

/// Internal error type for lexical analysis errors.
/// 
/// These errors are used internally by the lexer and are typically converted
/// to `ProtoParseError.lexicalError` for public API consumption.
internal enum LexerError: Error {
    
    // MARK: - Character and Token Errors
    
    /// Invalid character encountered that cannot be part of any valid token
    case invalidCharacter(Character, line: Int, column: Int)
    
    /// String literal was not properly terminated with closing quote
    case unterminatedString(line: Int, column: Int)
    
    /// Invalid escape sequence in string literal
    case invalidEscapeSequence(String, line: Int, column: Int)
    
    // MARK: - Number Parsing Errors
    
    /// Invalid integer literal format
    case invalidIntegerLiteral(String, line: Int, column: Int)
    
    /// Invalid floating point literal format
    case invalidFloatLiteral(String, line: Int, column: Int)
    
    /// Number literal is out of valid range
    case numberOutOfRange(String, line: Int, column: Int)
    
    // MARK: - Comment Errors
    
    /// Multi-line comment was not properly closed
    case unterminatedComment(line: Int, column: Int)
    
    // MARK: - Input Errors
    
    /// Unexpected end of input while parsing
    case unexpectedEndOfInput(line: Int, column: Int)
    
    /// Input contains invalid UTF-8 sequences
    case invalidUTF8(line: Int, column: Int)
}

// MARK: - LexerError + CustomStringConvertible

extension LexerError: CustomStringConvertible {
    
    internal var description: String {
        switch self {
        case .invalidCharacter(let char, let line, let column):
            return "Invalid character '\(char)' at \(line):\(column)"
            
        case .unterminatedString(let line, let column):
            return "Unterminated string literal at \(line):\(column)"
            
        case .invalidEscapeSequence(let sequence, let line, let column):
            return "Invalid escape sequence '\(sequence)' at \(line):\(column)"
            
        case .invalidIntegerLiteral(let value, let line, let column):
            return "Invalid integer literal '\(value)' at \(line):\(column)"
            
        case .invalidFloatLiteral(let value, let line, let column):
            return "Invalid float literal '\(value)' at \(line):\(column)"
            
        case .numberOutOfRange(let value, let line, let column):
            return "Number '\(value)' out of range at \(line):\(column)"
            
        case .unterminatedComment(let line, let column):
            return "Unterminated comment at \(line):\(column)"
            
        case .unexpectedEndOfInput(let line, let column):
            return "Unexpected end of input at \(line):\(column)"
            
        case .invalidUTF8(let line, let column):
            return "Invalid UTF-8 sequence at \(line):\(column)"
        }
    }
}

// MARK: - LexerError + ProtoParseError Conversion

extension LexerError {
    
    /// Converts this lexer error to a public API error with file context
    internal func toProtoParseError(file: String) -> ProtoParseError {
        switch self {
        case .invalidCharacter(let char, let line, let column):
            return .lexicalError(
                message: "Invalid character '\(char)'",
                file: file,
                line: line,
                column: column
            )
            
        case .unterminatedString(let line, let column):
            return .lexicalError(
                message: "Unterminated string literal",
                file: file,
                line: line,
                column: column
            )
            
        case .invalidEscapeSequence(let sequence, let line, let column):
            return .lexicalError(
                message: "Invalid escape sequence '\(sequence)'",
                file: file,
                line: line,
                column: column
            )
            
        case .invalidIntegerLiteral(let value, let line, let column):
            return .lexicalError(
                message: "Invalid integer literal '\(value)'",
                file: file,
                line: line,
                column: column
            )
            
        case .invalidFloatLiteral(let value, let line, let column):
            return .lexicalError(
                message: "Invalid float literal '\(value)'",
                file: file,
                line: line,
                column: column
            )
            
        case .numberOutOfRange(let value, let line, let column):
            return .lexicalError(
                message: "Number '\(value)' out of range",
                file: file,
                line: line,
                column: column
            )
            
        case .unterminatedComment(let line, let column):
            return .lexicalError(
                message: "Unterminated comment",
                file: file,
                line: line,
                column: column
            )
            
        case .unexpectedEndOfInput(let line, let column):
            return .lexicalError(
                message: "Unexpected end of input",
                file: file,
                line: line,
                column: column
            )
            
        case .invalidUTF8(let line, let column):
            return .lexicalError(
                message: "Invalid UTF-8 sequence",
                file: file,
                line: line,
                column: column
            )
        }
    }
}

// MARK: - LexerError + Position Information

extension LexerError {
    
    /// Returns the line number where this error occurred
    internal var line: Int {
        switch self {
        case .invalidCharacter(_, let line, _),
             .unterminatedString(let line, _),
             .invalidEscapeSequence(_, let line, _),
             .invalidIntegerLiteral(_, let line, _),
             .invalidFloatLiteral(_, let line, _),
             .numberOutOfRange(_, let line, _),
             .unterminatedComment(let line, _),
             .unexpectedEndOfInput(let line, _),
             .invalidUTF8(let line, _):
            return line
        }
    }
    
    /// Returns the column number where this error occurred
    internal var column: Int {
        switch self {
        case .invalidCharacter(_, _, let column),
             .unterminatedString(_, let column),
             .invalidEscapeSequence(_, _, let column),
             .invalidIntegerLiteral(_, _, let column),
             .invalidFloatLiteral(_, _, let column),
             .numberOutOfRange(_, _, let column),
             .unterminatedComment(_, let column),
             .unexpectedEndOfInput(_, let column),
             .invalidUTF8(_, let column):
            return column
        }
    }
    
    /// Returns the position as a tuple (line, column)
    internal var position: (line: Int, column: Int) {
        return (line: line, column: column)
    }
}

// MARK: - LexerError + Convenience Constructors

extension LexerError {
    
    /// Creates an invalid character error
    internal static func invalidCharacter(_ char: Character, at line: Int, column: Int) -> LexerError {
        return .invalidCharacter(char, line: line, column: column)
    }
    
    /// Creates an unterminated string error
    internal static func unterminatedString(at line: Int, column: Int) -> LexerError {
        return .unterminatedString(line: line, column: column)
    }
    
    /// Creates an invalid escape sequence error
    internal static func invalidEscapeSequence(_ sequence: String, at line: Int, column: Int) -> LexerError {
        return .invalidEscapeSequence(sequence, line: line, column: column)
    }
    
    /// Creates an invalid integer literal error
    internal static func invalidIntegerLiteral(_ value: String, at line: Int, column: Int) -> LexerError {
        return .invalidIntegerLiteral(value, line: line, column: column)
    }
    
    /// Creates an invalid float literal error
    internal static func invalidFloatLiteral(_ value: String, at line: Int, column: Int) -> LexerError {
        return .invalidFloatLiteral(value, line: line, column: column)
    }
    
    /// Creates a number out of range error
    internal static func numberOutOfRange(_ value: String, at line: Int, column: Int) -> LexerError {
        return .numberOutOfRange(value, line: line, column: column)
    }
    
    /// Creates an unterminated comment error
    internal static func unterminatedComment(at line: Int, column: Int) -> LexerError {
        return .unterminatedComment(line: line, column: column)
    }
    
    /// Creates an unexpected end of input error
    internal static func unexpectedEndOfInput(at line: Int, column: Int) -> LexerError {
        return .unexpectedEndOfInput(line: line, column: column)
    }
    
    /// Creates an invalid UTF-8 error
    internal static func invalidUTF8(at line: Int, column: Int) -> LexerError {
        return .invalidUTF8(line: line, column: column)
    }
}
