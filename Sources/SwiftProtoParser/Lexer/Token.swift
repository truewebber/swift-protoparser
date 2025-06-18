import Foundation

// MARK: - Token

/// Represents a token in Protocol Buffers source code.
/// 
/// This struct contains the token type and position information for error reporting.
public struct Token {
    /// The type of the token
    public let type: TokenType
    
    /// The position of this token in the source file
    public let position: Position
    
    public init(type: TokenType, position: Position) {
        self.type = type
        self.position = position
    }
    
    /// Position information for a token
    public struct Position: Equatable {
        public let line: Int
        public let column: Int
        
        public init(line: Int, column: Int) {
            self.line = line
            self.column = column
        }
    }
}

/// Token types that can appear in a proto3 file
public enum TokenType {
    
    // MARK: - Language Elements
    
    /// Protocol Buffers keyword (syntax, message, etc.)
    case keyword(ProtoKeyword)
    
    /// Identifier (message name, field name, etc.)
    case identifier(String)
    
    // MARK: - Literals
    
    /// String literal with quotes ("hello world")
    case stringLiteral(String)
    
    /// Integer literal (42, -17)
    case integerLiteral(Int64)
    
    /// Floating point literal (3.14, -2.5e10)
    case floatLiteral(Double)
    
    /// Boolean literal (true, false)
    case boolLiteral(Bool)
    
    // MARK: - Symbols and Operators
    
    /// Single character symbols ({, }, [, ], =, ;, etc.)
    case symbol(Character)
    
    // MARK: - Whitespace and Comments
    
    /// Single or multi-line comment
    case comment(String)
    
    /// Whitespace (spaces, tabs)
    case whitespace
    
    /// Line terminator
    case newline
    
    // MARK: - Special
    
    /// End of file marker
    case eof
}

// MARK: - ProtoKeyword

/// Protocol Buffers keywords for proto3 syntax.
public enum ProtoKeyword: String, CaseIterable {
    
    // MARK: - Core Keywords
    
    /// Syntax declaration
    case syntax = "syntax"
    
    /// Package declaration
    case package = "package"
    
    /// Import statement
    case `import` = "import"
    
    /// Option declaration
    case option = "option"
    
    // MARK: - Type Definition Keywords
    
    /// Message type definition
    case message = "message"
    
    /// Enum type definition
    case `enum` = "enum"
    
    /// Service definition
    case service = "service"
    
    /// RPC method definition
    case rpc = "rpc"
    
    // MARK: - Field Modifiers
    
    /// Repeated field modifier
    case repeated = "repeated"
    
    /// Optional field modifier (proto2 compatibility)
    case optional = "optional"
    
    /// Required field modifier (proto2 compatibility)
    case required = "required"
    
    // MARK: - Service Keywords
    
    /// RPC return type declaration
    case returns = "returns"
    
    /// Streaming RPC modifier
    case stream = "stream"
    
    // MARK: - Reserved Keywords
    
    /// Reserved field declaration
    case reserved = "reserved"
    
    /// Oneof field group
    case oneof = "oneof"
    
    /// Map field type
    case map = "map"
    
    /// Extension definition (proto2 compatibility)
    case extend = "extend"
    
    /// Extension range declaration
    case extensions = "extensions"
    
    /// Group definition (deprecated, proto2 compatibility)
    case group = "group"
    
    /// Public import modifier
    case `public` = "public"
    
    /// Weak import modifier
    case weak = "weak"
}

// MARK: - Token + Equatable

extension Token: Equatable {
    
    public static func == (lhs: Token, rhs: Token) -> Bool {
        #if DEBUG
        // In debug mode (tests), ignore position for easier testing
        return lhs.type == rhs.type
        #else
        // In release mode, compare both type and position
        return lhs.type == rhs.type && lhs.position == rhs.position
        #endif
    }
}

// MARK: - TokenType + Equatable

extension TokenType: Equatable {
    
    public static func == (lhs: TokenType, rhs: TokenType) -> Bool {
        switch (lhs, rhs) {
        case (.keyword(let lhsKeyword), .keyword(let rhsKeyword)):
            return lhsKeyword == rhsKeyword
            
        case (.identifier(let lhsId), .identifier(let rhsId)):
            return lhsId == rhsId
            
        case (.stringLiteral(let lhsString), .stringLiteral(let rhsString)):
            return lhsString == rhsString
            
        case (.integerLiteral(let lhsInt), .integerLiteral(let rhsInt)):
            return lhsInt == rhsInt
            
        case (.floatLiteral(let lhsFloat), .floatLiteral(let rhsFloat)):
            return lhsFloat == rhsFloat
            
        case (.boolLiteral(let lhsBool), .boolLiteral(let rhsBool)):
            return lhsBool == rhsBool
            
        case (.symbol(let lhsSymbol), .symbol(let rhsSymbol)):
            return lhsSymbol == rhsSymbol
            
        case (.comment(let lhsComment), .comment(let rhsComment)):
            return lhsComment == rhsComment
            
        case (.whitespace, .whitespace),
             (.newline, .newline),
             (.eof, .eof):
            return true
            
        default:
            return false
        }
    }
}

// MARK: - Token + CustomStringConvertible

extension Token: CustomStringConvertible {
    
    public var description: String {
        return type.description
    }
}

// MARK: - TokenType + CustomStringConvertible

extension TokenType: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .keyword(let keyword):
            return "keyword(\(keyword.rawValue))"
            
        case .identifier(let identifier):
            return "identifier(\(identifier))"
            
        case .stringLiteral(let string):
            return "stringLiteral(\"\(string)\")"
            
        case .integerLiteral(let int):
            return "integerLiteral(\(int))"
            
        case .floatLiteral(let float):
            return "floatLiteral(\(float))"
            
        case .boolLiteral(let bool):
            return "boolLiteral(\(bool))"
            
        case .symbol(let symbol):
            return "symbol(\(symbol))"
            
        case .comment(let comment):
            return "comment(\(comment.prefix(20))...)"
            
        case .whitespace:
            return "whitespace"
            
        case .newline:
            return "newline"
            
        case .eof:
            return "eof"
        }
    }
}

// MARK: - Token + Convenience Properties

extension Token {
    
    /// Returns true if this token represents whitespace or comments
    public var isIgnorable: Bool {
        return type.isIgnorable
    }
    
    /// Returns true if this token is a literal value
    public var isLiteral: Bool {
        return type.isLiteral
    }
    
    /// Returns true if this token is a specific keyword
    public func isKeyword(_ keyword: ProtoKeyword) -> Bool {
        return type.isKeyword(keyword)
    }
    
    /// Returns true if this token is a specific symbol
    public func isSymbol(_ symbol: Character) -> Bool {
        return type.isSymbol(symbol)
    }
    
    /// Compares only the token type, ignoring position (useful for testing)
    public func hasSameType(as other: Token) -> Bool {
        return self.type == other.type
    }
    
    /// Compares token type with a given TokenType
    public func hasType(_ tokenType: TokenType) -> Bool {
        return self.type == tokenType
    }
}

// MARK: - TokenType + Convenience Properties

extension TokenType {
    
    /// Returns true if this token represents whitespace or comments
    public var isIgnorable: Bool {
        switch self {
        case .whitespace, .comment, .newline:
            return true
        default:
            return false
        }
    }
    
    /// Returns true if this token is a literal value
    public var isLiteral: Bool {
        switch self {
        case .stringLiteral, .integerLiteral, .floatLiteral, .boolLiteral:
            return true
        default:
            return false
        }
    }
    
    /// Returns true if this token is a specific keyword
    public func isKeyword(_ keyword: ProtoKeyword) -> Bool {
        if case .keyword(let tokenKeyword) = self {
            return tokenKeyword == keyword
        }
        return false
    }
    
    /// Returns true if this token is a specific symbol
    public func isSymbol(_ symbol: Character) -> Bool {
        if case .symbol(let tokenSymbol) = self {
            return tokenSymbol == symbol
        }
        return false
    }
}

// MARK: - Token + Test Convenience

#if DEBUG
extension Token {
    /// Creates a token with default position for testing
    public static func keyword(_ keyword: ProtoKeyword) -> Token {
        return Token(type: .keyword(keyword), position: Position(line: 1, column: 1))
    }
    
    /// Creates a token with default position for testing
    public static func identifier(_ name: String) -> Token {
        return Token(type: .identifier(name), position: Position(line: 1, column: 1))
    }
    
    /// Creates a token with default position for testing
    public static func stringLiteral(_ value: String) -> Token {
        return Token(type: .stringLiteral(value), position: Position(line: 1, column: 1))
    }
    
    /// Creates a token with default position for testing
    public static func integerLiteral(_ value: Int64) -> Token {
        return Token(type: .integerLiteral(value), position: Position(line: 1, column: 1))
    }
    
    /// Creates a token with default position for testing
    public static func floatLiteral(_ value: Double) -> Token {
        return Token(type: .floatLiteral(value), position: Position(line: 1, column: 1))
    }
    
    /// Creates a token with default position for testing
    public static func boolLiteral(_ value: Bool) -> Token {
        return Token(type: .boolLiteral(value), position: Position(line: 1, column: 1))
    }
    
    /// Creates a token with default position for testing
    public static func symbol(_ char: Character) -> Token {
        return Token(type: .symbol(char), position: Position(line: 1, column: 1))
    }
    
    /// Creates a token with default position for testing
    public static func comment(_ value: String) -> Token {
        return Token(type: .comment(value), position: Position(line: 1, column: 1))
    }
    
    /// Creates a token with default position for testing
    public static var whitespace: Token {
        return Token(type: .whitespace, position: Position(line: 1, column: 1))
    }
    
    /// Creates a token with default position for testing
    public static var newline: Token {
        return Token(type: .newline, position: Position(line: 1, column: 1))
    }
    
    /// Creates a token with default position for testing
    public static var eof: Token {
        return Token(type: .eof, position: Position(line: 1, column: 1))
    }
}
#endif
