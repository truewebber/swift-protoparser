import XCTest
import Foundation
@testable import SwiftProtoParser

/// Comprehensive integration tests for DependencyResolver API in SwiftProtoParser.
/// These tests validate multi-file parsing, import resolution, and descriptor generation.
final class SwiftProtoParserDependencyTests: XCTestCase {

  // MARK: - Properties
  
  private var testResourcesPath: String {
    // Use #file to determine the test directory location
    let thisFileURL = URL(fileURLWithPath: #file)
    let projectDirectory = thisFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let resourcesPath = projectDirectory.appendingPathComponent("Tests/TestResources").path
    return resourcesPath
  }
  
  private var dependencyTestCasesPath: String {
    return testResourcesPath + "/DependencyTestCases"
  }
  
  private var singleProtoFilesPath: String {
    return testResourcesPath + "/SingleProtoFiles"
  }

  // MARK: - Setup & Teardown

  override func setUp() {
    super.setUp()
    // Verify test resources exist
    XCTAssertTrue(FileManager.default.fileExists(atPath: testResourcesPath), 
                  "TestResources directory not found at: \(testResourcesPath)")
  }

  // MARK: - parseProtoFileWithImports Tests

  func testParseProtoFileWithImports_SimpleFile() {
    let simplePath = singleProtoFilesPath + "/simple.proto"
    
    let result = SwiftProtoParser.parseProtoFileWithImports(simplePath, importPaths: [singleProtoFilesPath])
    
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.syntax, .proto3)
      XCTAssertEqual(ast.package, "simple")
      XCTAssertEqual(ast.messages.count, 1)
      XCTAssertEqual(ast.messages[0].name, "SimpleMessage")
      XCTAssertEqual(ast.messages[0].fields.count, 2)
      
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoFileWithImports_WithDependencies() {
    let userPath = dependencyTestCasesPath + "/user.proto"
    
    let result = SwiftProtoParser.parseProtoFileWithImports(
      userPath, 
      importPaths: [dependencyTestCasesPath]
    )
    
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.syntax, .proto3)
      XCTAssertEqual(ast.package, "test.user")
      XCTAssertEqual(ast.imports.count, 1)
      XCTAssertEqual(ast.imports[0], "base.proto")
      XCTAssertEqual(ast.messages.count, 2)
      
      // Verify User message
      let userMessage = ast.messages.first { $0.name == "User" }
      XCTAssertNotNil(userMessage)
      XCTAssertEqual(userMessage?.fields.count, 4)
      
      // Verify Address message
      let addressMessage = ast.messages.first { $0.name == "Address" }
      XCTAssertNotNil(addressMessage)
      XCTAssertEqual(addressMessage?.fields.count, 3)
      
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoFileWithImports_ComplexDependencies() {
    let servicePath = dependencyTestCasesPath + "/service.proto"
    
    let result = SwiftProtoParser.parseProtoFileWithImports(
      servicePath, 
      importPaths: [dependencyTestCasesPath]
    )
    
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.syntax, .proto3)
      XCTAssertEqual(ast.package, "test.service")
      XCTAssertEqual(ast.imports.count, 1)
      XCTAssertEqual(ast.imports[0], "user.proto")
      XCTAssertEqual(ast.services.count, 1)
      XCTAssertEqual(ast.messages.count, 4)
      
      // Verify UserService
      let userService = ast.services[0]
      XCTAssertEqual(userService.name, "UserService")
      XCTAssertEqual(userService.methods.count, 3)
      
      // Verify service methods
      let getUser = userService.methods.first { $0.name == "GetUser" }
      XCTAssertNotNil(getUser)
      XCTAssertEqual(getUser?.inputType, "GetUserRequest")
      XCTAssertEqual(getUser?.outputType, "User")
      
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoFileWithImports_MissingImport() {
    let userPath = dependencyTestCasesPath + "/user.proto"
    
    // Don't provide import paths, so base.proto can't be found
    let result = SwiftProtoParser.parseProtoFileWithImports(userPath)
    
    switch result {
    case .success(_):
      XCTFail("Expected failure due to missing import")
      
    case .failure(let error):
      XCTAssertTrue(error.description.contains("Dependency resolution failed"))
    }
  }

  func testParseProtoFileWithImports_AllowMissingImports() {
    let userPath = dependencyTestCasesPath + "/user.proto"
    
    // Allow missing imports
    let result = SwiftProtoParser.parseProtoFileWithImports(
      userPath, 
      importPaths: [],
      allowMissingImports: true
    )
    
    switch result {
    case .success(let ast):
      // Should succeed even with missing imports
      XCTAssertEqual(ast.syntax, .proto3)
      XCTAssertEqual(ast.package, "test.user")
      XCTAssertEqual(ast.imports.count, 1)
      
    case .failure(let error):
      XCTFail("Expected success with allowMissingImports=true, got error: \(error)")
    }
  }

  func testParseProtoFileWithImports_FileNotFound() {
    let nonExistentPath = "/nonexistent/file.proto"
    
    let result = SwiftProtoParser.parseProtoFileWithImports(nonExistentPath)
    
    switch result {
    case .success(_):
      XCTFail("Expected failure for non-existent file")
      
    case .failure(let error):
      XCTAssertTrue(error.description.contains("I/O error") || error.description.contains("Dependency"))
    }
  }

  // MARK: - parseProtoDirectory Tests

  func testParseProtoDirectory_SingleFile() {
    let result = SwiftProtoParser.parseProtoDirectory(singleProtoFilesPath)
    
    switch result {
    case .success(let asts):
      XCTAssertEqual(asts.count, 1)
      
      let ast = asts[0]
      XCTAssertEqual(ast.syntax, .proto3)
      XCTAssertEqual(ast.package, "simple")
      XCTAssertEqual(ast.messages.count, 1)
      
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoDirectory_MultipleFiles() {
    let result = SwiftProtoParser.parseProtoDirectory(dependencyTestCasesPath)
    
    switch result {
    case .success(let asts):
      XCTAssertEqual(asts.count, 3) // base.proto, user.proto, service.proto
      
      // Find each expected file
      let baseAST = asts.first { $0.package == "test.base" }
      XCTAssertNotNil(baseAST)
      XCTAssertEqual(baseAST?.messages.count, 1)
      XCTAssertEqual(baseAST?.enums.count, 1)
      
      let userAST = asts.first { $0.package == "test.user" }
      XCTAssertNotNil(userAST)
      XCTAssertEqual(userAST?.messages.count, 2)
      XCTAssertEqual(userAST?.imports.count, 1)
      
      let serviceAST = asts.first { $0.package == "test.service" }
      XCTAssertNotNil(serviceAST)
      XCTAssertEqual(serviceAST?.services.count, 1)
      XCTAssertEqual(serviceAST?.messages.count, 4)
      
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoDirectory_WithMissingImports() {
    // Create a temporary directory with a file that has missing imports
    let tempDir = NSTemporaryDirectory() + "SwiftProtoParserTest_\(UUID().uuidString)"
    try! FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    
    defer {
      try? FileManager.default.removeItem(atPath: tempDir)
    }
    
    let testProtoContent = """
      syntax = "proto3";
      import "nonexistent.proto";
      
      message TestMessage {
        string name = 1;
      }
      """
    
    let testFilePath = tempDir + "/test.proto"
    try! testProtoContent.write(toFile: testFilePath, atomically: true, encoding: .utf8)
    
    // Test with allowMissingImports = true
    let result = SwiftProtoParser.parseProtoDirectory(tempDir, allowMissingImports: true)
    
    switch result {
    case .success(let asts):
      XCTAssertEqual(asts.count, 1)
      XCTAssertEqual(asts[0].messages.count, 1)
      XCTAssertEqual(asts[0].messages[0].name, "TestMessage")
      
    case .failure(let error):
      XCTFail("Expected success with allowMissingImports=true, got error: \(error)")
    }
  }

  // MARK: - parseProtoFileWithImportsToDescriptors Tests

  func testParseProtoFileWithImportsToDescriptors_SimpleFile() {
    let simplePath = singleProtoFilesPath + "/simple.proto"
    
    let result = SwiftProtoParser.parseProtoFileWithImportsToDescriptors(
      simplePath, 
      importPaths: [singleProtoFilesPath]
    )
    
    switch result {
    case .success(let fileDescriptor):
      XCTAssertEqual(fileDescriptor.name, "simple.proto")
      XCTAssertEqual(fileDescriptor.syntax, "proto3")
      XCTAssertEqual(fileDescriptor.package, "simple")
      XCTAssertEqual(fileDescriptor.messageType.count, 1)
      
      let simpleMessage = fileDescriptor.messageType[0]
      XCTAssertEqual(simpleMessage.name, "SimpleMessage")
      XCTAssertEqual(simpleMessage.field.count, 2)
      
      // Verify fields
      XCTAssertEqual(simpleMessage.field[0].name, "content")
      XCTAssertEqual(simpleMessage.field[0].number, 1)
      XCTAssertEqual(simpleMessage.field[0].type, .string)
      
      XCTAssertEqual(simpleMessage.field[1].name, "number")
      XCTAssertEqual(simpleMessage.field[1].number, 2)
      XCTAssertEqual(simpleMessage.field[1].type, .int32)
      
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoFileWithImportsToDescriptors_WithDependencies() {
    let userPath = dependencyTestCasesPath + "/user.proto"
    
    let result = SwiftProtoParser.parseProtoFileWithImportsToDescriptors(
      userPath, 
      importPaths: [dependencyTestCasesPath]
    )
    
    switch result {
    case .success(let fileDescriptor):
      XCTAssertEqual(fileDescriptor.name, "user.proto")
      XCTAssertEqual(fileDescriptor.syntax, "proto3")
      XCTAssertEqual(fileDescriptor.package, "test.user")
      XCTAssertEqual(fileDescriptor.dependency.count, 1)
      XCTAssertEqual(fileDescriptor.dependency[0], "base.proto")
      XCTAssertEqual(fileDescriptor.messageType.count, 2)
      
      // Verify User message
      let userMessage = fileDescriptor.messageType.first { $0.name == "User" }
      XCTAssertNotNil(userMessage)
      XCTAssertEqual(userMessage?.field.count, 4)
      
      // Verify Address message
      let addressMessage = fileDescriptor.messageType.first { $0.name == "Address" }
      XCTAssertNotNil(addressMessage)
      XCTAssertEqual(addressMessage?.field.count, 3)
      
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  // MARK: - parseProtoDirectoryToDescriptors Tests

  func testParseProtoDirectoryToDescriptors_MultipleFiles() {
    let result = SwiftProtoParser.parseProtoDirectoryToDescriptors(dependencyTestCasesPath)
    
    switch result {
    case .success(let fileDescriptors):
      XCTAssertEqual(fileDescriptors.count, 3)
      
      // Find each expected file descriptor
      let baseDescriptor = fileDescriptors.first { $0.package == "test.base" }
      XCTAssertNotNil(baseDescriptor)
      XCTAssertEqual(baseDescriptor?.messageType.count, 1)
      XCTAssertEqual(baseDescriptor?.enumType.count, 1)
      
      let userDescriptor = fileDescriptors.first { $0.package == "test.user" }
      XCTAssertNotNil(userDescriptor)
      XCTAssertEqual(userDescriptor?.messageType.count, 2)
      XCTAssertEqual(userDescriptor?.dependency.count, 1)
      
      let serviceDescriptor = fileDescriptors.first { $0.package == "test.service" }
      XCTAssertNotNil(serviceDescriptor)
      XCTAssertEqual(serviceDescriptor?.service.count, 1)
      XCTAssertEqual(serviceDescriptor?.messageType.count, 4)
      
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoDirectoryToDescriptors_VerifyServiceDescriptor() {
    let result = SwiftProtoParser.parseProtoDirectoryToDescriptors(dependencyTestCasesPath)
    
    switch result {
    case .success(let fileDescriptors):
      let serviceDescriptor = fileDescriptors.first { $0.package == "test.service" }
      XCTAssertNotNil(serviceDescriptor)
      
      guard let descriptor = serviceDescriptor else { return }
      
      // Verify service
      XCTAssertEqual(descriptor.service.count, 1)
      let userService = descriptor.service[0]
      XCTAssertEqual(userService.name, "UserService")
      XCTAssertEqual(userService.method.count, 3)
      
      // Verify GetUser method
      let getUserMethod = userService.method.first { $0.name == "GetUser" }
      XCTAssertNotNil(getUserMethod)
      XCTAssertEqual(getUserMethod?.inputType, ".test.service.GetUserRequest")
      XCTAssertEqual(getUserMethod?.outputType, ".test.service.User")
      
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  // MARK: - Error Handling Tests

  func testParseProtoFileWithImports_InvalidSyntax() {
    // Create a temporary file with invalid syntax
    let tempDir = NSTemporaryDirectory()
    let tempFilePath = tempDir + "invalid_\(UUID().uuidString).proto"
    
    defer {
      try? FileManager.default.removeItem(atPath: tempFilePath)
    }
    
    let invalidContent = """
      syntax = "proto3";
      
      message Invalid {
        string name = ;
      }
      """
    
    try! invalidContent.write(toFile: tempFilePath, atomically: true, encoding: .utf8)
    
    let result = SwiftProtoParser.parseProtoFileWithImports(tempFilePath)
    
    switch result {
    case .success(_):
      XCTFail("Expected failure for invalid syntax")
      
    case .failure(let error):
      XCTAssertTrue(error.description.contains("Syntax error") || error.description.contains("Unexpected"))
    }
  }

  // MARK: - Performance Tests

  func testParseProtoDirectoryPerformance() {
    // Measure performance of parsing multiple files
    measure {
      let result = SwiftProtoParser.parseProtoDirectory(dependencyTestCasesPath)
      
      switch result {
      case .success(let asts):
        XCTAssertEqual(asts.count, 3)
      case .failure(let error):
        XCTFail("Performance test failed: \(error)")
      }
    }
  }

  func testParseProtoDirectoryToDescriptorsPerformance() {
    // Measure performance of parsing multiple files to descriptors
    measure {
      let result = SwiftProtoParser.parseProtoDirectoryToDescriptors(dependencyTestCasesPath)
      
      switch result {
      case .success(let descriptors):
        XCTAssertEqual(descriptors.count, 3)
      case .failure(let error):
        XCTFail("Performance test failed: \(error)")
      }
    }
  }
}
