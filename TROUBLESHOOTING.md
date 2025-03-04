# Troubleshooting Guide for SwiftProtoParser

This guide provides solutions for common issues you might encounter when using the SwiftProtoParser library.

## Table of Contents

1. [Installation Issues](#installation-issues)
2. [Parsing Errors](#parsing-errors)
3. [Import Resolution Problems](#import-resolution-problems)
4. [Validation Errors](#validation-errors)
5. [Performance Issues](#performance-issues)
6. [Integration with Swift Protobuf](#integration-with-swift-protobuf)

## Installation Issues

### Package Resolution Fails

**Problem**: Swift Package Manager fails to resolve the SwiftProtoParser package.

**Solution**:
- Ensure you're using the correct URL in your Package.swift file.
- Check that you're using a compatible Swift version (5.9+).
- Try clearing the package cache with `swift package reset`.

### Dependency Conflicts

**Problem**: Conflicts with other packages that depend on SwiftProtobuf.

**Solution**:
- Ensure all packages use compatible versions of SwiftProtobuf.
- Specify exact versions in your Package.swift file to avoid conflicts.

## Parsing Errors

### File Not Found

**Problem**: `ProtoParserError.fileNotFound` error when parsing a proto file.

**Solution**:
- Check that the file path is correct and accessible.
- If using relative paths, ensure they're relative to the current working directory.
- Add import paths using the configuration builder:
  ```swift
  let config = Configuration.builder()
      .addImportPath("path/to/protos")
      .build()
  ```

### Syntax Errors

**Problem**: Lexer or parser errors indicating syntax issues in the proto file.

**Solution**:
- Check the error message for the line and column number of the error.
- Verify that your proto file follows the proto3 syntax rules.
- Common issues include:
  - Missing semicolons after field definitions
  - Incorrect field numbers
  - Invalid identifiers
  - Mismatched braces or parentheses

### Unsupported Features

**Problem**: Errors about unsupported proto features.

**Solution**:
- Ensure you're using proto3 syntax (not proto2).
- Check if you're using features that require specific configuration options:
  ```swift
  let config = Configuration.builder()
      .withServices(true)  // Enable service support
      .withExtensions(true)  // Enable extensions support
      .build()
  ```

## Import Resolution Problems

### Imports Not Found

**Problem**: `ImportError.importNotFound` when parsing files with imports.

**Solution**:
- Add all necessary import paths to the configuration:
  ```swift
  let config = Configuration.builder()
      .addImportPath("path/to/main/protos")
      .addImportPath("path/to/imported/protos")
      .build()
  ```
- Ensure imported files exist and have the correct path.

### Circular Imports

**Problem**: `ImportError.circularImport` when files import each other.

**Solution**:
- Restructure your proto files to avoid circular dependencies.
- Use shared message definitions in a separate file that both files import.

## Validation Errors

### Type Not Found

**Problem**: `ValidationError.typeNotFound` when referencing undefined types.

**Solution**:
- Ensure all referenced types are defined in the current file or imported files.
- Check for typos in type names.
- Verify that import paths are correctly configured.

### Field Number Conflicts

**Problem**: `ValidationError.fieldNumberConflict` in message definitions.

**Solution**:
- Ensure each field in a message has a unique number.
- Check for conflicts with reserved field numbers.

### Naming Conflicts

**Problem**: `ValidationError.namingConflict` for duplicate type names.

**Solution**:
- Ensure all message, enum, and service names are unique within their scope.
- Use different names or nested types to resolve conflicts.

## Performance Issues

### Slow Parsing

**Problem**: Parsing large proto files is slow.

**Solution**:
- Disable features you don't need:
  ```swift
  let config = Configuration.builder()
      .withSourceInfo(false)  // Disable source info generation
      .build()
  ```
- Split large proto files into smaller files with imports.
- Use the asynchronous parsing methods for better UI responsiveness.

### High Memory Usage

**Problem**: High memory consumption when parsing many files.

**Solution**:
- Parse files individually rather than all at once.
- Use autoreleasepool when parsing multiple files:
  ```swift
  for file in files {
      autoreleasepool {
          try parser.parseFile(file)
      }
  }
  ```

## Integration with Swift Protobuf

### Descriptor Compatibility

**Problem**: Descriptors generated by SwiftProtoParser aren't compatible with Swift Protobuf.

**Solution**:
- Ensure you're using compatible versions of SwiftProtoParser and Swift Protobuf.
- Use the descriptor directly with Swift Protobuf's descriptor-based APIs.

### Code Generation

**Problem**: Need to generate Swift code from parsed proto files.

**Solution**:
- SwiftProtoParser doesn't generate code directly. Use the official protoc compiler with the Swift plugin for code generation.
- You can use SwiftProtoParser to analyze and validate proto files before code generation.

## Still Having Issues?

If you're still experiencing problems after trying these solutions:

1. Check the [GitHub Issues](https://github.com/truewebber/swift-protoparser/issues) to see if your problem has been reported.
2. Create a new issue with:
   - A clear description of the problem
   - Steps to reproduce
   - Expected vs. actual behavior
   - Sample code and proto files (if possible)
   - Error messages and stack traces 