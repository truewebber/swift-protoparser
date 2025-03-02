# SwiftProtoParser Architecture

This document outlines the architecture of the SwiftProtoParser library, a Swift implementation for parsing Protocol Buffer (proto3) files into protocol buffer descriptors.

## Overview

SwiftProtoParser follows a pipeline architecture with distinct stages for processing proto files:

1. **Lexical Analysis**: Converts raw text into tokens
2. **Parsing**: Builds an Abstract Syntax Tree (AST) from tokens
3. **Validation**: Validates the AST against proto3 rules
4. **Descriptor Generation**: Converts the AST to Protocol Buffer descriptors

## Component Structure

The library is organized into the following main components:

```
SwiftProtoParser/
├── Public/           # Public API
├── Core/             # Core implementation
│   ├── Lexer/        # Lexical analysis
│   ├── Parser/       # Parsing
│   │   └── AST/      # Abstract Syntax Tree
│   ├── Validator/    # Validation
│   └── Generator/    # Descriptor generation
└── Models/           # Shared models
```

## Key Components

### Public API

The public API provides a clean, Swift-idiomatic interface for users of the library. It includes:

- `ProtoParser`: Main entry point for parsing proto files
- `Configuration`: Configuration options for the parser
- Error types and handling

### Lexer

The lexer is responsible for converting raw proto file text into a stream of tokens. It includes:

- `Token`: Represents a lexical token (identifier, keyword, operator, etc.)
- `TokenType`: Enumeration of token types
- `Lexer`: Performs lexical analysis

### Parser

The parser builds an Abstract Syntax Tree (AST) from the token stream. It includes:

- AST node types for proto3 elements (file, message, enum, field, etc.)
- `Parser`: Performs parsing and builds the AST

### Validator

The validator ensures that the AST adheres to proto3 rules. It includes:

- `SymbolTable`: Tracks defined types for reference resolution
- Validation components for different aspects (fields, messages, enums, etc.)
- Error reporting with detailed location information

### Generator

The generator converts the validated AST into Protocol Buffer descriptors. It includes:

- `DescriptorGenerator`: Generates FileDescriptorProto objects
- `SourceInfoGenerator`: Generates source code information

### Models

Shared models used across components, including:

- `FileProvider`: Interface for reading proto files
- `ImportResolver`: Resolves imports between proto files
- `Context`: Maintains parsing context

## Data Flow

1. User provides a proto file path or content to `ProtoParser`
2. `Lexer` converts the content into tokens
3. `Parser` builds an AST from the tokens
4. `ImportResolver` resolves any imports
5. `Validator` validates the AST
6. `DescriptorGenerator` generates Protocol Buffer descriptors
7. `ProtoParser` returns the descriptors to the user

## Error Handling

The library uses Swift's error handling mechanism with specific error types for each component:

- `LexerError`: Errors during lexical analysis
- `ParserError`: Errors during parsing
- `ValidationError`: Errors during validation
- `ImportError`: Errors during import resolution
- `DescriptorGeneratorError`: Errors during descriptor generation

These are wrapped in a public-facing `ProtoParserError` type for a consistent API.

## Configuration

The library is configurable through the `Configuration` struct, which includes options for:

- Import paths
- Source info generation
- Validation strictness
- Service/option/extension support

A builder pattern is provided for creating configurations.

## Testing Strategy

The library is tested at multiple levels:

- Unit tests for each component
- Integration tests with real proto files
- Comparison tests against protoc output

## Performance Considerations

The library is designed with performance in mind:

- Efficient memory usage
- Optimized parsing algorithms
- Configurable validation strictness

## Future Extensions

The architecture is designed to be extensible for future features:

- Support for proto2 syntax
- Code generation capabilities
- Integration with other Swift frameworks 