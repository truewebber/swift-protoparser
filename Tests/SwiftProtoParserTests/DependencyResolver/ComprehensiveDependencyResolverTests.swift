import Foundation
import XCTest

@testable import SwiftProtoParser

final class ComprehensiveDependencyResolverTests: XCTestCase {

  private var tempDir: URL!
  private var resolver: DependencyResolver!

  override func setUpWithError() throws {
    try super.setUpWithError()
    tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    resolver = DependencyResolver(importPaths: [tempDir.path])
  }

  override func tearDownWithError() throws {
    if FileManager.default.fileExists(atPath: tempDir.path) {
      try FileManager.default.removeItem(at: tempDir)
    }
    try super.tearDownWithError()
  }

  // MARK: - Comprehensive Resolution Tests

  func testResolveDependenciesWithSingleImport() throws {
    // Create dependency file
    let depContent = """
      syntax = "proto3";
      package dep;

      message DepMessage {
          string value = 1;
      }
      """

    let depFile = tempDir.appendingPathComponent("dep.proto")
    try depContent.write(to: depFile, atomically: true, encoding: .utf8)

    // Create main file with import
    let mainContent = """
      syntax = "proto3";
      package main;

      import "dep.proto";

      message MainMessage {
          DepMessage dep = 1;
      }
      """

    let mainFile = tempDir.appendingPathComponent("main.proto")
    try mainContent.write(to: mainFile, atomically: true, encoding: .utf8)

    // Test resolution
    let result = try resolver.resolveDependencies(for: mainFile.path)

    XCTAssertEqual(result.mainFile.filePath, mainFile.path)
    XCTAssertEqual(result.dependencies.count, 1)
    XCTAssertEqual(result.allFiles.count, 2)
    XCTAssertEqual(result.stats.totalFiles, 2)
    XCTAssertEqual(result.stats.directDependencies, 1)
    XCTAssertTrue(result.warnings.isEmpty)
  }

  func testResolveDependenciesWithMultipleImports() throws {
    // Create multiple dependency files
    let dep1Content = """
      syntax = "proto3";
      package dep1;

      message Dep1Message {
          string name = 1;
      }
      """

    let dep2Content = """
      syntax = "proto3";
      package dep2;

      message Dep2Message {
          int32 value = 1;
      }
      """

    let dep1File = tempDir.appendingPathComponent("dep1.proto")
    let dep2File = tempDir.appendingPathComponent("dep2.proto")

    try dep1Content.write(to: dep1File, atomically: true, encoding: .utf8)
    try dep2Content.write(to: dep2File, atomically: true, encoding: .utf8)

    // Create main file with multiple imports
    let mainContent = """
      syntax = "proto3";
      package main;

      import "dep1.proto";
      import "dep2.proto";

      message MainMessage {
          Dep1Message dep1 = 1;
          Dep2Message dep2 = 2;
      }
      """

    let mainFile = tempDir.appendingPathComponent("main.proto")
    try mainContent.write(to: mainFile, atomically: true, encoding: .utf8)

    // Test resolution
    let result = try resolver.resolveDependencies(for: mainFile.path)

    XCTAssertEqual(result.dependencies.count, 2)
    XCTAssertEqual(result.allFiles.count, 3)
    XCTAssertEqual(result.stats.directDependencies, 2)
    XCTAssertTrue(result.warnings.isEmpty)
  }

  func testResolveDependenciesRecursively() throws {
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

    // Test recursive resolution
    let result = try resolver.resolveDependencies(for: mainFile.path)

    XCTAssertEqual(result.dependencies.count, 2)
    XCTAssertEqual(result.allFiles.count, 3)
    XCTAssertEqual(result.stats.directDependencies, 1)
    XCTAssertEqual(result.stats.transitiveDependencies, 2)
    XCTAssertTrue(result.stats.resolutionTime > 0)
  }

  func testResolveDependenciesWithWellKnownTypes() throws {
    let mainContent = """
      syntax = "proto3";
      package main;

      import "google/protobuf/timestamp.proto";
      import "google/protobuf/any.proto";

      message MainMessage {
          google.protobuf.Timestamp created_at = 1;
          google.protobuf.Any data = 2;
      }
      """

    let mainFile = tempDir.appendingPathComponent("main.proto")
    try mainContent.write(to: mainFile, atomically: true, encoding: .utf8)

    let result = try resolver.resolveDependencies(for: mainFile.path)

    XCTAssertEqual(result.stats.directDependencies, 2)
    XCTAssertEqual(result.stats.wellKnownTypes, 2)
    XCTAssertTrue(result.warnings.isEmpty)
  }

  func testResolveDependenciesMultipleFiles() throws {
    // Create two separate files
    let file1Content = """
      syntax = "proto3";
      package file1;

      message File1Message {
          string name = 1;
      }
      """

    let file2Content = """
      syntax = "proto3";
      package file2;

      message File2Message {
          int32 value = 1;
      }
      """

    let file1 = tempDir.appendingPathComponent("file1.proto")
    let file2 = tempDir.appendingPathComponent("file2.proto")

    try file1Content.write(to: file1, atomically: true, encoding: .utf8)
    try file2Content.write(to: file2, atomically: true, encoding: .utf8)

    // Test multiple file resolution
    let results = try resolver.resolveDependencies(for: [file1.path, file2.path])

    XCTAssertEqual(results.count, 2)
    XCTAssertEqual(results[0].allFiles.count, 1)
    XCTAssertEqual(results[1].allFiles.count, 1)
  }

  func testResolveDirectory() throws {
    // Create multiple proto files in directory
    let files = ["test1.proto", "test2.proto", "test3.proto"]

    for (index, fileName) in files.enumerated() {
      let content = """
        syntax = "proto3";
        package test\(index + 1);

        message Test\(index + 1)Message {
            string name = 1;
        }
        """

      let file = tempDir.appendingPathComponent(fileName)
      try content.write(to: file, atomically: true, encoding: .utf8)
    }

    // Test directory resolution
    let results = try resolver.resolveDirectory(tempDir.path)

    XCTAssertEqual(results.count, 3)
    for result in results {
      XCTAssertEqual(result.allFiles.count, 1)
      XCTAssertTrue(result.warnings.isEmpty)
    }
  }

  func testResolveDirectoryRecursive() throws {
    // Create subdirectory
    let subDir = tempDir.appendingPathComponent("sub")
    try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

    // Create files in main and sub directory
    let mainFileContent = """
      syntax = "proto3";
      package main;

      message MainMessage {
          string name = 1;
      }
      """

    let subFileContent = """
      syntax = "proto3";
      package sub;

      message SubMessage {
          string value = 1;
      }
      """

    let mainFile = tempDir.appendingPathComponent("main.proto")
    let subFile = subDir.appendingPathComponent("sub.proto")

    try mainFileContent.write(to: mainFile, atomically: true, encoding: .utf8)
    try subFileContent.write(to: subFile, atomically: true, encoding: .utf8)

    // Test recursive directory resolution
    let results = try resolver.resolveDirectory(tempDir.path, recursive: true)

    XCTAssertEqual(results.count, 2)
  }

  // MARK: - Error Handling Tests

  func testResolveDependenciesFileNotFound() {
    let nonExistentFile = tempDir.appendingPathComponent("notfound.proto").path

    XCTAssertThrowsError(try resolver.resolveDependencies(for: nonExistentFile)) { error in
      XCTAssertTrue(error is ResolverError)
    }
  }

  func testResolveDependenciesMissingImport() throws {
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

    // Should throw error with default options
    XCTAssertThrowsError(try resolver.resolveDependencies(for: mainFile.path)) { error in
      XCTAssertTrue(error is ResolverError)
    }
  }

  func testResolveDependenciesLenientMode() throws {
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

    // Create lenient resolver
    let lenientResolver = DependencyResolver.lenient(importPaths: [tempDir.path])

    // Should succeed with warnings in lenient mode
    let result = try lenientResolver.resolveDependencies(for: mainFile.path)

    XCTAssertFalse(result.warnings.isEmpty)
    XCTAssertEqual(result.allFiles.count, 1)
  }

  func testResolveDependenciesInvalidSyntax() throws {
    let mainContent = """
      syntax = "proto2";
      package main;

      message MainMessage {
          string name = 1;
      }
      """

    let mainFile = tempDir.appendingPathComponent("main.proto")
    try mainContent.write(to: mainFile, atomically: true, encoding: .utf8)

    // Should throw error due to proto2 syntax
    XCTAssertThrowsError(try resolver.resolveDependencies(for: mainFile.path)) { error in
      guard let resolverError = error as? ResolverError else {
        XCTFail("Expected ResolverError")
        return
      }

      if case .invalidSyntax(_, let expected) = resolverError {
        XCTAssertEqual(expected, "proto3")
      }
      else {
        XCTFail("Expected invalidSyntax error")
      }
    }
  }

  func testResolveDependenciesCircularDependency() throws {
    // Create circular dependency: file1 -> file2 -> file1
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

    // Should throw circular dependency error
    XCTAssertThrowsError(try resolver.resolveDependencies(for: file1.path)) { error in
      guard let resolverError = error as? ResolverError else {
        XCTFail("Expected ResolverError")
        return
      }

      if case .circularDependency(_) = resolverError {
        // Expected
      }
      else {
        XCTFail("Expected circularDependency error")
      }
    }
  }

  // MARK: - Options and Configuration Tests

  func testResolverWithNonRecursiveOptions() throws {
    // Setup chain: main -> dep1 -> dep2
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

    // Create non-recursive resolver
    let options = DependencyResolver.Options(recursive: false)
    let nonRecursiveResolver = DependencyResolver(importPaths: [tempDir.path], options: options)

    let result = try nonRecursiveResolver.resolveDependencies(for: mainFile.path)

    // Should only resolve direct dependencies
    XCTAssertEqual(result.dependencies.count, 1)
    XCTAssertEqual(result.stats.directDependencies, 1)
  }

  func testResolverWithoutSyntaxValidation() throws {
    let mainContent = """
      syntax = "proto2";
      package main;

      message MainMessage {
          string name = 1;
      }
      """

    let mainFile = tempDir.appendingPathComponent("main.proto")
    try mainContent.write(to: mainFile, atomically: true, encoding: .utf8)

    // Create resolver without syntax validation
    let options = DependencyResolver.Options(validateSyntax: false)
    let noValidationResolver = DependencyResolver(importPaths: [tempDir.path], options: options)

    // Should succeed without syntax validation
    let result = try noValidationResolver.resolveDependencies(for: mainFile.path)

    XCTAssertEqual(result.allFiles.count, 1)
    XCTAssertTrue(result.warnings.isEmpty)
  }

  func testCircularDependencyDetectionAccordingToProtobufSpec() throws {
    // MARK: - Circular Dependency Tests According to Protocol Buffers Specification
    //
    // According to the Protocol Buffers specification (proto3), circular dependencies 
    // between .proto files are NOT allowed and should cause an error during compilation.
    // 
    // This test suite validates that our implementation correctly detects and rejects
    // circular import dependencies as required by the protobuf specification.
    //
    // Reference: https://protobuf.dev/programming-guides/proto3/#importing-definitions
    //
    // Key points:
    // 1. Circular imports between .proto files are prohibited
    // 2. The compiler should detect and report circular dependencies
    // 3. Circular type references within a single file are allowed
    // 4. This behavior is critical for protobuf compatibility

    // Create circular dependency: file1 -> file2 -> file1
    let file1Content = """
      syntax = "proto3";
      package file1;

      import "file2.proto";

      message File1Message {
          File2Message other = 1;
      }
      """

    let file2Content = """
      syntax = "proto3";
      package file2;

      import "file1.proto";

      message File2Message {
          File1Message other = 1;
      }
      """

    let file1 = tempDir.appendingPathComponent("file1.proto")
    let file2 = tempDir.appendingPathComponent("file2.proto")

    try file1Content.write(to: file1, atomically: true, encoding: .utf8)
    try file2Content.write(to: file2, atomically: true, encoding: .utf8)

    // Test with circular dependency detection enabled (default)
    let strictResolver = DependencyResolver.strict(importPaths: [tempDir.path])

    // Should throw circular dependency error as per protobuf spec
    XCTAssertThrowsError(try strictResolver.resolveDependencies(for: file1.path)) { error in
      guard let resolverError = error as? ResolverError else {
        XCTFail("Expected ResolverError, got \(type(of: error))")
        return
      }

      if case .circularDependency(let cycles) = resolverError {
        XCTAssertFalse(cycles.isEmpty, "Should detect at least one circular dependency")
        
        // Convert all cycles to a single string for easier checking
        let allCycles = cycles.joined(separator: " | ")
        
        // The cycle detection should show that we have a circular dependency
        // The exact format may vary, but it should involve our test files
        let hasFile1 = allCycles.contains("file1")
        
        XCTAssertTrue(hasFile1, "Cycle should reference file1, but got: \(cycles)")
        
        // The main requirement is that a circular dependency was detected
        // The exact cycle format can vary based on the implementation
      }
      else {
        XCTFail("Expected circularDependency error, got \(resolverError)")
      }
    }
  }

  func testComplexCircularDependencyDetection() throws {
    // Test more complex circular dependency: A -> B -> C -> A
    let fileAContent = """
      syntax = "proto3";
      package fileA;

      import "fileB.proto";

      message MessageA {
          MessageB b = 1;
      }
      """

    let fileBContent = """
      syntax = "proto3";
      package fileB;

      import "fileC.proto";

      message MessageB {
          MessageC c = 1;
      }
      """

    let fileCContent = """
      syntax = "proto3";
      package fileC;

      import "fileA.proto";

      message MessageC {
          MessageA a = 1;
      }
      """

    let fileA = tempDir.appendingPathComponent("fileA.proto")
    let fileB = tempDir.appendingPathComponent("fileB.proto")
    let fileC = tempDir.appendingPathComponent("fileC.proto")

    try fileAContent.write(to: fileA, atomically: true, encoding: .utf8)
    try fileBContent.write(to: fileB, atomically: true, encoding: .utf8)
    try fileCContent.write(to: fileC, atomically: true, encoding: .utf8)

    let resolver = DependencyResolver.strict(importPaths: [tempDir.path])

    // Should detect the 3-file circular dependency
    XCTAssertThrowsError(try resolver.resolveDependencies(for: fileA.path)) { error in
      guard let resolverError = error as? ResolverError,
            case .circularDependency(let cycles) = resolverError else {
        XCTFail("Expected circularDependency error")
        return
      }

      XCTAssertFalse(cycles.isEmpty, "Should detect circular dependency")
    }
  }

  func testValidImportChainWithoutCircularDependency() throws {
    // Test valid import chain: main -> dep1 -> dep2 (no cycles)
    let dep2Content = """
      syntax = "proto3";
      package dep2;

      message BaseMessage {
          string value = 1;
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

    let resolver = DependencyResolver.strict(importPaths: [tempDir.path])

    // Should succeed without errors (no circular dependencies)
    XCTAssertNoThrow {
      let result = try resolver.resolveDependencies(for: mainFile.path)
      XCTAssertEqual(result.dependencies.count, 2) // dep1 and dep2
      XCTAssertEqual(result.allFiles.count, 3) // main, dep1, dep2
      XCTAssertTrue(result.warnings.isEmpty)
    }
  }

  func testCircularDependencyDetectionCanBeDisabled() throws {
    // Test that circular dependency detection can be disabled (lenient mode)
    // Note: This is useful for testing/debugging purposes, but not recommended
    // for production use as it violates protobuf specification

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

    // Use lenient resolver (circular dependency detection disabled)
    let lenientResolver = DependencyResolver.lenient(importPaths: [tempDir.path])

    // Should succeed with warnings in lenient mode
    XCTAssertNoThrow {
      let result = try lenientResolver.resolveDependencies(for: file1.path)
      // May have warnings about circular dependencies or missing imports
      XCTAssertEqual(result.allFiles.count, 1) // Only main file resolved
    }
  }

  // MARK: - Cache and Performance Tests

  func testResolverCacheOperations() throws {
    let mainContent = """
      syntax = "proto3";
      package main;

      import "google/protobuf/timestamp.proto";

      message MainMessage {
          google.protobuf.Timestamp created_at = 1;
      }
      """

    let mainFile = tempDir.appendingPathComponent("main.proto")
    try mainContent.write(to: mainFile, atomically: true, encoding: .utf8)

    // First resolution
    let result1 = try resolver.resolveDependencies(for: mainFile.path)
    let stats1 = resolver.stats

    // Second resolution (should use cache)
    let result2 = try resolver.resolveDependencies(for: mainFile.path)
    let stats2 = resolver.stats

    XCTAssertEqual(result1.stats.totalFiles, result2.stats.totalFiles)
    XCTAssertGreaterThanOrEqual(stats2.cacheSize, stats1.cacheSize)

    // Clear cache
    resolver.clearCaches()
    let statsAfterClear = resolver.stats
    XCTAssertEqual(statsAfterClear.cacheSize, 0)
  }

  func testResolverValidateImportPaths() throws {
    // Test valid paths
    XCTAssertNoThrow(try resolver.validateImportPaths())

    // Test invalid path
    let invalidResolver = DependencyResolver(importPaths: ["/nonexistent/path"])
    XCTAssertThrowsError(try invalidResolver.validateImportPaths()) { error in
      XCTAssertTrue(error is ResolverError)
    }
  }

  // MARK: - Statistics and Result Tests

  func testResolutionResultAndStats() throws {
    let depContent = """
      syntax = "proto3";
      package dep;

      import "google/protobuf/timestamp.proto";

      message DepMessage {
          google.protobuf.Timestamp created_at = 1;
      }
      """

    let mainContent = """
      syntax = "proto3";
      package main;

      import "dep.proto";
      import "google/protobuf/any.proto";

      message MainMessage {
          DepMessage dep = 1;
          google.protobuf.Any data = 2;
      }
      """

    let depFile = tempDir.appendingPathComponent("dep.proto")
    let mainFile = tempDir.appendingPathComponent("main.proto")

    try depContent.write(to: depFile, atomically: true, encoding: .utf8)
    try mainContent.write(to: mainFile, atomically: true, encoding: .utf8)

    let result = try resolver.resolveDependencies(for: mainFile.path)

    // Test ResolutionResult properties
    XCTAssertNotNil(result.mainFile)
    XCTAssertFalse(result.dependencies.isEmpty)
    XCTAssertFalse(result.allFiles.isEmpty)
    XCTAssertEqual(result.allFiles.count, result.dependencies.count + 1)

    // Test ResolutionStats
    XCTAssertGreaterThan(result.stats.totalFiles, 0)
    XCTAssertGreaterThan(result.stats.directDependencies, 0)
    XCTAssertGreaterThanOrEqual(result.stats.transitiveDependencies, 0)
    XCTAssertGreaterThan(result.stats.wellKnownTypes, 0)
    XCTAssertGreaterThan(result.stats.resolutionTime, 0)
    XCTAssertGreaterThanOrEqual(result.stats.cacheHitRate, 0.0)
    XCTAssertLessThanOrEqual(result.stats.cacheHitRate, 1.0)
  }
}
