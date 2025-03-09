import XCTest

@testable import SwiftProtoParser

/// Test suite for Symbol Resolution.
///
/// This test suite verifies the functionality of the symbol resolution component
/// according to the acceptance criteria defined in ACCEPTANCE_CRITERIA.md.
///
/// Acceptance Criteria:.
/// - Resolve symbols across files.
/// - Handle nested types.
/// - Support extensions.
/// - Validate symbol references.
/// - Detect duplicate symbols.
final class SymbolResolutionTests: XCTestCase {

  // MARK: - Extension Resolution Tests

  /// Test adding and resolving an extension node.
  ///
  /// This test verifies that an extension node can be added to the symbol table.
  /// and its fields can be resolved.
  func testAddAndResolveExtendNode() throws {
    let symbolTable = SymbolTable()

    // Create a message node that will be extended
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Person",
      fields: [],
      oneofs: [],
      options: [],
      reserved: [],
      messages: [],
      enums: []
    )

    // Add the message to the symbol table
    try symbolTable.addSymbol(messageNode, kind: .message, package: "example")

    // Create extension fields
    let field1 = FieldNode(
      location: SourceLocation(line: 5, column: 1),
      name: "extra_field",
      type: TypeNode.scalar(.string),
      number: 100,
      isOptional: true,
      options: [],
      jsonName: "extraField"
    )

    let field2 = FieldNode(
      location: SourceLocation(line: 6, column: 1),
      name: "another_field",
      type: TypeNode.scalar(.int32),
      number: 101,
      isOptional: true,
      options: [],
      jsonName: "anotherField"
    )

    // Add extensions directly instead of using ExtendNode
    try symbolTable.addExtension(
      field1,
      extendedType: "example.Person",
      package: "example.extensions"
    )
    try symbolTable.addExtension(
      field2,
      extendedType: "example.Person",
      package: "example.extensions"
    )

    // Verify extensions were added correctly
    let extensions = symbolTable.lookupExtensions(for: "example.Person")
    XCTAssertEqual(extensions.count, 2, "Should have 2 extensions")

    // Verify extension fields
    XCTAssertTrue(
      symbolTable.isExtension("example.extensions.extra_field"),
      "extra_field should be recognized as an extension"
    )
    XCTAssertTrue(
      symbolTable.isExtension("example.extensions.another_field"),
      "another_field should be recognized as an extension"
    )

    // Verify hasExtension method
    XCTAssertTrue(
      symbolTable.hasExtension(for: "example.Person", named: "extra_field"),
      "Should find extension by name"
    )
    XCTAssertTrue(
      symbolTable.hasExtension(for: "example.Person", named: "another_field"),
      "Should find extension by name"
    )
    XCTAssertFalse(
      symbolTable.hasExtension(for: "example.Person", named: "nonexistent"),
      "Should not find nonexistent extension"
    )

    // Verify resolveOptionType method
    let extraFieldType = symbolTable.resolveOptionType(for: "example.extensions.extra_field")
    XCTAssertNotNil(extraFieldType, "Should resolve option type")

    if case .scalar(let scalarType) = extraFieldType {
      XCTAssertEqual(scalarType, .string, "Should resolve correct type")
    }
    else {
      XCTFail("Expected scalar type")
    }

    let anotherFieldType = symbolTable.resolveOptionType(for: "example.extensions.another_field")
    XCTAssertNotNil(anotherFieldType, "Should resolve option type")

    if case .scalar(let scalarType) = anotherFieldType {
      XCTAssertEqual(scalarType, .int32, "Should resolve correct type")
    }
    else {
      XCTFail("Expected scalar type")
    }

    // Test with non-existent extension
    let nonExistentType = symbolTable.resolveOptionType(for: "example.extensions.nonexistent")
    XCTAssertNil(nonExistentType, "Should return nil for non-existent extension")
  }

  /// Test field resolution.
  ///
  /// This test verifies that fields can be resolved from their parent message.
  func testFieldResolution() throws {
    let symbolTable = SymbolTable()

    // Create field nodes
    let nameField = FieldNode(
      location: SourceLocation(line: 2, column: 3),
      name: "name",
      type: TypeNode.scalar(.string),
      number: 1,
      isOptional: true,
      options: [],
      jsonName: "name"
    )

    let ageField = FieldNode(
      location: SourceLocation(line: 3, column: 3),
      name: "age",
      type: TypeNode.scalar(.int32),
      number: 2,
      isOptional: true,
      options: [],
      jsonName: "age"
    )

    // Create a message node with fields
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Person",
      fields: [nameField, ageField],
      oneofs: [],
      options: [],
      reserved: [],
      messages: [],
      enums: []
    )

    // Add the message to the symbol table
    try symbolTable.addSymbol(messageNode, kind: .message, package: "example")

    // Add fields as symbols
    try symbolTable.addSymbol(
      nameField,
      kind: .field,
      package: "example",
      parent: symbolTable.lookup("example.Person")
    )
    try symbolTable.addSymbol(
      ageField,
      kind: .field,
      package: "example",
      parent: symbolTable.lookup("example.Person")
    )

    // Verify hasField method
    XCTAssertTrue(
      symbolTable.hasField(in: "example.Person", named: "name"),
      "Should find field by name"
    )
    XCTAssertTrue(
      symbolTable.hasField(in: "example.Person", named: "age"),
      "Should find field by name"
    )
    XCTAssertFalse(
      symbolTable.hasField(in: "example.Person", named: "nonexistent"),
      "Should not find nonexistent field"
    )

    // Verify resolveFieldType method
    let nameType = symbolTable.resolveFieldType(in: "example.Person", named: "name")
    XCTAssertNotNil(nameType, "Should resolve field type")

    if case .scalar(let scalarType) = nameType {
      XCTAssertEqual(scalarType, .string, "Should resolve correct type")
    }
    else {
      XCTFail("Expected scalar type")
    }

    let ageType = symbolTable.resolveFieldType(in: "example.Person", named: "age")
    XCTAssertNotNil(ageType, "Should resolve field type")

    if case .scalar(let scalarType) = ageType {
      XCTAssertEqual(scalarType, .int32, "Should resolve correct type")
    }
    else {
      XCTFail("Expected scalar type")
    }

    // Test with non-existent field
    let nonExistentType = symbolTable.resolveFieldType(in: "example.Person", named: "nonexistent")
    XCTAssertNil(nonExistentType, "Should return nil for non-existent field")

    // Test with non-existent message
    let nonExistentMessageType = symbolTable.resolveFieldType(
      in: "example.NonExistent",
      named: "name"
    )
    XCTAssertNil(nonExistentMessageType, "Should return nil for non-existent message")
  }

  /// Test getting symbols by kind.
  ///
  /// This test verifies that symbols can be retrieved by kind.
  func testGetSymbolsByKind() throws {
    let symbolTable = SymbolTable()

    // Create various nodes
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Person",
      fields: [],
      oneofs: [],
      options: [],
      reserved: [],
      messages: [],
      enums: []
    )

    let enumNode = EnumNode(
      location: SourceLocation(line: 10, column: 1),
      name: "Status",
      values: [],
      options: []
    )

    let serviceNode = ServiceNode(
      location: SourceLocation(line: 20, column: 1),
      name: "UserService",
      rpcs: [],
      options: []
    )

    // Add symbols to the table
    try symbolTable.addSymbol(messageNode, kind: .message, package: "example")
    try symbolTable.addSymbol(enumNode, kind: .enumeration, package: "example")
    try symbolTable.addSymbol(serviceNode, kind: .service, package: "example")

    // Get symbols by kind
    let messages = symbolTable.getSymbols(ofKind: .message)
    let enums = symbolTable.getSymbols(ofKind: .enumeration)
    let services = symbolTable.getSymbols(ofKind: .service)
    let fields = symbolTable.getSymbols(ofKind: .field)

    // Verify results
    XCTAssertEqual(messages.count, 1, "Should find 1 message")
    XCTAssertEqual(messages[0].fullName, "example.Person", "Should find correct message")

    XCTAssertEqual(enums.count, 1, "Should find 1 enum")
    XCTAssertEqual(enums[0].fullName, "example.Status", "Should find correct enum")

    XCTAssertEqual(services.count, 1, "Should find 1 service")
    XCTAssertEqual(services[0].fullName, "example.UserService", "Should find correct service")

    XCTAssertEqual(fields.count, 0, "Should find 0 fields")
  }

  /// Test clearing the symbol table.
  ///
  /// This test verifies that the symbol table can be cleared.
  func testClearSymbolTable() throws {
    let symbolTable = SymbolTable()

    // Create a node
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Person",
      fields: [],
      oneofs: [],
      options: [],
      reserved: [],
      messages: [],
      enums: []
    )

    // Add symbol to the table
    try symbolTable.addSymbol(messageNode, kind: .message, package: "example")

    // Verify symbol was added
    XCTAssertNotNil(symbolTable.lookup("example.Person"), "Symbol should be found before clearing")

    // Clear the table
    symbolTable.clear()

    // Verify symbol was removed
    XCTAssertNil(symbolTable.lookup("example.Person"), "Symbol should not be found after clearing")

    // Verify no symbols of any kind
    XCTAssertEqual(
      symbolTable.getSymbols(ofKind: .message).count,
      0,
      "Should have no messages after clearing"
    )
    XCTAssertEqual(
      symbolTable.lookupExtensions(for: "example.Person").count,
      0,
      "Should have no extensions after clearing"
    )
  }

  // MARK: - Error Handling Tests

  /// Test duplicate symbol error.
  ///
  /// This test verifies that adding a duplicate symbol throws an error.
  func testDuplicateSymbolError() throws {
    let symbolTable = SymbolTable()

    // Create a node
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Person",
      fields: [],
      oneofs: [],
      options: [],
      reserved: [],
      messages: [],
      enums: []
    )

    // Add symbol to the table
    try symbolTable.addSymbol(messageNode, kind: .message, package: "example")

    // Try to add the same symbol again
    XCTAssertThrowsError(try symbolTable.addSymbol(messageNode, kind: .message, package: "example")) { error in
      guard case SymbolTableError.duplicateSymbol(let name) = error else {
        XCTFail("Expected duplicateSymbol error, got \(error)")
        return
      }

      XCTAssertEqual(name, "example.Person", "Error should contain the duplicate symbol name")
    }
  }

  /// Test duplicate extension error.
  ///
  /// This test verifies that adding a duplicate extension throws an error.
  func testDuplicateExtensionError() throws {
    let symbolTable = SymbolTable()

    // Create a message node that will be extended
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Person",
      fields: [],
      oneofs: [],
      options: [],
      reserved: [],
      messages: [],
      enums: []
    )

    // Add the message to the symbol table
    try symbolTable.addSymbol(messageNode, kind: .message, package: "example")

    // Create an extension field
    let field = FieldNode(
      location: SourceLocation(line: 5, column: 1),
      name: "extra_field",
      type: TypeNode.scalar(.string),
      number: 100,
      isOptional: true,
      options: [],
      jsonName: "extraField"
    )

    // Add the extension to the symbol table
    try symbolTable.addExtension(
      field,
      extendedType: "example.Person",
      package: "example.extensions"
    )

    // Try to add the same extension again
    XCTAssertThrowsError(
      try symbolTable.addExtension(
        field,
        extendedType: "example.Person",
        package: "example.extensions"
      )
    ) { error in
      guard case SymbolTableError.duplicateSymbol(let name) = error else {
        XCTFail("Expected duplicateSymbol error, got \(error)")
        return
      }

      XCTAssertEqual(
        name,
        "example.extensions.extra_field",
        "Error should contain the duplicate extension name"
      )
    }
  }
}
