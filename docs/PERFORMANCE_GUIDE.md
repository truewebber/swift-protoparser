# SwiftProtoParser Performance Guide

## 🚀 Performance & Caching System

SwiftProtoParser includes a comprehensive performance optimization system designed for production use with large Protocol Buffers projects.

## 📋 Quick Start

### Basic Caching
```swift
import SwiftProtoParser

// Parse with automatic caching
let result = SwiftProtoParser.parseProtoFileWithCaching("user.proto")

// Check cache statistics
let stats = SwiftProtoParser.getCacheStatistics()
print("Cache hit rate: \(stats.astHitRate * 100)%")
```

### Incremental Parsing for Large Projects
```swift
// Parse directory incrementally (only changed files)
let result = SwiftProtoParser.parseProtoDirectoryIncremental(
    "/path/to/proto/directory",
    recursive: true,
    importPaths: ["/path/to/imports"]
)

// Check incremental statistics
let stats = SwiftProtoParser.getIncrementalStatistics()
print("Incremental efficiency: \(stats.incrementalEfficiency * 100)%")
```

### Streaming for Very Large Files
```swift
// Parse large files (>50MB) with memory efficiency
let result = SwiftProtoParser.parseProtoFileStreaming(
    "/path/to/large.proto",
    importPaths: ["/imports"]
)
```

## 🔧 Configuration

### Cache Configuration
```swift
// High-performance configuration for large projects
let cache = PerformanceCache(configuration: .highPerformance)

// Memory-constrained configuration
let cache = PerformanceCache(configuration: .memoryConstrained)

// Custom configuration
let config = PerformanceCache.Configuration(
    maxASTEntries: 2000,
    maxDescriptorEntries: 1000,
    maxDependencyEntries: 500,
    maxMemoryUsage: 200 * 1024 * 1024, // 200MB
    timeToLive: 3600, // 1 hour
    enableMonitoring: true
)
let cache = PerformanceCache(configuration: config)
```

### Incremental Parser Configuration
```swift
let config = IncrementalParser.Configuration(
    maxInMemorySize: 100 * 1024 * 1024, // 100MB
    streamingChunkSize: 128 * 1024, // 128KB
    maxParallelFiles: 8,
    enableChangeDetection: true,
    enableResultCaching: true
)

let incrementalParser = IncrementalParser(
    configuration: config,
    cache: cache
)
```

## 📊 Performance Monitoring

### Cache Statistics
```swift
let stats = SwiftProtoParser.getCacheStatistics()

print("AST Cache Hit Rate: \(stats.astHitRate * 100)%")
print("Descriptor Cache Hit Rate: \(stats.descriptorHitRate * 100)%")
print("Total Memory Usage: \(stats.totalMemoryUsage / 1024 / 1024) MB")
print("Eviction Count: \(stats.evictionCount)")
print("Average Parse Time: \(stats.averageParseTime * 1000) ms")
```

### Incremental Statistics
```swift
let stats = SwiftProtoParser.getIncrementalStatistics()

print("Total Files Tracked: \(stats.totalFilesTracked)")
print("Incremental Efficiency: \(stats.incrementalEfficiency * 100)%")
print("Memory Peak Usage: \(stats.memoryPeakUsage / 1024 / 1024) MB")
print("Total Parsing Time: \(stats.totalParsingTime) seconds")
```

## 🎯 Benchmarking

### File Benchmarking
```swift
let config = PerformanceBenchmark.Configuration(
    iterations: 20,
    warmupIterations: 5,
    trackMemory: true,
    maxParsingTime: 1.0,
    maxMemoryUsage: 100 * 1024 * 1024
)

let result = SwiftProtoParser.benchmarkPerformance(
    "/path/to/proto/file.proto",
    configuration: config
)

print("Average Duration: \(result.averageDuration * 1000) ms")
print("Success Rate: \(result.successRate * 100)%")
print("Standard Deviation: \(result.standardDeviation * 1000) ms")
```

### Directory Benchmarking
```swift
let result = SwiftProtoParser.benchmarkPerformance("/path/to/proto/directory")

print("Operation: \(result.operation)")
print("Measurements: \(result.measurements.count)")
print("Average Memory Usage: \(result.averageMemoryUsage / 1024 / 1024) MB")
```

## 🔄 Best Practices

### 1. Development Workflow
```swift
// Enable caching for repeated parsing during development
let result = SwiftProtoParser.parseProtoFileWithCaching(
    "user.proto",
    enableCaching: true
)

// Clear caches when switching branches
SwiftProtoParser.clearPerformanceCaches()
```

### 2. CI/CD Integration
```swift
// Use incremental parsing in build systems
let result = SwiftProtoParser.parseProtoDirectoryIncremental(
    protoDirectory,
    recursive: true
)

// Benchmark performance in CI
let benchmark = SwiftProtoParser.benchmarkPerformance(
    protoDirectory,
    configuration: .quick
)

// Fail if performance degrades significantly
if benchmark.averageDuration > maxAllowedTime {
    throw BuildError.performanceRegression
}
```

### 3. Production Deployment
```swift
// Use high-performance configuration
let cache = PerformanceCache(configuration: .highPerformance)

// Monitor cache effectiveness
Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
    let stats = SwiftProtoParser.getCacheStatistics()
    logger.info("Cache hit rate: \(stats.astHitRate)")
    
    if stats.astHitRate < 0.8 {
        logger.warning("Low cache hit rate detected")
    }
}
```

### 4. Memory Management
```swift
// For memory-constrained environments
let cache = PerformanceCache(configuration: .memoryConstrained)

// Monitor memory usage
let stats = SwiftProtoParser.getCacheStatistics()
if stats.totalMemoryUsage > maxMemoryLimit {
    SwiftProtoParser.clearPerformanceCaches()
}

// Use streaming for large files
if fileSize > 50 * 1024 * 1024 { // 50MB
    let result = SwiftProtoParser.parseProtoFileStreaming(filePath)
}
```

## 📈 Performance Characteristics

### Typical Performance Improvements

| Scenario | Without Caching | With Caching | Improvement |
|----------|----------------|--------------|-------------|
| Repeated parsing | 10-50ms | 1-5ms | 5-10x faster |
| Large projects | 100-500ms | 20-100ms | 3-5x faster |
| CI/CD builds | 1-5 minutes | 10-60 seconds | 5-10x faster |

### Memory Usage

| Configuration | Memory Limit | Typical Usage | Cache Entries |
|---------------|--------------|---------------|---------------|
| Default | 100MB | 20-50MB | 1000 AST + 500 descriptors |
| High Performance | 500MB | 100-200MB | 5000 AST + 2500 descriptors |
| Memory Constrained | 10MB | 5-10MB | 100 AST + 50 descriptors |

### Cache Hit Rates

- **Development**: 80-95% (repeated parsing of same files)
- **CI/CD**: 60-80% (incremental builds)
- **Production**: 70-90% (stable proto schemas)

## 🚨 Troubleshooting

### Low Cache Hit Rate
```swift
let stats = SwiftProtoParser.getCacheStatistics()
if stats.astHitRate < 0.5 {
    // Files are changing frequently
    // Consider increasing cache size or TTL
}
```

### High Memory Usage
```swift
let stats = SwiftProtoParser.getCacheStatistics()
if stats.totalMemoryUsage > memoryLimit {
    // Clear expired entries
    cache.clearExpired()
    
    // Or clear all caches
    SwiftProtoParser.clearPerformanceCaches()
}
```

### Performance Regression Detection
```swift
let currentBenchmark = SwiftProtoParser.benchmarkPerformance(protoPath)
let baseline = loadBaselineBenchmark()

if currentBenchmark.averageDuration > baseline.averageDuration * 1.2 {
    print("Performance regression detected!")
    print("Current: \(currentBenchmark.averageDuration * 1000)ms")
    print("Baseline: \(baseline.averageDuration * 1000)ms")
}
```

## 🔗 Related Documentation

- [Architecture Guide](ARCHITECTURE.md)
- [API Reference](API_REFERENCE.md)
- [Migration Guide](MIGRATION_GUIDE.md)
- [Contributing Guidelines](CONTRIBUTING.md)

## 📞 Support

For performance-related questions:
1. Check cache statistics and configuration
2. Run benchmarks to identify bottlenecks
3. Consider incremental parsing for large projects
4. Use streaming for very large files

The performance system is designed to be transparent and provide detailed metrics for optimization.
