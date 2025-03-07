import Foundation

/// Manages the state of the validation process
/// This class is shared among all validator components
class ValidationState {
  // Current package being validated
  var currentPackage: String?

  // Track all defined types
  var definedTypes: [String: DefinitionNode] = [:]

  // Symbol table for type resolution
  var symbolTable: SymbolTable?

  // Track scope stack for nested type resolution
  struct Scope {
    let typeName: String  // Fully qualified name of the type
    let node: DefinitionNode  // The definition node
  }

  var scopeStack: [Scope] = []

  // Track imported types
  var importedTypes: [String: String] = [:]

  // Track imported definitions
  var importedDefinitions: [String: [DefinitionNode]] = [:]

  // Track dependencies between types
  var dependencies: [String: Set<String>] = [:]

  /// Initialize a new validation state
  init() {}

  /// Reset the validation state
  func reset() {
    currentPackage = nil
    definedTypes.removeAll()
    scopeStack.removeAll()
    importedTypes.removeAll()
    importedDefinitions.removeAll()
    dependencies.removeAll()
  }

  /// Push a definition node onto the scope stack
  /// - Parameter node: The definition node to push
  func pushScope(_ node: DefinitionNode) {
    let typeName = getFullyQualifiedName(node.name)
    scopeStack.append(Scope(typeName: typeName, node: node))
  }

  /// Pop the top scope from the stack
  func popScope() {
    _ = scopeStack.popLast()
  }

  /// Get the current scope
  /// - Returns: The current scope or nil if the stack is empty
  func currentScope() -> Scope? {
    return scopeStack.last
  }

  /// Get the fully qualified name for a type
  /// - Parameter name: The type name
  /// - Returns: The fully qualified name
  func getFullyQualifiedName(_ name: String) -> String {
    if name.hasPrefix(".") {
      return String(name.dropFirst())
    }

    if let currentScope = currentScope() {
      return "\(currentScope.typeName).\(name)"
    }

    if let pkg = currentPackage, !pkg.isEmpty {
      return "\(pkg).\(name)"
    }

    return name
  }

  /// Register a type in the defined types dictionary
  /// - Parameters:
  ///   - name: The type name
  ///   - node: The definition node
  /// - Throws: ValidationError if the type is already defined
  func registerType(_ name: String, node: DefinitionNode) throws {
    let fullName = getFullyQualifiedName(name)
    if definedTypes[fullName] != nil {
      throw ValidationError.duplicateTypeName(fullName)
    }
    definedTypes[fullName] = node
  }
}
