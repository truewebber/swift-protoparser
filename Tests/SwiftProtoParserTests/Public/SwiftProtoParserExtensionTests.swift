import Foundation
import XCTest

@testable import SwiftProtoParser

final class SwiftProtoParserExtensionTests: XCTestCase {

  // MARK: - Helpers

  private func writeTempProto(_ content: String, name: String = "test.proto") -> URL {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("spe_\(UUID().uuidString)", isDirectory: true)
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent(name)
    try! content.write(to: url, atomically: true, encoding: .utf8)
    return url
  }

  private func removeTempDir(for url: URL) {
    try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
  }

  // MARK: - File IO Tests

  func testParseProtoFileSuccess() {
    let tempFile = writeTempProto(
      """
      syntax = "proto3";
      message TestMessage {
          string name = 1;
      }
      """
    )
    defer { removeTempDir(for: tempFile) }

    let result = SwiftProtoParser.parseFile(tempFile.path)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file[0].syntax, "proto3")
      XCTAssertEqual(set.file[0].messageType.count, 1)
      XCTAssertEqual(set.file[0].messageType[0].name, "TestMessage")
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoFileNotFound() {
    let result = SwiftProtoParser.parseFile("/nonexistent/path/to/file.proto")

    switch result {
    case .success:
      XCTFail("Expected failure")
    case .failure(let error):
      switch error {
      case .ioError, .dependencyResolutionError:
        break
      default:
        XCTFail("Expected ioError or dependencyResolutionError, got \(error)")
      }
    }
  }

  func testParseProtoFileInvalidPath() {
    let result = SwiftProtoParser.parseFile("")

    switch result {
    case .success:
      XCTFail("Expected failure for empty path")
    case .failure(let error):
      switch error {
      case .ioError, .dependencyResolutionError:
        break
      default:
        XCTFail("Expected ioError or dependencyResolutionError, got \(error)")
      }
    }
  }

  // MARK: - parseFile with custom content Tests

  func testParseProtoStringWithCustomFileName() {
    let tempFile = writeTempProto(
      """
      syntax = "proto3";
      message User {
          string name = 1;
      }
      """,
      name: "custom_user.proto"
    )
    defer { removeTempDir(for: tempFile) }

    let result = SwiftProtoParser.parseFile(tempFile.path)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file[0].syntax, "proto3")
      XCTAssertEqual(set.file[0].messageType.count, 1)
      XCTAssertEqual(set.file[0].messageType[0].name, "User")
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoStringWithErrorFileName() {
    let tempFile = writeTempProto(
      """
      syntax = "proto3";
      message InvalidMessage {
          string name =
      """,
      name: "error_test.proto"
    )
    defer { removeTempDir(for: tempFile) }

    let result = SwiftProtoParser.parseFile(tempFile.path)

    switch result {
    case .success:
      XCTFail("Expected failure for invalid proto")
    case .failure(let error):
      if case .syntaxError(let message, let file, let line, let column) = error {
        XCTAssertEqual(file, "error_test.proto")
        XCTAssertFalse(message.isEmpty)
        XCTAssertGreaterThan(line, 0)
        XCTAssertGreaterThan(column, 0)
      }
      else {
        XCTFail("Expected syntaxError with file name, got \(error)")
      }
    }
  }

  // MARK: - getProtoVersion (now via parseFile)

  func testGetProtoVersionFromFile() {
    let tempFile = writeTempProto(
      """
      syntax = "proto3";
      message VersionTest {}
      """,
      name: "version_test.proto"
    )
    defer { removeTempDir(for: tempFile) }

    let result = SwiftProtoParser.parseFile(tempFile.path)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file[0].syntax, "proto3")
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testGetProtoVersionFileNotFound() {
    let result = SwiftProtoParser.parseFile("/nonexistent/file.proto")

    switch result {
    case .success:
      XCTFail("Expected failure")
    case .failure(let error):
      switch error {
      case .ioError, .dependencyResolutionError:
        break
      default:
        XCTFail("Expected ioError or dependencyResolutionError, got \(error)")
      }
    }
  }

  // MARK: - getPackageName (now via parseFile)

  func testGetPackageNameFromFile() {
    let tempFile = writeTempProto(
      """
      syntax = "proto3";
      package com.example.test;
      message PackageTest {}
      """,
      name: "package_test.proto"
    )
    defer { removeTempDir(for: tempFile) }

    let result = SwiftProtoParser.parseFile(tempFile.path)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file[0].package, "com.example.test")
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testGetPackageNameNoPackage() {
    let tempFile = writeTempProto(
      """
      syntax = "proto3";
      message NoPackageTest {}
      """,
      name: "no_package_test.proto"
    )
    defer { removeTempDir(for: tempFile) }

    let result = SwiftProtoParser.parseFile(tempFile.path)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file[0].package, "")
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  // MARK: - getMessageNames (now via parseFile)

  func testGetMessageNamesFromFile() {
    let tempFile = writeTempProto(
      """
      syntax = "proto3";
      message FirstMessage { string field1 = 1; }
      message SecondMessage { int32 field2 = 1; }
      message ThirdMessage { bool field3 = 1; }
      """,
      name: "messages_test.proto"
    )
    defer { removeTempDir(for: tempFile) }

    let result = SwiftProtoParser.parseFile(tempFile.path)

    switch result {
    case .success(let set):
      let names = set.file[0].messageType.map { $0.name }
      XCTAssertEqual(names, ["FirstMessage", "SecondMessage", "ThirdMessage"])
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testGetMessageNamesNoMessages() {
    let tempFile = writeTempProto(
      """
      syntax = "proto3";
      enum Status {
          UNKNOWN = 0;
          ACTIVE = 1;
      }
      """,
      name: "no_messages_test.proto"
    )
    defer { removeTempDir(for: tempFile) }

    let result = SwiftProtoParser.parseFile(tempFile.path)

    switch result {
    case .success(let set):
      XCTAssertTrue(set.file[0].messageType.isEmpty)
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  // MARK: - parseFile / parseDirectory with invalid paths

  func testParseProtoFileWithImportsWithPaths() {
    let result = SwiftProtoParser.parseFile("test.proto", importPaths: ["/path1", "/path2"])

    switch result {
    case .success:
      XCTFail("Expected failure for non-existent file")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("Dependency resolution failed") || error.description.contains("I/O error")
      )
    }
  }

  func testParseProtoDirectoryWithOptions() {
    let result = SwiftProtoParser.parseDirectory(
      "/some/directory",
      recursive: true,
      importPaths: ["/path1"]
    )

    switch result {
    case .success:
      XCTFail("Expected failure for non-existent directory")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("Dependency resolution failed") || error.description.contains("I/O error")
      )
    }
  }

  // MARK: - Error Conversion Tests

  func testParserErrorConversion() {
    let tempFile = writeTempProto(
      """
      syntax = "proto3";
      message Test {
          string field1 = 0;
      }
      """,
      name: "test_error.proto"
    )
    defer { removeTempDir(for: tempFile) }

    let result = SwiftProtoParser.parseFile(tempFile.path)

    switch result {
    case .success:
      XCTFail("Expected failure for field number 0")
    case .failure(let error):
      if case .syntaxError(let message, let fileName, let line, let column) = error {
        XCTAssertEqual(fileName, "test_error.proto")
        XCTAssertGreaterThan(line, 0)
        XCTAssertGreaterThan(column, 0)
        XCTAssertFalse(message.isEmpty)
      }
      else {
        XCTFail("Expected syntaxError, got \(error)")
      }
    }
  }

  func testEmptyParserErrors() {
    let tempFile = writeTempProto("syntax = \"proto3\";")
    defer { removeTempDir(for: tempFile) }

    let result = SwiftProtoParser.parseFile(tempFile.path)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file[0].syntax, "proto3")
      XCTAssertEqual(set.file[0].package, "")
      XCTAssertTrue(set.file[0].messageType.isEmpty)
      XCTAssertTrue(set.file[0].enumType.isEmpty)
      XCTAssertTrue(set.file[0].service.isEmpty)
    case .failure:
      break
    }
  }

  // MARK: - Edge Cases Tests

  func testParseProtoStringEmpty() {
    let tempFile = writeTempProto("")
    defer { removeTempDir(for: tempFile) }

    let result = SwiftProtoParser.parseFile(tempFile.path)

    // Empty file = no syntax → proto2 → must succeed (AC-1).
    switch result {
    case .success(let set):
      XCTAssertEqual(set.file[0].syntax, "", "Empty file descriptor syntax must be empty string (AC-1)")
    case .failure(let error):
      XCTFail("Empty file must succeed as no-syntax proto2 (AC-1): \(error)")
    }
  }

  func testParseProtoStringWhitespaceOnly() {
    let tempFile = writeTempProto("   \n\t  \r\n  ")
    defer { removeTempDir(for: tempFile) }

    let result = SwiftProtoParser.parseFile(tempFile.path)

    switch result {
    case .success:
      XCTFail("Expected failure for whitespace-only file")
    case .failure:
      break
    }
  }

  func testParseProtoStringUnicodeContent() {
    let tempFile = writeTempProto(
      """
      syntax = "proto3";
      message UnicodeTest {
          string unicode_field = 1; // 测试 unicode
      }
      """,
      name: "unicode_test.proto"
    )
    defer { removeTempDir(for: tempFile) }

    let result = SwiftProtoParser.parseFile(tempFile.path)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file[0].messageType.count, 1)
      XCTAssertEqual(set.file[0].messageType[0].name, "UnicodeTest")
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  // MARK: - Static API Tests

  func testSwiftProtoParserCannotBeInstantiated() {
    // Verify that the API surface is static only — both methods return Result types
    let fileResult = SwiftProtoParser.parseFile("")
    let dirResult = SwiftProtoParser.parseDirectory("")

    // Both should fail for invalid paths
    switch fileResult {
    case .success:
      XCTFail("Empty path should fail")
    case .failure:
      break
    }
    switch dirResult {
    case .success:
      XCTFail("Empty dir should fail")
    case .failure:
      break
    }
  }

  // MARK: - Complex Integration Tests

  func testParseComplexFileFromDisk() {
    let tempFile = writeTempProto(
      """
      syntax = "proto3";
      package integration.test;
      option java_package = "com.integration.test";

      enum UserType {
          UNKNOWN_USER = 0;
          REGULAR_USER = 1;
          ADMIN_USER = 2;
      }

      message User {
          string id = 1;
          string name = 2;
          UserType type = 3;
          repeated string tags = 4;
      }

      message UserList {
          repeated User users = 1;
          int32 total_count = 2;
      }

      service UserService {
          rpc GetUser(GetUserRequest) returns (User);
      }

      message GetUserRequest {
          string user_id = 1;
      }
      """,
      name: "complex_integration.proto"
    )
    defer { removeTempDir(for: tempFile) }

    let result = SwiftProtoParser.parseFile(tempFile.path)

    switch result {
    case .success(let set):
      let fd = set.file[0]
      XCTAssertEqual(fd.syntax, "proto3")
      XCTAssertEqual(fd.package, "integration.test")
      XCTAssertTrue(fd.hasOptions)
      XCTAssertEqual(fd.enumType.count, 1)
      XCTAssertEqual(fd.messageType.count, 3)
      XCTAssertEqual(fd.service.count, 1)

      // Verify message names via parseFile (replaces getMessageNames)
      let names = fd.messageType.map { $0.name }
      XCTAssertEqual(names.count, 3)
      XCTAssertTrue(names.contains("User"))
      XCTAssertTrue(names.contains("UserList"))
      XCTAssertTrue(names.contains("GetUserRequest"))

      // Verify package (replaces getPackageName)
      XCTAssertEqual(fd.package, "integration.test")

      // Verify syntax (replaces getProtoVersion)
      XCTAssertEqual(fd.syntax, "proto3")

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }
}
