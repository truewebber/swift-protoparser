# QUICK REFERENCE - Swift ProtoParser

## 🏗️ ARCHITECTURE OVERVIEW
```
.proto files → DependencyResolver → Lexer → Parser → DescriptorBuilder → ProtoDescriptors
```

## 📦 MODULES & RESPONSIBILITIES

### 1. Core
- **What**: Common types, errors, utilities
- **Key files**: `ProtoParseError.swift`, `ProtoVersion.swift`
- **Dependencies**: None

### 2. DependencyResolver  
- **What**: Resolve .proto imports and dependencies
- **Key files**: `DependencyResolver.swift`, `ImportResolver.swift`
- **Dependencies**: Core

### 3. Lexer
- **What**: Tokenize .proto files
- **Key files**: `Token.swift`, `Lexer.swift`
- **Dependencies**: Core

### 4. Parser
- **What**: Build AST from tokens
- **Key files**: `Parser.swift`, AST nodes
- **Dependencies**: Core, Lexer

### 5. DescriptorBuilder
- **What**: Convert AST to swift-protobuf descriptors
- **Key files**: `DescriptorBuilder.swift`, specialized builders
- **Dependencies**: Core, Parser, SwiftProtobuf

### 6. Public
- **What**: Public API
- **Key files**: `SwiftProtoParser.swift`
- **Dependencies**: All modules

## 🎯 KEY CONSTRAINTS
- **Swift 5.9+** minimum
- **Proto3 only** (no Proto2)
- **95% test coverage** required
- **Performance**: within 20% of protoc
- **Zero external dependencies** except swift-protobuf

## 🔧 MAIN PUBLIC API
```swift
// Простой случай - один файл
SwiftProtoParser.parseProtoFile(_ filePath: String) -> Result<ProtoDescriptor, ProtoParseError>

// С зависимостями в папках
SwiftProtoParser.parseProtoFile(
    _ filePath: String,
    importPaths: [String]
) -> Result<ProtoDescriptor, ProtoParseError>

// Парсинг всей папки
SwiftProtoParser.parseProtoDirectory(
    _ directoryPath: String,
    mainFile: String
) -> Result<[ProtoDescriptor], ProtoParseError>
```

## 🧪 TESTING STRATEGY
- Unit tests per module
- Integration tests for full pipeline
- Performance benchmarks
- Test resources in `Tests/TestResources/`
