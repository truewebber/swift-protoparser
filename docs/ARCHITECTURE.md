# Swift ProtoParser - Architecture Document

## 1. Architecture Overview

### Goal
Native Swift library for parsing Protocol Buffers (.proto) files into ProtoDescriptors without external dependencies on protoc.

### Architecture Principles
- **Modularity**: Clear separation of responsibilities between components
- **Readability**: Priority of code understanding over micro-optimizations  
- **Reusability**: Maximum use of swift-protobuf components
- **Stability**: Minimization of breaking changes in public API
- **Testability**: Test-oriented architecture

## 2. Overall Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ .proto Files│───▶│ Dependency  │───▶│    Lexer    │───▶│   Parser    │───▶│ Descriptor  │
│   + Deps    │    │  Resolver   │    │   Module    │    │   Module    │    │   Builder   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                          │                   │                   │                   │
                          ▼                   ▼                   ▼                   ▼
                   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
                   │  Resolved   │    │   Tokens    │    │     AST     │    │ Proto       │
                   │   Files     │    │             │    │   Nodes     │    │ Descriptors │
                   └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

### Data Flow
1. **Input**: .proto file + dependency folders
2. **DependencyResolver**: Import resolution → [ResolvedProtoFile]
3. **Lexer**: Tokenization of each file → [Token]
4. **Parser**: AST construction → [ProtoAST]  
5. **Builder**: Descriptor creation with dependencies → ProtoDescriptor
6. **Output**: Ready swift-protobuf descriptors

## 3. Modular Structure

### 3.1 Main Modules

```
SwiftProtoParser/
├── Core/                     # Basic types and utilities
│   ├── ProtoParseError.swift
│   ├── ProtoVersion.swift
│   └── Extensions/
├── DependencyResolver/       # Import resolution
│   ├── DependencyResolver.swift
│   ├── ImportResolver.swift
│   ├── FileSystemScanner.swift
│   ├── ResolvedProtoFile.swift
│   └── ResolverError.swift
├── Lexer/                    # Tokenization
│   ├── Token.swift
│   ├── Lexer.swift
│   ├── KeywordRecognizer.swift
│   └── LexerError.swift
├── Parser/                   # AST construction  
│   ├── AST/
│   │   ├── ProtoAST.swift
│   │   ├── MessageNode.swift
│   │   ├── FieldNode.swift
│   │   ├── ServiceNode.swift
│   │   ├── ExtendNode.swift
│   │   └── OptionNode.swift
│   ├── Parser.swift
│   ├── ParserState.swift
│   └── ParserError.swift
├── DescriptorBuilder/        # Conversion to Descriptors
│   ├── DescriptorBuilder.swift
│   ├── MessageDescriptorBuilder.swift
│   ├── FieldDescriptorBuilder.swift
│   └── BuilderError.swift
└── Public/                   # Public API
    ├── SwiftProtoParser.swift
    └── Extensions/
```

### 3.2 Module Details

#### Core Module
**Responsibility**: Common types, utilities, errors
- `ProtoParseError` - main error enum for public API
- `ProtoVersion` - Proto3 only support
- Extensions for standard types

#### DependencyResolver Module
**Responsibility**: Import and dependency resolution
- `DependencyResolver` - main class for dependency resolution
- `ImportResolver` - handling `import` directives in .proto files
- `FileSystemScanner` - searching .proto files in filesystem
- `ResolvedProtoFile` - resolved file model with metadata
- Circular dependency handling and caching

#### Lexer Module  
**Responsibility**: .proto file tokenization
- `Token` - all token types (keywords, identifiers, literals)
- `Lexer` - main tokenization class
- `KeywordRecognizer` - proto3 keyword recognition (including `extend`)
- Comment, whitespace, string literal handling

#### Parser Module
**Responsibility**: AST construction from tokens
- **AST submodule** - all syntax tree nodes
  - `ExtendNode` - AST node for extend statements (proto3 custom options)
  - `OptionNode` - AST representation of options
- `Parser` - recursive parser with predictive analysis
- `ParserState` - parser state for error recovery
- Proto3 syntax validation
- **Extend Support**: Full support for `extend google.protobuf.*` syntax

#### DescriptorBuilder Module
**Responsibility**: AST to swift-protobuf descriptor conversion
- `DescriptorBuilder` - main builder
- Specialized builders for each descriptor type
- Integration with `Google.Protobuf.*` types
- Semantic validation
- **Extend Processing**: Processing extend statements into descriptors

#### Public Module
**Responsibility**: Public API
- `SwiftProtoParser` - main class with `parseProtoFile` function
- Convenient extensions and utilities

## 3.3 Extend Support Architecture

### 3.3.1 Extend Support Overview
SwiftProtoParser supports full `extend` syntax for proto3 custom options:

```proto
syntax = "proto3";

import "google/protobuf/descriptor.proto";

extend google.protobuf.FileOptions {
  optional string my_file_option = 50001;
}

extend google.protobuf.MessageOptions {
  optional bool is_critical = 50002;
}
```

### 3.3.2 Extend Support Components

#### ExtendNode AST
```swift
public struct ExtendNode {
    public let extendedType: String        // "google.protobuf.FileOptions"
    public let fields: [FieldNode]         // Extension fields
    public let isValidProto3ExtendTarget: Bool  // Proto3 validation
}
```

#### Parser Integration
- **Keyword Recognition**: `extend` recognized as keyword
- **Syntax Parsing**: Full parsing of `extend Type { fields }` syntax
- **Proto3 Validation**: Only `google.protobuf.*` types allowed in proto3
- **Error Handling**: Detailed errors for invalid extend targets

#### DescriptorBuilder Integration
- **Extend Processing**: ExtendNode conversion to appropriate protobuf extensions
- **Custom Options**: Support for all google.protobuf option types (File, Message, Field, Service, Method, Enum, EnumValue)
- **Validation**: Semantic validation of extend targets and field numbers

### 3.3.3 Supported Extend Targets
- `google.protobuf.FileOptions`
- `google.protobuf.MessageOptions`  
- `google.protobuf.FieldOptions`
- `google.protobuf.ServiceOptions`
- `google.protobuf.MethodOptions`
- `google.protobuf.EnumOptions`
- `google.protobuf.EnumValueOptions`

## 4. API Design

### 4.1 Public API

```swift
public struct SwiftProtoParser {
    /// Main .proto file parsing function
    public static func parseProtoFile(_ filePath: String) -> Result<ProtoDescriptor, ProtoParseError>
    
    /// Parse from string (for testing/in-memory)
    public static func parseProtoString(_ content: String) -> Result<ProtoDescriptor, ProtoParseError>
    
    /// Parse with dependency support from folders
    public static func parseProtoFile(
        _ mainFilePath: String,
        importPaths: [String] = [],
        options: ParseOptions = .default
    ) -> Result<ProtoDescriptor, ProtoParseError>
    
    /// Parse directory with .proto files (all files as dependencies)
    public static func parseProtoDirectory(
        _ directoryPath: String,
        mainFile: String? = nil,
        options: ParseOptions = .default
    ) -> Result<[ProtoDescriptor], ProtoParseError>
}

public struct ParseOptions {
    public static let `default` = ParseOptions()
    public let validateSemantics: Bool = true
    public let strictMode: Bool = false
    public let resolveDependencies: Bool = true
    public let allowMissingImports: Bool = false
}
```

### 4.2 Error Handling

```swift
public enum ProtoParseError: Error, LocalizedError {
    case fileNotFound(String)
    case dependencyResolutionError(ResolverError, importPath: String)
    case circularDependency([String])
    case lexicalError(LexerError, file: String, line: Int, column: Int)
    case syntaxError(ParserError, file: String, line: Int, column: Int)  
    case semanticError(BuilderError, context: String)
    case ioError(underlying: Error)
    
    public var errorDescription: String? {
        // Detailed messages with error localization
    }
}
```

### 4.3 Inter-Module Interfaces

```swift
// DependencyResolver → Lexer
internal func resolveDependencies(
    mainFile: String, 
    importPaths: [String]
) -> Result<[ResolvedProtoFile], ResolverError>

// Lexer → Parser
internal func tokenize(_ file: ResolvedProtoFile) -> Result<[Token], LexerError>

// Parser → DescriptorBuilder  
internal func parse(_ tokens: [Token]) -> Result<ProtoAST, ParserError>

// DescriptorBuilder → Public
internal func buildDescriptor(
    mainAST: ProtoAST, 
    dependencies: [ProtoAST]
) -> Result<ProtoDescriptor, BuilderError>
```

## 5. Technology Stack

### 5.1 Core Technologies
- **Swift 5.9+** - minimum version
- **swift-protobuf 1.29.0+** - for ProtoDescriptor types
- **Swift Package Manager** - dependency management

### 5.2 Supported Platforms
- **macOS 12.0+**
- **iOS 15.0+** 
- **Linux** (all Swift-supported distributions)

### 5.3 Development Tools
- **swift-format** - code formatting
- **XCTest** - testing framework
- **swift test** - test execution
- **Makefile** - build automation

## 6. Performance and Optimization

### 6.1 Target Metrics
- **Performance**: Within 20% of protoc
- **Memory Usage**: Profiling with Instruments
- **Throughput**: Benchmark tests on large .proto files

### 6.2 Optimization Strategies
1. **Lazy initialization** of AST nodes
2. **String interning** for repeated identifiers  
3. **Optimized collections** for tokens
4. **Copy-on-Write** semantics for large structures

### 6.3 Profiling
- Benchmark tests in `Tests/BenchmarkTests/`
- Memory profiling with XCTest
- Performance regression detection

## 7. Testing Strategy

### 7.1 Coverage
- **Minimum 95%** code coverage
- **Unit tests** for each module
- **Integration tests** for full pipeline
- **Performance tests** against protoc

### 7.2 Test Structure
```
Tests/
├── SwiftProtoParserTests/
│   ├── DependencyResolverTests/
│   ├── LexerTests/
│   ├── ParserTests/ 
│   ├── DescriptorBuilderTests/
│   └── IntegrationTests/
├── BenchmarkTests/
└── TestResources/
    ├── SingleProtoFiles/
    └── DependencyTestCases/
        ├── SimpleImports/
        ├── CircularDeps/
        └── MissingDeps/
```

### 7.3 Test Data
- **Simple .proto files** for unit tests
- **Complex real-world files** for integration tests
- **Edge cases** for boundary conditions
- **Error cases** for error handling testing

## 8. Development Principles

### 8.1 Codebase
- **Explicit types** preferred over implicit
- **Small functions** with single responsibility
- **Immutable structures** where possible
- **Protocol-oriented design** for extensibility

### 8.2 Error Handling
- **Fail-fast** approach for critical errors
- **Detailed messages** with file position
- **Error recovery** for continued parsing after errors
- **Structured logging** for diagnostics

### 8.3 Documentation
- **DocC comments** for all public APIs
- **Usage examples** in documentation
- **Architecture Decision Records** for important decisions
- **Contributing guide** for contributors

## 9. Dependency Management

### 9.1 Import Types
```swift
// Standard Google imports
import "google/protobuf/timestamp.proto";
import "google/protobuf/duration.proto";

// Custom imports  
import "user/profile.proto";
import "common/types.proto";
```

### 9.2 Search Strategies
1. **Relative paths**: from current .proto file
2. **Import paths**: from specified directories  
3. **Standard locations**: well-known types from Google
4. **Caching**: reuse of already resolved files

### 9.3 Conflict Resolution
- **Duplicate imports**: ignoring repeated imports
- **Version conflicts**: error with detailed description
- **Circular dependencies**: detection and error
- **Missing imports**: optional error or warning

### 9.4 API Usage Examples

```swift
// Simple case - single file
let result = SwiftProtoParser.parseProtoFile("user.proto")

// With dependencies in folders
let result = SwiftProtoParser.parseProtoFile(
    "main.proto",
    importPaths: ["./protos", "./vendor/protos"]
)

// Parse entire directory
let results = SwiftProtoParser.parseProtoDirectory(
    "./protos",
    mainFile: "api.proto"
)
```

## 10. swift-protobuf Integration

### 10.1 Used Types
```swift
import SwiftProtobuf

// Main descriptors
- Google.Protobuf.FileDescriptorProto
- Google.Protobuf.DescriptorProto  
- Google.Protobuf.FieldDescriptorProto
- Google.Protobuf.ServiceDescriptorProto
```

### 10.2 Integration Strategy
- **Maximum reuse** of existing types
- **AST → Protobuf types conversion** in DescriptorBuilder
- **Validation** of compliance with official specification
- **Backward compatibility** with existing projects

## 11. Deployment and Releases

### 11.1 Versioning
- **Semantic Versioning 2.0** (major.minor.patch)
- **API stability** guarantees for major versions
- **Deprecation warnings** one major version ahead

### 11.2 Distribution
- **GitHub Releases** with changelog
- **Swift Package Index** registration
- **Swift Package Manager** primary installation method
- **MIT License** for maximum compatibility
