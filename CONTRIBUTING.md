# Contributing to SwiftProtoParser

Thank you for your interest in contributing to SwiftProtoParser! We welcome contributions from the community and are pleased to have you join us.

## 🚀 Getting Started

### Prerequisites

- **Swift 5.9+**
- **Xcode 15.0+** (for macOS development)
- **Git** for version control

### Setting Up the Development Environment

1. **Fork** the repository on GitHub
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/truewebber/swift-protoparser.git
   cd SwiftProtoParser
   ```

3. **Install dependencies** and run initial setup:
   ```bash
   make start-session
   ```

4. **Run tests** to ensure everything is working:
   ```bash
   make test
   make coverage
   ```

## 📋 How to Contribute

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When you create a bug report, please include:

- **Clear description** of the issue
- **Steps to reproduce** the behavior
- **Expected vs actual behavior**
- **Environment details** (Swift version, platform, etc.)
- **Sample .proto file** if applicable
- **Error messages** or logs

**Use this template:**

```markdown
**Bug Description**
A clear description of the bug.

**To Reproduce**
Steps to reproduce the behavior:
1. Create a .proto file with '...'
2. Call SwiftProtoParser.parseProtoFile('...')
3. See error

**Expected Behavior**
What you expected to happen.

**Environment**
- SwiftProtoParser version: [e.g. 1.0.0]
- Swift version: [e.g. 5.9]
- Platform: [e.g. macOS 14.0, iOS 17.0]

**Additional Context**
Any other context about the problem.
```

### Suggesting Features

We welcome feature suggestions! Please:

- **Check existing issues** to avoid duplicates
- **Provide clear use case** for the feature
- **Describe the expected behavior**
- **Consider backward compatibility**

### Contributing Code

#### Development Workflow

1. **Create a branch** for your work:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following our coding standards
3. **Add or update tests** for your changes
4. **Run tests** to ensure everything passes:
   ```bash
   make test
   make coverage
   ```

5. **Commit your changes** with a clear message:
   ```bash
   git commit -m "Add support for custom proto options"
   ```

6. **Push to your fork** and create a Pull Request

#### Pull Request Guidelines

- **Keep changes focused** - one feature/fix per PR
- **Write clear commit messages** 
- **Include tests** for new functionality
- **Update documentation** if needed
- **Ensure all tests pass**
- **Maintain code coverage** above 90%

**PR Template:**

```markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Code refactoring

## Testing
- [ ] Added new tests
- [ ] Updated existing tests
- [ ] All tests pass
- [ ] Coverage maintained/improved

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No breaking changes (or clearly documented)
```

## 🧪 Testing Guidelines

### Running Tests

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter SwiftProtoParserTests

# Run with coverage
make coverage
```

### Writing Tests

- **Follow existing patterns** in the test suite
- **Test both success and failure cases**
- **Use descriptive test names**: `testParseValidProtoWithExtendStatements()`
- **Include edge cases** and error conditions
- **Add test resources** in `Tests/TestResources/` if needed

### Test Coverage Requirements

- **Maintain 90%+ coverage** for new code
- **Add tests for bug fixes** to prevent regressions
- **Include performance tests** for optimization changes

## 📝 Code Style Guidelines

### Swift Style

Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/):

- **Use clear, descriptive names**
- **Follow camelCase** for functions and variables
- **Follow PascalCase** for types
- **Prefer clarity over brevity**

### Code Organization

- **Group related functionality** together
- **Use extensions** for protocol conformance
- **Add documentation comments** for public APIs
- **Keep functions focused** and small

### Example:

```swift
/// Parses a Protocol Buffers .proto file into an Abstract Syntax Tree
/// - Parameter filePath: Path to the .proto file
/// - Returns: Result containing the parsed AST or an error
/// - Throws: ProtoParseError if parsing fails
public static func parseProtoFile(_ filePath: String) -> Result<ProtoAST, ProtoParseError> {
    // Implementation
}
```

## 🏗️ Architecture Guidelines

### Adding New Features

- **Follow existing module structure**
- **Maintain separation of concerns**
- **Add comprehensive error handling**
- **Consider performance implications**
- **Update relevant documentation**

### Module Guidelines

- **Core**: Fundamental types and errors
- **Lexer**: Tokenization logic
- **Parser**: AST generation
- **DescriptorBuilder**: SwiftProtobuf integration
- **DependencyResolver**: Import resolution
- **Performance**: Caching and optimization
- **Public**: Public API interface

## 🔍 Code Review Process

### What We Look For

- **Correctness**: Does the code work as intended?
- **Tests**: Are there adequate tests?
- **Performance**: Are there any performance regressions?
- **Style**: Does it follow our coding standards?
- **Documentation**: Is the code well-documented?

### Review Timeline

- **Initial review**: Within 2-3 days
- **Follow-up reviews**: Within 1-2 days
- **Merge**: After approval and CI passes

## 📚 Documentation

### Updating Documentation

- **Update README.md** for user-facing changes
- **Update code comments** for API changes  
- **Add examples** for new features
- **Update architecture docs** for structural changes

### Documentation Style

- **Be clear and concise**
- **Include code examples**
- **Explain the "why" not just the "what"**
- **Keep it up to date**

## 🚨 Performance Considerations

### Performance Requirements

- **Maintain sub-millisecond** parsing for small files
- **Keep memory usage reasonable** (< 50MB for typical projects)
- **Preserve cache hit rates** above 80%
- **Add benchmarks** for performance-critical changes

### Performance Testing

```bash
# Run performance tests
swift test --filter Performance

# Generate performance report
make benchmark
```

## 🆘 Getting Help

### Community Support

- **GitHub Discussions**: For questions and general discussion
- **GitHub Issues**: For bugs and feature requests
- **Documentation**: Check the `docs/` directory

### Development Questions

If you're stuck:

1. **Check existing documentation**
2. **Search existing issues**
3. **Ask in GitHub Discussions**
4. **Ping maintainers** in your PR

## 📄 License

By contributing to SwiftProtoParser, you agree that your contributions will be licensed under the MIT License.

## 🙏 Recognition

Contributors will be recognized in:

- **GitHub contributors list**
- **Release notes** for significant contributions
- **Special mentions** for major features

---

Thank you for contributing to SwiftProtoParser! 🚀
