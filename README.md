# SwiftProtoParser

A Swift library for parsing Protocol Buffers `.proto` files into AST and descriptors without `protoc`.

[![Platform](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ftruewebber%2Fswift-protoparser%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/truewebber/swift-protoparser)
[![Swift Package Index](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ftruewebber%2Fswift-protoparser%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/truewebber/swift-protoparser)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=flat)](LICENSE)
[![Coverage](https://img.shields.io/badge/Test%20Coverage-93%25-green.svg?style=flat)](#testing)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/truewebber/swift-protoparser)

## Overview

SwiftProtoParser enables native parsing of Protocol Buffers schema files directly in Swift without requiring the `protoc` compiler. This is useful for building code generation tools, schema analyzers, API documentation generators, and other applications that need to process `.proto` files at runtime.

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/truewebber/swift-protoparser.git", from: "0.6.0")
]
```

## Basic Usage

### Parsing Proto Files

```swift
import SwiftProtoParser

// Parse a single .proto file
let result = SwiftProtoParser.parseFile("user.proto")
switch result {
case .success(let descriptorSet):
    let file = descriptorSet.file.last!
    print("Package: \(file.package)")
    print("Messages: \(file.messageType.map { $0.name })")
    print("Services: \(file.service.map { $0.name })")
case .failure(let error):
    print("Parse error: \(error.localizedDescription)")
}
```

### Working with Imports

```swift
// Parse with import resolution
let result = SwiftProtoParser.parseFile(
    "api.proto",
    importPaths: [
        "/path/to/proto/files",
        "/path/to/google/protobuf"
    ]
)

// Parse entire directory
let result = SwiftProtoParser.parseDirectory(
    "/path/to/proto/files",
    recursive: true,
    importPaths: ["/path/to/imports"]
)
```

### Working with Descriptors

```swift
// parseFile returns a FileDescriptorSet — all files in topological order
let result = SwiftProtoParser.parseFile("user.proto")
switch result {
case .success(let descriptorSet):
    // Iterate over all resolved files (dependencies first, requested file last)
    for file in descriptorSet.file {
        print("File: \(file.name)")
        print("Package: \(file.package)")
        for message in file.messageType {
            print("  message \(message.name): \(message.field.count) fields")
        }
    }
case .failure(let error):
    print("Error: \(error)")
}
```

## Features

- **Complete Proto3 Support**: All standard proto3 syntax and semantics
- **AST Generation**: Parse files into structured Abstract Syntax Tree
- **Descriptor Building**: Generate `Google_Protobuf_FileDescriptorProto` compatible with SwiftProtobuf
- **Map Fields**: Full support for map types with automatic synthetic entry message generation (protoc-compatible)
- **Dependency Resolution**: Handle `import` statements and multi-file dependencies
- **Extend Statements**: Support for proto3 custom options (`extend google.protobuf.*`)
- **Scope-Aware Enum Resolution**: Strict protobuf scoping rules enforcement (matches `protoc` behavior)
- **Qualified Types**: Well-known types and nested message references
- **Performance Caching**: Content-based caching with 85%+ hit rates
- **Incremental Parsing**: Only re-parse changed files in large projects
- **Streaming Support**: Memory-efficient parsing of large files (>50MB)

## Supported Proto3 Features

The library supports the complete proto3 specification including:

### Core Features
```protobuf
syntax = "proto3";
package example.v1;

import "google/protobuf/timestamp.proto";

// Messages with all field types
message User {
  string name = 1;
  int32 age = 2;
  repeated string emails = 3;
  map<string, string> metadata = 4;
  google.protobuf.Timestamp created_at = 5;
  
  // Nested messages
  message Address {
    string street = 1;
    string city = 2;
  }
  
  // Oneof groups
  oneof contact {
    string email = 10;
    string phone = 11;
  }
}

// Enums
enum Status {
  STATUS_UNSPECIFIED = 0;
  STATUS_ACTIVE = 1;
}

// Services with streaming
service UserService {
  rpc GetUser(GetUserRequest) returns (User);
  rpc StreamUsers(stream GetUserRequest) returns (stream User);
}
```

### Custom Options (Extend)
```protobuf
import "google/protobuf/descriptor.proto";

extend google.protobuf.FileOptions {
  string api_version = 50001;
}

extend google.protobuf.MessageOptions {
  bool enable_validation = 50002;
}

option (api_version) = "v1.0";

message ValidatedMessage {
  option (enable_validation) = true;
  string email = 1;
}
```

## Performance Features

### Caching

Content-based AST caching is built into the library. Repeated parsing of the same file content
returns a cached result without re-running the Lexer and Parser, achieving 85%+ hit rates in
typical workflows. Cache management is automatic and requires no configuration.

### Incremental Parsing

An incremental parsing engine tracks file modification timestamps and content hashes across
multiple calls. Only files that have actually changed — and their direct dependents — are
re-parsed. This reduces parsing time by 60–80% for large proto directories with infrequent
changes.

### Benchmarking

An internal benchmarking system measures single-file, string, directory, and descriptor
generation throughput with statistical analysis (mean, median, standard deviation). It is used
for regression detection in the development workflow.

## Requirements

- Swift 5.10+
- macOS 12.0+ / iOS 15.0+ / watchOS 8.0+ / tvOS 15.0+
- Linux (Ubuntu 20.04+)

## Dependencies

- [SwiftProtobuf](https://github.com/apple/swift-protobuf) 1.29.0+ (for descriptor generation)

## Documentation

- **[Architecture Guide](docs/ARCHITECTURE.md)**: Technical implementation details and module design
- **[Performance Guide](docs/PERFORMANCE_GUIDE.md)**: Caching, incremental parsing, and optimization
- **[Quick Reference](docs/QUICK_REFERENCE.md)**: API summary and common patterns

## Use Cases

- Protocol Buffer code generators for Swift
- Schema validation and linting tools
- API documentation generators from `.proto` files
- Proto file analysis and visualization tools
- Dynamic proto file processing without `protoc`
- Build systems requiring schema introspection

## Testing

The library has comprehensive test coverage with 1263 tests covering all functionality:

```bash
# Run all tests
swift test

# Run with coverage
make test
make coverage
```

Test coverage: **92.59%** (lines), **92.23%** (functions), **95.04%** (regions)

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:

- Code style and formatting
- Testing requirements (90%+ coverage for new code)
- Pull request process
- Development workflow

## License

MIT License. See [LICENSE](LICENSE) for details.
