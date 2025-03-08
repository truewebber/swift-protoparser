![Swift Lint](https://github.com/truewebber/swift-protoparser/actions/workflows/lint.yml/badge.svg?branch=master)
![Swift Test](https://github.com/truewebber/swift-protoparser/actions/workflows/test.yml/badge.svg?branch=master)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Swift Version](https://img.shields.io/badge/Swift-5.5+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platforms-macOS%20|%20Linux-blue.svg)](https://swift.org)
[![Code Coverage](https://img.shields.io/badge/Coverage-40.3%25-yellow.svg)](https://github.com/truewebber/swift-protoparser/blob/master/Tools/CodeCoverage/coverage_tracking.md)

<div align="center">
  <h1>SwiftProtoParser</h1>
  <p>A native Swift library for parsing Protocol Buffer (proto3) files into protocol buffer descriptors</p>
</div>

## 📋 Overview

SwiftProtoParser provides a native Swift implementation for parsing .proto files, similar to Google's protoc tool. It parses proto3 files and generates FileDescriptorProto objects that can be used with Swift Protobuf.

### 🌟 Key Features

- **Full proto3 syntax support** - Parse all proto3 language features
- **Services and RPC definitions** - Complete support for service definitions
- **Custom options** - Parse and validate custom options
- **Extensions** - Support for proto3 extensions
- **Detailed error reporting** - Comprehensive error messages with source locations
- **Swift-idiomatic API** - Designed to feel natural in Swift codebases
- **Cross-platform** - Works on macOS and Linux

## 🚀 Installation

### Swift Package Manager

Add SwiftProtoParser to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/truewebber/swift-protoparser.git", from: "1.0.0")
]
```

Then add the dependency to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["SwiftProtoParser"]
)
```

## 📖 Usage

### Basic Usage

```swift
import SwiftProtoParser

// Parse a proto file
let parser = ProtoParser()
do {
    let fileDescriptor = try parser.parse(filePath: "path/to/your.proto")
    
    // Access the parsed data
    print("Package: \(fileDescriptor.package)")
    print("Messages: \(fileDescriptor.messageType.count)")
    print("Services: \(fileDescriptor.service.count)")
} catch {
    print("Error parsing proto file: \(error)")
}
```

### Parsing Multiple Files with Imports

```swift
import SwiftProtoParser

// Create a configuration with import paths
let config = ParserConfiguration(importPaths: ["./protos", "./third_party/protos"])
let parser = ProtoParser(configuration: config)

do {
    // Parse a file with imports
    let fileDescriptor = try parser.parse(filePath: "path/to/main.proto")
    
    // All imports will be resolved automatically
    print("Successfully parsed with \(parser.importedFiles.count) imported files")
} catch {
    print("Error parsing proto files: \(error)")
}
```

## 🏗️ Architecture

SwiftProtoParser is composed of several components:

1. **Lexer**: Tokenizes the proto file input
2. **Parser**: Builds an Abstract Syntax Tree (AST) from tokens
3. **Validator**: Ensures the AST follows proto3 rules
4. **Symbol Resolver**: Resolves type references across files
5. **Descriptor Generator**: Converts the AST to FileDescriptorProto

## 🧪 Testing

SwiftProtoParser has a comprehensive test suite. To run the tests:

```bash
swift test
```

To run tests with code coverage:

```bash
swift test --enable-code-coverage
```

For detailed coverage reports, use the provided scripts:

```bash
./Tools/CodeCoverage/run_coverage.sh
./Tools/CodeCoverage/analyze_coverage.sh
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please ensure your code follows the project's coding style and includes appropriate tests.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📊 Project Status

SwiftProtoParser is under active development. Check the [coverage tracking document](Tools/CodeCoverage/coverage_tracking.md) for current test coverage status.

---

<div align="center">
  <sub>Built with ❤️ by <a href="https://truewebber.com">truewebber</a></sub>
</div>