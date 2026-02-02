import XCTest

@testable import SwiftProtoParser

final class SwiftProtoParserTests: XCTestCase {

  // MARK: - Basic Parsing Tests

  func testParseSimpleProtoString() {
    let protoContent = """
      syntax = "proto3";

      message HelloWorld {
          string name = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    XCTAssertTrue(result.isSuccess)
    if case .success(let ast) = result {
      XCTAssertEqual(ast.syntax, .proto3)
      XCTAssertEqual(ast.messages.count, 1)
      XCTAssertEqual(ast.messages.first?.name, "HelloWorld")
    }
  }

  func testParseProtoWithPackage() {
    let protoContent = """
      syntax = "proto3";

      package com.example;

      message User {
          string name = 1;
          int32 age = 2;
      }
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    XCTAssertTrue(result.isSuccess)
    if case .success(let ast) = result {
      XCTAssertEqual(ast.syntax, .proto3)
      XCTAssertEqual(ast.package, "com.example")
      XCTAssertEqual(ast.messages.count, 1)
      XCTAssertEqual(ast.messages.first?.name, "User")
    }
  }

  func testParseProtoWithMultipleMessages() {
    let protoContent = """
      syntax = "proto3";

      message Person {
          string name = 1;
      }

      message Address {
          string street = 1;
          string city = 2;
      }
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    XCTAssertTrue(result.isSuccess)
    if case .success(let ast) = result {
      XCTAssertEqual(ast.messages.count, 2)
      XCTAssertEqual(ast.messages[0].name, "Person")
      XCTAssertEqual(ast.messages[1].name, "Address")
    }
  }

  // MARK: - Convenience Methods Tests

  func testGetProtoVersion() {
    let protoContent = """
      syntax = "proto3";

      message Test {}
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    if case .success(_) = result {
      let versionResult = SwiftProtoParser.parseProtoString(protoContent)
      if case .success(let versionAst) = versionResult {
        XCTAssertEqual(versionAst.syntax, .proto3)
      }
    }
  }

  func testGetPackageName() {
    let protoContent = """
      syntax = "proto3";

      package my.test.package;

      message Test {}
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    XCTAssertTrue(result.isSuccess)
    if case .success(let ast) = result {
      XCTAssertEqual(ast.package, "my.test.package")
    }
  }

  func testGetMessageNames() {
    let protoContent = """
      syntax = "proto3";

      message FirstMessage {
          string field1 = 1;
      }

      message SecondMessage {
          int32 field2 = 1;
      }

      message ThirdMessage {
          bool field3 = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    XCTAssertTrue(result.isSuccess)
    if case .success(let ast) = result {
      let messageNames = ast.messages.map { $0.name }
      XCTAssertEqual(messageNames, ["FirstMessage", "SecondMessage", "ThirdMessage"])
    }
  }

  // MARK: - Error Handling Tests

  func testParseInvalidSyntax() {
    let protoContent = """
      syntax = "proto2";  // Not supported

      message Test {}
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    // Should still parse but with error in AST construction
    XCTAssertTrue(result.isSuccess)
    if case .success(let ast) = result {
      // proto2 gets converted to proto3 with error recorded
      XCTAssertEqual(ast.syntax, .proto3)
    }
  }

  func testParseIncompleteProto() {
    let protoContent = """
      syntax = "proto3";

      message Test {
          string name = 
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    // Should fail with syntax error
    XCTAssertTrue(result.isFailure)
    if case .failure(let error) = result {
      XCTAssertTrue(error.description.contains("Syntax error"))
    }
  }

  func testParseMissingSyntax() {
    let protoContent = """
      message Test {
          string name = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    // Should fail because syntax declaration is required
    XCTAssertTrue(result.isFailure)
    if case .failure(let error) = result {
      XCTAssertTrue(error.description.contains("Syntax error"))
    }
  }

  func testParseEmptyString() {
    let result = SwiftProtoParser.parseProtoString("")

    XCTAssertTrue(result.isFailure)
    if case .failure(let error) = result {
      XCTAssertTrue(error.description.contains("Syntax error"))
    }
  }

  // MARK: - Future API Tests

  func testParseProtoFileWithImports() {
    let result = SwiftProtoParser.parseProtoFileWithImports("test.proto")

    XCTAssertTrue(result.isFailure)
    if case .failure(let error) = result {
      XCTAssertTrue(
        error.description.contains("Dependency resolution failed") || error.description.contains("I/O error")
      )
    }
  }

  func testParseProtoDirectory() {
    let result = SwiftProtoParser.parseProtoDirectory("/some/path")

    XCTAssertTrue(result.isFailure)
    if case .failure(let error) = result {
      XCTAssertTrue(
        error.description.contains("Dependency resolution failed") || error.description.contains("I/O error")
      )
    }
  }

  // MARK: - Integration Tests

  func testComplexProtoFile() {
    let protoContent = """
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

    let result = SwiftProtoParser.parseProtoString(protoContent)

    XCTAssertTrue(result.isSuccess)
    if case .success(let ast) = result {
      XCTAssertEqual(ast.syntax, .proto3)
      XCTAssertEqual(ast.package, "example.complex")
      XCTAssertEqual(ast.options.count, 1)
      XCTAssertEqual(ast.messages.count, 2)
      XCTAssertEqual(ast.enums.count, 1)
      XCTAssertEqual(ast.services.count, 1)

      // Check User message
      let userMessage = ast.messages.first { $0.name == "User" }
      XCTAssertNotNil(userMessage)
      XCTAssertEqual(userMessage?.fields.count, 4)

      // Check enum
      XCTAssertEqual(ast.enums.first?.name, "Status")

      // Check service
      XCTAssertEqual(ast.services.first?.name, "UserService")
    }
  }

  // MARK: - Performance Tests

  func testDirectLexerAndParser() {
    let protoContent = """
      syntax = "proto3";

      message HelloWorld {
          string name = 1;
      }
      """

    // Test lexer directly
    let lexer = Lexer(input: protoContent, fileName: "test")
    let lexResult = lexer.tokenize()

    XCTAssertTrue(lexResult.isSuccess)

    if case .success(let tokens) = lexResult {
      // Test parser directly
      let parser = Parser(tokens: tokens)
      let parseResult = parser.parse()

      switch parseResult {
      case .success(let ast):
        XCTAssertEqual(ast.syntax, .proto3)
        XCTAssertEqual(ast.messages.count, 1)
        XCTAssertEqual(ast.messages.first?.name, "HelloWorld")

      case .failure(let errors):
        XCTFail("Direct parser failed: \(errors.errors)")
      }
    }
  }

  // MARK: - Debug Tests

  func testSimpleEnumOnly() {
    let protoContent = """
      syntax = "proto3";

      enum Status {
          UNKNOWN = 0;
          ACTIVE = 1;
          INACTIVE = 2;
      }
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    XCTAssertTrue(result.isSuccess)
    if case .success(let ast) = result {
      XCTAssertEqual(ast.enums.count, 1)
      XCTAssertEqual(ast.enums.first?.name, "Status")
      XCTAssertEqual(ast.enums.first?.values.count, 3)
    }
  }

  func testSimpleServiceOnly() {
    let protoContent = """
      syntax = "proto3";

      service UserService {
          rpc GetUser(UserRequest) returns (User);
      }

      message UserRequest {
          string user_id = 1;
      }

      message User {
          string name = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(protoContent)

    XCTAssertTrue(result.isSuccess)
    if case .success(let ast) = result {
      XCTAssertEqual(ast.services.count, 1)
      XCTAssertEqual(ast.services.first?.name, "UserService")
      XCTAssertEqual(ast.services.first?.methods.count, 1)
      XCTAssertEqual(ast.messages.count, 2)
    }
  }

  // MARK: - Descriptor API Tests

  func testParseProtoStringToDescriptorsSuccess() {
    let protoContent = """
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
      """

    let result = SwiftProtoParser.parseProtoStringToDescriptors(protoContent, fileName: "test.proto")

    switch result {
    case .success(let fileDescriptor):
      // Verify basic properties
      XCTAssertEqual(fileDescriptor.name, "test.proto")
      XCTAssertEqual(fileDescriptor.syntax, "proto3")
      XCTAssertEqual(fileDescriptor.package, "com.example")

      // Verify messages
      XCTAssertEqual(fileDescriptor.messageType.count, 1)
      let userMessage = fileDescriptor.messageType[0]
      XCTAssertEqual(userMessage.name, "User")
      XCTAssertEqual(userMessage.field.count, 3)

      // Verify fields
      XCTAssertEqual(userMessage.field[0].name, "id")
      XCTAssertEqual(userMessage.field[0].number, 1)
      XCTAssertEqual(userMessage.field[0].type, .int32)

      XCTAssertEqual(userMessage.field[1].name, "name")
      XCTAssertEqual(userMessage.field[1].number, 2)
      XCTAssertEqual(userMessage.field[1].type, .string)

      XCTAssertEqual(userMessage.field[2].name, "active")
      XCTAssertEqual(userMessage.field[2].number, 3)
      XCTAssertEqual(userMessage.field[2].type, .bool)

      // Verify enums
      XCTAssertEqual(fileDescriptor.enumType.count, 1)
      let statusEnum = fileDescriptor.enumType[0]
      XCTAssertEqual(statusEnum.name, "Status")
      XCTAssertEqual(statusEnum.value.count, 3)

      // Verify enum values
      XCTAssertEqual(statusEnum.value[0].name, "UNKNOWN")
      XCTAssertEqual(statusEnum.value[0].number, 0)

      // Verify services
      XCTAssertEqual(fileDescriptor.service.count, 1)
      let userService = fileDescriptor.service[0]
      XCTAssertEqual(userService.name, "UserService")
      XCTAssertEqual(userService.method.count, 1)

      // Verify service methods
      XCTAssertEqual(userService.method[0].name, "GetUser")
      XCTAssertEqual(userService.method[0].inputType, ".com.example.User")
      XCTAssertEqual(userService.method[0].outputType, ".com.example.User")

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoStringToDescriptorsWithInvalidSyntax() {
    let protoContent = """
      syntax = "proto3";

      message User {
        int32 = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoStringToDescriptors(protoContent, fileName: "invalid.proto")

    switch result {
    case .success(_):
      XCTFail("Expected parsing to fail due to missing field name")
    case .failure(let error):
      // Should get syntax error for missing field name
      XCTAssertTrue(error.description.contains("Unexpected token"))
    }
  }

  func testParseProtoStringToDescriptorsWithDescriptorError() {
    // Test a valid AST that might cause descriptor builder issues
    let protoContent = """
      syntax = "proto3";

      message EmptyMessage {
      }
      """

    let result = SwiftProtoParser.parseProtoStringToDescriptors(protoContent, fileName: "empty.proto")

    switch result {
    case .success(let fileDescriptor):
      // This should actually succeed
      XCTAssertEqual(fileDescriptor.name, "empty.proto")
      XCTAssertEqual(fileDescriptor.messageType.count, 1)
      XCTAssertEqual(fileDescriptor.messageType[0].name, "EmptyMessage")
      XCTAssertEqual(fileDescriptor.messageType[0].field.count, 0)

    case .failure(let error):
      XCTFail("Expected success for empty message, got error: \(error)")
    }
  }

  func testParseProtoToDescriptorsFromFile() {
    // Create a temporary proto file
    let tempDir = NSTemporaryDirectory()
    let fileName = "test_descriptors.proto"
    let filePath = tempDir + fileName

    let protoContent = """
      syntax = "proto3";

      package test;

      message TestMessage {
        string content = 1;
        int32 value = 2;
      }
      """

    do {
      try protoContent.write(toFile: filePath, atomically: true, encoding: .utf8)

      let result = SwiftProtoParser.parseProtoToDescriptors(filePath)

      switch result {
      case .success(let fileDescriptor):
        XCTAssertEqual(fileDescriptor.name, fileName)
        XCTAssertEqual(fileDescriptor.syntax, "proto3")
        XCTAssertEqual(fileDescriptor.package, "test")
        XCTAssertEqual(fileDescriptor.messageType.count, 1)
        XCTAssertEqual(fileDescriptor.messageType[0].name, "TestMessage")

      case .failure(let error):
        XCTFail("Expected success, got error: \(error)")
      }

      // Clean up
      try FileManager.default.removeItem(atPath: filePath)

    }
    catch {
      XCTFail("Failed to create test file: \(error)")
    }
  }

  func testParseProtoToDescriptorsFileNotFound() {
    let nonExistentPath = "/non/existent/path/test.proto"

    let result = SwiftProtoParser.parseProtoToDescriptors(nonExistentPath)

    switch result {
    case .success(_):
      XCTFail("Expected file not found error")
    case .failure(let error):
      if case .ioError(_) = error {
        // Expected IO error for file not found
      }
      else {
        XCTFail("Expected ioError, got: \(error)")
      }
    }
  }

  func testParseProtoStringToDescriptorsWithOptions() {
    let protoContent = """
      syntax = "proto3";

      option java_package = "com.example.generated";
      option java_outer_classname = "TestProto";

      message TestMessage {
        string name = 1 [deprecated = true];
        int32 id = 2;
      }
      """

    let result = SwiftProtoParser.parseProtoStringToDescriptors(protoContent, fileName: "options_test.proto")

    switch result {
    case .success(let fileDescriptor):
      // Verify file options
      XCTAssertTrue(fileDescriptor.hasOptions)
      XCTAssertEqual(fileDescriptor.options.javaPackage, "com.example.generated")
      XCTAssertEqual(fileDescriptor.options.javaOuterClassname, "TestProto")

      // Verify field options
      let testMessage = fileDescriptor.messageType[0]
      let nameField = testMessage.field[0]
      XCTAssertTrue(nameField.hasOptions)
      XCTAssertTrue(nameField.options.deprecated)

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoStringToDescriptorsComplexTypes() {
    let protoContent = """
      syntax = "proto3";

      message Outer {
        message Inner {
          string value = 1;
        }
        
        Inner inner = 1;
        repeated string tags = 2;
        map<string, int32> counts = 3;
      }
      """

    let result = SwiftProtoParser.parseProtoStringToDescriptors(protoContent, fileName: "complex.proto")

    switch result {
    case .success(let fileDescriptor):
      let outerMessage = fileDescriptor.messageType[0]
      XCTAssertEqual(outerMessage.name, "Outer")

      // Check nested types (Inner + CountsEntry for map)
      XCTAssertEqual(outerMessage.nestedType.count, 2)

      // Verify CountsEntry (synthetic map entry message)
      let countsEntry = outerMessage.nestedType.first { $0.name == "CountsEntry" }
      XCTAssertNotNil(countsEntry, "CountsEntry should be generated for map field")
      XCTAssertTrue(countsEntry?.options.mapEntry ?? false, "CountsEntry should have map_entry = true")
      XCTAssertEqual(countsEntry?.field.count, 2, "CountsEntry should have 2 fields (key and value)")

      // Verify key field in CountsEntry
      let keyField = countsEntry?.field.first { $0.name == "key" }
      XCTAssertEqual(keyField?.number, 1)
      XCTAssertEqual(keyField?.type, .string)
      XCTAssertEqual(keyField?.label, .optional)

      // Verify value field in CountsEntry
      let valueField = countsEntry?.field.first { $0.name == "value" }
      XCTAssertEqual(valueField?.number, 2)
      XCTAssertEqual(valueField?.type, .int32)
      XCTAssertEqual(valueField?.label, .optional)

      // Verify Inner nested message
      let innerMessage = outerMessage.nestedType.first { $0.name == "Inner" }
      XCTAssertNotNil(innerMessage, "Inner nested message should exist")
      XCTAssertEqual(innerMessage?.field.count, 1)

      // Check fields
      XCTAssertEqual(outerMessage.field.count, 3)

      // inner field
      XCTAssertEqual(outerMessage.field[0].name, "inner")
      XCTAssertEqual(outerMessage.field[0].typeName, ".Inner")

      // repeated field
      XCTAssertEqual(outerMessage.field[1].name, "tags")
      XCTAssertEqual(outerMessage.field[1].label, .repeated)
      XCTAssertEqual(outerMessage.field[1].type, .string)

      // map field
      XCTAssertEqual(outerMessage.field[2].name, "counts")
      XCTAssertEqual(outerMessage.field[2].type, .message)
      XCTAssertEqual(outerMessage.field[2].typeName, "CountsEntry")

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }
}
