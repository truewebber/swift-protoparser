import Foundation
import XCTest

@testable import SwiftProtoParser

final class IncrementalParserComprehensiveTests: XCTestCase {

  var tempDir: URL!
  var incrementalParser: IncrementalParser!
  var performanceCache: PerformanceCache!

  override func setUp() {
    super.setUp()
    tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    performanceCache = PerformanceCache(configuration: .default)
    incrementalParser = IncrementalParser(configuration: .default, cache: performanceCache)
  }

  override func tearDown() {
    if let tempDir = tempDir {
      try? FileManager.default.removeItem(at: tempDir)
    }
    incrementalParser = nil
    performanceCache = nil
    super.tearDown()
  }

  // MARK: - Configuration Tests

  func testDefaultConfiguration() {
    let config = IncrementalParser.Configuration.default
    XCTAssertEqual(config.maxInMemorySize, 50 * 1024 * 1024)
    XCTAssertEqual(config.streamingChunkSize, 64 * 1024)
    XCTAssertEqual(config.maxParallelFiles, 4)
    XCTAssertTrue(config.enableChangeDetection)
    XCTAssertTrue(config.enableResultCaching)
  }

  func testHighPerformanceConfiguration() {
    let config = IncrementalParser.Configuration.highPerformance
    XCTAssertEqual(config.maxInMemorySize, 200 * 1024 * 1024)
    XCTAssertEqual(config.streamingChunkSize, 256 * 1024)
    XCTAssertEqual(config.maxParallelFiles, 8)
    XCTAssertTrue(config.enableChangeDetection)
    XCTAssertTrue(config.enableResultCaching)
  }

  func testMemoryConstrainedConfiguration() {
    let config = IncrementalParser.Configuration.memoryConstrained
    XCTAssertEqual(config.maxInMemorySize, 10 * 1024 * 1024)
    XCTAssertEqual(config.streamingChunkSize, 16 * 1024)
    XCTAssertEqual(config.maxParallelFiles, 2)
    XCTAssertTrue(config.enableChangeDetection)
    XCTAssertFalse(config.enableResultCaching)
  }

  func testCustomConfiguration() {
    let customConfig = IncrementalParser.Configuration(
      maxInMemorySize: 100 * 1024 * 1024,
      streamingChunkSize: 128 * 1024,
      maxParallelFiles: 6,
      enableChangeDetection: false,
      enableResultCaching: true
    )

    let customParser = IncrementalParser(configuration: customConfig, cache: performanceCache)
    XCTAssertNotNil(customParser)
  }

  // MARK: - Change Detection Tests

  func testDetectChangesEmptyDirectory() throws {
    let changeSet = try incrementalParser.detectChanges(in: tempDir.path, recursive: false)

    XCTAssertTrue(changeSet.modifiedFiles.isEmpty)
    XCTAssertTrue(changeSet.affectedFiles.isEmpty)
    XCTAssertTrue(changeSet.addedFiles.isEmpty)
    XCTAssertTrue(changeSet.removedFiles.isEmpty)
    XCTAssertFalse(changeSet.hasChanges)
    XCTAssertEqual(changeSet.totalAffected, 0)
  }

  func testDetectChangesNewFiles() throws {
    // Create proto files
    let protoContent = """
      syntax = "proto3";
      package test;

      message TestMessage {
        string name = 1;
      }
      """

    let file1 = tempDir.appendingPathComponent("test1.proto")
    let file2 = tempDir.appendingPathComponent("test2.proto")

    try protoContent.write(to: file1, atomically: true, encoding: .utf8)
    try protoContent.write(to: file2, atomically: true, encoding: .utf8)

    let changeSet = try incrementalParser.detectChanges(in: tempDir.path, recursive: false)

    XCTAssertTrue(changeSet.modifiedFiles.isEmpty)
    XCTAssertTrue(changeSet.affectedFiles.isEmpty)
    XCTAssertEqual(changeSet.addedFiles.count, 2)
    XCTAssertTrue(changeSet.removedFiles.isEmpty)
    XCTAssertTrue(changeSet.hasChanges)
    XCTAssertEqual(changeSet.totalAffected, 2)

    XCTAssertTrue(changeSet.addedFiles.contains(file1.path))
    XCTAssertTrue(changeSet.addedFiles.contains(file2.path))
  }

  func testDetectChangesRecursive() throws {
    // Create subdirectory with proto files
    let subDir = tempDir.appendingPathComponent("subdir")
    try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

    let protoContent = """
      syntax = "proto3";
      message SubMessage { string value = 1; }
      """

    let mainFile = tempDir.appendingPathComponent("main.proto")
    let subFile = subDir.appendingPathComponent("sub.proto")

    try protoContent.write(to: mainFile, atomically: true, encoding: .utf8)
    try protoContent.write(to: subFile, atomically: true, encoding: .utf8)

    // Test recursive detection
    let recursiveChangeSet = try incrementalParser.detectChanges(in: tempDir.path, recursive: true)
    XCTAssertEqual(recursiveChangeSet.addedFiles.count, 2)

    // Test non-recursive detection
    let nonRecursiveChangeSet = try incrementalParser.detectChanges(in: tempDir.path, recursive: false)
    XCTAssertEqual(nonRecursiveChangeSet.addedFiles.count, 1)
    XCTAssertTrue(nonRecursiveChangeSet.addedFiles.contains(mainFile.path))
    XCTAssertFalse(nonRecursiveChangeSet.addedFiles.contains(subFile.path))
  }

  func testDetectChangesModifiedFiles() throws {
    let originalContent = """
      syntax = "proto3";
      message Original { string name = 1; }
      """

    let modifiedContent = """
      syntax = "proto3";
      message Modified { string name = 1; int32 value = 2; }
      """

    let protoFile = tempDir.appendingPathComponent("modified.proto")

    // Create original file
    try originalContent.write(to: protoFile, atomically: true, encoding: .utf8)

    // First detection - should show as added
    let firstChangeSet = try incrementalParser.detectChanges(in: tempDir.path, recursive: false)
    XCTAssertEqual(firstChangeSet.addedFiles.count, 1)

    // Process the added file to establish baseline
    _ = try incrementalParser.parseIncremental(changeSet: firstChangeSet)

    // Modify the file
    try modifiedContent.write(to: protoFile, atomically: true, encoding: .utf8)

    // Second detection - should show as modified
    let secondChangeSet = try incrementalParser.detectChanges(in: tempDir.path, recursive: false)
    XCTAssertEqual(secondChangeSet.modifiedFiles.count, 1)
    XCTAssertTrue(secondChangeSet.modifiedFiles.contains(protoFile.path))
  }

  func testDetectChangesRemovedFiles() throws {
    let protoContent = """
      syntax = "proto3";
      message ToBeRemoved { string name = 1; }
      """

    let protoFile = tempDir.appendingPathComponent("remove_me.proto")

    // Create file
    try protoContent.write(to: protoFile, atomically: true, encoding: .utf8)

    // First detection - establish baseline
    let firstChangeSet = try incrementalParser.detectChanges(in: tempDir.path, recursive: false)
    _ = try incrementalParser.parseIncremental(changeSet: firstChangeSet)

    // Remove file
    try FileManager.default.removeItem(at: protoFile)

    // Second detection - should show as removed
    let secondChangeSet = try incrementalParser.detectChanges(in: tempDir.path, recursive: false)
    XCTAssertEqual(secondChangeSet.removedFiles.count, 1)
    XCTAssertTrue(secondChangeSet.removedFiles.contains(protoFile.path))
  }

  // MARK: - Incremental Parsing Tests

  func testParseIncrementalEmptyChangeSet() throws {
    let emptyChangeSet = IncrementalParser.ChangeSet(
      modifiedFiles: [],
      affectedFiles: [],
      addedFiles: [],
      removedFiles: []
    )

    let results = try incrementalParser.parseIncremental(changeSet: emptyChangeSet)
    XCTAssertTrue(results.isEmpty)
  }

  func testParseIncrementalNewFiles() throws {
    let protoContent = """
      syntax = "proto3";
      package test.incremental;

      message IncrementalMessage {
        string name = 1;
        int32 value = 2;
      }
      """

    let file1 = tempDir.appendingPathComponent("incremental1.proto")
    let file2 = tempDir.appendingPathComponent("incremental2.proto")

    try protoContent.write(to: file1, atomically: true, encoding: .utf8)
    try protoContent.write(to: file2, atomically: true, encoding: .utf8)

    let changeSet = try incrementalParser.detectChanges(in: tempDir.path, recursive: false)
    let results = try incrementalParser.parseIncremental(changeSet: changeSet)

    XCTAssertEqual(results.count, 2)

    for (filePath, result) in results {
      switch result {
      case .success(let ast):
        XCTAssertEqual(ast.package, "test.incremental")
        XCTAssertEqual(ast.messages.count, 1)
        XCTAssertEqual(ast.messages.first?.name, "IncrementalMessage")
      case .failure(let error):
        XCTFail("Parsing should succeed for \(filePath): \(error)")
      }
    }
  }

  // MARK: - Streaming File Tests

  func testParseStreamingFileSmall() throws {
    let smallContent = """
      syntax = "proto3";
      message SmallMessage { string name = 1; }
      """

    let smallFile = tempDir.appendingPathComponent("small.proto")
    try smallContent.write(to: smallFile, atomically: true, encoding: .utf8)

    let result = try incrementalParser.parseStreamingFile(smallFile.path)

    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages.count, 1)
      XCTAssertEqual(ast.messages.first?.name, "SmallMessage")
    case .failure(let error):
      XCTFail("Small file parsing should succeed: \(error)")
    }
  }

  func testParseStreamingFileNonExistent() {
    let nonExistentFile = tempDir.appendingPathComponent("nonexistent.proto").path

    do {
      let result = try incrementalParser.parseStreamingFile(nonExistentFile)
      switch result {
      case .success:
        XCTFail("Non-existent file should not parse successfully")
      case .failure:
        XCTAssertTrue(true, "Non-existent file correctly failed")
      }
    }
    catch {
      XCTAssertTrue(true, "Non-existent file correctly threw error")
    }
  }

  // MARK: - Statistics Tests

  func testGetStatisticsInitial() {
    let stats = incrementalParser.getStatistics()

    XCTAssertEqual(stats.totalFilesTracked, 0)
    XCTAssertEqual(stats.filesProcessedIncrementally, 0)
    XCTAssertEqual(stats.filesProcessedFromScratch, 0)
    XCTAssertEqual(stats.totalParsingTime, 0.0)
    XCTAssertEqual(stats.incrementalSavings, 0.0)
    XCTAssertEqual(stats.memoryPeakUsage, 0)
    XCTAssertEqual(stats.incrementalEfficiency, 0.0)
  }

  func testStatisticsAfterParsing() throws {
    let protoContent = """
      syntax = "proto3";
      message StatsMessage { string data = 1; }
      """

    let protoFile = tempDir.appendingPathComponent("stats.proto")
    try protoContent.write(to: protoFile, atomically: true, encoding: .utf8)

    let changeSet = try incrementalParser.detectChanges(in: tempDir.path, recursive: false)
    _ = try incrementalParser.parseIncremental(changeSet: changeSet)

    let stats = incrementalParser.getStatistics()

    XCTAssertEqual(stats.totalFilesTracked, 1)
    XCTAssertEqual(stats.filesProcessedIncrementally, 1)
    XCTAssertGreaterThan(stats.totalParsingTime, 0.0)
    XCTAssertGreaterThanOrEqual(stats.incrementalEfficiency, 0.0)
    XCTAssertLessThanOrEqual(stats.incrementalEfficiency, 1.0)
  }

  // MARK: - Reset Tests

  func testReset() throws {
    let protoContent = """
      syntax = "proto3";
      message ResetMessage { string data = 1; }
      """

    let protoFile = tempDir.appendingPathComponent("reset.proto")
    try protoContent.write(to: protoFile, atomically: true, encoding: .utf8)

    // Parse some files to populate state
    let changeSet = try incrementalParser.detectChanges(in: tempDir.path, recursive: false)
    _ = try incrementalParser.parseIncremental(changeSet: changeSet)

    // Verify state is populated
    let statsBefore = incrementalParser.getStatistics()
    XCTAssertGreaterThan(statsBefore.totalFilesTracked, 0)

    // Reset
    incrementalParser.reset()

    // Wait for async reset to complete
    Thread.sleep(forTimeInterval: 0.1)

    // Verify state is cleared
    let statsAfter = incrementalParser.getStatistics()
    XCTAssertEqual(statsAfter.totalFilesTracked, 0)
    XCTAssertEqual(statsAfter.filesProcessedIncrementally, 0)
    XCTAssertEqual(statsAfter.totalParsingTime, 0.0)
  }

  // MARK: - Edge Cases and Error Handling Tests

  func testDetectChangesInvalidDirectory() {
    let invalidDir = "/nonexistent/directory/path"

    do {
      _ = try incrementalParser.detectChanges(in: invalidDir, recursive: false)
      XCTFail("Should fail for invalid directory")
    }
    catch {
      XCTAssertTrue(true, "Invalid directory correctly threw error")
    }
  }

  func testChangeSetProperties() {
    let changeSet = IncrementalParser.ChangeSet(
      modifiedFiles: ["file1.proto", "file2.proto"],
      affectedFiles: ["file3.proto"],
      addedFiles: ["file4.proto", "file5.proto"],
      removedFiles: ["file6.proto"]
    )

    XCTAssertEqual(changeSet.totalAffected, 5)  // modified + affected + added
    XCTAssertTrue(changeSet.hasChanges)

    let emptyChangeSet = IncrementalParser.ChangeSet(
      modifiedFiles: [],
      affectedFiles: [],
      addedFiles: [],
      removedFiles: []
    )

    XCTAssertEqual(emptyChangeSet.totalAffected, 0)
    XCTAssertFalse(emptyChangeSet.hasChanges)
  }

  func testBatchProcessingIndirectly() throws {
    // Test batch processing indirectly by creating many files
    // This will exercise the internal chunking logic without direct access
    let protoContent = """
      syntax = "proto3";
      message BatchMessage$INDEX { string data = 1; }
      """

    // Create more files than maxParallelFiles to force batching
    for i in 1...10 {
      let content = protoContent.replacingOccurrences(of: "$INDEX", with: "\(i)")
      let file = tempDir.appendingPathComponent("batch\(i).proto")
      try content.write(to: file, atomically: true, encoding: .utf8)
    }

    let changeSet = try incrementalParser.detectChanges(in: tempDir.path, recursive: false)
    let results = try incrementalParser.parseIncremental(changeSet: changeSet)

    XCTAssertEqual(results.count, 10)

    // All files should parse successfully, testing internal batching
    for (_, result) in results {
      switch result {
      case .success:
        XCTAssertTrue(true, "Batch file parsed successfully")
      case .failure(let error):
        XCTFail("Batch file should parse successfully: \(error)")
      }
    }
  }

  // MARK: - Integration Tests

  func testFullIncrementalWorkflow() throws {
    // Test complete workflow: detect changes -> parse -> modify -> detect again -> parse

    let originalContent = """
      syntax = "proto3";
      package workflow.test;

      message WorkflowMessage {
        string name = 1;
      }
      """

    let workflowFile = tempDir.appendingPathComponent("workflow.proto")
    try originalContent.write(to: workflowFile, atomically: true, encoding: .utf8)

    // Step 1: Initial detection and parsing
    let changeSet1 = try incrementalParser.detectChanges(in: tempDir.path, recursive: false)
    XCTAssertEqual(changeSet1.addedFiles.count, 1)

    let results1 = try incrementalParser.parseIncremental(changeSet: changeSet1)
    XCTAssertEqual(results1.count, 1)

    // Step 2: No changes - should detect nothing
    let changeSet2 = try incrementalParser.detectChanges(in: tempDir.path, recursive: false)
    XCTAssertFalse(changeSet2.hasChanges)

    let results2 = try incrementalParser.parseIncremental(changeSet: changeSet2)
    XCTAssertTrue(results2.isEmpty)

    // Step 3: Modify file
    let modifiedContent = """
      syntax = "proto3";
      package workflow.test;

      message WorkflowMessage {
        string name = 1;
        int32 version = 2;
      }
      """

    try modifiedContent.write(to: workflowFile, atomically: true, encoding: .utf8)

    // Step 4: Detect modification
    let changeSet3 = try incrementalParser.detectChanges(in: tempDir.path, recursive: false)
    XCTAssertEqual(changeSet3.modifiedFiles.count, 1)

    let results3 = try incrementalParser.parseIncremental(changeSet: changeSet3)
    XCTAssertEqual(results3.count, 1)

    // Verify the modification was parsed correctly
    if case .success(let ast) = results3.values.first! {
      XCTAssertEqual(ast.messages.first?.fields.count, 2)
    }
    else {
      XCTFail("Modified file should parse successfully")
    }

    // Step 5: Check statistics
    let finalStats = incrementalParser.getStatistics()
    XCTAssertEqual(finalStats.totalFilesTracked, 1)
    XCTAssertEqual(finalStats.filesProcessedIncrementally, 2)  // initial + modification
    XCTAssertGreaterThan(finalStats.totalParsingTime, 0.0)
  }
}
