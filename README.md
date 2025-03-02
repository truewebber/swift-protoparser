![Swift Lint](https://github.com/truewebber/swift-protoparser/actions/workflows/lint.yml/badge.svg?branch=master)
![Swift Test](https://github.com/truewebber/swift-protoparser/actions/workflows/test.yml/badge.svg?branch=master)

# SwiftProtoParser

A Swift library for parsing Protocol Buffer (proto3) files into protocol buffer descriptors.

## Overview

SwiftProtoParser provides a native Swift implementation for parsing .proto files, similar to Google's protoc tool. It parses proto3 files and generates FileDescriptorProto objects that can be used with Swift Protobuf.

Key features:
- Full proto3 syntax support
- Services and RPC definitions
- Custom options
- Extensions
- Detailed error reporting
- Swift-idiomatic API

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/truewebber/swift-protoparser.git", from: "0.1.0")
]
```

## Usage

### Basic Usage

```swift
import SwiftProtoParser

// Parse a proto file
let parser = ProtoParser()
do {
    let descriptor = try parser.parseFile("path/to/file.proto")
    // Use the descriptor
} catch {
    print("Error parsing proto file: \(error)")
}
```

### Configuration

```swift
import SwiftProtoParser

// Create a custom configuration
let config = Configuration.builder()
    .addImportPath("path/to/imports")
    .withSourceInfo(true)
    .withServices(true)
    .build()

// Create a parser with the configuration
let parser = ProtoParser(configuration: config)
```

## Requirements

- Swift 5.9+
- macOS 13.0+ or iOS 16.0+

## Documentation

For detailed documentation, see the [API Documentation](https://github.com/truewebber/swift-protoparser/wiki).

## Architecture

The library follows a pipeline architecture with distinct stages for processing proto files:

1. **Lexical Analysis**: Converts raw text into tokens
2. **Parsing**: Builds an Abstract Syntax Tree (AST) from tokens
3. **Validation**: Validates the AST against proto3 rules
4. **Descriptor Generation**: Converts the AST to Protocol Buffer descriptors

For more details, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Status

This project is currently under active development. API may change before the 1.0 release.