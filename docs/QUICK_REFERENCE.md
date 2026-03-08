# Quick Reference — SwiftProtoParser

## Architecture Overview

```
.proto files → DependencyResolver → ProtoParsingPipeline (Lexer + Parser) → DescriptorBuilder → FileDescriptorSet
```

## Layers & Dependencies

| Layer | Module | Depends on |
|---|---|---|
| 0 | Core (`ProtoParseError`, `ProtoVersion`) | — |
| 1 | Lexer (`Lexer`, `Token`, `LexerError`) | Core |
| 2 | Parser (`Parser`, `ProtoAST`, `ProtoParsingPipeline`) | Lexer, Core |
| 3 | DescriptorBuilder | Parser, Core |
| 4 | DependencyResolver | Lexer, Parser, Core |
| 5 | Performance (`PerformanceCache`, `IncrementalParser`, `PerformanceBenchmark`) | Layers 2–4 |
| 6 | Public API (`SwiftProtoParser`) | All layers |

**Rule**: no lower layer may reference a higher layer.

## Public API

```swift
import SwiftProtoParser

// Parse a single file + all its transitive imports
SwiftProtoParser.parseFile(
    _ filePath: String,
    importPaths: [String] = []
) -> Result<Google_Protobuf_FileDescriptorSet, ProtoParseError>

// Parse all .proto files in a directory + their imports
SwiftProtoParser.parseDirectory(
    _ directoryPath: String,
    recursive: Bool = false,
    importPaths: [String] = []
) -> Result<Google_Protobuf_FileDescriptorSet, ProtoParseError>
```

Both return `Google_Protobuf_FileDescriptorSet` with files in topological order
(dependencies first, requested file(s) last).

## Error Cases

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

## Common Patterns

### Single file

```swift
switch SwiftProtoParser.parseFile("api.proto", importPaths: ["./protos"]) {
case .success(let set):
    let main = set.file.last!
    print(main.messageType.map { $0.name })
case .failure(let error):
    print(error.localizedDescription)
}
```

### Directory scan

```swift
switch SwiftProtoParser.parseDirectory("./protos", recursive: true) {
case .success(let set):
    for file in set.file { print(file.name) }
case .failure(let error):
    print(error)
}
```

### Inspect a service

```swift
if case .success(let set) = SwiftProtoParser.parseFile("service.proto") {
    for svc in set.file.last!.service {
        for rpc in svc.method {
            print("\(rpc.name): \(rpc.inputType) → \(rpc.outputType)")
        }
    }
}
```

## Key Constraints

- **Swift 5.10+** minimum
- **Proto3 only** (no Proto2)
- **No external dependencies** except SwiftProtobuf
- **Thread-safe**: `parseFile` / `parseDirectory` are pure static functions

## Supported Features

- Complete Proto3 syntax
- `import` resolution with transitive dependencies
- Circular dependency detection
- `map<K, V>` fields with synthetic entry messages (protoc-compatible)
- `oneof` groups
- Nested messages and enums
- Services with unary / client-streaming / server-streaming / bidi-streaming RPCs
- Custom options via `extend google.protobuf.*`
- Qualified types (`google.protobuf.Timestamp`, etc.)
- `reserved` field numbers and names
- Semantic type validation: unresolvable type references return `.semanticError` (protoc-compatible)
- Protobuf C++ scoping rules for unqualified type names (inner message → package hierarchy → root)
