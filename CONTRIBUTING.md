# Contributing to SwiftProtoParser

Thank you for your interest in contributing to SwiftProtoParser! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

Please be respectful and considerate of others when contributing to this project.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/swift-protoparser.git`
3. Create a new branch for your feature or bugfix: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Run tests to ensure everything works: `swift test`
6. Commit your changes: `git commit -m "Add your feature"`
7. Push to your fork: `git push origin feature/your-feature-name`
8. Create a pull request

## Development Workflow

### Setting Up the Development Environment

1. Make sure you have Xcode 15.0+ installed
2. Install SwiftLint for code style checking
3. Run `swift package resolve` to fetch dependencies

### Building the Project

```bash
swift build
```

### Running Tests

```bash
swift test
```

## Coding Guidelines

### Swift Style Guide

- Follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use Swift's native error handling with `throws`
- Prefer value types over reference types when appropriate
- Use clear, descriptive names for variables, functions, and types

### Documentation

- Document all public APIs using Swift's documentation comments
- Include examples in documentation where helpful
- Keep documentation up-to-date with code changes

### Testing

- Write unit tests for all new functionality
- Ensure existing tests pass with your changes
- Aim for high test coverage

## Pull Request Process

1. Update the README.md or documentation with details of changes if appropriate
2. Update the CHANGELOG.md with details of changes
3. The PR should work on the main branch
4. Include tests for new functionality
5. Ensure the CI pipeline passes

## Reporting Bugs

When reporting bugs, please include:

- A clear, descriptive title
- Steps to reproduce the issue
- Expected behavior
- Actual behavior
- Any relevant logs or error messages
- Your environment (OS, Swift version, etc.)

## Feature Requests

Feature requests are welcome. Please provide:

- A clear, descriptive title
- A detailed description of the proposed feature
- Any relevant examples or use cases
- If possible, a rough implementation idea

## Project Structure

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

## License

By contributing to SwiftProtoParser, you agree that your contributions will be licensed under the project's MIT License. 