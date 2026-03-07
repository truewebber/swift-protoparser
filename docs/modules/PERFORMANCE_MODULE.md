# Performance Module Documentation

## 📋 Overview

The Performance module provides enterprise-grade optimization capabilities for SwiftProtoParser, including caching, incremental parsing, and comprehensive benchmarking tools.

## 🏗️ Architecture

```
Performance/
├── PerformanceCache.swift      # Centralized caching system
├── IncrementalParser.swift     # Change detection & incremental parsing  
└── PerformanceBenchmark.swift  # Performance measurement & analysis
```

## 🎯 Core Components

### 1. PerformanceCache

**Purpose**: Content-based caching system for AST, descriptors, and dependency results.

**Key Features**:
- Content hash-based cache invalidation
- LRU eviction policies
- Configurable memory limits
- Real-time statistics tracking
- Thread-safe concurrent access

**Dependencies**: 
- Core (for AST types)
- SwiftProtobuf (for descriptors)

**Public API**:
```swift
public final class PerformanceCache {
    public struct Configuration
    public struct Statistics
    
    public func getCachedAST(for: String, contentHash: String) -> ProtoAST?
    public func cacheAST(_ ast: ProtoAST, for: String, contentHash: String, fileSize: Int64, parseTime: TimeInterval)
    public func getStatistics() -> Statistics
    public func clearAll()
}
```

### 2. IncrementalParser

**Purpose**: Selective re-parsing for large projects with change detection.

**Key Features**:
- File modification tracking
- Dependency graph analysis
- Parallel batch processing
- Memory-efficient streaming
- Change set calculation

**Dependencies**:
- PerformanceCache (for result caching)
- Core (for error types)
- ProtoParsingPipeline (Layer 2, for actual parsing — **not** the public SwiftProtoParser facade)
- DependencyResolver (Layer 4, for multi-file resolution)

**API**:
```swift
final class IncrementalParser {
    struct Configuration
    struct Statistics
    struct ChangeSet
    
    func detectChanges(in: String, recursive: Bool) throws -> ChangeSet
    func parseIncremental(changeSet: ChangeSet, importPaths: [String]) throws -> [String: Result<ProtoAST, ProtoParseError>]
    func parseStreamingFile(_ filePath: String, importPaths: [String]) throws -> Result<ProtoAST, ProtoParseError>
}
```

### 3. PerformanceBenchmark

**Purpose**: Comprehensive performance measurement and regression detection.

**Key Features**:
- Statistical analysis (mean, median, std dev)
- Memory usage tracking
- Warmup iterations
- Baseline comparison
- Configurable benchmarks

**Dependencies**:
- PerformanceCache (for cache benchmarking)
- ProtoParsingPipeline (Layer 2, for file/string parsing — **not** the public SwiftProtoParser facade)
- DescriptorBuilder (Layer 3, for descriptor generation benchmarks)
- DependencyResolver (Layer 4, for multi-file benchmarks)

**API**:
```swift
final class PerformanceBenchmark {
    struct Configuration
    struct BenchmarkResult
    struct Measurement
    
    func benchmarkSingleFile(_ filePath: String) -> BenchmarkResult
    func benchmarkDirectory(_ directoryPath: String) -> BenchmarkResult
    func runComprehensiveSuite(_ testFilesDirectory: String) -> BenchmarkSuite
}
```

## 🔄 Data Flow

### Caching Flow
```
Parse Request → Check Content Hash → Cache Hit? → Return Cached AST
                                  ↓ (Miss)
                               Parse File → Cache Result → Return AST
```

### Incremental Flow
```
Directory Scan → Change Detection → Dependency Analysis → Selective Re-parsing → Result Aggregation
```

### Benchmarking Flow
```
Warmup Iterations → Measured Iterations → Statistical Analysis → Result Reporting
```

## 📊 Performance Characteristics

### Cache Performance
- **Cache Hit Time**: 1-5ms (vs 10-50ms parsing)
- **Memory Overhead**: ~2-5% of cached content size
- **Hit Rate**: 70-95% (depending on workflow)

### Incremental Performance  
- **Change Detection**: 10-50ms for 1000+ files
- **Selective Re-parsing**: 60-80% time savings
- **Memory Usage**: 50-200MB peak (configurable)

### Benchmark Accuracy
- **Timing Precision**: Microsecond resolution
- **Memory Tracking**: Byte-level accuracy
- **Statistical Confidence**: Standard deviation < 10%

## 🔧 Configuration

### Cache Configurations
```swift
// Default: Balanced performance and memory
.default: 1000 AST + 500 descriptors, 100MB limit

// High Performance: Maximum speed
.highPerformance: 5000 AST + 2500 descriptors, 500MB limit

// Memory Constrained: Minimal footprint
.memoryConstrained: 100 AST + 50 descriptors, 10MB limit
```

### Incremental Configurations
```swift
// Default: General purpose
.default: 50MB in-memory, 64KB chunks, 4 parallel files

// High Performance: Large projects
.highPerformance: 200MB in-memory, 256KB chunks, 8 parallel files

// Memory Constrained: Limited resources
.memoryConstrained: 10MB in-memory, 16KB chunks, 2 parallel files
```

## ⚡ Performance Optimizations

### Caching Optimizations
1. **Content-based hashing**: Only re-parse when content changes
2. **LRU eviction**: Keep frequently used entries
3. **Concurrent access**: Thread-safe with minimal locking
4. **Memory monitoring**: Automatic cleanup when limits exceeded

### Incremental Optimizations
1. **Change detection**: Fast file metadata comparison
2. **Dependency tracking**: Only re-parse affected files
3. **Parallel processing**: Batch files across CPU cores
4. **Streaming support**: Handle large files without memory pressure

### Benchmark Optimizations
1. **Warmup iterations**: Eliminate JIT compilation effects
2. **Statistical analysis**: Accurate performance measurement
3. **Memory tracking**: Real memory usage (not virtual)
4. **Regression detection**: Automated performance monitoring

## 🧪 Testing Strategy

### Test Coverage
- **PerformanceCache**: 15 tests covering caching, statistics, configurations
- **IncrementalParser**: Limited coverage (61.86% regions)
- **PerformanceBenchmark**: Basic coverage (23.94% regions)
- **Integration Tests**: 14 tests in PerformanceAPITests

### Test Categories
1. **Unit Tests**: Individual component functionality
2. **Integration Tests**: End-to-end workflows
3. **Performance Tests**: Actual performance measurement
4. **Error Handling**: Failure scenarios and recovery

## 🔗 Module Dependencies

### Internal Dependencies
```
PerformanceCache      → Core (error types), Parser (AST types)
IncrementalParser     → PerformanceCache, ProtoParsingPipeline (Layer 2), DependencyResolver (Layer 4)
PerformanceBenchmark  → PerformanceCache, ProtoParsingPipeline (Layer 2), DescriptorBuilder (Layer 3), DependencyResolver (Layer 4)
```

**Critical constraint**: No component in the Performance module calls `SwiftProtoParser` (the
public facade, Layer 6). All parsing is performed via `ProtoParsingPipeline` directly.
This ensures proper layer separation and avoids circular logical dependencies.

### External Dependencies
```
Performance → SwiftProtobuf (descriptor types)
Performance → Foundation (file system, threading)
```

## 📈 Future Enhancements

### Planned Improvements
1. **Disk-based caching**: Persistent cache across sessions
2. **Network caching**: Distributed cache for team development
3. **Advanced analytics**: ML-based performance prediction
4. **IDE integration**: Real-time performance feedback

### Optimization Opportunities
1. **SIMD optimizations**: Faster content hashing
2. **Memory mapping**: Reduce I/O overhead for large files
3. **Compression**: Reduce cache memory usage
4. **Predictive parsing**: Pre-parse likely-needed files

## 🔍 Monitoring & Debugging

### Available Metrics
- Cache hit/miss rates
- Memory usage patterns
- Parse time distributions
- Incremental efficiency
- Error frequencies

### Debug Tools
- Detailed cache statistics
- Performance regression detection
- Memory usage tracking
- Change detection logging

## 📚 Related Documentation

- [Performance Guide](../PERFORMANCE_GUIDE.md) - User-facing documentation
- [Architecture](../ARCHITECTURE.md) - Overall system architecture
- [Core Module](CORE_MODULE.md) - Base types and errors
- [Parser Module](PARSER_MODULE.md) - AST generation
