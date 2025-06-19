import XCTest
import Foundation
@testable import SwiftProtoParser

final class BasicDependencyResolverTests: XCTestCase {
  
  private var tempDir: URL!
  
  override func setUpWithError() throws {
    try super.setUpWithError()
    tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
  }
  
  override func tearDownWithError() throws {
    if FileManager.default.fileExists(atPath: tempDir.path) {
      try FileManager.default.removeItem(at: tempDir)
    }
    try super.tearDownWithError()
  }
  
  // MARK: - Basic DependencyResolver Tests
  
  func testDependencyResolverInitialization() {
    let resolver = DependencyResolver(importPaths: [tempDir.path])
    XCTAssertNotNil(resolver)
    
    let description = resolver.description
    XCTAssertTrue(description.contains("DependencyResolver"))
  }
  
  func testDependencyResolverFactoryMethods() {
    let paths = [tempDir.path]
    
    let standard = DependencyResolver.standard(importPaths: paths)
    XCTAssertNotNil(standard)
    
    let lenient = DependencyResolver.lenient(importPaths: paths)
    XCTAssertNotNil(lenient)
    
    let strict = DependencyResolver.strict(importPaths: paths)
    XCTAssertNotNil(strict)
  }
  
  func testDependencyResolverOptions() {
    let defaultOptions = DependencyResolver.Options.default
    XCTAssertFalse(defaultOptions.allowMissingImports)
    XCTAssertTrue(defaultOptions.recursive)
    XCTAssertTrue(defaultOptions.validateSyntax)
    XCTAssertTrue(defaultOptions.detectCircularDependencies)
    XCTAssertEqual(defaultOptions.maxDepth, 50)
    
    let customOptions = DependencyResolver.Options(
      allowMissingImports: true,
      recursive: false,
      validateSyntax: false,
      detectCircularDependencies: false,
      maxDepth: 10
    )
    XCTAssertTrue(customOptions.allowMissingImports)
    XCTAssertFalse(customOptions.recursive)
    XCTAssertFalse(customOptions.validateSyntax)
    XCTAssertFalse(customOptions.detectCircularDependencies)
    XCTAssertEqual(customOptions.maxDepth, 10)
  }
  
  func testDependencyResolverBasicResolution() throws {
    let protoContent = """
    syntax = "proto3";
    package test;
    
    message TestMessage {
      string name = 1;
    }
    """
    
    let protoFile = tempDir.appendingPathComponent("test.proto")
    try protoContent.write(to: protoFile, atomically: true, encoding: .utf8)
    
    let resolver = DependencyResolver(importPaths: [tempDir.path])
    let result = try resolver.resolveDependencies(for: protoFile.path)
    
    XCTAssertEqual(result.mainFile.filePath, protoFile.path)
    XCTAssertTrue(result.dependencies.isEmpty)
    XCTAssertEqual(result.allFiles.count, 1)
    XCTAssertEqual(result.stats.totalFiles, 1)
  }
  
  func testDependencyResolverCacheOperations() {
    let resolver = DependencyResolver(importPaths: [tempDir.path])
    
    let initialStats = resolver.stats
    XCTAssertEqual(initialStats.cacheHits, 0)
    XCTAssertEqual(initialStats.cacheSize, 0)
    
    resolver.clearCaches()
    let clearedStats = resolver.stats
    XCTAssertEqual(clearedStats.cacheHits, 0)
    XCTAssertEqual(clearedStats.cacheSize, 0)
  }
  
  // MARK: - Basic FileSystemScanner Tests
  
  func testFileSystemScannerInitialization() {
    let scanner = FileSystemScanner(importPaths: [tempDir.path])
    XCTAssertNotNil(scanner)
    
    let description = scanner.description
    XCTAssertTrue(description.contains("FileSystemScanner"))
  }
  
  func testFileSystemScannerFindProtoFiles() throws {
    let protoFile = tempDir.appendingPathComponent("test.proto")
    try "syntax = \"proto3\";".write(to: protoFile, atomically: true, encoding: .utf8)
    
    let scanner = FileSystemScanner(importPaths: [tempDir.path])
    let files = try scanner.findAllProtoFiles(in: tempDir.path)
    
    XCTAssertEqual(files.count, 1)
    XCTAssertTrue(files.contains(protoFile.path))
  }
  
  func testFileSystemScannerAbsolutePath() {
    let scanner = FileSystemScanner(importPaths: [tempDir.path])
    let absolutePath = scanner.absolutePath(for: "test.proto")
    XCTAssertTrue(absolutePath.hasSuffix("test.proto"))
  }
  
  func testFileSystemScannerWellKnownTypes() {
    XCTAssertTrue(FileSystemScanner.isWellKnownType("google/protobuf/timestamp.proto"))
    XCTAssertTrue(FileSystemScanner.isWellKnownType("google/protobuf/any.proto"))
    XCTAssertFalse(FileSystemScanner.isWellKnownType("custom/file.proto"))
    XCTAssertFalse(FileSystemScanner.isWellKnownType(""))
    
    let wellKnownTypes = FileSystemScanner.wellKnownTypes()
    XCTAssertFalse(wellKnownTypes.isEmpty)
    XCTAssertTrue(wellKnownTypes.contains("google/protobuf/timestamp.proto"))
  }
  
  func testFileSystemScannerPathUtilities() {
    let scanner = FileSystemScanner(importPaths: [tempDir.path])
    
    XCTAssertTrue(scanner.isAccessible(tempDir.path))
    XCTAssertTrue(scanner.isDirectory(tempDir.path))
    XCTAssertFalse(scanner.isAccessible("/nonexistent/path"))
  }
  
  // MARK: - Basic ImportResolver Tests
  
  func testImportResolverInitialization() {
    let scanner = FileSystemScanner(importPaths: [tempDir.path])
    let resolver = ImportResolver(scanner: scanner)
    XCTAssertNotNil(resolver)
    
    let stats = resolver.cacheStats
    XCTAssertEqual(stats.hits, 0)
    XCTAssertEqual(stats.size, 0)
  }
  
  func testImportResolverWithImportPaths() {
    let resolver = ImportResolver(importPaths: [tempDir.path])
    XCTAssertNotNil(resolver)
  }
  
  func testImportResolverWellKnownTypes() {
    XCTAssertTrue(ImportResolver.isWellKnownType("google/protobuf/timestamp.proto"))
    XCTAssertFalse(ImportResolver.isWellKnownType("custom/file.proto"))
    
    let info = ImportResolver.wellKnownTypeInfo("google/protobuf/timestamp.proto")
    XCTAssertNotNil(info)
    XCTAssertTrue(info?.contains("Timestamp") ?? false)
    
    let noInfo = ImportResolver.wellKnownTypeInfo("custom/file.proto")
    XCTAssertNil(noInfo)
  }
  
  func testImportResolverCacheOperations() {
    let scanner = FileSystemScanner(importPaths: [tempDir.path])
    var resolver = ImportResolver(scanner: scanner)
    
    let initialStats = resolver.cacheStats
    XCTAssertEqual(initialStats.hits, 0)
    XCTAssertEqual(initialStats.size, 0)
    
    resolver.clearCache()
    let clearedStats = resolver.cacheStats
    XCTAssertEqual(clearedStats.hits, 0)
    XCTAssertEqual(clearedStats.size, 0)
  }
  
  // MARK: - Basic ResolvedProtoFile Tests
  
  func testResolvedProtoFileBasicCreation() throws {
    let protoContent = """
    syntax = "proto3";
    package test;
    
    message TestMessage {
      string name = 1;
    }
    """
    
    let protoFile = tempDir.appendingPathComponent("test.proto")
    try protoContent.write(to: protoFile, atomically: true, encoding: .utf8)
    
    let resolved = try ResolvedProtoFile.from(filePath: protoFile.path)
    
    XCTAssertEqual(resolved.filePath, protoFile.path)
    XCTAssertEqual(resolved.fileName, "test.proto")
    XCTAssertEqual(resolved.syntax, "proto3")
    XCTAssertEqual(resolved.packageName, "test")
    XCTAssertTrue(resolved.imports.isEmpty)
    XCTAssertFalse(resolved.isMainFile)
  }
  
  func testResolvedProtoFileWithMainFlag() throws {
    let protoContent = """
    syntax = "proto3";
    package test;
    
    message TestMessage {
      string name = 1;
    }
    """
    
    let protoFile = tempDir.appendingPathComponent("main.proto")
    try protoContent.write(to: protoFile, atomically: true, encoding: .utf8)
    
    let resolved = try ResolvedProtoFile.from(filePath: protoFile.path, isMainFile: true)
    
    XCTAssertTrue(resolved.isMainFile)
    XCTAssertEqual(resolved.fileName, "main.proto")
  }
  
  func testResolvedProtoFileComputedProperties() throws {
    let protoContent = "syntax = \"proto3\";"
    let protoFile = tempDir.appendingPathComponent("example.proto")
    try protoContent.write(to: protoFile, atomically: true, encoding: .utf8)
    
    let resolved = try ResolvedProtoFile.from(filePath: protoFile.path)
    
    XCTAssertEqual(resolved.baseName, "example")
    XCTAssertEqual(resolved.directory, tempDir.path)
    XCTAssertTrue(resolved.importPath.hasSuffix(".proto"))
  }
  
  func testResolvedProtoFileEquality() throws {
    let protoContent = "syntax = \"proto3\";"
    let protoFile = tempDir.appendingPathComponent("test.proto")
    try protoContent.write(to: protoFile, atomically: true, encoding: .utf8)
    
    let resolved1 = try ResolvedProtoFile.from(filePath: protoFile.path)
    let resolved2 = try ResolvedProtoFile.from(filePath: protoFile.path)
    
    XCTAssertEqual(resolved1, resolved2)
    XCTAssertEqual(resolved1.hashValue, resolved2.hashValue)
  }
  
  func testResolvedProtoFileDescription() throws {
    let protoContent = """
    syntax = "proto3";
    package test;
    
    import "other.proto";
    
    message TestMessage {
      string name = 1;
    }
    """
    
    let protoFile = tempDir.appendingPathComponent("test.proto")
    try protoContent.write(to: protoFile, atomically: true, encoding: .utf8)
    
    let resolved = try ResolvedProtoFile.from(filePath: protoFile.path, isMainFile: true)
    let description = resolved.description
    
    XCTAssertTrue(description.contains("ResolvedProtoFile"))
    XCTAssertTrue(description.contains("test.proto"))
    XCTAssertTrue(description.contains("proto3"))
    XCTAssertTrue(description.contains("test"))
    XCTAssertTrue(description.contains("main"))
  }
  
  func testResolvedProtoFileWithImports() throws {
    let protoContent = """
    syntax = "proto3";
    package test;
    
    import "google/protobuf/timestamp.proto";
    import "custom/file.proto";
    
    message TestMessage {
      string name = 1;
    }
    """
    
    let protoFile = tempDir.appendingPathComponent("test.proto")
    try protoContent.write(to: protoFile, atomically: true, encoding: .utf8)
    
    let resolved = try ResolvedProtoFile.from(filePath: protoFile.path)
    
    XCTAssertEqual(resolved.imports.count, 2)
    XCTAssertTrue(resolved.imports.contains("google/protobuf/timestamp.proto"))
    XCTAssertTrue(resolved.imports.contains("custom/file.proto"))
  }
  
  func testResolvedProtoFileWithoutSyntax() throws {
    let protoContent = """
    package test;
    
    message TestMessage {
      string name = 1;
    }
    """
    
    let protoFile = tempDir.appendingPathComponent("nosyntax.proto")
    try protoContent.write(to: protoFile, atomically: true, encoding: .utf8)
    
    let resolved = try ResolvedProtoFile.from(filePath: protoFile.path)
    
    XCTAssertNil(resolved.syntax)
    XCTAssertEqual(resolved.packageName, "test")
  }
  
  func testResolvedProtoFileWithoutPackage() throws {
    let protoContent = """
    syntax = "proto3";
    
    message TestMessage {
      string name = 1;
    }
    """
    
    let protoFile = tempDir.appendingPathComponent("nopackage.proto")
    try protoContent.write(to: protoFile, atomically: true, encoding: .utf8)
    
    let resolved = try ResolvedProtoFile.from(filePath: protoFile.path)
    
    XCTAssertEqual(resolved.syntax, "proto3")
    XCTAssertNil(resolved.packageName)
  }
}
