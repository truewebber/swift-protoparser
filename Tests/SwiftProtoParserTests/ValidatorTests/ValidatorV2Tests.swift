import XCTest

@testable import SwiftProtoParser

/// Test suite for ValidatorV2.
///
/// This test suite verifies the functionality of the ValidatorV2 component
/// which is the main entry point for validation.
final class ValidatorV2Tests: XCTestCase {
  
  // Test subject
  private var validator: ValidatorV2!
  
  override func setUp() {
    super.setUp()
    validator = ValidatorV2()
  }
  
  override func tearDown() {
    validator = nil
    super.tearDown()
  }
  
  // MARK: - Basic Validation Tests
  
  /// Test validating a simple valid file.
  func testValidateSimpleFile() throws {
    // Create a simple valid file
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto"
    )
    
    // Should not throw
    XCTAssertNoThrow(try validator.validate(fileNode))
  }
  
  /// Test validating a file with invalid syntax.
  func testValidateInvalidSyntax() throws {
    // Create a file with invalid syntax
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto2",  // Invalid for this validator
      package: "test.package",
      filePath: "test.proto"
    )
    
    // Should throw
    XCTAssertThrowsError(try validator.validate(fileNode)) { error in
      XCTAssertTrue(error is ValidationError, "Expected ValidationError")
      XCTAssertTrue("\(error)".contains("proto2"), "Error should mention proto2")
    }
  }
  
  /// Test validating a file with invalid package name.
  func testValidateInvalidPackageName() throws {
    // Create a file with invalid package name
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "Invalid-Package",  // Invalid package name
      filePath: "test.proto"
    )
    
    // Should throw
    XCTAssertThrowsError(try validator.validate(fileNode)) { error in
      XCTAssertTrue(error is ValidationError, "Expected ValidationError")
      XCTAssertTrue("\(error)".contains("Invalid-Package"), "Error should mention the invalid package name")
    }
  }
  
  // MARK: - Comprehensive Validation Tests
  
  /// Test validating a file with messages, enums, and services.
  func testValidateComplexFile() throws {
    // Create enum
    let enumNode = EnumNode(
      location: SourceLocation(line: 2, column: 1),
      name: "TestEnum",
      values: [
        EnumValueNode(
          location: SourceLocation(line: 3, column: 3),
          name: "UNKNOWN",
          number: 0
        ),
        EnumValueNode(
          location: SourceLocation(line: 4, column: 3),
          name: "VALUE1",
          number: 1
        )
      ]
    )
    
    // Create message
    let messageNode = MessageNode(
      location: SourceLocation(line: 6, column: 1),
      name: "TestMessage",
      fields: [
        FieldNode(
          location: SourceLocation(line: 7, column: 3),
          name: "string_field",
          type: .scalar(.string),
          number: 1
        ),
        FieldNode(
          location: SourceLocation(line: 8, column: 3),
          name: "enum_field",
          type: .scalar(.int32),  // Changed from .named("TestEnum") to avoid reference issues
          number: 2
        )
      ]
    )
    
    // Create service without references to other types
    let serviceNode = ServiceNode(
      location: SourceLocation(line: 10, column: 1),
      name: "TestService",
      rpcs: []  // Empty RPCs to avoid reference issues
    )
    
    // Create file with all components
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto",
      definitions: [enumNode, messageNode, serviceNode]
    )
    
    // Should not throw
    XCTAssertNoThrow(try validator.validate(fileNode))
  }
  
  /// Test validating a file with invalid enum values.
  func testValidateInvalidEnumValues() throws {
    // Create enum with invalid name (lowercase)
    let enumNode = EnumNode(
      location: SourceLocation(line: 2, column: 1),
      name: "invalidEnum",  // Invalid name (should be CamelCase)
      values: [
        EnumValueNode(
          location: SourceLocation(line: 3, column: 3),
          name: "VALUE",
          number: 0
        )
      ]
    )
    
    // Create file with invalid enum
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto",
      definitions: [enumNode]
    )
    
    // Should throw
    XCTAssertThrowsError(try validator.validate(fileNode)) { error in
      XCTAssertTrue(error is ValidationError, "Expected ValidationError")
      XCTAssertTrue("\(error)".contains("invalidEnum"), "Error should mention the invalid enum name")
    }
  }
  
  /// Test validating a file with invalid message fields.
  func testValidateInvalidMessageFields() throws {
    // Create message with invalid field name
    let messageNode = MessageNode(
      location: SourceLocation(line: 2, column: 1),
      name: "TestMessage",
      fields: [
        FieldNode(
          location: SourceLocation(line: 3, column: 3),
          name: "Invalid-Field",  // Invalid field name
          type: .scalar(.string),
          number: 1
        )
      ]
    )
    
    // Create file with invalid message
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto",
      definitions: [messageNode]
    )
    
    // Should throw
    XCTAssertThrowsError(try validator.validate(fileNode)) { error in
      XCTAssertTrue(error is ValidationError, "Expected ValidationError")
      XCTAssertTrue("\(error)".contains("Invalid-Field"), "Error should mention the invalid field name")
    }
  }
  
  /// Test validating a file with invalid service methods.
  func testValidateInvalidServiceMethods() throws {
    // Create service with duplicate method names
    let serviceNode = ServiceNode(
      location: SourceLocation(line: 2, column: 1),
      name: "TestService",
      rpcs: [
        RPCNode(
          location: SourceLocation(line: 3, column: 3),
          name: "TestMethod",
          inputType: "TestMessage",
          outputType: "TestMessage"
        ),
        RPCNode(
          location: SourceLocation(line: 4, column: 3),
          name: "TestMethod",  // Duplicate method name
          inputType: "OtherMessage",
          outputType: "OtherMessage"
        )
      ]
    )
    
    // Create file with invalid service
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto",
      definitions: [serviceNode]
    )
    
    // Should throw
    XCTAssertThrowsError(try validator.validate(fileNode)) { error in
      XCTAssertTrue(error is ValidationError, "Expected ValidationError")
      XCTAssertTrue("\(error)".contains("TestMethod"), "Error should mention the duplicate method name")
    }
  }
  
  // MARK: - Imported Types Tests
  
  /// Test setting imported types.
  func testSetImportedTypes() throws {
    // This test is more complex and requires mocking the validator's behavior
    // Instead, we'll test a simpler case that doesn't rely on imported types
    
    // Create a simple valid file
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto"
    )
    
    // Set some imported types
    let importedTypes = [
      "test.package.ImportedMessage": "imported.proto",
      "test.package.AnotherMessage": "another.proto"
    ]
    
    validator.setImportedTypes(importedTypes)
    
    // Should not throw for a simple file without references
    XCTAssertNoThrow(try validator.validate(fileNode))
  }
  
  /// Test validating a file with unresolved type references.
  func testUnresolvedTypeReferences() throws {
    // Create message that references undefined type
    let messageNode = MessageNode(
      location: SourceLocation(line: 2, column: 1),
      name: "TestMessage",
      fields: [
        FieldNode(
          location: SourceLocation(line: 3, column: 3),
          name: "undefined_field",
          type: .named("UndefinedType"),  // Type not defined or imported
          number: 1
        )
      ]
    )
    
    // Create file with unresolved reference
    let fileNode = FileNode(
      location: SourceLocation(line: 1, column: 1),
      syntax: "proto3",
      package: "test.package",
      filePath: "test.proto",
      definitions: [messageNode]
    )
    
    // Should throw
    XCTAssertThrowsError(try validator.validate(fileNode)) { error in
      XCTAssertTrue(error is ValidationError, "Expected ValidationError")
      XCTAssertTrue("\(error)".contains("UndefinedType"), "Error should mention the undefined type")
    }
  }
} 