import Foundation
import XCTest

@testable import SwiftProtoParser

final class PerformanceAPITests: XCTestCase {

  var tempDir: URL!

  override func setUp() {
    super.setUp()
    tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent(UUID().uuidString)
    try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
  }

  override func tearDown() {
    if let tempDir = tempDir {
      try? FileManager.default.removeItem(at: tempDir)
    }
    super.tearDown()
  }

  // MARK: - Parsing Tests (previously tested via caching API)

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

    // First parse
    let result1 = SwiftProtoParser.parseFile(protoFile.path)
    XCTAssertTrue(result1.isSuccess)

    if case .success(let set1) = result1 {
      XCTAssertEqual(set1.file[0].package, "test.caching")
      XCTAssertEqual(set1.file[0].messageType.count, 1)
      XCTAssertEqual(set1.file[0].messageType[0].name, "CachedMessage")
    }

    // Second parse — result must be consistent
    let result2 = SwiftProtoParser.parseFile(protoFile.path)
    XCTAssertTrue(result2.isSuccess)

    if case .success(let set2) = result2 {
      XCTAssertEqual(set2.file[0].package, "test.caching")
      XCTAssertEqual(set2.file[0].messageType.count, 1)
    }
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

    let result = SwiftProtoParser.parseFile(protoFile.path)
    XCTAssertTrue(result.isSuccess)

    if case .success(let set) = result {
      XCTAssertEqual(set.file[0].package, "test.nocaching")
      XCTAssertEqual(set.file[0].messageType.count, 1)
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
    let result1 = SwiftProtoParser.parseFile(protoFile.path)
    XCTAssertTrue(result1.isSuccess)

    if case .success(let set1) = result1 {
      XCTAssertEqual(set1.file[0].messageType[0].name, "OriginalMessage")
    }

    // Modify file content and parse again
    try! modifiedContent.write(to: protoFile, atomically: true, encoding: .utf8)

    let result2 = SwiftProtoParser.parseFile(protoFile.path)
    XCTAssertTrue(result2.isSuccess)

    if case .success(let set2) = result2 {
      XCTAssertEqual(set2.file[0].messageType[0].name, "ModifiedMessage")
      XCTAssertEqual(set2.file[0].messageType[0].field.count, 2)
    }
  }

  // MARK: - Directory Parsing Tests (previously tested via incremental API)

  func testParseProtoDirectoryIncremental() {
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

    let result = SwiftProtoParser.parseDirectory(tempDir.path)
    XCTAssertTrue(result.isSuccess)

    if case .success(let set) = result {
      XCTAssertEqual(set.file.count, 2)

      let messageNames = set.file.flatMap { $0.messageType.map { $0.name } }
      XCTAssertTrue(messageNames.contains("Message1"))
      XCTAssertTrue(messageNames.contains("Message2"))
    }
  }

  // MARK: - Large File Tests (previously tested via streaming API)

  func testParseProtoFileStreaming() {
    var largeContent = """
      syntax = "proto3";
      package test.streaming;

      """

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

    let result = SwiftProtoParser.parseFile(largeFile.path)
    XCTAssertTrue(result.isSuccess)

    if case .success(let set) = result {
      XCTAssertEqual(set.file[0].package, "test.streaming")
      XCTAssertEqual(set.file[0].messageType.count, 100)
    }
  }

  // MARK: - Statistics Tests (functional equivalents)

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

    // Parse file (first call)
    let result1 = SwiftProtoParser.parseFile(protoFile.path)
    XCTAssertTrue(result1.isSuccess)

    // Parse again (second call — internally may use cache)
    let result2 = SwiftProtoParser.parseFile(protoFile.path)
    XCTAssertTrue(result2.isSuccess)

    // Results should be consistent
    if case .success(let set1) = result1, case .success(let set2) = result2 {
      XCTAssertEqual(set1.file[0].messageType.count, set2.file[0].messageType.count)
      XCTAssertEqual(set1.file[0].messageType[0].name, set2.file[0].messageType[0].name)
    }
  }

  func testIncrementalStatistics() {
    let protoContent = """
      syntax = "proto3";
      package test.incremental.stats;

      message IncrementalMessage {
        string name = 1;
      }
      """

    let protoFile = tempDir.appendingPathComponent("incremental.proto")
    try! protoContent.write(to: protoFile, atomically: true, encoding: .utf8)

    // Parse directory — should succeed
    let result = SwiftProtoParser.parseDirectory(tempDir.path)
    XCTAssertTrue(result.isSuccess)

    if case .success(let set) = result {
      XCTAssertGreaterThanOrEqual(set.file.count, 1)
    }
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

    // Parse to populate internal caches
    let result1 = SwiftProtoParser.parseFile(protoFile.path)
    XCTAssertTrue(result1.isSuccess)

    // Parse again — should still work correctly regardless of internal cache state
    let result2 = SwiftProtoParser.parseFile(protoFile.path)
    XCTAssertTrue(result2.isSuccess)

    if case .success(let set1) = result1, case .success(let set2) = result2 {
      XCTAssertEqual(set1.file[0].messageType[0].name, set2.file[0].messageType[0].name)
    }
  }

  // MARK: - Benchmark Tests (functional equivalents)

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

    // Run parseFile multiple times (simulates benchmark iterations)
    var results: [Bool] = []
    for _ in 1...3 {
      let result = SwiftProtoParser.parseFile(protoFile.path)
      results.append(result.isSuccess)
    }

    let successCount = results.filter { $0 }.count
    XCTAssertEqual(successCount, 3)
    XCTAssertGreaterThan(results.count, 0)
  }

  func testBenchmarkDirectoryPerformance() {
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

    // Run parseDirectory multiple times (simulates benchmark iterations)
    var results: [Bool] = []
    for _ in 1...2 {
      let result = SwiftProtoParser.parseDirectory(tempDir.path)
      results.append(result.isSuccess)
    }

    let successCount = results.filter { $0 }.count
    XCTAssertEqual(successCount, 2)
  }

  func testBenchmarkNonExistentPath() {
    let result = SwiftProtoParser.parseFile("/nonexistent/path")

    switch result {
    case .success:
      XCTFail("Non-existent path should fail")
    case .failure:
      break
    }
  }

  // MARK: - Error Handling Tests

  func testParseProtoFileWithCachingError() {
    let result = SwiftProtoParser.parseFile("/nonexistent/file.proto")
    XCTAssertTrue(result.isFailure)

    if case .failure(let error) = result {
      XCTAssertTrue(
        error.description.contains("I/O error") || error.description.contains("Dependency")
          || error.description.contains("No such file")
      )
    }
  }

  func testParseProtoFileStreamingError() {
    let result = SwiftProtoParser.parseFile("/nonexistent/large.proto")
    XCTAssertTrue(result.isFailure)

    if case .failure(let error) = result {
      XCTAssertTrue(
        error.description.contains("I/O error") || error.description.contains("Dependency")
          || error.description.contains("No such file")
      )
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

    // Parse 10 times — all should succeed
    var allSucceeded = true
    for _ in 0..<10 {
      let result = SwiftProtoParser.parseFile(protoFile.path)
      if result.isFailure { allSucceeded = false }
    }

    XCTAssertTrue(allSucceeded, "All 10 parsing attempts should succeed")

    // Verify final result correctness
    if case .success(let set) = SwiftProtoParser.parseFile(protoFile.path) {
      XCTAssertEqual(set.file[0].messageType[0].name, "PerformanceMessage")
    }
  }
}
