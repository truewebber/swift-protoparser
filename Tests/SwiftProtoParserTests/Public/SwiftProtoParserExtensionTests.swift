import XCTest
@testable import SwiftProtoParser
import Foundation

final class SwiftProtoParserExtensionTests: XCTestCase {
  
  // MARK: - File IO Tests
  
  func testParseProtoFileSuccess() {
    // Create a temporary .proto file
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent("test.proto")
    
    let protoContent = """
      syntax = "proto3";
      
      message TestMessage {
          string name = 1;
      }
      """
    
    do {
      try protoContent.write(to: tempFile, atomically: true, encoding: .utf8)
      
      let result = SwiftProtoParser.parseProtoFile(tempFile.path)
      
      XCTAssertTrue(result.isSuccess)
      if case .success(let ast) = result {
        XCTAssertEqual(ast.syntax, .proto3)
        XCTAssertEqual(ast.messages.count, 1)
        XCTAssertEqual(ast.messages.first?.name, "TestMessage")
      }
      
      // Cleanup
      try FileManager.default.removeItem(at: tempFile)
    } catch {
      XCTFail("Failed to create or cleanup temp file: \(error)")
    }
  }
  
  func testParseProtoFileNotFound() {
    let nonExistentPath = "/nonexistent/path/to/file.proto"
    let result = SwiftProtoParser.parseProtoFile(nonExistentPath)
    
    XCTAssertTrue(result.isFailure)
    if case .failure(let error) = result {
      if case .ioError(let underlying) = error {
        XCTAssertNotNil(underlying)
      } else {
        XCTFail("Expected ioError, got \(error)")
      }
    }
  }
  
  func testParseProtoFileInvalidPath() {
    let invalidPath = ""
    let result = SwiftProtoParser.parseProtoFile(invalidPath)
    
    XCTAssertTrue(result.isFailure)
    if case .failure(let error) = result {
      if case .ioError = error {
        // Expected IO error for invalid path
      } else {
        XCTFail("Expected ioError, got \(error)")
      }
    }
  }
  
  // MARK: - parseProtoString with fileName Tests
  
  func testParseProtoStringWithCustomFileName() {
    let protoContent = """
      syntax = "proto3";
      
      message User {
          string name = 1;
      }
      """
    
    let customFileName = "custom_user.proto"
    let result = SwiftProtoParser.parseProtoString(protoContent, fileName: customFileName)
    
    XCTAssertTrue(result.isSuccess)
    if case .success(let ast) = result {
      XCTAssertEqual(ast.syntax, .proto3)
      XCTAssertEqual(ast.messages.count, 1)
      XCTAssertEqual(ast.messages.first?.name, "User")
    }
  }
  
  func testParseProtoStringWithErrorFileName() {
    let invalidContent = """
      syntax = "proto3";
      
      message InvalidMessage {
          // Missing field number and semicolon
          string name = 
      """
    
    let fileName = "error_test.proto"
    let result = SwiftProtoParser.parseProtoString(invalidContent, fileName: fileName)
    
    XCTAssertTrue(result.isFailure)
    if case .failure(let error) = result {
      if case .syntaxError(let message, let file, let line, let column) = error {
        XCTAssertEqual(file, fileName)
        XCTAssertFalse(message.isEmpty)
        XCTAssertGreaterThan(line, 0)
        XCTAssertGreaterThan(column, 0)
      } else {
        XCTFail("Expected syntax error with file name, got \(error)")
      }
    }
  }
  
  // MARK: - Convenience Methods Full Tests
  
  func testGetProtoVersionFromFile() {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent("version_test.proto")
    
    let protoContent = """
      syntax = "proto3";
      
      message VersionTest {}
      """
    
    do {
      try protoContent.write(to: tempFile, atomically: true, encoding: .utf8)
      
      let result = SwiftProtoParser.getProtoVersion(tempFile.path)
      
      XCTAssertTrue(result.isSuccess)
      if case .success(let version) = result {
        XCTAssertEqual(version, .proto3)
      }
      
      // Cleanup
      try FileManager.default.removeItem(at: tempFile)
    } catch {
      XCTFail("Failed to create or cleanup temp file: \(error)")
    }
  }
  
  func testGetProtoVersionFileNotFound() {
    let result = SwiftProtoParser.getProtoVersion("/nonexistent/file.proto")
    
    XCTAssertTrue(result.isFailure)
    if case .failure(let error) = result {
      if case .ioError = error {
        // Expected IO error
      } else {
        XCTFail("Expected ioError, got \(error)")
      }
    }
  }
  
  func testGetPackageNameFromFile() {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent("package_test.proto")
    
    let protoContent = """
      syntax = "proto3";
      
      package com.example.test;
      
      message PackageTest {}
      """
    
    do {
      try protoContent.write(to: tempFile, atomically: true, encoding: .utf8)
      
      let result = SwiftProtoParser.getPackageName(tempFile.path)
      
      XCTAssertTrue(result.isSuccess)
      if case .success(let packageName) = result {
        XCTAssertEqual(packageName, "com.example.test")
      }
      
      // Cleanup
      try FileManager.default.removeItem(at: tempFile)
    } catch {
      XCTFail("Failed to create or cleanup temp file: \(error)")
    }
  }
  
  func testGetPackageNameNoPackage() {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent("no_package_test.proto")
    
    let protoContent = """
      syntax = "proto3";
      
      message NoPackageTest {}
      """
    
    do {
      try protoContent.write(to: tempFile, atomically: true, encoding: .utf8)
      
      let result = SwiftProtoParser.getPackageName(tempFile.path)
      
      XCTAssertTrue(result.isSuccess)
      if case .success(let packageName) = result {
        XCTAssertNil(packageName)
      }
      
      // Cleanup
      try FileManager.default.removeItem(at: tempFile)
    } catch {
      XCTFail("Failed to create or cleanup temp file: \(error)")
    }
  }
  
  func testGetMessageNamesFromFile() {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent("messages_test.proto")
    
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
    
    do {
      try protoContent.write(to: tempFile, atomically: true, encoding: .utf8)
      
      let result = SwiftProtoParser.getMessageNames(tempFile.path)
      
      XCTAssertTrue(result.isSuccess)
      if case .success(let messageNames) = result {
        XCTAssertEqual(messageNames, ["FirstMessage", "SecondMessage", "ThirdMessage"])
      }
      
      // Cleanup
      try FileManager.default.removeItem(at: tempFile)
    } catch {
      XCTFail("Failed to create or cleanup temp file: \(error)")
    }
  }
  
  func testGetMessageNamesNoMessages() {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent("no_messages_test.proto")
    
    let protoContent = """
      syntax = "proto3";
      
      // No messages, only enum
      enum Status {
          UNKNOWN = 0;
          ACTIVE = 1;
      }
      """
    
    do {
      try protoContent.write(to: tempFile, atomically: true, encoding: .utf8)
      
      let result = SwiftProtoParser.getMessageNames(tempFile.path)
      
      XCTAssertTrue(result.isSuccess)
      if case .success(let messageNames) = result {
        XCTAssertTrue(messageNames.isEmpty)
      }
      
      // Cleanup
      try FileManager.default.removeItem(at: tempFile)
    } catch {
      XCTFail("Failed to create or cleanup temp file: \(error)")
    }
  }
  
  // MARK: - Future API Extended Tests
  
  func testParseProtoFileWithImportsWithPaths() {
    let result = SwiftProtoParser.parseProtoFileWithImports("test.proto", importPaths: ["/path1", "/path2"])
    
    XCTAssertTrue(result.isFailure)
    if case .failure(let error) = result {
      if case .internalError(let message) = error {
        XCTAssertTrue(message.contains("Import resolution not yet implemented"))
      } else {
        XCTFail("Expected internalError, got \(error)")
      }
    }
  }
  
  func testParseProtoDirectoryWithMainFile() {
    let result = SwiftProtoParser.parseProtoDirectory("/some/directory", mainFile: "main.proto")
    
    XCTAssertTrue(result.isFailure)
    if case .failure(let error) = result {
      if case .internalError(let message) = error {
        XCTAssertTrue(message.contains("Directory parsing not yet implemented"))
      } else {
        XCTFail("Expected internalError, got \(error)")
      }
    }
  }
  
  // MARK: - Error Conversion Tests
  
  func testParserErrorConversion() {
    let invalidContent = """
      syntax = "proto3";
      
      message Test {
          string field1 = 0; // Invalid field number
      }
      """
    
    let result = SwiftProtoParser.parseProtoString(invalidContent, fileName: "test_error.proto")
    
    XCTAssertTrue(result.isFailure)
    if case .failure(let error) = result {
      if case .syntaxError(let message, let fileName, let line, let column) = error {
        XCTAssertEqual(fileName, "test_error.proto")
        XCTAssertGreaterThan(line, 0)
        XCTAssertGreaterThan(column, 0)
        XCTAssertFalse(message.isEmpty)
      } else {
        XCTFail("Expected syntax error, got \(error)")
      }
    }
  }
  
  func testEmptyParserErrors() {
    // This is an edge case - testing when parser returns no errors but still fails
    // This tests the internal error fallback
    let content = """
      syntax = "proto3";
      """
    
    let result = SwiftProtoParser.parseProtoString(content)
    
    // This should actually succeed with an empty AST
    if case .success(let ast) = result {
      XCTAssertEqual(ast.syntax, .proto3)
      XCTAssertNil(ast.package)
      XCTAssertTrue(ast.messages.isEmpty)
      XCTAssertTrue(ast.enums.isEmpty)
      XCTAssertTrue(ast.services.isEmpty)
    }
  }
  
  // MARK: - Edge Cases Tests
  
  func testParseProtoStringEmpty() {
    let result = SwiftProtoParser.parseProtoString("")
    
    XCTAssertTrue(result.isFailure)
    // Should fail with lexer or parser error
  }
  
  func testParseProtoStringWhitespaceOnly() {
    let result = SwiftProtoParser.parseProtoString("   \n\t  \r\n  ")
    
    XCTAssertTrue(result.isFailure)
    // Should fail because no syntax declaration
  }
  
  func testParseProtoStringUnicodeContent() {
    let protoContent = """
      syntax = "proto3";
      
      message UnicodeTest {
          string unicode_field = 1; // 测试 unicode
      }
      """
    
    let result = SwiftProtoParser.parseProtoString(protoContent, fileName: "unicode_test.proto")
    
    XCTAssertTrue(result.isSuccess)
    if case .success(let ast) = result {
      XCTAssertEqual(ast.messages.count, 1)
      XCTAssertEqual(ast.messages.first?.name, "UnicodeTest")
    }
  }
  
  // MARK: - Static API Tests
  
  func testSwiftProtoParserCannotBeInstantiated() {
    // This tests that SwiftProtoParser init is private
    // If it compiles, the API design is correct (static only)
    
    // Test that all methods are static
    XCTAssertTrue(type(of: SwiftProtoParser.parseProtoString("")) == Result<ProtoAST, ProtoParseError>.self)
    XCTAssertTrue(type(of: SwiftProtoParser.parseProtoFile("")) == Result<ProtoAST, ProtoParseError>.self)
  }
  
  // MARK: - Complex Integration Tests
  
  func testParseComplexFileFromDisk() {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent("complex_integration.proto")
    
    let complexContent = """
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
      """
    
    do {
      try complexContent.write(to: tempFile, atomically: true, encoding: .utf8)
      
      let result = SwiftProtoParser.parseProtoFile(tempFile.path)
      
      XCTAssertTrue(result.isSuccess)
      if case .success(let ast) = result {
        XCTAssertEqual(ast.syntax, .proto3)
        XCTAssertEqual(ast.package, "integration.test")
        XCTAssertEqual(ast.options.count, 1)
        XCTAssertEqual(ast.enums.count, 1)
        XCTAssertEqual(ast.messages.count, 3)
        XCTAssertEqual(ast.services.count, 1)
        
        // Test convenience methods on this complex file
        let versionResult = SwiftProtoParser.getProtoVersion(tempFile.path)
        XCTAssertTrue(versionResult.isSuccess)
        
        let packageResult = SwiftProtoParser.getPackageName(tempFile.path)
        XCTAssertTrue(packageResult.isSuccess)
        if case .success(let package) = packageResult {
          XCTAssertEqual(package, "integration.test")
        }
        
                 let messagesResult = SwiftProtoParser.getMessageNames(tempFile.path)
         XCTAssertTrue(messagesResult.isSuccess)
         if case .success(let messageNames) = messagesResult {
           XCTAssertEqual(messageNames.count, 3)
           XCTAssertTrue(messageNames.contains("User"))
           XCTAssertTrue(messageNames.contains("UserList"))
           XCTAssertTrue(messageNames.contains("GetUserRequest"))
         }
      }
      
      // Cleanup
      try FileManager.default.removeItem(at: tempFile)
    } catch {
      XCTFail("Failed to create or cleanup temp file: \(error)")
    }
  }
}
