# Core Module - Implementation Plan

## 📋 FILES TO IMPLEMENT

### ProtoParseError.swift
**Purpose**: Main error type for public API
```swift
public enum ProtoParseError: Error, LocalizedError {
    case fileNotFound(String)
    case dependencyResolutionError(ResolverError, importPath: String)
    case circularDependency([String])
    case lexicalError(LexerError, file: String, line: Int, column: Int)
    case syntaxError(ParserError, file: String, line: Int, column: Int)  
    case semanticError(BuilderError, context: String)
    case ioError(underlying: Error)
}
```

### ProtoVersion.swift  
**Purpose**: Version handling (Proto3 only)
```swift
public enum ProtoVersion {
    case proto3
    // Proto2 explicitly not supported
}
```

### Extensions/
**Purpose**: Utility extensions for standard types
- String extensions for proto parsing
- Collection extensions
- Error handling utilities

## 🎯 IMPLEMENTATION ORDER
1. ProtoVersion.swift (simplest)
2. ProtoParseError.swift (needed by all modules)
3. Extensions/ (as needed)

## ✅ DONE
- [ ] ProtoVersion.swift
- [ ] ProtoParseError.swift  
- [ ] Extensions/

## 🔗 DEPENDENCIES
- None (this is the base module)
