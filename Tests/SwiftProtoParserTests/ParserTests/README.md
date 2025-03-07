# Parser Tests

This directory contains tests for the Parser component of the SwiftProtoParser.

## Current Coverage

The Parser component currently has good test coverage:
- **Parser.swift**: 
  - Line coverage: 94.39%
  - Function coverage: 76.56%
  - Region coverage: 90.15%

However, the AST nodes have much lower coverage:
- **EnumNode.swift**: 12.98% line coverage
- **ServiceNode.swift**: 11.45% line coverage
- **ExtendNode.swift**: 37.97% line coverage
- **FieldNode.swift**: 34.60% line coverage
- **MessageNode.swift**: 52.66% line coverage
- **FileNode.swift**: 73.91% line coverage
- **Node.swift**: 59.46% line coverage

## Test Plan

Our goal is to improve the test coverage of the AST nodes to at least 80% line coverage. We'll focus on the following areas:

### 1. AST Node Tests

Create dedicated test classes for each AST node type:
- `EnumNodeTests`
- `ServiceNodeTests`
- `ExtendNodeTests`
- `FieldNodeTests`
- `MessageNodeTests`
- `FileNodeTests`
- `NodeTests`

Each test class will verify:
- Node creation and initialization
- Property getters and setters
- Node-specific functionality
- Edge cases and error handling

### 2. Parser Integration Tests

Enhance the existing `ParserTests` to cover:
- Complex parsing scenarios
- Error handling and recovery
- Edge cases (empty files, large files, etc.)
- Performance considerations

### 3. Test Categories

For each AST node type, we'll create tests in these categories:
- **Positive Tests**: Verify correct behavior with valid inputs
- **Negative Tests**: Verify error handling with invalid inputs
- **Corner Case Tests**: Verify behavior with edge cases and boundary conditions

## Implementation Strategy

1. Start with the lowest coverage components (EnumNode, ServiceNode)
2. Create test fixtures and helper methods for common test scenarios
3. Use property-based testing for complex structures
4. Ensure all error paths are tested

## Running the Tests

To run just the Parser tests:

```bash
swift test --filter ParserTests
```

To run the tests with code coverage:

```bash
swift test --enable-code-coverage
xcrun llvm-cov report .build/debug/SwiftProtoParserPackageTests.xctest/Contents/MacOS/SwiftProtoParserPackageTests -instr-profile=.build/debug/codecov/default.profdata -ignore-filename-regex=".build|Tests" -name="Parser"
``` 