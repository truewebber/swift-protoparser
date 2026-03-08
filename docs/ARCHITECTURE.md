# SwiftProtoParser — Architecture

## 1. Goal

Native Swift library for parsing Protocol Buffers `.proto` files into
`Google_Protobuf_FileDescriptorSet` descriptors without `protoc`.

## 2. Architecture Principles

- **Strict layer hierarchy**: dependencies flow downward only; no lower layer references a
  higher one.
- **Separation of concerns**: each module has a single clearly defined responsibility.
- **Testability**: every module is independently unit-testable; public API is injectable via
  the `Result` type.
- **Minimal public surface**: two static methods expose the full capability of the library.

## 3. Layer Diagram

```
┌──────────────────────────────────────────────────────┐
│  Layer 6 — Public API                                │
│  SwiftProtoParser  (parseFile / parseDirectory)      │
└────────────────────┬─────────────────────────────────┘
                     │ depends on all lower layers
┌────────────────────▼─────────────────────────────────┐
│  Layer 5 — Performance                               │
│  PerformanceCache · IncrementalParser                │
│  PerformanceBenchmark                                │
└──────────┬──────────────┬────────────────────────────┘
           │              │
┌──────────▼──┐  ┌────────▼──────────────────────────┐
│  Layer 4    │  │  Layer 3 — DescriptorBuilder       │
│  Dependency │  │  DescriptorBuilder                 │
│  Resolver   │  │  MessageDescriptorBuilder          │
│             │  │  FieldDescriptorBuilder            │
│             │  │  EnumDescriptorBuilder             │
│             │  │  ServiceDescriptorBuilder          │
│             │  │  UnresolvedTypeValidator           │
│             │  │  EnumTypePostProcessor             │
└──────────┬──┘  └────────────────────────────────────┘
           │                         ▲
┌──────────▼──────────────────────────────────────────┐
│  Layer 2 — Parser                                   │
│  ProtoParsingPipeline  (Lexer→Parser utility)       │
│  Parser · ParserState · ParserError                 │
│  AST: ProtoAST · MessageNode · FieldNode            │
│       ServiceNode · EnumNode · ExtendNode           │
│       OptionNode · FieldType · FieldLabel           │
└──────────┬──────────────────────────────────────────┘
           │
┌──────────▼──────────────────────────────────────────┐
│  Layer 1 — Lexer                                    │
│  Lexer · Token · KeywordRecognizer · LexerError     │
└──────────┬──────────────────────────────────────────┘
           │
┌──────────▼──────────────────────────────────────────┐
│  Layer 0 — Core                                     │
│  ProtoParseError · ProtoVersion                     │
└─────────────────────────────────────────────────────┘
```

## 4. Module Descriptions

### Layer 0 — Core

**Files**: `Core/ProtoParseError.swift`, `Core/ProtoVersion.swift`

**Responsibility**: Common types with zero dependencies.

- `ProtoParseError` — public enum; the only error type visible to library consumers.
- `ProtoVersion` — `proto3` sentinel (proto2 is not supported).

### Layer 1 — Lexer

**Files**: `Lexer/Lexer.swift`, `Lexer/Token.swift`, `Lexer/KeywordRecognizer.swift`,
`Lexer/LexerError.swift`

**Responsibility**: Convert raw `.proto` text into a flat list of typed tokens.

- `Lexer` — main tokenizer; produces `[Token]` or `ProtoParseError` on failure.
- `Token` — discriminated union covering all proto3 terminal symbols.
- `KeywordRecognizer` — maps identifier strings to `Keyword` enum cases.

### Layer 2 — Parser

**Files**: `Parser/Parser.swift`, `Parser/ParserState.swift`, `Parser/ParserError.swift`,
`Parser/EnumFieldTypeResolver.swift`, `Parser/ProtoParsingPipeline.swift`,
`Parser/AST/*.swift`

**Responsibility**: Transform a token stream into a typed Abstract Syntax Tree.

- `ProtoParsingPipeline` — internal utility that executes the full Lexer → Parser pipeline
  from either a `String` or a file path. Used by the public API, `IncrementalParser`, and
  `PerformanceBenchmark` — the single canonical parsing entry point within the module.
- `Parser` — recursive-descent parser; produces `ProtoAST` or `ParserErrors`.
- `ParserState` — mutable state and error-recovery helpers.
- `EnumFieldTypeResolver` — post-parse pass that reclassifies `.message` field types to
  `.enumType` where appropriate (scope-aware).
- AST nodes: `ProtoAST`, `MessageNode`, `FieldNode`, `ServiceNode`, `EnumNode`,
  `ExtendNode`, `OptionNode`, `FieldType`, `FieldLabel`.

### Layer 3 — DescriptorBuilder

**Files**: `DescriptorBuilder/DescriptorBuilder.swift`,
`DescriptorBuilder/MessageDescriptorBuilder.swift`,
`DescriptorBuilder/FieldDescriptorBuilder.swift`,
`DescriptorBuilder/EnumDescriptorBuilder.swift`,
`DescriptorBuilder/ServiceDescriptorBuilder.swift`,
`DescriptorBuilder/DescriptorError.swift`,
`DescriptorBuilder/UnresolvedTypeValidator.swift`,
`DescriptorBuilder/EnumTypePostProcessor.swift`

**Responsibility**: Convert `ProtoAST` into SwiftProtobuf descriptor types and validate
cross-file type references.

- `DescriptorBuilder.buildFileDescriptor(from:fileName:)` — top-level entry point; delegates
  to specialized builders.
- Generates synthetic entry messages for `map<K, V>` fields (protoc-compatible).
- Produces fully qualified type names (`.package.Type`) for all message/enum references.
- `UnresolvedTypeValidator` — post-assembly pass applied to the full `FileDescriptorSet`;
  validates every `typeName` against the global type registry and applies protobuf C++ scoping
  rules (innermost message scope → package hierarchy → root) to resolve unqualified references.
  Returns `.semanticError` for types that cannot be resolved — matching `protoc` behaviour.
- `EnumTypePostProcessor` — second post-assembly pass; corrects `type` from `.message` to
  `.enum` for fields whose `typeName` resolves to an enum defined in another file.

### Layer 4 — DependencyResolver

**Files**: `DependencyResolver/DependencyResolver.swift`,
`DependencyResolver/ImportResolver.swift`,
`DependencyResolver/FileSystemScanner.swift`,
`DependencyResolver/ResolvedProtoFile.swift`,
`DependencyResolver/ResolverError.swift`

**Responsibility**: Resolve `import` statements and produce a topologically-ordered list of
`ResolvedProtoFile` objects (file path + raw content).

- Handles relative paths, configurable import search directories.
- Detects circular dependencies.
- `resolveDependencies(for:)` — resolves a single entry file and all its transitive imports.
- `resolveDirectory(_:recursive:)` — resolves all `.proto` files in a directory.

### Layer 5 — Performance

**Files**: `Performance/PerformanceCache.swift`,
`Performance/IncrementalParser.swift`,
`Performance/PerformanceBenchmark.swift`

**Responsibility**: Caching, incremental re-parsing, and benchmarking. All three components
are **internal**; they are not part of the public API.

Dependencies within the module:

```
PerformanceCache      → Layer 2 (AST types)
IncrementalParser     → Layer 2 ProtoParsingPipeline, Layer 4, PerformanceCache
PerformanceBenchmark  → Layer 2 ProtoParsingPipeline, Layer 3, Layer 4, PerformanceCache
```

**No component in Layer 5 calls `SwiftProtoParser` (Layer 6).** Parsing is performed
directly via `ProtoParsingPipeline` and `DependencyResolver`.

- `PerformanceCache` — content-hash-based LRU cache for `ProtoAST` objects; thread-safe.
- `IncrementalParser` — detects changed files, re-parses only affected files and their
  dependents.
- `PerformanceBenchmark` — statistical measurement of parsing throughput and latency.

### Layer 6 — Public API

**Files**: `Public/SwiftProtoParser.swift`

**Responsibility**: Expose a minimal, stable, version-safe public interface.

```swift
public struct SwiftProtoParser {
    public static func parseFile(
        _ filePath: String,
        importPaths: [String] = []
    ) -> Result<Google_Protobuf_FileDescriptorSet, ProtoParseError>

    public static func parseDirectory(
        _ directoryPath: String,
        recursive: Bool = false,
        importPaths: [String] = []
    ) -> Result<Google_Protobuf_FileDescriptorSet, ProtoParseError>
}
```

The facade delegates to `DependencyResolver` (Layer 4), `ProtoParsingPipeline` (Layer 2),
`DescriptorBuilder` (Layer 3), `UnresolvedTypeValidator` (Layer 3), and
`EnumTypePostProcessor` (Layer 3). It contains no parsing or validation logic of its own.

## 5. Data Flow

```
User calls parseFile("api.proto", importPaths: ["./protos"])
  │
  ▼ Layer 4
DependencyResolver.resolveDependencies(for: "api.proto")
  → reads file system, resolves all imports recursively
  → returns [ResolvedProtoFile] in topological order
  │
  ▼ Layer 2 (per file)
ProtoParsingPipeline.parse(content:fileName:)
  → Lexer → [Token]
  → Parser → ProtoAST
  │
  ▼ Layer 3 (per file)
DescriptorBuilder.buildFileDescriptor(from:fileName:)
  → ProtoAST → Google_Protobuf_FileDescriptorProto
  │
  ▼ Layer 6 — assembly
SwiftProtoParser.buildDescriptorSet(from: [ResolvedProtoFile])
  → assembles Google_Protobuf_FileDescriptorSet
  │
  ▼ Layer 3 — post-processing pass 1
UnresolvedTypeValidator.validate(_:)
  → validates all typeName values against the global type registry
  → applies C++ scoping rules for unresolved references
  → returns .failure(.semanticError) if any type cannot be resolved
  │
  ▼ Layer 3 — post-processing pass 2
EnumTypePostProcessor.process(_:)
  → corrects field type from .message → .enum for cross-file enum references
  │
  ▼
Result<Google_Protobuf_FileDescriptorSet, ProtoParseError>
```

## 6. Error Model

`ProtoParseError` (public) is the single error type visible to consumers. Internal errors
(`LexerError`, `ParserError`, `DescriptorError`, `ResolverError`) are wrapped before crossing
layer boundaries.

```swift
public enum ProtoParseError: Error {
    case fileNotFound(String)
    case ioError(underlying: Error)
    case dependencyResolutionError(message: String, importPath: String)
    case circularDependency([String])
    case lexicalError(message: String, file: String, line: Int, column: Int)
    case syntaxError(message: String, file: String, line: Int, column: Int)
    case semanticError(message: String, context: String)
    case descriptorError(String)
    case performanceLimitExceeded(message: String, limit: String)
    case internalError(message: String)
}
```

## 7. Extend Support

Proto3 `extend` statements for custom options are fully supported:

**Supported targets**: `google.protobuf.FileOptions`, `MessageOptions`, `FieldOptions`,
`ServiceOptions`, `MethodOptions`, `EnumOptions`, `EnumValueOptions`.

The `ExtendNode` AST node is parsed by `Parser`, validated to only extend
`google.protobuf.*` types in proto3, and the extension fields are included in the generated
descriptor.

## 8. Map Field Implementation

`map<K, V>` fields are syntactic sugar for a repeated nested message. The library generates
synthetic entry messages matching `protoc` output exactly:

```
// Input (proto syntax)
message Request {
  map<string, string> metadata = 1;
}

// Output (descriptor equivalent)
message Request {
  message MetadataEntry {
    option map_entry = true;
    string key = 1;
    string value = 2;
  }
  repeated MetadataEntry metadata = 1;
}
```

`MessageDescriptorBuilder` handles this transformation automatically.

## 9. Technology Stack

- **Swift 5.10+**
- **swift-protobuf 1.29.0+** — for `Google_Protobuf_*` descriptor types
- **Swift Package Manager** — dependency management
- **XCTest** — testing
- **swift-format** — code style enforcement

## 10. Testing Strategy

- **Unit tests per module** — each layer tested in isolation with mocks/stubs where needed.
- **Integration tests** — full pipeline from `.proto` string to `FileDescriptorSet`.
- **Error path tests** — explicit coverage of every `ProtoParseError` case.
- **Target**: ≥ 92% region coverage, 95% line coverage.
