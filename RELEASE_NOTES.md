# Release Notes

## Version 0.3.0 (Extensions Support)

We're excited to announce the release of SwiftProtoParser 0.3.0, which adds full support for extensions in proto3 files.

### New Features

- **Extensions Support**: Parse and validate extension definitions that allow extending existing message types with new fields.
- **Field Validation**: Validate extension field numbers and types according to proto3 rules.
- **Descriptor Generation**: Generate proper descriptor representations for extensions compatible with Swift Protobuf.
- **Integration**: Seamless integration with Google Protobuf extensions.

### Improvements

- **Enhanced Validation**: Improved validation to correctly handle extended types.
- **Comprehensive Test Coverage**: Added tests for all extension functionality.
- **Updated Documentation**: Added examples and documentation for using extensions.

### Example Usage

```swift
// Define extensions in your proto file
syntax = "proto3";

message MyMessage {
  int32 id = 1;
}

extend MyMessage {
  string extra_info = 2;
  bool is_valid = 3;
}

// In another file, you can extend imported messages
import "my_message.proto";

extend MyMessage {
  repeated string tags = 4;
}
```

### Requirements

- Swift 5.9+
- macOS 13.0+ or iOS 16.0+

## Version 0.2.0 (Custom Options Support)

We're excited to announce the release of SwiftProtoParser 0.2.0, which adds full support for custom options in proto3 files.

### New Features

- **Custom Options Support**: Parse and validate custom options at all levels (file, message, field, enum, enum value, service, method).
- **Nested Fields Support**: Handle nested fields in custom options using dot notation.
- **Type Resolution**: Resolve option types from the symbol table, including those from imported files.
- **Value Validation**: Validate option values against their defined types, including repeated and map options.
- **Descriptor Generation**: Generate UninterpretedOption objects for custom options in descriptors.

### Improvements

- **Enhanced Symbol Table**: Track option extensions for type resolution.
- **Improved Validation**: Validate option values against their defined types.
- **Comprehensive Test Coverage**: Added tests for all acceptance criteria from previous sprints.
- **Updated Documentation**: Added examples and documentation for custom options.

### Example Usage

```swift
// Define custom options in your proto file
import "google/protobuf/descriptor.proto";

extend google.protobuf.FileOptions {
  string my_file_option = 50000;
}

extend google.protobuf.MessageOptions {
  int32 my_message_option = 50001;
}

// Use custom options
option (my_file_option) = "Hello, world!";

message MyMessage {
  option (my_message_option) = 42;
  // ...
}
```

### Requirements

- Swift 5.9+
- macOS 13.0+ or iOS 16.0+

## Version 0.1.0 (Initial Release)

We're excited to announce the initial release of SwiftProtoParser, a Swift library for parsing Protocol Buffer (proto3) files into protocol buffer descriptors.

### Overview

SwiftProtoParser provides a native Swift implementation for parsing .proto files, similar to Google's protoc tool. It parses proto3 files and generates FileDescriptorProto objects that can be used with Swift Protobuf.

### Features

- **Full proto3 Syntax Support**: Parse all proto3 language elements including messages, enums, services, and options.
- **Comprehensive Validation**: Validate proto files against proto3 rules with detailed error messages.
- **Import Resolution**: Handle imports between proto files with configurable import paths.
- **Descriptor Generation**: Generate Protocol Buffer descriptors compatible with Swift Protobuf.
- **Source Info Generation**: Include source code information in generated descriptors.
- **Swift-idiomatic API**: Clean, easy-to-use API with Swift error handling.
- **Configurable**: Customize parsing behavior with a flexible configuration system.
- **Detailed Error Reporting**: Get precise error messages with line and column information.

### Installation

#### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/truewebber/swift-protoparser.git", from: "0.1.0")
]
```

### Basic Usage

```swift
import SwiftProtoParser

// Create a parser with default configuration
let parser = ProtoParser()

do {
    // Parse a proto file
    let descriptor = try parser.parseFile("path/to/file.proto")
    
    // Use the descriptor with Swift Protobuf
    // ...
} catch {
    print("Error parsing proto file: \(error)")
}
```

### Custom Configuration

```swift
import SwiftProtoParser

// Create a configuration using the builder pattern
let config = Configuration.builder()
    .addImportPath("path/to/imports")
    .withSourceInfo(true)
    .withServices(true)
    .build()

// Create a parser with the custom configuration
let parser = ProtoParser(configuration: config)
```

### Requirements

- Swift 5.9+
- macOS 13.0+ or iOS 16.0+

### Documentation

For detailed documentation, see:
- [README.md](README.md): Overview and basic usage
- [ARCHITECTURE.md](ARCHITECTURE.md): Library architecture and design
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md): Solutions for common issues
- [Examples](Examples/): Usage examples

### Known Limitations

- Only proto3 syntax is supported (not proto2)
- Custom options are not yet supported (planned for the next release)
- Some advanced proto3 features may have limited support

### Future Plans

- Custom options support (coming in next release)
- Performance optimizations
- Support for more advanced proto3 features
- Additional validation rules
- Integration with code generation tools

### Acknowledgments

- The Swift Protobuf team for their excellent Swift Protobuf library
- The Protocol Buffers team at Google for the protoc tool and specification

### Feedback and Contributions

We welcome feedback and contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to the project. 