# Parser Module - Implementation Plan

## 📋 FILES TO IMPLEMENT

### AST/ Directory
**Purpose**: All AST node types
```swift
// ProtoAST.swift - Root AST node
public struct ProtoAST {
    let syntax: ProtoVersion
    let package: String?
    let imports: [String]
    let options: [OptionNode]
    let messages: [MessageNode]
    let enums: [EnumNode]
    let services: [ServiceNode]
}

// MessageNode.swift
public struct MessageNode {
    let name: String
    let fields: [FieldNode]
    let nestedMessages: [MessageNode]
    let nestedEnums: [EnumNode]
    let options: [OptionNode]
}

// FieldNode.swift
public struct FieldNode {
    let name: String
    let type: FieldType
    let number: Int32
    let label: FieldLabel? // repeated, optional
    let options: [OptionNode]
}

// ServiceNode.swift, EnumNode.swift, OptionNode.swift, etc.
```

### Parser.swift
**Purpose**: Recursive descent parser
```swift
public final class Parser {
    func parse(_ tokens: [Token]) -> Result<ProtoAST, ParserError>
    
    // Private parsing methods
    private func parseMessage() -> MessageNode?
    private func parseField() -> FieldNode?
    private func parseService() -> ServiceNode?
    // etc.
}
```

### ParserState.swift
**Purpose**: Parser state management and error recovery
```swift
struct ParserState {
    var currentIndex: Int
    var tokens: [Token]
    var errors: [ParserError]
    
    // State management methods
}
```

### ParserError.swift
**Purpose**: Parser-specific errors
```swift
public enum ParserError: Error {
    case unexpectedToken(Token, expected: String, line: Int, column: Int)
    case missingRequiredElement(String, line: Int, column: Int)
    case duplicateElement(String, line: Int, column: Int)
    case invalidFieldNumber(Int32, line: Int, column: Int)
}
```

## 🎯 IMPLEMENTATION ORDER
1. AST nodes (ProtoAST, MessageNode, FieldNode, etc.)
2. ParserError.swift
3. ParserState.swift  
4. Parser.swift (main logic)

## 🧪 KEY TEST CASES
- Simple message parsing
- Nested messages and enums
- Field types and options
- Services and RPCs
- Error recovery and reporting
- Proto3 syntax validation

## ✅ DONE
- [ ] AST/ directory with all nodes
- [ ] ParserError.swift
- [ ] ParserState.swift
- [ ] Parser.swift

## 🔗 DEPENDENCIES
- Core module (errors)
- Lexer module (tokens)
