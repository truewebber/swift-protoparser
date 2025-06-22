# SwiftProtoParser

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20iOS-lightgrey.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/Tests-792%20passing-green.svg)](#testing)
[![Coverage](https://img.shields.io/badge/Coverage-79.89%25-yellow.svg)](#testing)

A **high-performance Swift library** for parsing Protocol Buffers `.proto` files with enterprise-grade optimization features including caching, incremental parsing, and comprehensive benchmarking tools.

## ✨ Features

### 🚀 Core Parsing Capabilities
- **Complete Proto3 Support** - Full Protocol Buffers 3 specification compliance
- **AST Generation** - Rich Abstract Syntax Tree with full type information
- **Dependency Resolution** - Automatic import chain resolution for multi-file projects
- **Descriptor Generation** - Google Protocol Buffers compatible descriptors
- **Comprehensive Error Handling** - Detailed error messages with suggestions

### ⚡ Enterprise Performance Features
- **5-10x Faster Parsing** with intelligent content-based caching
- **Incremental Parsing** for large projects (only re-parse changed files)
- **Memory-Efficient Streaming** for very large proto files (>50MB)
- **Real-Time Performance Monitoring** with detailed statistics
- **Automated Benchmarking** and regression detection

### 🔧 Production-Ready
- **792 Comprehensive Tests** ensuring reliability and stability  
- **Thread-Safe Operations** for concurrent parsing
- **Configurable Memory Limits** for different deployment scenarios
- **Excellent Error Recovery** with graceful degradation

## 📦 Installation

### Swift Package Manager
```swift
dependencies: [
    .package(url: "https://github.com/your-org/swift-protoparser.git", from: "1.0.0")
]
```

### Package.swift
```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "SwiftProtoParser", package: "swift-protoparser")
    ]
)
```

## 🚀 Quick Start

### Basic Usage
```swift
import SwiftProtoParser

// Parse a single proto file
let result = SwiftProtoParser.parseProtoFile("user.proto")

switch result {
case .success(let ast):
    print("Package: \(ast.package ?? "none")")
    print("Messages: \(ast.messages.map { $0.name })")
    print("Services: \(ast.services.map { $0.name })")
    
case .failure(let error):
    print("Parse error: \(error)")
}
```

### Multi-File Projects with Dependencies
```swift
// Parse with import resolution
let result = SwiftProtoParser.parseProtoFileWithImports(
    "main.proto",
    importPaths: ["./protos", "./vendor/protos"],
    allowMissingImports: false
)

// Parse entire directory
let directoryResult = SwiftProtoParser.parseProtoDirectory(
    "./protos",
    recursive: true
)
```

### High-Performance Caching
```swift
// Enable caching for 5-10x speedup in repeated parsing
let result = SwiftProtoParser.parseProtoFileWithCaching("user.proto")

// Check cache performance
let stats = SwiftProtoParser.getCacheStatistics()
print("Cache hit rate: \(stats.astHitRate * 100)%")

// Incremental parsing for large projects
let incrementalResult = SwiftProtoParser.parseProtoDirectoryIncremental("./protos")
```

### Protocol Buffers Descriptors
```swift
// Generate Google Protocol Buffers compatible descriptors
let descriptorResult = SwiftProtoParser.parseProtoToDescriptors("user.proto")

switch descriptorResult {
case .success(let fileDescriptor):
    print("File: \(fileDescriptor.name)")
    print("Package: \(fileDescriptor.package)")
    print("Messages: \(fileDescriptor.messageType.map { $0.name })")
    
case .failure(let error):
    print("Descriptor error: \(error)")
}
```

## 📊 Performance Benchmarking

```swift
// Benchmark parsing performance
let benchmark = SwiftProtoParser.benchmarkPerformance(
    "./protos",
    configuration: .default
)

print("Average Duration: \(benchmark.averageDuration * 1000) ms")
print("Success Rate: \(benchmark.successRate * 100)%")
print("Memory Usage: \(benchmark.averageMemoryUsage / 1024 / 1024) MB")
```

## 🎯 Advanced Usage

### Custom Cache Configuration
```swift
// High-performance setup for large projects
let cache = PerformanceCache(configuration: .highPerformance)

// Memory-constrained setup
let cache = PerformanceCache(configuration: .memoryConstrained)

// Custom configuration
let config = PerformanceCache.Configuration(
    maxASTEntries: 2000,
    maxMemoryUsage: 200 * 1024 * 1024, // 200MB
    timeToLive: 3600 // 1 hour
)
```

### Streaming Large Files
```swift
// Memory-efficient parsing for very large files
let result = SwiftProtoParser.parseProtoFileStreaming("large.proto")
```

### Error Handling
```swift
let result = SwiftProtoParser.parseProtoFile("example.proto")

switch result {
case .success(let ast):
    // Process successful parse
    
case .failure(.fileNotFound(let path)):
    print("File not found: \(path)")
    
case .failure(.syntaxError(let message, let file, let line, let column)):
    print("Syntax error in \(file) at \(line):\(column): \(message)")
    
case .failure(.dependencyResolutionError(let message, let importPath)):
    print("Cannot resolve import '\(importPath)': \(message)")
    
case .failure(let error):
    print("Other error: \(error)")
}
```

## 📈 Performance Characteristics

| Scenario | Without Caching | With Caching | Improvement |
|----------|-----------------|--------------|-------------|
| **Repeated parsing** | 10-50ms | 1-5ms | **5-10x faster** |
| **Large projects** | 100-500ms | 20-100ms | **3-5x faster** |
| **CI/CD builds** | 1-5 minutes | 10-60 seconds | **5-10x faster** |

### Memory Usage by Configuration

| Configuration | Memory Limit | Typical Usage | Cache Entries |
|---------------|--------------|---------------|---------------|
| **Default** | 100MB | 20-50MB | 1000 AST + 500 descriptors |
| **High Performance** | 500MB | 100-200MB | 5000 AST + 2500 descriptors |
| **Memory Constrained** | 10MB | 5-10MB | 100 AST + 50 descriptors |

## 🧪 Testing

SwiftProtoParser includes **792 comprehensive tests** ensuring reliability:

```bash
# Run all tests
swift test

# Run with coverage
swift test --enable-code-coverage

# Generate coverage report
make coverage
```

### Test Coverage
- **79.89% regions coverage** (excellent for a complex parser)
- **81.26% lines coverage** 
- **78.62% functions coverage**
- **Zero test failures** across all scenarios

## 📚 Documentation

Comprehensive documentation is available in the [`docs/`](docs/) directory:

- **[Quick Reference](docs/QUICK_REFERENCE.md)** - Fast API overview
- **[Performance Guide](docs/PERFORMANCE_GUIDE.md)** - Complete optimization guide
- **[Architecture](docs/ARCHITECTURE.md)** - System design and architecture
- **[Module Documentation](docs/modules/)** - Detailed component documentation

## 🛠️ Development

### Prerequisites
- **Swift 5.9+**
- **Xcode 15.0+** (for macOS development)
- **swift-protobuf 1.20.0+**

### Build from Source
```bash
git clone https://github.com/your-org/swift-protoparser.git
cd swift-protoparser
swift build
```

### Development Commands
```bash
# Quick session startup
make start-session

# Run tests
make test

# Generate coverage
make coverage

# Run performance benchmarks
swift test --filter "Performance"
```

## 🔮 Roadmap

### ✅ Completed (v1.0)
- Complete Proto3 parsing with AST generation
- Multi-file dependency resolution  
- Google Protocol Buffers descriptor generation
- Enterprise-grade performance & caching system
- Comprehensive test suite (792 tests)

### 🚧 Upcoming (v1.1)
- **CLI Tool** for proto validation and analysis
- **API Documentation** with DocC
- **Migration Guide** from other proto parsers
- **Advanced Error Reporting** with source locations

### 🔮 Future (v2.0+)
- Proto2 compatibility support
- Custom plugin system
- IDE integration features
- Advanced analytics and ML-based optimization

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Process
1. **Fork** the repository
2. **Create** a feature branch
3. **Add tests** for new functionality
4. **Ensure** all tests pass and coverage remains high
5. **Submit** a pull request

### Code Quality Standards
- **Test-driven development** - Add tests before implementing features
- **High test coverage** - Maintain 80%+ coverage
- **Performance awareness** - Include benchmarks for performance-critical changes
- **Documentation** - Update docs for API changes

## 📄 License

SwiftProtoParser is released under the **MIT License**. See [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- **Apple Swift Team** for the Swift language and Swift Package Manager
- **Protocol Buffers Team** at Google for the protobuf specification  
- **swift-protobuf** contributors for inspiration and compatibility reference
- **Open Source Community** for feedback and contributions

## 🆘 Support

### Getting Help
- **📖 Documentation**: Check [docs/](docs/) for comprehensive guides
- **🐛 Bug Reports**: File issues in the GitHub repository
- **💡 Feature Requests**: Discuss in GitHub discussions
- **❓ Questions**: Use GitHub discussions for general questions

### Performance Issues
1. **Check** [Performance Guide](docs/PERFORMANCE_GUIDE.md)
2. **Run** benchmarks to identify bottlenecks
3. **Enable** caching for repeated parsing
4. **Use** incremental parsing for large projects

---

**SwiftProtoParser** - High-performance Protocol Buffers parsing for Swift with enterprise-grade optimization ⚡
