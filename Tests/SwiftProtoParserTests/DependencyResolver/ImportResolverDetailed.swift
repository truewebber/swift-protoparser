import Foundation
import XCTest

@testable import SwiftProtoParser

final class ImportResolverDetailedTests: XCTestCase {

  private var tempDir: URL!
  private var scanner: FileSystemScanner!
  private var resolver: ImportResolver!

  override func setUpWithError() throws {
    try super.setUpWithError()
    tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    scanner = FileSystemScanner(importPaths: [tempDir.path])
    resolver = ImportResolver(scanner: scanner)
  }

  override func tearDownWithError() throws {
    if FileManager.default.fileExists(atPath: tempDir.path) {
      try FileManager.default.removeItem(at: tempDir)
    }
    try super.tearDownWithError()
  }

  // MARK: - Individual Import Resolution Tests

  func testResolveImportSingleFile() throws {
    let depContent = """
      syntax = "proto3";
      package dep;

      message DepMessage {
          string value = 1;
      }
      """

    let depFile = tempDir.appendingPathComponent("dep.proto")
    try depContent.write(to: depFile, atomically: true, encoding: .utf8)

    let resolved = try resolver.resolveImport("dep.proto", fromFile: tempDir.path)

    XCTAssertEqual(resolved, depFile.path)
  }

  func testResolveImportWellKnownType() throws {
    let resolved = try resolver.resolveImport("google/protobuf/timestamp.proto", fromFile: tempDir.path)

    XCTAssertEqual(resolved, "google/protobuf/timestamp.proto")
  }

  func testResolveImportNotFound() {
    XCTAssertThrowsError(try resolver.resolveImport("nonexistent.proto", fromFile: tempDir.path)) { error in
      guard let resolverError = error as? ResolverError else {
        XCTFail("Expected ResolverError")
        return
      }

      if case .importNotFound(let importPath, _) = resolverError {
        XCTAssertEqual(importPath, "nonexistent.proto")
      }
      else {
        XCTFail("Expected importNotFound error")
      }
    }
  }

  func testResolveImportCache() throws {
    let depContent = """
      syntax = "proto3";
      package dep;

      message DepMessage {
          string value = 1;
      }
      """

    let depFile = tempDir.appendingPathComponent("dep.proto")
    try depContent.write(to: depFile, atomically: true, encoding: .utf8)

    let resolved1 = try resolver.resolveImport("dep.proto", fromFile: tempDir.path)
    let resolved2 = try resolver.resolveImport("dep.proto", fromFile: tempDir.path)

    XCTAssertEqual(resolved1, resolved2)

    let stats = resolver.cacheStats
    XCTAssertGreaterThan(stats.size, 0)
  }

  // MARK: - Multiple Import Resolution Tests

  func testResolveImportsFromFile() throws {
    // Create dependency files
    let dep1Content = "syntax = \"proto3\"; package dep1; message Dep1Message { string name = 1; }"
    let dep2Content = "syntax = \"proto3\"; package dep2; message Dep2Message { int32 value = 1; }"

    let dep1File = tempDir.appendingPathComponent("dep1.proto")
    let dep2File = tempDir.appendingPathComponent("dep2.proto")

    try dep1Content.write(to: dep1File, atomically: true, encoding: .utf8)
    try dep2Content.write(to: dep2File, atomically: true, encoding: .utf8)

    // Create main file with imports
    let mainContent = """
      syntax = "proto3";
      package main;

      import "dep1.proto";
      import "dep2.proto";
      import "google/protobuf/timestamp.proto";

      message MainMessage {
          Dep1Message dep1 = 1;
          Dep2Message dep2 = 2;
          google.protobuf.Timestamp created_at = 3;
      }
      """

    let mainFile = tempDir.appendingPathComponent("main.proto")
    try mainContent.write(to: mainFile, atomically: true, encoding: .utf8)

    let resolvedFile = try ResolvedProtoFile.from(filePath: mainFile.path)
    let resolvedImports = try resolver.resolveImports(from: resolvedFile)

    XCTAssertEqual(resolvedImports.count, 3)
    XCTAssertTrue(resolvedImports.contains(dep1File.path))
    XCTAssertTrue(resolvedImports.contains(dep2File.path))
    XCTAssertTrue(resolvedImports.contains("google/protobuf/timestamp.proto"))
  }

  func testResolveImportsRecursively() throws {
    // Create chain: main -> dep1 -> dep2
    let dep2Content = """
      syntax = "proto3";
      package dep2;

      message BaseMessage {
          string id = 1;
      }
      """

    let dep1Content = """
      syntax = "proto3";
      package dep1;

      import "dep2.proto";

      message MiddleMessage {
          BaseMessage base = 1;
      }
      """

    let mainContent = """
      syntax = "proto3";
      package main;

      import "dep1.proto";

      message MainMessage {
          MiddleMessage middle = 1;
      }
      """

    let dep2File = tempDir.appendingPathComponent("dep2.proto")
    let dep1File = tempDir.appendingPathComponent("dep1.proto")
    let mainFile = tempDir.appendingPathComponent("main.proto")

    try dep2Content.write(to: dep2File, atomically: true, encoding: .utf8)
    try dep1Content.write(to: dep1File, atomically: true, encoding: .utf8)
    try mainContent.write(to: mainFile, atomically: true, encoding: .utf8)

    let resolvedFile = try ResolvedProtoFile.from(filePath: mainFile.path)
    let allImports = try resolver.resolveImportsRecursively(from: resolvedFile)

    XCTAssertEqual(allImports.count, 2)
    XCTAssertTrue(allImports.contains(dep1File.path))
    XCTAssertTrue(allImports.contains(dep2File.path))
  }

  func testResolveImportsRecursivelyWithWellKnownTypes() throws {
    let dep1Content = """
      syntax = "proto3";
      package dep1;

      import "google/protobuf/timestamp.proto";

      message DepMessage {
          google.protobuf.Timestamp created_at = 1;
      }
      """

    let mainContent = """
      syntax = "proto3";
      package main;

      import "dep1.proto";
      import "google/protobuf/any.proto";

      message MainMessage {
          DepMessage dep = 1;
          google.protobuf.Any data = 2;
      }
      """

    let dep1File = tempDir.appendingPathComponent("dep1.proto")
    let mainFile = tempDir.appendingPathComponent("main.proto")

    try dep1Content.write(to: dep1File, atomically: true, encoding: .utf8)
    try mainContent.write(to: mainFile, atomically: true, encoding: .utf8)

    let resolvedFile = try ResolvedProtoFile.from(filePath: mainFile.path)
    let allImports = try resolver.resolveImportsRecursively(from: resolvedFile)

    // Should include dep1.proto and well-known types
    XCTAssertTrue(allImports.contains(dep1File.path))
    XCTAssertTrue(allImports.contains("google/protobuf/any.proto"))
    XCTAssertTrue(allImports.contains("google/protobuf/timestamp.proto"))
  }

  // MARK: - Validation Tests

  func testValidateImportsSuccess() throws {
    let depContent = "syntax = \"proto3\"; package dep; message DepMessage { string name = 1; }"
    let depFile = tempDir.appendingPathComponent("dep.proto")
    try depContent.write(to: depFile, atomically: true, encoding: .utf8)

    let mainContent = """
      syntax = "proto3";
      package main;

      import "dep.proto";
      import "google/protobuf/timestamp.proto";

      message MainMessage {
          DepMessage dep = 1;
          google.protobuf.Timestamp created_at = 2;
      }
      """

    let mainFile = tempDir.appendingPathComponent("main.proto")
    try mainContent.write(to: mainFile, atomically: true, encoding: .utf8)

    let resolvedFile = try ResolvedProtoFile.from(filePath: mainFile.path)
    let errors = resolver.validateImports(in: resolvedFile)

    XCTAssertTrue(errors.isEmpty)
  }

  func testValidateImportsWithErrors() throws {
    let mainContent = """
      syntax = "proto3";
      package main;

      import "missing1.proto";
      import "missing2.proto";
      import "google/protobuf/timestamp.proto";

      message MainMessage {
          string name = 1;
      }
      """

    let mainFile = tempDir.appendingPathComponent("main.proto")
    try mainContent.write(to: mainFile, atomically: true, encoding: .utf8)

    let resolvedFile = try ResolvedProtoFile.from(filePath: mainFile.path)
    let errors = resolver.validateImports(in: resolvedFile)

    XCTAssertEqual(errors.count, 2)

    for error in errors {
      // All errors should be ResolverError type
      _ = error as ResolverError  // This cast should always succeed
    }
  }

  // MARK: - Circular Dependency Detection Tests

  func testDetectCircularDependenciesNone() throws {
    // Create linear chain: file1 -> file2 -> file3
    let file3Content = "syntax = \"proto3\"; package file3; message File3Message { string id = 1; }"
    let file2Content = """
      syntax = "proto3";
      package file2;

      import "file3.proto";

      message File2Message {
          File3Message file3 = 1;
      }
      """
    let file1Content = """
      syntax = "proto3";
      package file1;

      import "file2.proto";

      message File1Message {
          File2Message file2 = 1;
      }
      """

    let file3 = tempDir.appendingPathComponent("file3.proto")
    let file2 = tempDir.appendingPathComponent("file2.proto")
    let file1 = tempDir.appendingPathComponent("file1.proto")

    try file3Content.write(to: file3, atomically: true, encoding: .utf8)
    try file2Content.write(to: file2, atomically: true, encoding: .utf8)
    try file1Content.write(to: file1, atomically: true, encoding: .utf8)

    let resolvedFiles = [
      try ResolvedProtoFile.from(filePath: file1.path),
      try ResolvedProtoFile.from(filePath: file2.path),
      try ResolvedProtoFile.from(filePath: file3.path),
    ]

    let cycles = resolver.detectCircularDependencies(in: resolvedFiles)

    XCTAssertTrue(cycles.isEmpty)
  }

  func testDetectCircularDependenciesSimple() throws {
    // Create simple cycle: file1 -> file2 -> file1
    let file1Content = """
      syntax = "proto3";
      package file1;

      import "file2.proto";

      message File1Message {
          string name = 1;
      }
      """

    let file2Content = """
      syntax = "proto3";
      package file2;

      import "file1.proto";

      message File2Message {
          string value = 1;
      }
      """

    let file1 = tempDir.appendingPathComponent("file1.proto")
    let file2 = tempDir.appendingPathComponent("file2.proto")

    try file1Content.write(to: file1, atomically: true, encoding: .utf8)
    try file2Content.write(to: file2, atomically: true, encoding: .utf8)

    let resolvedFiles = [
      try ResolvedProtoFile.from(filePath: file1.path),
      try ResolvedProtoFile.from(filePath: file2.path),
    ]

    let cycles = resolver.detectCircularDependencies(in: resolvedFiles)

    XCTAssertFalse(cycles.isEmpty)
    XCTAssertEqual(cycles.count, 1)
    XCTAssertGreaterThan(cycles[0].count, 1)
  }

  func testDetectCircularDependenciesComplex() throws {
    // Create complex cycle: file1 -> file2 -> file3 -> file1
    let file1Content = """
      syntax = "proto3";
      package file1;

      import "file2.proto";

      message File1Message {
          string name = 1;
      }
      """

    let file2Content = """
      syntax = "proto3";
      package file2;

      import "file3.proto";

      message File2Message {
          string value = 1;
      }
      """

    let file3Content = """
      syntax = "proto3";
      package file3;

      import "file1.proto";

      message File3Message {
          string id = 1;
      }
      """

    let file1 = tempDir.appendingPathComponent("file1.proto")
    let file2 = tempDir.appendingPathComponent("file2.proto")
    let file3 = tempDir.appendingPathComponent("file3.proto")

    try file1Content.write(to: file1, atomically: true, encoding: .utf8)
    try file2Content.write(to: file2, atomically: true, encoding: .utf8)
    try file3Content.write(to: file3, atomically: true, encoding: .utf8)

    let resolvedFiles = [
      try ResolvedProtoFile.from(filePath: file1.path),
      try ResolvedProtoFile.from(filePath: file2.path),
      try ResolvedProtoFile.from(filePath: file3.path),
    ]

    let cycles = resolver.detectCircularDependencies(in: resolvedFiles)

    XCTAssertFalse(cycles.isEmpty)
    XCTAssertEqual(cycles.count, 1)
    XCTAssertGreaterThan(cycles[0].count, 1)  // Should have multiple elements in cycle
  }

  // MARK: - Error Handling Tests

  func testResolveImportCircularDependency() throws {
    // Test circular dependency detection in ImportResolver
    // Create a file that imports itself (direct self-reference)
    let file1Content = """
      syntax = "proto3";
      package file1;

      import "file1.proto";

      message File1Message {
          string name = 1;
      }
      """

    let file1 = tempDir.appendingPathComponent("file1.proto")
    try file1Content.write(to: file1, atomically: true, encoding: .utf8)

    // For this test, let's test the circular dependency detection method directly
    let resolvedFile = try ResolvedProtoFile.from(filePath: file1.path)
    let cycles = resolver.detectCircularDependencies(in: [resolvedFile])

    // Should detect self-reference as circular dependency
    XCTAssertFalse(cycles.isEmpty)
  }

  func testResolveImportsRecursivelyWithMissingFile() throws {
    let mainContent = """
      syntax = "proto3";
      package main;

      import "missing.proto";

      message MainMessage {
          string name = 1;
      }
      """

    let mainFile = tempDir.appendingPathComponent("main.proto")
    try mainContent.write(to: mainFile, atomically: true, encoding: .utf8)

    let resolvedFile = try ResolvedProtoFile.from(filePath: mainFile.path)

    XCTAssertThrowsError(try resolver.resolveImportsRecursively(from: resolvedFile)) { error in
      XCTAssertTrue(error is ResolverError)
    }
  }

  // MARK: - Cache Management Tests

  func testCacheOperations() throws {
    let depContent = "syntax = \"proto3\"; package dep; message DepMessage { string name = 1; }"
    let depFile = tempDir.appendingPathComponent("dep.proto")
    try depContent.write(to: depFile, atomically: true, encoding: .utf8)

    // Initial cache state
    let initialStats = resolver.cacheStats
    XCTAssertEqual(initialStats.hits, 0)
    XCTAssertEqual(initialStats.size, 0)

    // Resolve import (should cache result)
    _ = try resolver.resolveImport("dep.proto", fromFile: tempDir.path)

    let afterFirstStats = resolver.cacheStats
    XCTAssertGreaterThan(afterFirstStats.size, initialStats.size)

    // Resolve same import again (should use cache)
    _ = try resolver.resolveImport("dep.proto", fromFile: tempDir.path)

    // Clear cache
    resolver.clearCache()

    let clearedStats = resolver.cacheStats
    XCTAssertEqual(clearedStats.size, 0)
  }

  // MARK: - Well-Known Types Tests

  func testWellKnownTypeInfo() {
    let timestampInfo = ImportResolver.wellKnownTypeInfo("google/protobuf/timestamp.proto")
    XCTAssertNotNil(timestampInfo)
    XCTAssertTrue(timestampInfo?.contains("Timestamp") ?? false)

    let anyInfo = ImportResolver.wellKnownTypeInfo("google/protobuf/any.proto")
    XCTAssertNotNil(anyInfo)
    XCTAssertTrue(anyInfo?.contains("Any") ?? false)

    let customInfo = ImportResolver.wellKnownTypeInfo("custom/file.proto")
    XCTAssertNil(customInfo)
  }
}
