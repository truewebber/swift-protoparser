# Contributing to SwiftProtoParser

Thank you for your interest in contributing to SwiftProtoParser! This document provides guidelines and instructions for contributing to this project.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for everyone.

## How to Contribute

### Reporting Bugs

If you find a bug, please create an issue with the following information:

1. A clear, descriptive title
2. Steps to reproduce the issue
3. Expected behavior
4. Actual behavior
5. Any relevant logs or screenshots
6. Your environment (Swift version, OS, etc.)

### Suggesting Enhancements

We welcome suggestions for enhancements! Please create an issue with:

1. A clear, descriptive title
2. A detailed description of the proposed enhancement
3. Any relevant examples or use cases

### Pull Requests

1. Fork the repository
2. Create a new branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run the tests to ensure they pass (`swift test`)
5. Commit your changes (`git commit -m 'Add some amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Development Workflow

### Setting Up the Development Environment

1. Clone the repository
2. Run `swift package resolve` to fetch dependencies
3. Open the package in Xcode or your preferred IDE

### Running Tests

```bash
# Run all tests
swift test

# Run tests with code coverage
swift test --enable-code-coverage

# Generate coverage reports
./Tools/CodeCoverage/run_coverage.sh
./Tools/CodeCoverage/analyze_coverage.sh
```

### Coding Style

- Follow the Swift API Design Guidelines
- Use meaningful variable and function names
- Write clear comments for complex logic
- Include documentation comments for public APIs

### Test Coverage

We aim for high test coverage. Please include tests for any new functionality or bug fixes. Check the current coverage status in the [coverage tracking document](Tools/CodeCoverage/coverage_tracking.md).

## Release Process

1. Update version numbers in relevant files
2. Update the CHANGELOG.md
3. Create a new GitHub release with release notes
4. Tag the release with the version number

## License

By contributing to SwiftProtoParser, you agree that your contributions will be licensed under the project's MIT License. 