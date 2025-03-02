# Acceptance Criteria for SwiftProtoParser Components

This document defines the acceptance criteria for each component of the SwiftProtoParser library.

## Lexer

The lexer must:
- Correctly tokenize all valid proto3 syntax elements
- Handle whitespace and comments correctly
- Recognize all proto3 keywords
- Recognize all proto3 literals (string, number, boolean)
- Recognize all proto3 operators and punctuation
- Track line and column information for each token
- Provide meaningful error messages for invalid input
- Include line and column information in error messages

## Parser

The parser must:
- Parse all basic proto3 elements (syntax, package, import, message, enum, field)
- Parse nested messages
- Parse map fields
- Parse reserved fields and field numbers
- Parse oneof fields
- Parse options
- Parse comments (both line and block)
- Build a correct Abstract Syntax Tree (AST)
- Provide meaningful error messages for invalid input
- Include line and column information in error messages

## Service and RPC Support

The service and RPC support must:
- Parse service definitions
- Parse RPC method definitions
- Parse streaming options (client streaming, server streaming, bidirectional streaming)
- Validate service and method names
- Validate input and output types
- Provide meaningful error messages for invalid input

## Custom Options Support

The custom options support must:
- Parse option definitions
- Support file-level options
- Support message-level options
- Support field-level options
- Support enum-level options
- Support enum value-level options
- Support service-level options
- Support method-level options
- Resolve option types
- Validate option values
- Provide meaningful error messages for invalid input

## Extensions Support

The extensions support must:
- Parse extension definitions
- Support using extensions in options
- Validate extension field numbers
- Validate extension field types
- Provide meaningful error messages for invalid input

## Symbol Resolution and Validation

The symbol resolution and validation must:
- Track defined types in a symbol table
- Manage scope for nested types
- Resolve type references
- Validate field numbers are within valid range (1-536,870,911, excluding 19,000-19,999)
- Validate field names follow proto3 naming conventions
- Validate enum values start at 0 for the first value
- Validate message and enum names don't conflict
- Validate package names follow proto3 conventions
- Validate type references exist
- Provide detailed error messages with line/column information

## Import Resolution

The import resolution must:
- Resolve import statements
- Support relative imports
- Support absolute imports
- Handle circular imports
- Support configurable import paths
- Provide meaningful error messages for missing imports

## Descriptor Generation

The descriptor generation must:
- Generate valid FileDescriptorProto objects
- Generate valid DescriptorProto objects for messages
- Generate valid EnumDescriptorProto objects for enums
- Generate valid FieldDescriptorProto objects for fields
- Generate valid ServiceDescriptorProto objects for services
- Generate valid MethodDescriptorProto objects for methods
- Generate valid UninterpretedOption objects for options
- Match protoc output for the same input files

## Source Info Generation

The source info generation must:
- Track source locations during parsing
- Generate valid SourceCodeInfo objects
- Include locations for all elements (file, message, enum, field, service, method, option)
- Match protoc source info output for the same input files

## Configuration

The configuration must:
- Support configuring import paths
- Support enabling/disabling source info generation
- Support configuring validation strictness
- Support enabling/disabling services
- Support enabling/disabling custom options
- Support enabling/disabling extensions
- Provide a builder pattern for creating configurations
- Have comprehensive documentation for all options

## Public API

The public API must:
- Follow Swift API design guidelines
- Provide both synchronous and asynchronous parsing methods
- Use Swift error handling (throws)
- Have comprehensive documentation
- Be easy to use
- Support parsing from file paths and string content

## Error Handling

The error handling must:
- Provide specific error types for different kinds of errors
- Include line and column information in error messages
- Provide context in error messages
- Wrap internal errors into public-facing error types
- Be helpful for debugging

## Performance

The performance must:
- Parse a 1000-line proto file in under 1 second on a modern device
- Use memory efficiently
- Have no memory leaks
- Support parsing multiple files efficiently 