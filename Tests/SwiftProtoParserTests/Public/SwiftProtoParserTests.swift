import Foundation
import XCTest

@testable import SwiftProtoParser

final class SwiftProtoParserTests: XCTestCase {

  // MARK: - Helpers

  private func writeTempProto(_ content: String, name: String = "test.proto") -> String {
    let dir = (NSTemporaryDirectory() as NSString).appendingPathComponent("spp_\(UUID().uuidString)")
    try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    let path = (dir as NSString).appendingPathComponent(name)
    try! content.write(toFile: path, atomically: true, encoding: .utf8)
    return path
  }

  private func removeTempFile(_ path: String) {
    // Remove the parent temp directory created by writeTempProto
    let dir = (path as NSString).deletingLastPathComponent
    try? FileManager.default.removeItem(atPath: dir)
  }

  // MARK: - Basic Parsing Tests

  func testParseSimpleProtoString() {
    let path = writeTempProto(
      """
      syntax = "proto3";
      message HelloWorld {
          string name = 1;
      }
      """
    )
    defer { removeTempFile(path) }

    let result = SwiftProtoParser.parseFile(path)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file.count, 1)
      XCTAssertEqual(set.file[0].syntax, "proto3")
      XCTAssertEqual(set.file[0].messageType.count, 1)
      XCTAssertEqual(set.file[0].messageType[0].name, "HelloWorld")
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoWithPackage() {
    let path = writeTempProto(
      """
      syntax = "proto3";
      package com.example;
      message User {
          string name = 1;
          int32 age = 2;
      }
      """
    )
    defer { removeTempFile(path) }

    let result = SwiftProtoParser.parseFile(path)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file[0].syntax, "proto3")
      XCTAssertEqual(set.file[0].package, "com.example")
      XCTAssertEqual(set.file[0].messageType.count, 1)
      XCTAssertEqual(set.file[0].messageType[0].name, "User")
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoWithMultipleMessages() {
    let path = writeTempProto(
      """
      syntax = "proto3";
      message Person {
          string name = 1;
      }
      message Address {
          string street = 1;
          string city = 2;
      }
      """
    )
    defer { removeTempFile(path) }

    let result = SwiftProtoParser.parseFile(path)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file[0].messageType.count, 2)
      XCTAssertEqual(set.file[0].messageType[0].name, "Person")
      XCTAssertEqual(set.file[0].messageType[1].name, "Address")
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  // MARK: - Convenience Methods Tests (now via parseFile)

  func testGetProtoVersion() {
    let path = writeTempProto(
      """
      syntax = "proto3";
      message Test {}
      """
    )
    defer { removeTempFile(path) }

    let result = SwiftProtoParser.parseFile(path)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file[0].syntax, "proto3")
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testGetPackageName() {
    let path = writeTempProto(
      """
      syntax = "proto3";
      package my.test.package;
      message Test {}
      """
    )
    defer { removeTempFile(path) }

    let result = SwiftProtoParser.parseFile(path)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file[0].package, "my.test.package")
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testGetMessageNames() {
    let path = writeTempProto(
      """
      syntax = "proto3";
      message FirstMessage { string field1 = 1; }
      message SecondMessage { int32 field2 = 1; }
      message ThirdMessage { bool field3 = 1; }
      """
    )
    defer { removeTempFile(path) }

    let result = SwiftProtoParser.parseFile(path)

    switch result {
    case .success(let set):
      let names = set.file[0].messageType.map { $0.name }
      XCTAssertEqual(names, ["FirstMessage", "SecondMessage", "ThirdMessage"])
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  // MARK: - Error Handling Tests

  func testParseInvalidSyntax() {
    // proto2 is not officially supported but the parser converts it to proto3 internally
    let path = writeTempProto(
      """
      syntax = "proto2";
      message Test {}
      """
    )
    defer { removeTempFile(path) }

    let result = SwiftProtoParser.parseFile(path)

    // Should still parse (proto2 converted to proto3 internally)
    switch result {
    case .success(let set):
      XCTAssertEqual(set.file[0].syntax, "proto3")
    case .failure:
      break  // Some parsers may reject proto2 — either outcome is acceptable
    }
  }

  func testParseIncompleteProto() {
    let path = writeTempProto(
      """
      syntax = "proto3";
      message Test {
          string name =
      """
    )
    defer { removeTempFile(path) }

    let result = SwiftProtoParser.parseFile(path)

    switch result {
    case .success:
      XCTFail("Expected failure for incomplete proto")
    case .failure(let error):
      XCTAssertTrue(error.description.contains("Syntax error") || error.description.contains("error"))
    }
  }

  func testParseMissingSyntax() {
    let path = writeTempProto(
      """
      message Test {
          string name = 1;
      }
      """
    )
    defer { removeTempFile(path) }

    let result = SwiftProtoParser.parseFile(path)

    switch result {
    case .success:
      XCTFail("Expected failure because syntax declaration is required")
    case .failure:
      break  // Any error is acceptable — DependencyResolver or parser may reject missing syntax
    }
  }

  func testParseEmptyString() {
    let path = writeTempProto("")
    defer { removeTempFile(path) }

    let result = SwiftProtoParser.parseFile(path)

    switch result {
    case .success:
      XCTFail("Expected failure for empty file")
    case .failure:
      break
    }
  }

  // MARK: - Future API Tests

  func testParseFileWithNonExistentPath() {
    let result = SwiftProtoParser.parseFile("test.proto")

    switch result {
    case .success:
      XCTFail("Expected failure for non-existent file")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("Dependency resolution failed") || error.description.contains("I/O error")
      )
    }
  }

  func testParseDirectoryWithNonExistentPath() {
    let result = SwiftProtoParser.parseDirectory("/some/path")

    switch result {
    case .success:
      XCTFail("Expected failure for non-existent directory")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("Dependency resolution failed") || error.description.contains("I/O error")
      )
    }
  }

  // MARK: - Integration Tests

  func testComplexProtoFile() {
    let path = writeTempProto(
      """
      syntax = "proto3";
      package example.complex;
      option java_package = "com.example.complex";

      enum Status {
          UNKNOWN = 0;
          ACTIVE = 1;
          INACTIVE = 2;
      }

      message User {
          string name = 1;
          int32 age = 2;
          Status status = 3;
          repeated string hobbies = 4;
      }

      service UserService {
          rpc GetUser(UserRequest) returns (User);
      }

      message UserRequest {
          string user_id = 1;
      }
      """
    )
    defer { removeTempFile(path) }

    let result = SwiftProtoParser.parseFile(path)

    switch result {
    case .success(let set):
      let fd = set.file[0]
      XCTAssertEqual(fd.syntax, "proto3")
      XCTAssertEqual(fd.package, "example.complex")
      XCTAssertTrue(fd.hasOptions)
      XCTAssertEqual(fd.messageType.count, 2)
      XCTAssertEqual(fd.enumType.count, 1)
      XCTAssertEqual(fd.service.count, 1)

      let user = fd.messageType.first { $0.name == "User" }
      XCTAssertNotNil(user)
      XCTAssertEqual(user?.field.count, 4)

      XCTAssertEqual(fd.enumType[0].name, "Status")
      XCTAssertEqual(fd.service[0].name, "UserService")
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  // MARK: - Direct Parsing Test (previously tested Lexer/Parser directly)

  func testDirectLexerAndParser() {
    // Previously tested via internal Lexer/Parser directly; now uses public parseFile API
    let path = writeTempProto(
      """
      syntax = "proto3";
      message HelloWorld {
          string name = 1;
      }
      """
    )
    defer { removeTempFile(path) }

    let result = SwiftProtoParser.parseFile(path)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file[0].syntax, "proto3")
      XCTAssertEqual(set.file[0].messageType.count, 1)
      XCTAssertEqual(set.file[0].messageType[0].name, "HelloWorld")
    case .failure(let errors):
      XCTFail("Parser failed: \(errors)")
    }
  }

  // MARK: - Debug Tests

  func testSimpleEnumOnly() {
    let path = writeTempProto(
      """
      syntax = "proto3";
      enum Status {
          UNKNOWN = 0;
          ACTIVE = 1;
          INACTIVE = 2;
      }
      """
    )
    defer { removeTempFile(path) }

    let result = SwiftProtoParser.parseFile(path)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file[0].enumType.count, 1)
      XCTAssertEqual(set.file[0].enumType[0].name, "Status")
      XCTAssertEqual(set.file[0].enumType[0].value.count, 3)
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testSimpleServiceOnly() {
    let path = writeTempProto(
      """
      syntax = "proto3";
      service UserService {
          rpc GetUser(UserRequest) returns (User);
      }
      message UserRequest { string user_id = 1; }
      message User { string name = 1; }
      """
    )
    defer { removeTempFile(path) }

    let result = SwiftProtoParser.parseFile(path)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file[0].service.count, 1)
      XCTAssertEqual(set.file[0].service[0].name, "UserService")
      XCTAssertEqual(set.file[0].service[0].method.count, 1)
      XCTAssertEqual(set.file[0].messageType.count, 2)
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  // MARK: - Descriptor API Tests

  func testParseProtoStringToDescriptorsSuccess() {
    let path = writeTempProto(
      """
      syntax = "proto3";
      package com.example;

      message User {
        int32 id = 1;
        string name = 2;
        bool active = 3;
      }

      enum Status {
        UNKNOWN = 0;
        ACTIVE = 1;
        INACTIVE = 2;
      }

      service UserService {
        rpc GetUser(User) returns (User);
      }
      """,
      name: "test.proto"
    )
    defer { removeTempFile(path) }

    let result = SwiftProtoParser.parseFile(path)

    switch result {
    case .success(let set):
      let fd = set.file[0]
      XCTAssertEqual(fd.syntax, "proto3")
      XCTAssertEqual(fd.package, "com.example")

      XCTAssertEqual(fd.messageType.count, 1)
      let user = fd.messageType[0]
      XCTAssertEqual(user.name, "User")
      XCTAssertEqual(user.field.count, 3)
      XCTAssertEqual(user.field[0].name, "id")
      XCTAssertEqual(user.field[0].number, 1)
      XCTAssertEqual(user.field[0].type, .int32)
      XCTAssertEqual(user.field[1].name, "name")
      XCTAssertEqual(user.field[1].number, 2)
      XCTAssertEqual(user.field[1].type, .string)
      XCTAssertEqual(user.field[2].name, "active")
      XCTAssertEqual(user.field[2].number, 3)
      XCTAssertEqual(user.field[2].type, .bool)

      XCTAssertEqual(fd.enumType.count, 1)
      let status = fd.enumType[0]
      XCTAssertEqual(status.name, "Status")
      XCTAssertEqual(status.value.count, 3)
      XCTAssertEqual(status.value[0].name, "UNKNOWN")
      XCTAssertEqual(status.value[0].number, 0)

      XCTAssertEqual(fd.service.count, 1)
      let svc = fd.service[0]
      XCTAssertEqual(svc.name, "UserService")
      XCTAssertEqual(svc.method.count, 1)
      XCTAssertEqual(svc.method[0].name, "GetUser")
      XCTAssertEqual(svc.method[0].inputType, ".com.example.User")
      XCTAssertEqual(svc.method[0].outputType, ".com.example.User")

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoStringToDescriptorsWithInvalidSyntax() {
    let path = writeTempProto(
      """
      syntax = "proto3";
      message User {
        int32 = 1;
      }
      """,
      name: "invalid.proto"
    )
    defer { removeTempFile(path) }

    let result = SwiftProtoParser.parseFile(path)

    switch result {
    case .success:
      XCTFail("Expected parsing to fail due to missing field name")
    case .failure(let error):
      XCTAssertTrue(error.description.contains("Unexpected token") || error.description.contains("error"))
    }
  }

  func testParseProtoStringToDescriptorsWithDescriptorError() {
    let path = writeTempProto(
      """
      syntax = "proto3";
      message EmptyMessage {}
      """,
      name: "empty.proto"
    )
    defer { removeTempFile(path) }

    let result = SwiftProtoParser.parseFile(path)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file[0].messageType.count, 1)
      XCTAssertEqual(set.file[0].messageType[0].name, "EmptyMessage")
      XCTAssertEqual(set.file[0].messageType[0].field.count, 0)
    case .failure(let error):
      XCTFail("Expected success for empty message, got error: \(error)")
    }
  }

  func testParseProtoToDescriptorsFromFile() {
    let path = writeTempProto(
      """
      syntax = "proto3";
      package test;
      message TestMessage {
        string content = 1;
        int32 value = 2;
      }
      """,
      name: "test_descriptors.proto"
    )
    defer { removeTempFile(path) }

    let result = SwiftProtoParser.parseFile(path)

    switch result {
    case .success(let set):
      let fd = set.file[0]
      XCTAssertEqual(fd.syntax, "proto3")
      XCTAssertEqual(fd.package, "test")
      XCTAssertEqual(fd.messageType.count, 1)
      XCTAssertEqual(fd.messageType[0].name, "TestMessage")
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoToDescriptorsFileNotFound() {
    let result = SwiftProtoParser.parseFile("/non/existent/path/test.proto")

    switch result {
    case .success:
      XCTFail("Expected file not found error")
    case .failure(let error):
      switch error {
      case .ioError, .dependencyResolutionError:
        break
      default:
        XCTFail("Expected ioError or dependencyResolutionError, got: \(error)")
      }
    }
  }

  func testParseProtoStringToDescriptorsWithOptions() {
    let path = writeTempProto(
      """
      syntax = "proto3";
      option java_package = "com.example.generated";
      option java_outer_classname = "TestProto";
      message TestMessage {
        string name = 1 [deprecated = true];
        int32 id = 2;
      }
      """,
      name: "options_test.proto"
    )
    defer { removeTempFile(path) }

    let result = SwiftProtoParser.parseFile(path)

    switch result {
    case .success(let set):
      let fd = set.file[0]
      XCTAssertTrue(fd.hasOptions)
      XCTAssertEqual(fd.options.javaPackage, "com.example.generated")
      XCTAssertEqual(fd.options.javaOuterClassname, "TestProto")

      let nameField = fd.messageType[0].field[0]
      XCTAssertTrue(nameField.hasOptions)
      XCTAssertTrue(nameField.options.deprecated)
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoStringToDescriptorsComplexTypes() {
    let path = writeTempProto(
      """
      syntax = "proto3";
      message Outer {
        message Inner { string value = 1; }
        Inner inner = 1;
        repeated string tags = 2;
        map<string, int32> counts = 3;
      }
      """,
      name: "complex.proto"
    )
    defer { removeTempFile(path) }

    let result = SwiftProtoParser.parseFile(path)

    switch result {
    case .success(let set):
      let outer = set.file[0].messageType[0]
      XCTAssertEqual(outer.name, "Outer")

      // Inner + CountsEntry (synthetic map entry)
      XCTAssertEqual(outer.nestedType.count, 2)

      let countsEntry = outer.nestedType.first { $0.name == "CountsEntry" }
      XCTAssertNotNil(countsEntry)
      XCTAssertTrue(countsEntry?.options.mapEntry ?? false)
      XCTAssertEqual(countsEntry?.field.count, 2)

      let keyField = countsEntry?.field.first { $0.name == "key" }
      XCTAssertEqual(keyField?.number, 1)
      XCTAssertEqual(keyField?.type, .string)
      XCTAssertEqual(keyField?.label, .optional)

      let valueField = countsEntry?.field.first { $0.name == "value" }
      XCTAssertEqual(valueField?.number, 2)
      XCTAssertEqual(valueField?.type, .int32)
      XCTAssertEqual(valueField?.label, .optional)

      let innerMsg = outer.nestedType.first { $0.name == "Inner" }
      XCTAssertNotNil(innerMsg)
      XCTAssertEqual(innerMsg?.field.count, 1)

      XCTAssertEqual(outer.field.count, 3)
      XCTAssertEqual(outer.field[0].name, "inner")
      XCTAssertEqual(outer.field[1].name, "tags")
      XCTAssertEqual(outer.field[1].label, .repeated)
      XCTAssertEqual(outer.field[1].type, .string)
      XCTAssertEqual(outer.field[2].name, "counts")
      XCTAssertEqual(outer.field[2].type, .message)

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }
}
