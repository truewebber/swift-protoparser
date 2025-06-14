# Lexer Module - Implementation Plan

## 📋 FILES TO IMPLEMENT

### Token.swift
**Purpose**: All token types for proto3 syntax
```swift
public enum Token {
    case keyword(ProtoKeyword)
    case identifier(String)
    case stringLiteral(String)
    case integerLiteral(Int64)
    case floatLiteral(Double)
    case boolLiteral(Bool)
    case symbol(Character) // {, }, [, ], =, ;, etc.
    case comment(String)
    case whitespace
    case newline
    case eof
}

public enum ProtoKeyword: String, CaseIterable {
    case syntax, package, import, option, message, enum, service, rpc
    case repeated, optional, required // proto2 compatibility
    case returns, stream
}
```

### Lexer.swift
**Purpose**: Main tokenizer class
```swift
public final class Lexer {
    func tokenize(_ input: String) -> Result<[Token], LexerError>
    // Character-by-character parsing
    // Handle proto3 syntax rules
    // Preserve position info for errors
}
```

### KeywordRecognizer.swift
**Purpose**: Recognize proto3 keywords vs identifiers
```swift
struct KeywordRecognizer {
    static func recognize(_ identifier: String) -> Token
}
```

### LexerError.swift
**Purpose**: Lexer-specific errors
```swift
public enum LexerError: Error {
    case invalidCharacter(Character, line: Int, column: Int)
    case unterminatedString(line: Int, column: Int)
    case invalidEscapeSequence(String, line: Int, column: Int)
}
```

## 🎯 IMPLEMENTATION ORDER
1. Token.swift (defines the interface)
2. LexerError.swift (error handling)
3. KeywordRecognizer.swift (simple utility)
4. Lexer.swift (main implementation)

## 🧪 KEY TEST CASES
- Basic proto3 syntax tokenization
- String literals with escapes
- Numbers (int64, double)
- Comments (single-line //, multi-line /* */)
- Keywords vs identifiers
- Error cases (unterminated strings, invalid chars)

## ✅ DONE
- [ ] Token.swift
- [ ] LexerError.swift
- [ ] KeywordRecognizer.swift
- [ ] Lexer.swift

## 🔗 DEPENDENCIES
- Core module (for error integration)
