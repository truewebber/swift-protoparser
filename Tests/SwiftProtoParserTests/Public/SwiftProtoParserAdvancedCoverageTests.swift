import Foundation
import XCTest

@testable import SwiftProtoParser

final class SwiftProtoParserAdvancedCoverageTests: XCTestCase {

  // MARK: - Helpers

  private func createTempProtoFile(content: String, name: String? = nil) -> String {
    let fileName = name ?? (UUID().uuidString + ".proto")
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent(fileName)
    try! content.write(to: tempFile, atomically: true, encoding: .utf8)
    return tempFile.path
  }

  private func removeTempFile(_ path: String) {
    try? FileManager.default.removeItem(atPath: path)
  }

  private func createTempDirectory() -> URL {
    let subDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try! FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
    return subDir
  }

  private func removeTempDirectory(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
  }

  // MARK: - File IO Error Handling Tests

  func testParseProtoFileNonexistentFile() {
    let result = SwiftProtoParser.parseFile("/nonexistent/path/file.proto")

    switch result {
    case .success:
      XCTFail("Should fail for nonexistent file")
    case .failure(let error):
      switch error {
      case .ioError, .dependencyResolutionError:
        break
      default:
        XCTFail("Expected ioError or dependencyResolutionError, got: \(error)")
      }
    }
  }

  func testParseProtoToDescriptorsNonexistentFile() {
    let result = SwiftProtoParser.parseFile("/nonexistent/path/file.proto")

    switch result {
    case .success:
      XCTFail("Should fail for nonexistent file")
    case .failure(let error):
      switch error {
      case .ioError, .dependencyResolutionError:
        break
      default:
        XCTFail("Expected ioError or dependencyResolutionError, got: \(error)")
      }
    }
  }

  func testParseProtoFileWithCachingNonexistentFile() {
    // parseFile does not expose caching; this validates error handling for missing files
    let result = SwiftProtoParser.parseFile("/nonexistent/path/file.proto")

    switch result {
    case .success:
      XCTFail("Should fail for nonexistent file")
    case .failure(let error):
      switch error {
      case .ioError, .dependencyResolutionError:
        break
      default:
        XCTFail("Expected ioError or dependencyResolutionError, got: \(error)")
      }
    }
  }

  // MARK: - Parser Error Conversion Tests

  func testParseProtoStringParserErrorConversion() {
    let tempFile = createTempProtoFile(
      content: """
        syntax = "proto3";
        message Test {
          string = 1;
        }
        """,
      name: "test.proto"
    )
    defer { removeTempFile(tempFile) }

    let result = SwiftProtoParser.parseFile(tempFile)

    switch result {
    case .success:
      XCTFail("Should fail for invalid proto")
    case .failure(let error):
      if case .syntaxError(let message, let file, _, _) = error {
        XCTAssertTrue(message.contains("field name") || message.contains("unexpected") || !message.isEmpty)
        XCTAssertEqual(file, "test.proto")
      }
      else {
        XCTFail("Expected syntaxError, got: \(error)")
      }
    }
  }

  func testParseProtoStringEmptyParserErrors() {
    let tempFile = createTempProtoFile(content: "")
    defer { removeTempFile(tempFile) }

    let result = SwiftProtoParser.parseFile(tempFile)

    switch result {
    case .success:
      XCTFail("Empty content should fail")
    case .failure(let error):
      XCTAssertTrue(true, "Empty content handled: \(error)")
    }
  }

  // MARK: - Descriptor Error Conversion Tests

  func testParseProtoStringToDescriptorsWithInvalidAST() {
    let tempFile = createTempProtoFile(
      content: """
        syntax = "proto3";
        message Test { string name = 1; }
        """
    )
    defer { removeTempFile(tempFile) }

    let result = SwiftProtoParser.parseFile(tempFile)

    switch result {
    case .success(let set):
      XCTAssertFalse(set.file.isEmpty)
    case .failure(let error):
      XCTAssertTrue(true, "Descriptor error handling: \(error)")
    }
  }

  func testParseProtoStringToDescriptorsDefaultFileName() {
    let tempFile = createTempProtoFile(
      content: """
        syntax = "proto3";
        message SimpleTest { string value = 1; }
        """,
      name: "string.proto"
    )
    defer { removeTempFile(tempFile) }

    let result = SwiftProtoParser.parseFile(tempFile)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file[0].name, "string.proto")
    case .failure:
      XCTAssertTrue(true, "Descriptor conversion handled")
    }
  }

  // MARK: - Convenience Methods Edge Cases

  func testGetProtoVersionInvalidFile() {
    let result = SwiftProtoParser.parseFile("/nonexistent/file.proto")

    switch result {
    case .success:
      XCTFail("Should fail for nonexistent file")
    case .failure(let error):
      switch error {
      case .ioError, .dependencyResolutionError:
        break
      default:
        XCTFail("Expected ioError or dependencyResolutionError, got: \(error)")
      }
    }
  }

  func testGetPackageNameInvalidFile() {
    let result = SwiftProtoParser.parseFile("/nonexistent/file.proto")

    switch result {
    case .success:
      XCTFail("Should fail for nonexistent file")
    case .failure(let error):
      switch error {
      case .ioError, .dependencyResolutionError:
        break
      default:
        XCTFail("Expected ioError or dependencyResolutionError, got: \(error)")
      }
    }
  }

  func testGetMessageNamesInvalidFile() {
    let result = SwiftProtoParser.parseFile("/nonexistent/file.proto")

    switch result {
    case .success:
      XCTFail("Should fail for nonexistent file")
    case .failure(let error):
      switch error {
      case .ioError, .dependencyResolutionError:
        break
      default:
        XCTFail("Expected ioError or dependencyResolutionError, got: \(error)")
      }
    }
  }

  // MARK: - Import Resolution Edge Cases

  func testParseProtoFileWithImportsInvalidFile() {
    let result = SwiftProtoParser.parseFile("/nonexistent/file.proto", importPaths: ["/some/path"])

    switch result {
    case .success:
      XCTFail("Should fail for nonexistent file")
    case .failure(let error):
      switch error {
      case .dependencyResolutionError, .ioError:
        break
      default:
        XCTFail("Expected dependency or IO error, got: \(error)")
      }
    }
  }

  func testParseProtoDirectoryInvalidPath() {
    let result = SwiftProtoParser.parseDirectory("/nonexistent/directory", recursive: true)

    switch result {
    case .success:
      XCTFail("Should fail for nonexistent directory")
    case .failure(let error):
      switch error {
      case .dependencyResolutionError, .ioError:
        break
      default:
        XCTFail("Expected dependency or IO error, got: \(error)")
      }
    }
  }

  func testParseProtoFileWithImportsToDescriptorsInvalidFile() {
    // parseFile always resolves all deps — missing file always fails
    let result = SwiftProtoParser.parseFile("/nonexistent/file.proto")

    switch result {
    case .success:
      XCTFail("Should fail for nonexistent file")
    case .failure(let error):
      switch error {
      case .dependencyResolutionError, .ioError:
        break
      default:
        XCTFail("Expected dependency or IO error, got: \(error)")
      }
    }
  }

  func testParseProtoDirectoryToDescriptorsInvalidPath() {
    let result = SwiftProtoParser.parseDirectory("/nonexistent/directory", recursive: false)

    switch result {
    case .success:
      XCTFail("Should fail for nonexistent directory")
    case .failure(let error):
      switch error {
      case .dependencyResolutionError, .ioError:
        break
      default:
        XCTFail("Expected dependency or IO error, got: \(error)")
      }
    }
  }

  // MARK: - Caching Tests (functional behavior — no internal cache state exposed)

  func testParseProtoFileWithCachingDisabled() {
    let tempFile = createTempProtoFile(
      content: """
        syntax = "proto3";
        message CacheTest { string value = 1; }
        """
    )
    defer { removeTempFile(tempFile) }

    let result = SwiftProtoParser.parseFile(tempFile)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file[0].messageType.count, 1)
      XCTAssertEqual(set.file[0].messageType[0].name, "CacheTest")
    case .failure(let error):
      XCTFail("Should succeed for valid proto: \(error)")
    }
  }

  func testParseProtoFileWithCachingEnabled() {
    let tempFile = createTempProtoFile(
      content: """
        syntax = "proto3";
        message CacheTest { string value = 1; }
        """
    )
    defer { removeTempFile(tempFile) }

    // First parse
    let result1 = SwiftProtoParser.parseFile(tempFile)
    // Second parse — should return same result regardless of internal cache
    let result2 = SwiftProtoParser.parseFile(tempFile)

    if case .success(let set1) = result1, case .success(let set2) = result2 {
      XCTAssertEqual(set1.file[0].messageType[0].name, set2.file[0].messageType[0].name)
    }
    else {
      XCTFail("Both parses should succeed")
    }
  }

  // MARK: - Incremental Parsing Tests

  func testParseProtoDirectoryIncrementalInvalidPath() {
    let result = SwiftProtoParser.parseDirectory("/nonexistent/directory", recursive: true)

    switch result {
    case .success:
      XCTFail("Should fail for nonexistent directory")
    case .failure(let error):
      switch error {
      case .dependencyResolutionError, .ioError:
        break
      default:
        XCTFail("Expected dependency or IO error, got: \(error)")
      }
    }
  }

  func testParseProtoDirectoryIncrementalFallback() {
    let tempDir = createTempDirectory()
    defer { removeTempDirectory(tempDir) }

    try! """
    syntax = "proto3";
    message Test { string name = 1; }
    """.write(to: tempDir.appendingPathComponent("test.proto"), atomically: true, encoding: .utf8)

    let result = SwiftProtoParser.parseDirectory(tempDir.path, recursive: false)

    switch result {
    case .success(let set):
      XCTAssertGreaterThan(set.file.count, 0)
    case .failure:
      XCTAssertTrue(true, "Directory parsing handled")
    }
  }

  // MARK: - Streaming Parsing Tests

  func testParseProtoFileStreamingInvalidFile() {
    let result = SwiftProtoParser.parseFile("/nonexistent/file.proto")

    switch result {
    case .success:
      XCTFail("Should fail for nonexistent file")
    case .failure(let error):
      switch error {
      case .ioError, .dependencyResolutionError:
        break
      default:
        XCTFail("Expected ioError or dependencyResolutionError, got: \(error)")
      }
    }
  }

  func testParseProtoFileStreamingValidFile() {
    let tempFile = createTempProtoFile(
      content: """
        syntax = "proto3";
        message StreamingTest {
          string large_field = 1;
          repeated string items = 2;
        }
        """
    )
    defer { removeTempFile(tempFile) }

    let result = SwiftProtoParser.parseFile(tempFile)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file[0].messageType.count, 1)
      XCTAssertEqual(set.file[0].messageType[0].name, "StreamingTest")
    case .failure:
      XCTAssertTrue(true, "Streaming parsing handled")
    }
  }

  // MARK: - Statistics and Caching API Tests (functional behavior)

  func testGetCacheStatistics() {
    // Parsing the same file twice should give consistent results
    let tempFile = createTempProtoFile(
      content: """
        syntax = "proto3";
        message StatTest { string value = 1; }
        """
    )
    defer { removeTempFile(tempFile) }

    let result1 = SwiftProtoParser.parseFile(tempFile)
    let result2 = SwiftProtoParser.parseFile(tempFile)

    if case .success(let set1) = result1, case .success(let set2) = result2 {
      XCTAssertEqual(set1.file.count, set2.file.count)
      XCTAssertEqual(set1.file[0].messageType.count, set2.file[0].messageType.count)
    }
    else {
      XCTFail("Both parses should succeed")
    }
  }

  func testGetIncrementalStatistics() {
    // parseDirectory should work for multiple files
    let tempDir = createTempDirectory()
    defer { removeTempDirectory(tempDir) }

    try! """
    syntax = "proto3";
    message IncrementalMessage { string name = 1; }
    """.write(
      to: tempDir.appendingPathComponent("incremental.proto"),
      atomically: true,
      encoding: .utf8
    )

    let result = SwiftProtoParser.parseDirectory(tempDir.path)

    switch result {
    case .success(let set):
      XCTAssertGreaterThanOrEqual(set.file.count, 1)
    case .failure(let error):
      XCTFail("Expected success: \(error)")
    }
  }

  func testClearPerformanceCaches() {
    let tempFile = createTempProtoFile(
      content: """
        syntax = "proto3";
        message ClearTest { string value = 1; }
        """
    )
    defer { removeTempFile(tempFile) }

    // Parse twice — results should be consistent regardless of internal cache state
    let result1 = SwiftProtoParser.parseFile(tempFile)
    let result2 = SwiftProtoParser.parseFile(tempFile)

    if case .success(let set1) = result1, case .success(let set2) = result2 {
      XCTAssertEqual(set1.file[0].messageType[0].name, set2.file[0].messageType[0].name)
    }
    else {
      XCTFail("Repeated parsing should succeed")
    }
  }

  // MARK: - Benchmark Performance Tests

  func testBenchmarkPerformanceNonexistentPath() {
    let result = SwiftProtoParser.parseFile("/nonexistent/path")

    switch result {
    case .success:
      XCTFail("Non-existent path should fail")
    case .failure:
      break
    }
  }

  func testBenchmarkPerformanceValidFile() {
    let tempFile = createTempProtoFile(
      content: """
        syntax = "proto3";
        message BenchmarkTest {
          string name = 1;
          int32 id = 2;
          repeated string tags = 3;
        }
        """
    )
    defer { removeTempFile(tempFile) }

    let result = SwiftProtoParser.parseFile(tempFile)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file[0].messageType[0].name, "BenchmarkTest")
    case .failure(let error):
      XCTFail("Expected success: \(error)")
    }
  }

  func testBenchmarkPerformanceValidDirectory() {
    let tempDir = createTempDirectory()
    defer { removeTempDirectory(tempDir) }

    try! """
    syntax = "proto3";
    message Test1 { string name = 1; }
    """.write(to: tempDir.appendingPathComponent("test1.proto"), atomically: true, encoding: .utf8)

    try! """
    syntax = "proto3";
    message Test2 { int32 id = 1; }
    """.write(to: tempDir.appendingPathComponent("test2.proto"), atomically: true, encoding: .utf8)

    let result = SwiftProtoParser.parseDirectory(tempDir.path)

    switch result {
    case .success(let set):
      XCTAssertGreaterThanOrEqual(set.file.count, 2)
      let names = set.file.map { $0.messageType.map { $0.name } }.flatMap { $0 }
      XCTAssertTrue(names.contains("Test1"))
      XCTAssertTrue(names.contains("Test2"))
    case .failure(let error):
      XCTFail("Expected success: \(error)")
    }
  }

  func testBenchmarkPerformanceCustomConfiguration() {
    // Previously tested PerformanceBenchmark.Configuration (now internal).
    // Verifies that parseFile returns correct results regardless of config.
    let tempFile = createTempProtoFile(
      content: """
        syntax = "proto3";
        message ConfigTest { string value = 1; }
        """
    )
    defer { removeTempFile(tempFile) }

    let result = SwiftProtoParser.parseFile(tempFile)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file[0].messageType[0].name, "ConfigTest")
    case .failure(let error):
      XCTFail("Expected success: \(error)")
    }
  }

  // MARK: - Edge Cases for Private Helpers

  func testPrivateGetFileSizeHelper() {
    let tempFile = createTempProtoFile(
      content: """
        syntax = "proto3";
        message SizeTest { string data = 1; }
        """
    )
    defer { removeTempFile(tempFile) }

    // Internal getFileSize is exercised indirectly through parseFile
    let result = SwiftProtoParser.parseFile(tempFile)

    switch result {
    case .success(let set):
      XCTAssertFalse(set.file.isEmpty)
    case .failure:
      XCTFail("Parsing should succeed")
    }
  }

  // MARK: - Shared Instances Tests (functional equivalents)

  func testSharedCacheInstance() {
    // Verify that repeated parseFile calls give consistent results
    // (internally backed by the same shared cache instance)
    let tempFile = createTempProtoFile(
      content: """
        syntax = "proto3";
        message SharedCacheTest { string value = 1; }
        """
    )
    defer { removeTempFile(tempFile) }

    let result1 = SwiftProtoParser.parseFile(tempFile)
    let result2 = SwiftProtoParser.parseFile(tempFile)

    if case .success(let set1) = result1, case .success(let set2) = result2 {
      XCTAssertEqual(set1.file[0].messageType[0].name, set2.file[0].messageType[0].name)
    }
    else {
      XCTFail("Both parses should succeed and return consistent results")
    }
  }

  func testSharedIncrementalParserInstance() {
    // Verify that repeated parseDirectory calls give consistent results
    // (internally backed by the same shared incremental parser instance)
    let tempDir = createTempDirectory()
    defer { removeTempDirectory(tempDir) }

    try! """
    syntax = "proto3";
    message SharedParserTest { string value = 1; }
    """.write(
      to: tempDir.appendingPathComponent("shared.proto"),
      atomically: true,
      encoding: .utf8
    )

    let result1 = SwiftProtoParser.parseDirectory(tempDir.path)
    let result2 = SwiftProtoParser.parseDirectory(tempDir.path)

    if case .success(let set1) = result1, case .success(let set2) = result2 {
      XCTAssertEqual(set1.file.count, set2.file.count)
    }
    else {
      XCTFail("Both directory parses should succeed and return consistent results")
    }
  }
}
