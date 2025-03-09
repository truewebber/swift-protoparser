import XCTest

@testable import SwiftProtoParser

/// Test suite for SymbolTable.
///
/// This test suite verifies the functionality of the SymbolTable component
/// according to the acceptance criteria defined in ACCEPTANCE_CRITERIA.md.
///
/// Acceptance Criteria:.
/// - Add and lookup symbols.
/// - Support nested types.
/// - Handle extensions.
/// - Validate symbol references.
/// - Detect duplicate symbols.
final class SymbolTableTests: XCTestCase {

  // MARK: - Positive Tests

  /// Test adding and looking up symbols.
  ///
  /// This test verifies that symbols can be added to and looked up from the symbol table.
  func testAddAndLookupSymbols() throws {
    // Create a symbol table
    let symbolTable = SymbolTable()

    // Create a message node
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Person",
      fields: []
    )

    // Create an enum node
    let enumNode = EnumNode(
      location: SourceLocation(line: 10, column: 1),
      name: "Status",
      values: []
    )

    // Add the nodes to the symbol table
    try symbolTable.addSymbol(messageNode, kind: .message, package: "example")
    try symbolTable.addSymbol(enumNode, kind: .enumeration, package: "example")

    // Look up the nodes
    let foundMessage = symbolTable.lookup("example.Person")
    let foundEnum = symbolTable.lookup("example.Status")

    // Verify the nodes were found
    XCTAssertNotNil(foundMessage, "Message should be found")
    XCTAssertNotNil(foundEnum, "Enum should be found")
    XCTAssertEqual(foundMessage?.fullName, "example.Person", "Message name should match")
    XCTAssertEqual(foundEnum?.fullName, "example.Status", "Enum name should match")
  }

  /// Test looking up types.
  ///
  /// This test verifies that types can be looked up from the symbol table.
  func testLookupTypes() throws {
    // Create a symbol table
    let symbolTable = SymbolTable()

    // Create a message node
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Person",
      fields: []
    )

    // Create an enum node
    let enumNode = EnumNode(
      location: SourceLocation(line: 10, column: 1),
      name: "Status",
      values: []
    )

    // Add the nodes to the symbol table
    try symbolTable.addSymbol(messageNode, kind: .message, package: "example")
    try symbolTable.addSymbol(enumNode, kind: .enumeration, package: "example")

    // Look up the types
    let foundMessage = symbolTable.lookupType("example.Person")
    let foundEnum = symbolTable.lookupType("example.Status")

    // Verify the types were found
    XCTAssertNotNil(foundMessage, "Message type should be found")
    XCTAssertNotNil(foundEnum, "Enum type should be found")
    XCTAssertEqual(foundMessage?.fullName, "example.Person", "Message name should match")
    XCTAssertEqual(foundEnum?.fullName, "example.Status", "Enum name should match")
  }

  /// Test nested types.
  ///
  /// This test verifies that nested types can be added to and looked up from the symbol table.
  func testNestedTypes() throws {
    // Create a symbol table
    let symbolTable = SymbolTable()

    // Create a nested enum
    let nestedEnum = EnumNode(
      location: SourceLocation(line: 5, column: 3),
      name: "PhoneType",
      values: []
    )

    // Create a nested message
    let nestedMessage = MessageNode(
      location: SourceLocation(line: 10, column: 3),
      name: "Address",
      fields: []
    )

    // Create a parent message with nested types
    let parentMessage = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Person",
      fields: [],
      messages: [nestedMessage],
      enums: [nestedEnum]
    )

    // Add the parent message to the symbol table
    try symbolTable.addSymbol(parentMessage, kind: .message, package: "example")

    // Add the nested types to the symbol table
    let parentSymbol = symbolTable.lookup("example.Person")
    try symbolTable.addSymbol(nestedEnum, kind: .enumeration, package: nil, parent: parentSymbol)
    try symbolTable.addSymbol(nestedMessage, kind: .message, package: nil, parent: parentSymbol)

    // Look up the nested types
    let foundNestedEnum = symbolTable.lookupType("example.Person.PhoneType")
    let foundNestedMessage = symbolTable.lookupType("example.Person.Address")

    // Verify the nested types were found
    XCTAssertNotNil(foundNestedEnum, "Nested enum should be found")
    XCTAssertNotNil(foundNestedMessage, "Nested message should be found")
    XCTAssertEqual(
      foundNestedEnum?.fullName,
      "example.Person.PhoneType",
      "Nested enum name should match"
    )
    XCTAssertEqual(
      foundNestedMessage?.fullName,
      "example.Person.Address",
      "Nested message name should match"
    )
  }

  /// Test package lookup.
  ///
  /// This test verifies that symbols can be looked up with package names.
  func testPackageLookup() throws {
    // Create a symbol table
    let symbolTable = SymbolTable()

    // Create message nodes in different packages
    let message1 = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Person",
      fields: []
    )

    let message2 = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Person",
      fields: []
    )

    // Add the nodes to the symbol table with different packages
    try symbolTable.addSymbol(message1, kind: .message, package: "example.user")
    try symbolTable.addSymbol(message2, kind: .message, package: "example.model")

    // Look up the nodes with fully qualified names
    let foundMessage1 = symbolTable.lookup("example.user.Person")
    let foundMessage2 = symbolTable.lookup("example.model.Person")

    // Verify the nodes were found
    XCTAssertNotNil(foundMessage1, "Message in user package should be found")
    XCTAssertNotNil(foundMessage2, "Message in model package should be found")

    // Verify the nodes are different
    XCTAssertNotEqual(foundMessage1, foundMessage2, "Messages should be different")
  }

  /// Test non-existent symbols.
  ///
  /// This test verifies that looking up non-existent symbols returns nil.
  func testNonExistentSymbols() {
    // Create a symbol table
    let symbolTable = SymbolTable()

    // Look up non-existent symbols
    let nonExistentSymbol = symbolTable.lookup("example.NonExistent")
    let nonExistentType = symbolTable.lookupType("example.NonExistent")

    // Verify the symbols were not found
    XCTAssertNil(nonExistentSymbol, "Non-existent symbol should not be found")
    XCTAssertNil(nonExistentType, "Non-existent type should not be found")
  }

  /// Test extensions.
  ///
  /// This test verifies that extensions can be added to and looked up from the symbol table.
  func testExtensions() throws {
    // Create a symbol table
    let symbolTable = SymbolTable()

    // Create a message node
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Person",
      fields: []
    )

    // Add the message to the symbol table
    try symbolTable.addSymbol(messageNode, kind: .message, package: "example")

    // Create extension fields
    let field1 = FieldNode(
      location: SourceLocation(line: 10, column: 3),
      name: "age",
      type: .scalar(.int32),
      number: 100
    )

    let field2 = FieldNode(
      location: SourceLocation(line: 11, column: 3),
      name: "email",
      type: .scalar(.string),
      number: 101
    )

    // Create an extension node
    let extendNode = ExtendNode(
      location: SourceLocation(line: 9, column: 1),
      typeName: "example.Person",
      fields: [field1, field2]
    )

    // Add the extension to the symbol table
    try symbolTable.addExtension(field1, extendedType: "example.Person", package: "example.ext")
    try symbolTable.addExtension(field2, extendedType: "example.Person", package: "example.ext")

    // Get the extensions for the message
    let extensions = symbolTable.lookupExtensions(for: "example.Person")

    // Verify the extensions were found
    XCTAssertEqual(extensions.count, 2, "Should have 2 extensions")
    XCTAssertTrue(
      extensions.contains(where: { $0.fullName.hasSuffix("age") }),
      "Extensions should include age field"
    )
    XCTAssertTrue(
      extensions.contains(where: { $0.fullName.hasSuffix("email") }),
      "Extensions should include email field"
    )
  }

  /// Test field resolution.
  ///
  /// This test verifies that fields can be resolved from their parent message.
  func testFieldResolution() throws {
    // Create a symbol table
    let symbolTable = SymbolTable()

    // Create fields
    let field1 = FieldNode(
      location: SourceLocation(line: 2, column: 3),
      name: "name",
      type: .scalar(.string),
      number: 1
    )

    let field2 = FieldNode(
      location: SourceLocation(line: 3, column: 3),
      name: "id",
      type: .scalar(.int32),
      number: 2
    )

    // Create a message with fields
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Person",
      fields: [field1, field2]
    )

    // Add the message to the symbol table
    try symbolTable.addSymbol(messageNode, kind: .message, package: "example")

    // Add fields as symbols
    let messageSymbol = symbolTable.lookup("example.Person")
    try symbolTable.addSymbol(field1, kind: .field, package: "example", parent: messageSymbol)
    try symbolTable.addSymbol(field2, kind: .field, package: "example", parent: messageSymbol)

    // Verify hasField method
    XCTAssertTrue(
      symbolTable.hasField(in: "example.Person", named: "name"),
      "Should find name field"
    )
    XCTAssertTrue(
      symbolTable.hasField(in: "example.Person", named: "id"),
      "Should find id field"
    )

    // Resolve field types
    let nameType = symbolTable.resolveFieldType(in: "example.Person", named: "name")
    let idType = symbolTable.resolveFieldType(in: "example.Person", named: "id")

    // Verify the field types were resolved
    XCTAssertNotNil(nameType, "Field 'name' type should be resolved")
    XCTAssertNotNil(idType, "Field 'id' type should be resolved")

    if case .scalar(let nameScalar) = nameType {
      XCTAssertEqual(nameScalar, .string, "Field 'name' should be string type")
    }
    else {
      XCTFail("Field 'name' should be scalar type")
    }

    if case .scalar(let idScalar) = idType {
      XCTAssertEqual(idScalar, .int32, "Field 'id' should be int32 type")
    }
    else {
      XCTFail("Field 'id' should be scalar type")
    }
  }

  /// Test getting symbols by kind.
  ///
  /// This test verifies that symbols can be retrieved by kind.
  func testGetSymbolsByKind() throws {
    // Create a symbol table
    let symbolTable = SymbolTable()

    // Create a message node
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Person",
      fields: []
    )

    // Create an enum node
    let enumNode = EnumNode(
      location: SourceLocation(line: 10, column: 1),
      name: "Status",
      values: []
    )

    // Create a service node
    let serviceNode = ServiceNode(
      location: SourceLocation(line: 20, column: 1),
      name: "UserService",
      rpcs: []
    )

    // Add the nodes to the symbol table
    try symbolTable.addSymbol(messageNode, kind: .message, package: "example")
    try symbolTable.addSymbol(enumNode, kind: .enumeration, package: "example")
    try symbolTable.addSymbol(serviceNode, kind: .service, package: "example")

    // Get symbols by kind
    let messages = symbolTable.getSymbols(ofKind: .message)
    let enums = symbolTable.getSymbols(ofKind: .enumeration)
    let services = symbolTable.getSymbols(ofKind: .service)

    // Verify the symbols were retrieved
    XCTAssertEqual(messages.count, 1, "Should have 1 message")
    XCTAssertEqual(enums.count, 1, "Should have 1 enum")
    XCTAssertEqual(services.count, 1, "Should have 1 service")
    XCTAssertEqual(messages[0].fullName, "example.Person", "Message name should match")
    XCTAssertEqual(enums[0].fullName, "example.Status", "Enum name should match")
    XCTAssertEqual(services[0].fullName, "example.UserService", "Service name should match")
  }

  /// Test option type resolution.
  ///
  /// This test verifies that option types can be resolved.
  func testOptionTypeResolution() throws {
    // Create a symbol table
    let symbolTable = SymbolTable()

    // Create a message node for custom options
    let optionMessage = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "CustomOptions",
      fields: []
    )

    // Add the option message to the symbol table
    try symbolTable.addSymbol(optionMessage, kind: .message, package: "example")

    // Create an option field
    let optionField = FieldNode(
      location: SourceLocation(line: 2, column: 3),
      name: "custom_option",
      type: .scalar(.string),
      number: 1000
    )

    // Create an extension node for the option
    let extendNode = ExtendNode(
      location: SourceLocation(line: 5, column: 1),
      typeName: "google.protobuf.MessageOptions",
      fields: [optionField]
    )

    // Add the extension to the symbol table
    try symbolTable.addExtension(
      optionField,
      extendedType: "google.protobuf.MessageOptions",
      package: "example"
    )

    // Resolve the option type
    let resolvedOption = symbolTable.resolveOptionType(for: "example.custom_option")

    // Verify the option was resolved
    XCTAssertNotNil(resolvedOption, "Option should be resolved")
    if case .scalar(let scalarType) = resolvedOption {
      XCTAssertEqual(scalarType, .string, "Option type should be string")
    }
    else {
      XCTFail("Option should be scalar type")
    }
  }

  /// Test clearing the symbol table.
  ///
  /// This test verifies that the symbol table can be cleared.
  func testClearSymbolTable() throws {
    // Create a symbol table
    let symbolTable = SymbolTable()

    // Create a message node
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Person",
      fields: []
    )

    // Add the message to the symbol table
    try symbolTable.addSymbol(messageNode, kind: .message, package: "example")

    // Verify the message was added
    let foundMessage = symbolTable.lookup("example.Person")
    XCTAssertNotNil(foundMessage, "Message should be found")

    // Clear the symbol table
    symbolTable.clear()

    // Verify the message was removed
    let clearedMessage = symbolTable.lookup("example.Person")
    XCTAssertNil(clearedMessage, "Message should not be found after clearing")
  }

  // MARK: - Negative Tests

  /// Test duplicate symbols.
  ///
  /// This test verifies that adding duplicate symbols throws an error.
  func testDuplicateSymbols() throws {
    // Create a symbol table
    let symbolTable = SymbolTable()

    // Create a message node
    let messageNode1 = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Person",
      fields: []
    )

    // Create another message node with the same name
    let messageNode2 = MessageNode(
      location: SourceLocation(line: 10, column: 1),
      name: "Person",
      fields: []
    )

    // Add the first message to the symbol table
    try symbolTable.addSymbol(messageNode1, kind: .message, package: "example")

    // Verify adding a duplicate symbol throws an error
    XCTAssertThrowsError(
      try symbolTable.addSymbol(messageNode2, kind: .message, package: "example")
    ) { error in
      guard let symbolError = error as? SymbolTableError else {
        XCTFail("Expected SymbolTableError")
        return
      }

      if case .duplicateSymbol(let name) = symbolError {
        XCTAssertEqual(name, "example.Person", "Error should contain the duplicate symbol name")
      }
      else {
        XCTFail("Expected duplicateSymbol error")
      }
    }
  }

  /// Test duplicate extensions.
  ///
  /// This test verifies that adding duplicate extensions throws an error.
  func testDuplicateExtensions() throws {
    // Create a symbol table
    let symbolTable = SymbolTable()

    // Create a message node
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "Person",
      fields: []
    )

    // Add the message to the symbol table
    try symbolTable.addSymbol(messageNode, kind: .message, package: "example")

    // Create an extension field
    let field = FieldNode(
      location: SourceLocation(line: 5, column: 3),
      name: "age",
      type: .scalar(.int32),
      number: 100
    )

    // Add the first extension to the symbol table
    try symbolTable.addExtension(field, extendedType: "example.Person", package: "example.ext")

    // Verify adding a duplicate extension throws an error
    XCTAssertThrowsError(
      try symbolTable.addExtension(field, extendedType: "example.Person", package: "example.ext")
    ) { error in
      guard let symbolError = error as? SymbolTableError else {
        XCTFail("Expected SymbolTableError")
        return
      }

      if case .duplicateSymbol(let name) = symbolError {
        XCTAssertEqual(name, "example.ext.age", "Error should contain the duplicate extension name")
      }
      else {
        XCTFail("Expected duplicateSymbol error")
      }
    }
  }
}
