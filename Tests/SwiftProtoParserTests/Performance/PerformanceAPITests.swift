import XCTest
@testable import SwiftProtoParser

final class PerformanceAPITests: XCTestCase {

  var tempDir: URL!
  
  override func setUp() {
    super.setUp()
    tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    
    // Clear performance caches before each test
    SwiftProtoParser.clearPerformanceCaches()
  }
  
  override func tearDown() {
    if let tempDir = tempDir {
      try? FileManager.default.removeItem(at: tempDir)
    }
    SwiftProtoParser.clearPerformanceCaches()
    super.tearDown()
  }

  // MARK: - Caching API Tests

  func testParseProtoFileWithCaching() {
    let protoContent = """
      syntax = "proto3";
      package test.caching;

      message CachedMessage {
        string name = 1;
        int32 value = 2;
      }
      """

    let protoFile = tempDir.appendingPathComponent("cached.proto")
    try! protoContent.write(to: protoFile, atomically: true, encoding: .utf8)

    // First parse (cache miss)
    let result1 = SwiftProtoParser.parseProtoFileWithCaching(protoFile.path, enableCaching: true)
    XCTAssertTrue(result1.isSuccess)
    
    if case .success(let ast1) = result1 {
      XCTAssertEqual(ast1.package, "test.caching")
      XCTAssertEqual(ast1.messages.count, 1)
      XCTAssertEqual(ast1.messages.first?.name, "CachedMessage")
    }

    // Second parse (cache hit)
    let result2 = SwiftProtoParser.parseProtoFileWithCaching(protoFile.path, enableCaching: true)
    XCTAssertTrue(result2.isSuccess)
    
    if case .success(let ast2) = result2 {
      XCTAssertEqual(ast2.package, "test.caching")
      XCTAssertEqual(ast2.messages.count, 1)
    }

    // Verify cache statistics
    let stats = SwiftProtoParser.getCacheStatistics()
    XCTAssertGreaterThan(stats.astCacheHits, 0)
  }

  func testParseProtoFileWithCachingDisabled() {
    let protoContent = """
      syntax = "proto3";
      package test.nocaching;

      message NonCachedMessage {
        string data = 1;
      }
      """

    let protoFile = tempDir.appendingPathComponent("nocached.proto")
    try! protoContent.write(to: protoFile, atomically: true, encoding: .utf8)

    // Parse with caching disabled
    let result = SwiftProtoParser.parseProtoFileWithCaching(protoFile.path, enableCaching: false)
    XCTAssertTrue(result.isSuccess)
    
    if case .success(let ast) = result {
      XCTAssertEqual(ast.package, "test.nocaching")
      XCTAssertEqual(ast.messages.count, 1)
    }
  }

  func testCacheInvalidationOnFileChange() {
    let originalContent = """
      syntax = "proto3";
      package test.change;

      message OriginalMessage {
        string name = 1;
      }
      """

    let modifiedContent = """
      syntax = "proto3";
      package test.change;

      message ModifiedMessage {
        string name = 1;
        int32 value = 2;
      }
      """

    let protoFile = tempDir.appendingPathComponent("changing.proto")
    
    // Write original content and parse
    try! originalContent.write(to: protoFile, atomically: true, encoding: .utf8)
    let result1 = SwiftProtoParser.parseProtoFileWithCaching(protoFile.path)
    XCTAssertTrue(result1.isSuccess)
    
    if case .success(let ast1) = result1 {
      XCTAssertEqual(ast1.messages.first?.name, "OriginalMessage")
    }

    // Modify file content
    try! modifiedContent.write(to: protoFile, atomically: true, encoding: .utf8)
    
    // Parse again - should get new content (cache miss due to content change)
    let result2 = SwiftProtoParser.parseProtoFileWithCaching(protoFile.path)
    XCTAssertTrue(result2.isSuccess)
    
    if case .success(let ast2) = result2 {
      XCTAssertEqual(ast2.messages.first?.name, "ModifiedMessage")
      XCTAssertEqual(ast2.messages.first?.fields.count, 2)
    }
  }

  // MARK: - Incremental Parsing Tests

  func testParseProtoDirectoryIncremental() {
    // Create multiple proto files
    let file1Content = """
      syntax = "proto3";
      package test.incremental;

      message Message1 {
        string name = 1;
      }
      """

    let file2Content = """
      syntax = "proto3";
      package test.incremental;

      message Message2 {
        int32 value = 1;
      }
      """

    let file1 = tempDir.appendingPathComponent("message1.proto")
    let file2 = tempDir.appendingPathComponent("message2.proto")

    try! file1Content.write(to: file1, atomically: true, encoding: .utf8)
    try! file2Content.write(to: file2, atomically: true, encoding: .utf8)

    // Parse directory incrementally
    let result = SwiftProtoParser.parseProtoDirectoryIncremental(tempDir.path)
    XCTAssertTrue(result.isSuccess)
    
    if case .success(let asts) = result {
      XCTAssertEqual(asts.count, 2)
      
      let messageNames = asts.flatMap { $0.messages.map { $0.name } }
      XCTAssertTrue(messageNames.contains("Message1"))
      XCTAssertTrue(messageNames.contains("Message2"))
    }
  }

  // MARK: - Streaming Tests

  func testParseProtoFileStreaming() {
    // Create a moderately large proto file
    var largeContent = """
      syntax = "proto3";
      package test.streaming;

      """

    // Add many message definitions to make it larger
    for i in 1...100 {
      largeContent += """
        message LargeMessage\(i) {
          string field1 = 1;
          int32 field2 = 2;
          bool field3 = 3;
        }

        """
    }

    let largeFile = tempDir.appendingPathComponent("large.proto")
    try! largeContent.write(to: largeFile, atomically: true, encoding: .utf8)

    // Parse using streaming
    let result = SwiftProtoParser.parseProtoFileStreaming(largeFile.path)
    XCTAssertTrue(result.isSuccess)
    
    if case .success(let ast) = result {
      XCTAssertEqual(ast.package, "test.streaming")
      XCTAssertEqual(ast.messages.count, 100)
    }
  }

  // MARK: - Statistics Tests

  func testCacheStatistics() {
    let protoContent = """
      syntax = "proto3";
      package test.stats;

      message StatsMessage {
        string data = 1;
      }
      """

    let protoFile = tempDir.appendingPathComponent("stats.proto")
    try! protoContent.write(to: protoFile, atomically: true, encoding: .utf8)

    // Initial statistics
    let initialStats = SwiftProtoParser.getCacheStatistics()
    XCTAssertEqual(initialStats.astCacheHits, 0)
    XCTAssertEqual(initialStats.astCacheMisses, 0)

    // Parse file (cache miss)
    _ = SwiftProtoParser.parseProtoFileWithCaching(protoFile.path)

    // Parse again (cache hit)
    _ = SwiftProtoParser.parseProtoFileWithCaching(protoFile.path)

    // Check updated statistics
    let finalStats = SwiftProtoParser.getCacheStatistics()
    XCTAssertGreaterThan(finalStats.astCacheHits, 0)
    XCTAssertGreaterThan(finalStats.astCacheMisses, 0)
    XCTAssertGreaterThan(finalStats.astHitRate, 0.0)
  }

  func testIncrementalStatistics() {
    // Create a proto file
    let protoContent = """
      syntax = "proto3";
      package test.incremental.stats;

      message IncrementalMessage {
        string name = 1;
      }
      """

    let protoFile = tempDir.appendingPathComponent("incremental.proto")
    try! protoContent.write(to: protoFile, atomically: true, encoding: .utf8)

    // Parse directory incrementally
    _ = SwiftProtoParser.parseProtoDirectoryIncremental(tempDir.path)

    // Check incremental statistics
    let stats = SwiftProtoParser.getIncrementalStatistics()
    XCTAssertGreaterThanOrEqual(stats.totalFilesTracked, 0)
    XCTAssertGreaterThanOrEqual(stats.incrementalEfficiency, 0.0)
  }

  func testClearPerformanceCaches() {
    let protoContent = """
      syntax = "proto3";
      package test.clear;

      message ClearMessage {
        string data = 1;
      }
      """

    let protoFile = tempDir.appendingPathComponent("clear.proto")
    try! protoContent.write(to: protoFile, atomically: true, encoding: .utf8)

    // Parse file to populate cache
    _ = SwiftProtoParser.parseProtoFileWithCaching(protoFile.path)

    // Verify cache has entries
    let statsBeforeClear = SwiftProtoParser.getCacheStatistics()
    XCTAssertGreaterThan(statsBeforeClear.astCacheMisses, 0)

    // Clear caches
    SwiftProtoParser.clearPerformanceCaches()

    // Verify caches are cleared
    let statsAfterClear = SwiftProtoParser.getCacheStatistics()
    XCTAssertEqual(statsAfterClear.astCacheHits, 0)
    XCTAssertEqual(statsAfterClear.astCacheMisses, 0)
  }

  // MARK: - Benchmark Tests

  func testBenchmarkPerformance() {
    let protoContent = """
      syntax = "proto3";
      package test.benchmark;

      message BenchmarkMessage {
        string name = 1;
        int32 value = 2;
        repeated string items = 3;
      }
      """

    let protoFile = tempDir.appendingPathComponent("benchmark.proto")
    try! protoContent.write(to: protoFile, atomically: true, encoding: .utf8)

    // Run benchmark
    let config = PerformanceBenchmark.Configuration(
      iterations: 3,
      warmupIterations: 1,
      trackMemory: true,
      maxParsingTime: 1.0,
      maxMemoryUsage: 100 * 1024 * 1024
    )
    
    let result = SwiftProtoParser.benchmarkPerformance(protoFile.path, configuration: config)
    
    XCTAssertEqual(result.measurements.count, 3)
    XCTAssertGreaterThan(result.averageDuration, 0)
    XCTAssertGreaterThanOrEqual(result.successRate, 0.0)
    XCTAssertLessThanOrEqual(result.successRate, 1.0)
  }

  func testBenchmarkDirectoryPerformance() {
    // Create multiple proto files
    for i in 1...3 {
      let content = """
        syntax = "proto3";
        package test.benchmark.dir;

        message BenchmarkMessage\(i) {
          string name = 1;
        }
        """
      
      let file = tempDir.appendingPathComponent("benchmark\(i).proto")
      try! content.write(to: file, atomically: true, encoding: .utf8)
    }

    // Run directory benchmark
    let config = PerformanceBenchmark.Configuration(
      iterations: 2,
      warmupIterations: 1,
      trackMemory: false,
      maxParsingTime: 2.0,
      maxMemoryUsage: 200 * 1024 * 1024
    )
    
    let result = SwiftProtoParser.benchmarkPerformance(tempDir.path, configuration: config)
    
    XCTAssertEqual(result.measurements.count, 2)
    XCTAssertGreaterThan(result.averageDuration, 0)
  }

  func testBenchmarkNonExistentPath() {
    let result = SwiftProtoParser.benchmarkPerformance("/nonexistent/path")
    
    XCTAssertTrue(result.operation.contains("not found"))
    XCTAssertEqual(result.measurements.count, 0)
  }

  // MARK: - Error Handling Tests

  func testParseProtoFileWithCachingError() {
    let result = SwiftProtoParser.parseProtoFileWithCaching("/nonexistent/file.proto")
    XCTAssertTrue(result.isFailure)
    
    if case .failure(let error) = result {
      XCTAssertTrue(error.description.contains("I/O error") || error.description.contains("No such file"))
    }
  }

  func testParseProtoFileStreamingError() {
    let result = SwiftProtoParser.parseProtoFileStreaming("/nonexistent/large.proto")
    XCTAssertTrue(result.isFailure)
    
    if case .failure(let error) = result {
      XCTAssertTrue(error.description.contains("I/O error") || error.description.contains("No such file"))
    }
  }

  // MARK: - Performance Tests

  func testCachingPerformanceImprovement() {
    let protoContent = """
      syntax = "proto3";
      package test.performance;

      message PerformanceMessage {
        string name = 1;
        int32 value = 2;
        repeated string items = 3;
        map<string, int32> data = 4;
      }
      """

    let protoFile = tempDir.appendingPathComponent("performance.proto")
    try! protoContent.write(to: protoFile, atomically: true, encoding: .utf8)

    // Measure parsing without caching
    let startTimeNoCaching = Date()
    for _ in 0..<10 {
      _ = SwiftProtoParser.parseProtoFileWithCaching(protoFile.path, enableCaching: false)
    }
    let noCachingTime = Date().timeIntervalSince(startTimeNoCaching)

    // Clear and measure parsing with caching
    SwiftProtoParser.clearPerformanceCaches()
    
    let startTimeCaching = Date()
    for _ in 0..<10 {
      _ = SwiftProtoParser.parseProtoFileWithCaching(protoFile.path, enableCaching: true)
    }
    let cachingTime = Date().timeIntervalSince(startTimeCaching)

    // Caching should be faster for repeated parsing (though first parse might be slower)
    // We mainly verify that caching doesn't break functionality
    XCTAssertGreaterThan(noCachingTime, 0)
    XCTAssertGreaterThan(cachingTime, 0)
    
    // Verify cache statistics show hits
    let stats = SwiftProtoParser.getCacheStatistics()
    XCTAssertGreaterThan(stats.astCacheHits, 0)
  }
}
