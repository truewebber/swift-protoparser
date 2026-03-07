# SwiftProtoParser

A Swift library for parsing Protocol Buffers `.proto` files into `FileDescriptorSet` descriptors without `protoc`.

[![Platform](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ftruewebber%2Fswift-protoparser%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/truewebber/swift-protoparser)
[![Swift Package Index](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ftruewebber%2Fswift-protoparser%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/truewebber/swift-protoparser)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=flat)](LICENSE)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/truewebber/swift-protoparser)

## Overview

SwiftProtoParser enables native parsing of Protocol Buffers schema files directly in Swift
without requiring the `protoc` compiler. It returns standard `Google_Protobuf_FileDescriptorSet`
objects compatible with [SwiftProtobuf](https://github.com/apple/swift-protobuf), making it a
drop-in source of descriptor data for code generators, schema analyzers, and dynamic proto
processing tools.

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/truewebber/swift-protoparser.git", from: "0.7.0")
]
```

## Public API

The entire public interface consists of two methods on `SwiftProtoParser`:

```swift
// Parse a single .proto file and all its transitive imports.
static func parseFile(
    _ filePath: String,
    importPaths: [String] = []
) -> Result<Google_Protobuf_FileDescriptorSet, ProtoParseError>

// Parse all .proto files in a directory and their transitive imports.
static func parseDirectory(
    _ directoryPath: String,
    recursive: Bool = false,
    importPaths: [String] = []
) -> Result<Google_Protobuf_FileDescriptorSet, ProtoParseError>
```

Both methods return a `Google_Protobuf_FileDescriptorSet` containing deduplicated descriptors
in topological order (all dependencies first, then the parsed files).

## Basic Usage

### Parse a single file

```swift
import SwiftProtoParser
import SwiftProtobuf

let result = SwiftProtoParser.parseFile("user.proto")
switch result {
case .success(let descriptorSet):
    for file in descriptorSet.file {
        print("File:     \(file.name)")
        print("Package:  \(file.package)")
        print("Messages: \(file.messageType.map { $0.name })")
        print("Services: \(file.service.map { $0.name })")
    }
case .failure(let error):
    print("Parse error: \(error.localizedDescription)")
}
```

### Parse with import resolution

```swift
let result = SwiftProtoParser.parseFile(
    "/path/to/api.proto",
    importPaths: [
        "/path/to/proto/files",
        "/path/to/google/protobuf"
    ]
)
```

### Parse a directory

```swift
// All .proto files in the directory, with recursive subdirectory scanning.
let result = SwiftProtoParser.parseDirectory(
    "/path/to/proto/files",
    recursive: true,
    importPaths: ["/path/to/external/imports"]
)

switch result {
case .success(let descriptorSet):
    print("Parsed \(descriptorSet.file.count) files")
    for file in descriptorSet.file {
        print("  \(file.name): \(file.messageType.count) messages")
    }
case .failure(let error):
    print("Error: \(error)")
}
```

### Inspect the descriptor set

```swift
let result = SwiftProtoParser.parseFile("service.proto")
guard case .success(let set) = result else { return }

// All files are in topological order: dependencies first, requested file last.
let mainFile = set.file.last!

// Messages
for message in mainFile.messageType {
    print("message \(message.name):")
    for field in message.field {
        print("  \(field.name) = \(field.number)")
    }
}

// Services
for service in mainFile.service {
    for method in service.method {
        print("rpc \(method.name)(\(method.inputType)) returns (\(method.outputType))")
    }
}
```

## Error Handling

```swift
switch SwiftProtoParser.parseFile("api.proto", importPaths: ["./protos"]) {
case .success(let set):
    // use set.file
case .failure(let error):
    switch error {
    case .fileNotFound(let path):
        print("Missing file: \(path)")
    case .dependencyResolutionError(let message, let importPath):
        print("Import resolution failed at '\(importPath)': \(message)")
    case .syntaxError(let message, let file, let line, let column):
        print("\(file):\(line):\(column): \(message)")
    case .descriptorError(let message):
        print("Descriptor build error: \(message)")
    default:
        print(error.localizedDescription)
    }
}
```

## Supported Proto3 Features

### Core syntax

```protobuf
syntax = "proto3";
package example.v1;

import "google/protobuf/timestamp.proto";

message User {
  string name = 1;
  int32 age = 2;
  repeated string emails = 3;
  map<string, string> metadata = 4;
  google.protobuf.Timestamp created_at = 5;

  message Address {
    string street = 1;
    string city = 2;
  }

  oneof contact {
    string email = 10;
    string phone = 11;
  }
}

enum Status {
  STATUS_UNSPECIFIED = 0;
  STATUS_ACTIVE = 1;
}

service UserService {
  rpc GetUser(GetUserRequest) returns (User);
  rpc StreamUsers(stream GetUserRequest) returns (stream User);
}
```

### Custom options via `extend`

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

## Requirements

- Swift 5.10+
- macOS 12.0+ / iOS 15.0+ / watchOS 8.0+ / tvOS 15.0+
- Linux (Ubuntu 20.04+)

## Dependencies

- [SwiftProtobuf](https://github.com/apple/swift-protobuf) 1.29.0+

## Documentation

- **[Architecture Guide](docs/ARCHITECTURE.md)**: Layer design and module responsibilities
- **[Quick Reference](docs/QUICK_REFERENCE.md)**: API summary and patterns
- **[Performance Guide](docs/PERFORMANCE_GUIDE.md)**: Internal caching and incremental parsing

## Testing

```bash
swift test          # run all tests
make test           # run with coverage report
```

## License

MIT License. See [LICENSE](LICENSE) for details.
