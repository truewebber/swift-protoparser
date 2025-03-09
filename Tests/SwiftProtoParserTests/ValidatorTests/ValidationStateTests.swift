import XCTest

@testable import SwiftProtoParser

/// Test suite for ValidationState.
///
/// This test suite verifies the functionality of the ValidationState component
/// which is used by the validator to track state during validation.
final class ValidationStateTests: XCTestCase {

  // Test subject
  private var validationState: ValidationState!

  override func setUp() {
    super.setUp()
    validationState = ValidationState()
  }

  override func tearDown() {
    validationState = nil
    super.tearDown()
  }

  // MARK: - Basic State Tests

  /// Test initializing and resetting the validation state.
  func testInitAndReset() {
    // Initial state should be empty
    XCTAssertNil(validationState.currentPackage)
    XCTAssertTrue(validationState.definedTypes.isEmpty)
    XCTAssertTrue(validationState.scopeStack.isEmpty)
    XCTAssertTrue(validationState.importedTypes.isEmpty)
    XCTAssertTrue(validationState.importedDefinitions.isEmpty)
    XCTAssertTrue(validationState.dependencies.isEmpty)

    // Set some state
    validationState.currentPackage = "test.package"

    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage"
    )

    try? validationState.registerType("TestMessage", node: messageNode)
    validationState.pushScope(messageNode)
    validationState.importedTypes["ImportedType"] = "imported.proto"
    validationState.importedDefinitions["imported.proto"] = [messageNode]
    validationState.dependencies["TestMessage"] = ["DependentType"]

    // Reset should clear everything
    validationState.reset()

    XCTAssertNil(validationState.currentPackage)
    XCTAssertTrue(validationState.definedTypes.isEmpty)
    XCTAssertTrue(validationState.scopeStack.isEmpty)
    XCTAssertTrue(validationState.importedTypes.isEmpty)
    XCTAssertTrue(validationState.importedDefinitions.isEmpty)
    XCTAssertTrue(validationState.dependencies.isEmpty)
  }

  // MARK: - Scope Stack Tests

  /// Test pushing and popping scopes.
  func testScopeStackOperations() {
    // Create test nodes
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage"
    )

    let nestedMessageNode = MessageNode(
      location: SourceLocation(line: 2, column: 3),
      name: "NestedMessage"
    )

    // Initially empty
    XCTAssertTrue(validationState.scopeStack.isEmpty)
    XCTAssertNil(validationState.currentScope())

    // Push first scope
    validationState.pushScope(messageNode)
    XCTAssertEqual(validationState.scopeStack.count, 1)
    XCTAssertEqual(validationState.currentScope()?.node.name, "TestMessage")

    // Push second scope
    validationState.pushScope(nestedMessageNode)
    XCTAssertEqual(validationState.scopeStack.count, 2)
    XCTAssertEqual(validationState.currentScope()?.node.name, "NestedMessage")

    // Pop scope
    validationState.popScope()
    XCTAssertEqual(validationState.scopeStack.count, 1)
    XCTAssertEqual(validationState.currentScope()?.node.name, "TestMessage")

    // Pop last scope
    validationState.popScope()
    XCTAssertTrue(validationState.scopeStack.isEmpty)
    XCTAssertNil(validationState.currentScope())
  }

  // MARK: - Name Resolution Tests

  /// Test fully qualified name resolution.
  func testFullyQualifiedNameResolution() {
    // Test with no package or scope
    XCTAssertEqual(validationState.getFullyQualifiedName("Message"), "Message")

    // Test with package
    validationState.currentPackage = "test.package"
    XCTAssertEqual(validationState.getFullyQualifiedName("Message"), "test.package.Message")

    // Test with absolute name (starting with dot)
    XCTAssertEqual(validationState.getFullyQualifiedName(".absolute.path.Message"), "absolute.path.Message")

    // Test with scope
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "OuterMessage"
    )
    validationState.pushScope(messageNode)
    XCTAssertEqual(validationState.getFullyQualifiedName("NestedMessage"), "test.package.OuterMessage.NestedMessage")

    // Test with nested scope
    let nestedMessageNode = MessageNode(
      location: SourceLocation(line: 2, column: 3),
      name: "MiddleMessage"
    )
    validationState.pushScope(nestedMessageNode)
    XCTAssertEqual(
      validationState.getFullyQualifiedName("InnerMessage"),
      "test.package.OuterMessage.MiddleMessage.InnerMessage"
    )
  }

  // MARK: - Type Registration Tests

  /// Test registering types.
  func testTypeRegistration() throws {
    validationState.currentPackage = "test.package"

    // Register a type
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage"
    )

    try validationState.registerType("TestMessage", node: messageNode)
    XCTAssertEqual(validationState.definedTypes.count, 1)
    XCTAssertNotNil(validationState.definedTypes["test.package.TestMessage"])

    // Register another type
    let enumNode = EnumNode(
      location: SourceLocation(line: 2, column: 1),
      name: "TestEnum",
      values: [
        EnumValueNode(
          location: SourceLocation(line: 3, column: 3),
          name: "VALUE",
          number: 0
        )
      ]
    )

    try validationState.registerType("TestEnum", node: enumNode)
    XCTAssertEqual(validationState.definedTypes.count, 2)
    XCTAssertNotNil(validationState.definedTypes["test.package.TestEnum"])

    // Register a nested type
    validationState.pushScope(messageNode)
    let nestedMessageNode = MessageNode(
      location: SourceLocation(line: 4, column: 3),
      name: "NestedMessage"
    )

    try validationState.registerType("NestedMessage", node: nestedMessageNode)
    XCTAssertEqual(validationState.definedTypes.count, 3)
    XCTAssertNotNil(validationState.definedTypes["test.package.TestMessage.NestedMessage"])
  }

  /// Test registering duplicate types.
  func testDuplicateTypeRegistration() throws {
    validationState.currentPackage = "test.package"

    // Register a type
    let messageNode1 = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "TestMessage"
    )

    try validationState.registerType("TestMessage", node: messageNode1)

    // Try to register a duplicate type
    let messageNode2 = MessageNode(
      location: SourceLocation(line: 2, column: 1),
      name: "TestMessage"
    )

    XCTAssertThrowsError(try validationState.registerType("TestMessage", node: messageNode2)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      if case .duplicateTypeName(let name) = validationError {
        XCTAssertEqual(name, "test.package.TestMessage")
      }
      else {
        XCTFail("Expected duplicateTypeName error")
      }
    }
  }

  // MARK: - Imported Types Tests

  /// Test managing imported types.
  func testImportedTypes() {
    // Add imported types
    validationState.importedTypes["ImportedMessage"] = "imported.proto"
    validationState.importedTypes["AnotherMessage"] = "another.proto"

    XCTAssertEqual(validationState.importedTypes.count, 2)
    XCTAssertEqual(validationState.importedTypes["ImportedMessage"], "imported.proto")
    XCTAssertEqual(validationState.importedTypes["AnotherMessage"], "another.proto")

    // Add imported definitions
    let messageNode = MessageNode(
      location: SourceLocation(line: 1, column: 1),
      name: "ImportedMessage"
    )

    validationState.importedDefinitions["imported.proto"] = [messageNode]
    XCTAssertEqual(validationState.importedDefinitions.count, 1)
    XCTAssertEqual(validationState.importedDefinitions["imported.proto"]?.count, 1)
    XCTAssertEqual(validationState.importedDefinitions["imported.proto"]?[0].name, "ImportedMessage")
  }

  // MARK: - Dependencies Tests

  /// Test managing type dependencies.
  func testDependencies() {
    // Add dependencies
    validationState.dependencies["Message1"] = ["Dependency1", "Dependency2"]
    validationState.dependencies["Message2"] = ["Dependency3"]

    XCTAssertEqual(validationState.dependencies.count, 2)
    XCTAssertEqual(validationState.dependencies["Message1"]?.count, 2)
    XCTAssertTrue(validationState.dependencies["Message1"]?.contains("Dependency1") ?? false)
    XCTAssertTrue(validationState.dependencies["Message1"]?.contains("Dependency2") ?? false)
    XCTAssertEqual(validationState.dependencies["Message2"]?.count, 1)
    XCTAssertTrue(validationState.dependencies["Message2"]?.contains("Dependency3") ?? false)
  }
}
