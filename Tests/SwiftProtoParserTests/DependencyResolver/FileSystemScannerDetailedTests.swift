import Foundation
import XCTest

@testable import SwiftProtoParser

final class FileSystemScannerDetailedTests: XCTestCase {

  private var tempDir: URL!
  private var scanner: FileSystemScanner!

  override func setUpWithError() throws {
    try super.setUpWithError()
    tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    scanner = FileSystemScanner(importPaths: [tempDir.path])
  }

  override func tearDownWithError() throws {
    if FileManager.default.fileExists(atPath: tempDir.path) {
      try FileManager.default.removeItem(at: tempDir)
    }
    try super.tearDownWithError()
  }

  // MARK: - File Finding Tests

  func testFindProtoFileSuccess() throws {
    let protoContent = "syntax = \"proto3\"; package test; message TestMessage { string name = 1; }"
    let protoFile = tempDir.appendingPathComponent("test.proto")
    try protoContent.write(to: protoFile, atomically: true, encoding: .utf8)

    let foundPath = try scanner.findProtoFile("test.proto")

    XCTAssertEqual(foundPath, protoFile.path)
  }

  func testFindProtoFileInSubdirectory() throws {
    // Create subdirectory structure
    let subDir = tempDir.appendingPathComponent("subdir")
    try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

    let protoContent = "syntax = \"proto3\"; package test; message TestMessage { string name = 1; }"
    let protoFile = subDir.appendingPathComponent("test.proto")
    try protoContent.write(to: protoFile, atomically: true, encoding: .utf8)

    let foundPath = try scanner.findProtoFile("subdir/test.proto")

    XCTAssertEqual(foundPath, protoFile.path)
  }

  func testFindProtoFileNotFound() {
    XCTAssertThrowsError(try scanner.findProtoFile("nonexistent.proto")) { error in
      guard let resolverError = error as? ResolverError else {
        XCTFail("Expected ResolverError")
        return
      }

      if case .importNotFound(let importPath, let searchPaths) = resolverError {
        XCTAssertEqual(importPath, "nonexistent.proto")
        XCTAssertEqual(searchPaths, [tempDir.path])
      }
      else {
        XCTFail("Expected importNotFound error")
      }
    }
  }

  func testFindProtoFileEmptyPath() {
    XCTAssertThrowsError(try scanner.findProtoFile("")) { error in
      guard let resolverError = error as? ResolverError else {
        XCTFail("Expected ResolverError")
        return
      }

      if case .invalidImportPath(let path) = resolverError {
        XCTAssertEqual(path, "")
      }
      else {
        XCTFail("Expected invalidImportPath error")
      }
    }
  }

  func testFindProtoFileWithWhitespace() throws {
    let protoContent = "syntax = \"proto3\"; package test; message TestMessage { string name = 1; }"
    let protoFile = tempDir.appendingPathComponent("test.proto")
    try protoContent.write(to: protoFile, atomically: true, encoding: .utf8)

    // Test with leading/trailing whitespace
    let foundPath = try scanner.findProtoFile("  test.proto  ")

    XCTAssertEqual(foundPath, protoFile.path)
  }

  func testFindProtoFileWithMultipleImportPaths() throws {
    // Create second import path
    let tempDir2 = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir2, withIntermediateDirectories: true)
    defer {
      try? FileManager.default.removeItem(at: tempDir2)
    }

    // Create file in second path
    let protoContent = "syntax = \"proto3\"; package test; message TestMessage { string name = 1; }"
    let protoFile = tempDir2.appendingPathComponent("test.proto")
    try protoContent.write(to: protoFile, atomically: true, encoding: .utf8)

    // Create scanner with multiple paths
    let multiPathScanner = FileSystemScanner(importPaths: [tempDir.path, tempDir2.path])

    let foundPath = try multiPathScanner.findProtoFile("test.proto")

    XCTAssertEqual(foundPath, protoFile.path)
  }

  // MARK: - Directory Scanning Tests

  func testFindAllProtoFiles() throws {
    // Create multiple proto files
    let files = ["test1.proto", "test2.proto", "other.txt", "test3.proto"]

    for fileName in files {
      let content =
        fileName.hasSuffix(".proto")
        ? "syntax = \"proto3\"; package test; message TestMessage { string name = 1; }" : "not a proto file"

      let file = tempDir.appendingPathComponent(fileName)
      try content.write(to: file, atomically: true, encoding: .utf8)
    }

    let foundFiles = try scanner.findAllProtoFiles(in: tempDir.path)

    XCTAssertEqual(foundFiles.count, 3)  // Only .proto files
    for file in foundFiles {
      XCTAssertTrue(file.hasSuffix(".proto"))
      XCTAssertTrue(FileManager.default.fileExists(atPath: file))
    }
  }

  func testFindAllProtoFilesEmptyDirectory() throws {
    let emptyDir = tempDir.appendingPathComponent("empty")
    try FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)

    let foundFiles = try scanner.findAllProtoFiles(in: emptyDir.path)

    XCTAssertTrue(foundFiles.isEmpty)
  }

  func testFindAllProtoFilesDirectoryNotFound() {
    XCTAssertThrowsError(try scanner.findAllProtoFiles(in: "/nonexistent/directory")) { error in
      guard let resolverError = error as? ResolverError else {
        XCTFail("Expected ResolverError")
        return
      }

      if case .directoryNotFound(let path) = resolverError {
        XCTAssertEqual(path, "/nonexistent/directory")
      }
      else {
        XCTFail("Expected directoryNotFound error")
      }
    }
  }

  func testFindAllProtoFilesNotADirectory() throws {
    // Create a regular file
    let regularFile = tempDir.appendingPathComponent("notdir.txt")
    try "not a directory".write(to: regularFile, atomically: true, encoding: .utf8)

    XCTAssertThrowsError(try scanner.findAllProtoFiles(in: regularFile.path)) { error in
      guard let resolverError = error as? ResolverError else {
        XCTFail("Expected ResolverError")
        return
      }

      if case .directoryNotFound(_) = resolverError {
        // Expected
      }
      else {
        XCTFail("Expected directoryNotFound error")
      }
    }
  }

  // MARK: - Recursive Scanning Tests

  func testFindAllProtoFilesRecursively() throws {
    // Create nested directory structure
    let subDir1 = tempDir.appendingPathComponent("sub1")
    let subDir2 = subDir1.appendingPathComponent("sub2")

    try FileManager.default.createDirectory(at: subDir1, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: subDir2, withIntermediateDirectories: true)

    // Create proto files at different levels
    let files = [
      (tempDir.appendingPathComponent("root.proto"), "root"),
      (subDir1.appendingPathComponent("sub1.proto"), "sub1"),
      (subDir2.appendingPathComponent("sub2.proto"), "sub2"),
    ]

    for (file, package) in files {
      let content =
        "syntax = \"proto3\"; package \(package); message \(package.capitalized)Message { string name = 1; }"
      try content.write(to: file, atomically: true, encoding: .utf8)
    }

    let foundFiles = try scanner.findAllProtoFilesRecursively(in: tempDir.path)

    XCTAssertEqual(foundFiles.count, 3)

    // Check that all files were found
    for (expectedFile, _) in files {
      XCTAssertTrue(foundFiles.contains(expectedFile.path))
    }
  }

  func testFindAllProtoFilesRecursivelyEmptyTree() throws {
    let emptyDir = tempDir.appendingPathComponent("empty")
    try FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)

    let foundFiles = try scanner.findAllProtoFilesRecursively(in: emptyDir.path)

    XCTAssertTrue(foundFiles.isEmpty)
  }

  func testFindAllProtoFilesRecursivelyDirectoryNotFound() {
    XCTAssertThrowsError(try scanner.findAllProtoFilesRecursively(in: "/nonexistent/directory")) { error in
      guard let resolverError = error as? ResolverError else {
        XCTFail("Expected ResolverError")
        return
      }

      if case .directoryNotFound(let path) = resolverError {
        XCTAssertEqual(path, "/nonexistent/directory")
      }
      else {
        XCTFail("Expected directoryNotFound error")
      }
    }
  }

  func testFindAllProtoFilesRecursivelyWithMixedFiles() throws {
    // Create complex directory structure with mixed files
    let subDir1 = tempDir.appendingPathComponent("proto")
    let subDir2 = tempDir.appendingPathComponent("other")
    let subDir3 = subDir1.appendingPathComponent("nested")

    try FileManager.default.createDirectory(at: subDir1, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: subDir2, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: subDir3, withIntermediateDirectories: true)

    // Create various files
    let filesToCreate = [
      (tempDir.appendingPathComponent("root.proto"), "proto"),
      (tempDir.appendingPathComponent("readme.txt"), "text"),
      (subDir1.appendingPathComponent("service.proto"), "proto"),
      (subDir1.appendingPathComponent("config.json"), "json"),
      (subDir2.appendingPathComponent("data.xml"), "xml"),
      (subDir3.appendingPathComponent("nested.proto"), "proto"),
    ]

    for (file, type) in filesToCreate {
      let content =
        type == "proto"
        ? "syntax = \"proto3\"; package test; message TestMessage { string name = 1; }" : "not a proto file"
      try content.write(to: file, atomically: true, encoding: .utf8)
    }

    let foundFiles = try scanner.findAllProtoFilesRecursively(in: tempDir.path)

    // Should find only the .proto files
    XCTAssertEqual(foundFiles.count, 3)
    for file in foundFiles {
      XCTAssertTrue(file.hasSuffix(".proto"))
    }
  }

  // MARK: - Path Utility Tests

  func testAbsolutePath() {
    let relativePath = "test.proto"
    let absolutePath = scanner.absolutePath(for: relativePath)

    XCTAssertTrue(absolutePath.contains("test.proto"))
    XCTAssertTrue((absolutePath as NSString).isAbsolutePath)
  }

  func testAbsolutePathAlreadyAbsolute() {
    let alreadyAbsolute = "/absolute/path/test.proto"
    let result = scanner.absolutePath(for: alreadyAbsolute)

    XCTAssertEqual(result, alreadyAbsolute)
  }

  func testIsAccessible() {
    XCTAssertTrue(scanner.isAccessible(tempDir.path))
    XCTAssertFalse(scanner.isAccessible("/nonexistent/path"))
  }

  func testIsDirectory() {
    XCTAssertTrue(scanner.isDirectory(tempDir.path))
    XCTAssertFalse(scanner.isDirectory("/nonexistent/path"))

    // Create a regular file
    let regularFile = tempDir.appendingPathComponent("regular.txt")
    try! "content".write(to: regularFile, atomically: true, encoding: .utf8)

    XCTAssertFalse(scanner.isDirectory(regularFile.path))
  }

  // MARK: - Import Path Validation Tests

  func testValidateImportPathsSuccess() {
    XCTAssertNoThrow(try scanner.validateImportPaths())
  }

  func testValidateImportPathsNonExistentDirectory() {
    let invalidScanner = FileSystemScanner(importPaths: ["/nonexistent/path"])

    XCTAssertThrowsError(try invalidScanner.validateImportPaths()) { error in
      guard let resolverError = error as? ResolverError else {
        XCTFail("Expected ResolverError")
        return
      }

      if case .directoryNotFound(let path) = resolverError {
        XCTAssertEqual(path, "/nonexistent/path")
      }
      else {
        XCTFail("Expected directoryNotFound error")
      }
    }
  }

  func testValidateImportPathsNotADirectory() throws {
    // Create a regular file
    let regularFile = tempDir.appendingPathComponent("notdir.txt")
    try "content".write(to: regularFile, atomically: true, encoding: .utf8)

    let invalidScanner = FileSystemScanner(importPaths: [regularFile.path])

    XCTAssertThrowsError(try invalidScanner.validateImportPaths()) { error in
      guard let resolverError = error as? ResolverError else {
        XCTFail("Expected ResolverError")
        return
      }

      if case .invalidImportPathWithReason(let path, let reason) = resolverError {
        XCTAssertEqual(path, regularFile.path)
        XCTAssertEqual(reason, "not a directory")
      }
      else {
        XCTFail("Expected invalidImportPathWithReason error")
      }
    }
  }

  func testValidateImportPathsMultiplePaths() throws {
    // Create additional valid directory
    let validDir = tempDir.appendingPathComponent("valid")
    try FileManager.default.createDirectory(at: validDir, withIntermediateDirectories: true)

    // Create invalid file
    let invalidFile = tempDir.appendingPathComponent("invalid.txt")
    try "content".write(to: invalidFile, atomically: true, encoding: .utf8)

    let mixedScanner = FileSystemScanner(importPaths: [tempDir.path, validDir.path, invalidFile.path])

    XCTAssertThrowsError(try mixedScanner.validateImportPaths()) { error in
      XCTAssertTrue(error is ResolverError)
    }
  }

  // MARK: - Well-Known Types Tests

  func testWellKnownTypesStatic() {
    XCTAssertTrue(FileSystemScanner.isWellKnownType("google/protobuf/timestamp.proto"))
    XCTAssertTrue(FileSystemScanner.isWellKnownType("google/protobuf/any.proto"))
    XCTAssertTrue(FileSystemScanner.isWellKnownType("google/protobuf/duration.proto"))
    XCTAssertTrue(FileSystemScanner.isWellKnownType("google/type/date.proto"))
    XCTAssertTrue(FileSystemScanner.isWellKnownType("google/api/annotations.proto"))

    XCTAssertFalse(FileSystemScanner.isWellKnownType("custom/file.proto"))
    XCTAssertFalse(FileSystemScanner.isWellKnownType(""))
    XCTAssertFalse(FileSystemScanner.isWellKnownType("protobuf/timestamp.proto"))
  }

  func testWellKnownTypesListNotEmpty() {
    let wellKnownTypes = FileSystemScanner.wellKnownTypes()

    XCTAssertFalse(wellKnownTypes.isEmpty)
    XCTAssertTrue(wellKnownTypes.contains("google/protobuf/timestamp.proto"))
    XCTAssertTrue(wellKnownTypes.contains("google/protobuf/any.proto"))
    XCTAssertTrue(wellKnownTypes.contains("google/protobuf/duration.proto"))
    XCTAssertTrue(wellKnownTypes.contains("google/protobuf/empty.proto"))
  }

  // MARK: - Edge Cases and Error Handling

  func testFindProtoFileWithSpecialCharacters() throws {
    let specialFileName = "test-file_name.proto"
    let protoContent = "syntax = \"proto3\"; package test; message TestMessage { string name = 1; }"
    let protoFile = tempDir.appendingPathComponent(specialFileName)
    try protoContent.write(to: protoFile, atomically: true, encoding: .utf8)

    let foundPath = try scanner.findProtoFile(specialFileName)

    XCTAssertEqual(foundPath, protoFile.path)
  }

  func testFindAllProtoFilesWithSpecialCharacters() throws {
    let specialFiles = ["test-1_file.proto", "test.2.proto", "test_special-name.proto"]

    for fileName in specialFiles {
      let content = "syntax = \"proto3\"; package test; message TestMessage { string name = 1; }"
      let file = tempDir.appendingPathComponent(fileName)
      try content.write(to: file, atomically: true, encoding: .utf8)
    }

    let foundFiles = try scanner.findAllProtoFiles(in: tempDir.path)

    XCTAssertEqual(foundFiles.count, specialFiles.count)
  }

  func testEmptyImportPaths() {
    let emptyScanner = FileSystemScanner(importPaths: [])
    let description = emptyScanner.description

    XCTAssertTrue(description.contains("FileSystemScanner"))
    XCTAssertTrue(description.contains("importPaths: []"))
  }

  func testScannerDescription() {
    let description = scanner.description

    XCTAssertTrue(description.contains("FileSystemScanner"))
    XCTAssertTrue(description.contains("importPaths"))
    XCTAssertTrue(description.contains(tempDir.path))
  }

  // MARK: - Permissions and Access Tests

  func testFindProtoFileRelativeToCurrentDirectory() throws {
    // Save current directory
    let originalDirectory = FileManager.default.currentDirectoryPath
    defer {
      FileManager.default.changeCurrentDirectoryPath(originalDirectory)
    }

    // Change to temp directory
    FileManager.default.changeCurrentDirectoryPath(tempDir.path)

    // Create file in current directory
    let protoContent = "syntax = \"proto3\"; package test; message TestMessage { string name = 1; }"
    let protoFile = tempDir.appendingPathComponent("current.proto")
    try protoContent.write(to: protoFile, atomically: true, encoding: .utf8)

    // Create scanner with no import paths
    let emptyScanner = FileSystemScanner(importPaths: [])

    // Should find file relative to current directory
    let foundPath = try emptyScanner.findProtoFile("current.proto")

    // Normalize paths to handle /var vs /private/var differences on macOS
    let normalizedFoundPath = URL(fileURLWithPath: foundPath).resolvingSymlinksInPath().path
    let normalizedExpectedPath = protoFile.resolvingSymlinksInPath().path

    XCTAssertEqual(normalizedFoundPath, normalizedExpectedPath)
  }
}
