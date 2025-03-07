# Lexer Tests

This directory contains tests for the lexical analyzer component of the SwiftProtoParser.

## Test Coverage

The `LexerTests` class provides comprehensive test coverage for the `Lexer` component:

- **Overall Coverage**: 
  - Line coverage: 80.62%
  - Function coverage: 78.57%
  - Region coverage: 76.74%

### Test Categories

The tests are organized into the following categories:

1. **Basic Tokenization**:
   - Keywords (`testKeywords`)
   - Identifiers (`testIdentifiers`)
   - String literals (`testStringLiterals`)
   - Number literals (`testNumberLiterals`)
   - Operators and punctuation (`testOperatorsAndPunctuation`)

2. **Whitespace and Comments**:
   - Handling of whitespace (`testWhitespaceAndComments`)
   - Files with only whitespace and comments (`testWhitespaceAndCommentsOnly`)

3. **Source Location Tracking**:
   - Line and column tracking (`testLineAndColumnTracking`)

4. **Error Handling**:
   - Unterminated string literals (`testUnterminatedStringLiteral`)
   - Invalid escape sequences (`testInvalidEscapeSequence`)
   - Invalid number formats (`testInvalidNumberFormat`)

5. **Edge Cases**:
   - Empty input (`testEmptyInput`)
   - Extremely long identifiers (`testExtremelyLongIdentifier`)
   - Adjacent punctuation (`testAdjacentPunctuation`)

## Areas for Improvement

While the test coverage is good, there are a few areas that could be improved:

1. Testing of error message formatting (`LexerError.description`)
2. Coverage of the `peekPrevious()` method
3. Testing of Unicode escape sequences in strings
4. More comprehensive testing of error conditions

## Running the Tests

To run just the Lexer tests:

```bash
swift test --filter LexerTests
```

To run the tests with code coverage:

```bash
swift test --enable-code-coverage
xcrun llvm-cov report .build/debug/SwiftProtoParserPackageTests.xctest/Contents/MacOS/SwiftProtoParserPackageTests -instr-profile=.build/debug/codecov/default.profdata -ignore-filename-regex=".build|Tests" -name="Lexer.swift"
``` 