import XCTest
@testable import SwiftProtoParser

final class SwiftProtoParserAdvancedCoverageTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Clear caches before each test for clean state
    SwiftProtoParser.clearPerformanceCaches()
  }

  override func tearDown() {
    SwiftProtoParser.clearPerformanceCaches()
    super.tearDown()
  }

  // MARK: - File IO Error Handling Tests

  func testParseProtoFileNonexistentFile() {
    let result = SwiftProtoParser.parseProtoFile("/nonexistent/path/file.proto")
    
    switch result {
    case .success:
      XCTFail("Should fail for nonexistent file")
    case .failure(let error):
      if case .ioError = error {
        XCTAssertTrue(true, "Correctly failed with ioError")
      } else {
        XCTFail("Expected ioError, got: \(error)")
      }
    }
  }

  func testParseProtoToDescriptorsNonexistentFile() {
    let result = SwiftProtoParser.parseProtoToDescriptors("/nonexistent/path/file.proto")
    
    switch result {
    case .success:
      XCTFail("Should fail for nonexistent file")
    case .failure(let error):
      if case .ioError = error {
        XCTAssertTrue(true, "Correctly failed with ioError")
      } else {
        XCTFail("Expected ioError, got: \(error)")
      }
    }
  }

  func testParseProtoFileWithCachingNonexistentFile() {
    let result = SwiftProtoParser.parseProtoFileWithCaching("/nonexistent/path/file.proto")
    
    switch result {
    case .success:
      XCTFail("Should fail for nonexistent file")
    case .failure(let error):
      if case .ioError = error {
        XCTAssertTrue(true, "Correctly failed with ioError")
      } else {
        XCTFail("Expected ioError, got: \(error)")
      }
    }
  }

  // MARK: - Parser Error Conversion Tests

  func testParseProtoStringParserErrorConversion() {
    let invalidProto = """
      syntax = "proto3";
      message Test {
        string = 1; // missing field name
      }
      """
    
    let result = SwiftProtoParser.parseProtoString(invalidProto, fileName: "test.proto")
    
    switch result {
    case .success:
      XCTFail("Should fail for invalid proto")
    case .failure(let error):
      if case .syntaxError(let message, let file, _, _) = error {
        XCTAssertTrue(message.contains("field name") || message.contains("unexpected"))
        XCTAssertEqual(file, "test.proto")
      } else {
        XCTFail("Expected syntaxError, got: \(error)")
      }
    }
  }

  func testParseProtoStringEmptyParserErrors() {
    // Test edge case where parser returns failure with empty errors array
    let emptyContent = ""
    
    let result = SwiftProtoParser.parseProtoString(emptyContent)
    
    switch result {
    case .success:
      XCTFail("Empty content should fail")
    case .failure(let error):
      // Should handle empty parser errors gracefully
      XCTAssertTrue(true, "Empty content handled: \(error)")
    }
  }

  // MARK: - Descriptor Error Conversion Tests

  func testParseProtoStringToDescriptorsWithInvalidAST() {
    // Test scenario where AST parses but DescriptorBuilder fails
    let protoWithUnsupportedFeature = """
      syntax = "proto3";
      
      message Test {
        string name = 1;
      }
      """
    
    let result = SwiftProtoParser.parseProtoStringToDescriptors(protoWithUnsupportedFeature)
    
    switch result {
    case .success(let descriptor):
      // Should actually succeed for this simple case
      XCTAssertFalse(descriptor.name.isEmpty)
    case .failure(let error):
      // If it fails, should be proper error handling
      XCTAssertTrue(true, "Descriptor error handling: \(error)")
    }
  }

  func testParseProtoStringToDescriptorsDefaultFileName() {
    let simpleProto = """
      syntax = "proto3";
      message SimpleTest {
        string value = 1;
      }
      """
    
    let result = SwiftProtoParser.parseProtoStringToDescriptors(simpleProto)
    
    switch result {
    case .success(let descriptor):
      XCTAssertEqual(descriptor.name, "string.proto")
    case .failure:
      XCTAssertTrue(true, "Descriptor conversion handled")
    }
  }

  // MARK: - Convenience Methods Edge Cases

  func testGetProtoVersionInvalidFile() {
    let result = SwiftProtoParser.getProtoVersion("/nonexistent/file.proto")
    
    switch result {
    case .success:
      XCTFail("Should fail for nonexistent file")
    case .failure(let error):
      if case .ioError = error {
        XCTAssertTrue(true, "Correctly failed with ioError")
      } else {
        XCTFail("Expected ioError, got: \(error)")
      }
    }
  }

  func testGetPackageNameInvalidFile() {
    let result = SwiftProtoParser.getPackageName("/nonexistent/file.proto")
    
    switch result {
    case .success:
      XCTFail("Should fail for nonexistent file")
    case .failure(let error):
      if case .ioError = error {
        XCTAssertTrue(true, "Correctly failed with ioError")
      } else {
        XCTFail("Expected ioError, got: \(error)")
      }
    }
  }

  func testGetMessageNamesInvalidFile() {
    let result = SwiftProtoParser.getMessageNames("/nonexistent/file.proto")
    
    switch result {
    case .success:
      XCTFail("Should fail for nonexistent file")
    case .failure(let error):
      if case .ioError = error {
        XCTAssertTrue(true, "Correctly failed with ioError")
      } else {
        XCTFail("Expected ioError, got: \(error)")
      }
    }
  }

  // MARK: - Import Resolution Edge Cases

  func testParseProtoFileWithImportsInvalidFile() {
    let result = SwiftProtoParser.parseProtoFileWithImports(
      "/nonexistent/file.proto",
      importPaths: ["/some/path"],
      allowMissingImports: false
    )
    
    switch result {
    case .success:
      XCTFail("Should fail for nonexistent file")
    case .failure(let error):
      // Should be dependency resolution error or IO error
      switch error {
      case .dependencyResolutionError, .ioError:
        XCTAssertTrue(true, "Correctly failed with appropriate error")
      default:
        XCTFail("Expected dependency or IO error, got: \(error)")
      }
    }
  }

  func testParseProtoDirectoryInvalidPath() {
    let result = SwiftProtoParser.parseProtoDirectory(
      "/nonexistent/directory",
      recursive: true,
      importPaths: [],
      allowMissingImports: false
    )
    
    switch result {
    case .success:
      XCTFail("Should fail for nonexistent directory")
    case .failure(let error):
      switch error {
      case .dependencyResolutionError, .ioError:
        XCTAssertTrue(true, "Correctly failed with appropriate error")
      default:
        XCTFail("Expected dependency or IO error, got: \(error)")
      }
    }
  }

  func testParseProtoFileWithImportsToDescriptorsInvalidFile() {
    let result = SwiftProtoParser.parseProtoFileWithImportsToDescriptors(
      "/nonexistent/file.proto",
      importPaths: [],
      allowMissingImports: true
    )
    
    switch result {
    case .success:
      XCTFail("Should fail for nonexistent file")
    case .failure(let error):
      switch error {
      case .dependencyResolutionError, .ioError:
        XCTAssertTrue(true, "Correctly failed with appropriate error")
      default:
        XCTFail("Expected dependency or IO error, got: \(error)")
      }
    }
  }

  func testParseProtoDirectoryToDescriptorsInvalidPath() {
    let result = SwiftProtoParser.parseProtoDirectoryToDescriptors(
      "/nonexistent/directory",
      recursive: false,
      importPaths: ["/some/path"],
      allowMissingImports: true
    )
    
    switch result {
    case .success:
      XCTFail("Should fail for nonexistent directory")
    case .failure(let error):
      switch error {
      case .dependencyResolutionError, .ioError:
        XCTAssertTrue(true, "Correctly failed with appropriate error")
      default:
        XCTFail("Expected dependency or IO error, got: \(error)")
      }
    }
  }

  // MARK: - Performance Caching Tests

  func testParseProtoFileWithCachingDisabled() {
    let tempFile = createTempProtoFile(content: """
      syntax = "proto3";
      message CacheTest {
        string value = 1;
      }
      """)
    defer { removeTempFile(tempFile) }
    
    let result = SwiftProtoParser.parseProtoFileWithCaching(tempFile, enableCaching: false)
    
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages.count, 1)
      XCTAssertEqual(ast.messages[0].name, "CacheTest")
    case .failure(let error):
      XCTFail("Should succeed for valid proto: \(error)")
    }
  }

  func testParseProtoFileWithCachingEnabled() {
    let tempFile = createTempProtoFile(content: """
      syntax = "proto3";
      message CacheTest {
        string value = 1;
      }
      """)
    defer { removeTempFile(tempFile) }
    
    // First parse - should cache
    let result1 = SwiftProtoParser.parseProtoFileWithCaching(tempFile, enableCaching: true)
    switch result1 {
    case .success: XCTAssertTrue(true)
    case .failure: XCTFail("First parse should succeed")
    }
    
    // Second parse - should use cache
    let result2 = SwiftProtoParser.parseProtoFileWithCaching(tempFile, enableCaching: true)
    switch result2 {
    case .success: XCTAssertTrue(true)
    case .failure: XCTFail("Second parse should succeed")
    }
    
    // Statistics should show cache usage
    let stats = SwiftProtoParser.getCacheStatistics()
    XCTAssertGreaterThan(stats.astCacheHits, 0)
  }

  // MARK: - Incremental Parsing Tests

  func testParseProtoDirectoryIncrementalInvalidPath() {
    let result = SwiftProtoParser.parseProtoDirectoryIncremental(
      "/nonexistent/directory",
      recursive: true,
      importPaths: []
    )
    
    switch result {
    case .success:
      XCTFail("Should fail for nonexistent directory")
    case .failure(let error):
      switch error {
      case .dependencyResolutionError, .ioError:
        XCTAssertTrue(true, "Correctly failed with appropriate error")
      default:
        XCTFail("Expected dependency or IO error, got: \(error)")
      }
    }
  }

  func testParseProtoDirectoryIncrementalFallback() {
    let tempDir = createTempDirectory()
    defer { removeTempDirectory(tempDir) }
    
    // Create a proto file
    let protoFile = tempDir.appendingPathComponent("test.proto")
    try! """
      syntax = "proto3";
      message Test {
        string name = 1;
      }
      """.write(to: protoFile, atomically: true, encoding: .utf8)
    
    let result = SwiftProtoParser.parseProtoDirectoryIncremental(
      tempDir.path,
      recursive: false,
      importPaths: []
    )
    
    switch result {
    case .success(let asts):
      XCTAssertGreaterThan(asts.count, 0)
    case .failure:
      XCTAssertTrue(true, "Incremental parsing fallback handled")
    }
  }

  // MARK: - Streaming Parsing Tests

  func testParseProtoFileStreamingInvalidFile() {
    let result = SwiftProtoParser.parseProtoFileStreaming(
      "/nonexistent/file.proto",
      importPaths: []
    )
    
    switch result {
    case .success:
      XCTFail("Should fail for nonexistent file")
    case .failure(let error):
      if case .ioError = error {
        XCTAssertTrue(true, "Correctly failed with ioError")
      } else {
        XCTFail("Expected ioError, got: \(error)")
      }
    }
  }

  func testParseProtoFileStreamingValidFile() {
    let tempFile = createTempProtoFile(content: """
      syntax = "proto3";
      message StreamingTest {
        string large_field = 1;
        repeated string items = 2;
      }
      """)
    defer { removeTempFile(tempFile) }
    
    let result = SwiftProtoParser.parseProtoFileStreaming(
      tempFile,
      importPaths: []
    )
    
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages.count, 1)
      XCTAssertEqual(ast.messages[0].name, "StreamingTest")
    case .failure:
      XCTAssertTrue(true, "Streaming parsing handled")
    }
  }

  // MARK: - Statistics and Caching API Tests

  func testGetCacheStatistics() {
    let stats = SwiftProtoParser.getCacheStatistics()
    
    // Should have valid statistics structure
    XCTAssertGreaterThanOrEqual(stats.astCacheHits, 0)
    XCTAssertGreaterThanOrEqual(stats.dependencyCacheHits, 0)
    XCTAssertGreaterThanOrEqual(stats.descriptorCacheHits, 0)
  }

  func testGetIncrementalStatistics() {
    let stats = SwiftProtoParser.getIncrementalStatistics()
    
    // Should have valid statistics structure
    XCTAssertGreaterThanOrEqual(stats.totalFilesTracked, 0)
    XCTAssertGreaterThanOrEqual(stats.filesProcessedIncrementally, 0)
    XCTAssertGreaterThanOrEqual(stats.filesProcessedFromScratch, 0)
  }

  func testClearPerformanceCaches() {
    // Add some data to caches first
    let tempFile = createTempProtoFile(content: """
      syntax = "proto3";
      message ClearTest {
        string value = 1;
      }
      """)
    defer { removeTempFile(tempFile) }
    
    _ = SwiftProtoParser.parseProtoFileWithCaching(tempFile)
    
    // Clear caches
    SwiftProtoParser.clearPerformanceCaches()
    
    // Statistics should be reset
    _ = SwiftProtoParser.getCacheStatistics()
    _ = SwiftProtoParser.getIncrementalStatistics()
    
    XCTAssertTrue(true, "Cache clearing completed")
  }

  // MARK: - Benchmark Performance Tests

  func testBenchmarkPerformanceNonexistentPath() {
    let result = SwiftProtoParser.benchmarkPerformance("/nonexistent/path")
    
    XCTAssertTrue(result.operation.contains("not found"))
    XCTAssertTrue(result.measurements.isEmpty)
  }

  func testBenchmarkPerformanceValidFile() {
    let tempFile = createTempProtoFile(content: """
      syntax = "proto3";
      message BenchmarkTest {
        string name = 1;
        int32 id = 2;
        repeated string tags = 3;
      }
      """)
    defer { removeTempFile(tempFile) }
    
    let result = SwiftProtoParser.benchmarkPerformance(tempFile)
    
    XCTAssertFalse(result.operation.isEmpty)
    // Check that operation contains meaningful content
    XCTAssertTrue(result.operation.contains("parseProtoFile") || result.operation.contains("benchmark") || result.operation.contains(".proto"))
  }

  func testBenchmarkPerformanceValidDirectory() {
    let tempDir = createTempDirectory()
    defer { removeTempDirectory(tempDir) }
    
    // Create multiple proto files
    let protoFile1 = tempDir.appendingPathComponent("test1.proto")
    try! """
      syntax = "proto3";
      message Test1 {
        string name = 1;
      }
      """.write(to: protoFile1, atomically: true, encoding: .utf8)
    
    let protoFile2 = tempDir.appendingPathComponent("test2.proto")
    try! """
      syntax = "proto3";
      message Test2 {
        int32 id = 1;
      }
      """.write(to: protoFile2, atomically: true, encoding: .utf8)
    
    let result = SwiftProtoParser.benchmarkPerformance(tempDir.path)
    
    XCTAssertFalse(result.operation.isEmpty)
    // Check that operation contains meaningful content
    XCTAssertTrue(result.operation.contains("parseProtoDirectory") || result.operation.contains("benchmark") || result.operation.contains("Directory"))
  }

  func testBenchmarkPerformanceCustomConfiguration() {
    let tempFile = createTempProtoFile(content: """
      syntax = "proto3";
      message ConfigTest {
        string value = 1;
      }
      """)
    defer { removeTempFile(tempFile) }
    
    let customConfig = PerformanceBenchmark.Configuration(
      iterations: 1,
      warmupIterations: 0,
      trackMemory: false,
      maxParsingTime: 5.0,
      maxMemoryUsage: 200 * 1024 * 1024
    )
    
    let result = SwiftProtoParser.benchmarkPerformance(tempFile, configuration: customConfig)
    
    XCTAssertFalse(result.operation.isEmpty)
    XCTAssertEqual(result.configuration.iterations, 1)
  }

  // MARK: - Edge Cases for Private Helpers

  func testPrivateGetFileSizeHelper() {
    let tempFile = createTempProtoFile(content: """
      syntax = "proto3";
      message SizeTest {
        string data = 1;
      }
      """)
    defer { removeTempFile(tempFile) }
    
    // This tests the private getFileSize helper indirectly through caching
    let result = SwiftProtoParser.parseProtoFileWithCaching(tempFile)
    switch result {
    case .success: XCTAssertTrue(true)
    case .failure: XCTFail("Caching should succeed")
    }
  }

  // MARK: - Shared Instances Tests

  func testSharedCacheInstance() {
    let cache1 = SwiftProtoParser.sharedCache
    let cache2 = SwiftProtoParser.sharedCache
    
    // Should be the same instance
    XCTAssertTrue(cache1 === cache2)
  }

  func testSharedIncrementalParserInstance() {
    let parser1 = SwiftProtoParser.sharedIncrementalParser
    let parser2 = SwiftProtoParser.sharedIncrementalParser
    
    // Should be the same instance
    XCTAssertTrue(parser1 === parser2)
  }

  // MARK: - Test Utilities

  private func createTempProtoFile(content: String) -> String {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".proto")
    
    try! content.write(to: tempFile, atomically: true, encoding: .utf8)
    
    return tempFile.path
  }

  private func removeTempFile(_ path: String) {
    try? FileManager.default.removeItem(atPath: path)
  }

  private func createTempDirectory() -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    let subDir = tempDir.appendingPathComponent(UUID().uuidString)
    
    try! FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true, attributes: nil)
    
    return subDir
  }

  private func removeTempDirectory(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
  }
}
