import Foundation

/// Implementation of reference validation
class ReferenceValidator: ReferenceValidating {
  // Reference to the shared validation state
  private let state: ValidationState

  /// Initialize with a validation state
  /// - Parameter state: The validation state
  init(state: ValidationState) {
    self.state = state
  }

  /// Register types in a file
  /// - Parameter file: The file node
  /// - Throws: ValidationError if registration fails
  func registerTypes(_ file: FileNode) throws {
    let prefix = state.currentPackage.map { $0 + "." } ?? ""

    // Register messages
    for message in file.messages {
      let fullName = prefix + message.name
      try state.registerType(fullName, node: message)
    }

    // Register enums
    for enum_ in file.enums {
      let fullName = prefix + enum_.name
      try state.registerType(fullName, node: enum_)
    }
  }

  /// Validate type reference
  /// - Parameters:
  ///   - typeName: The type name
  ///   - message: The message containing the reference
  /// - Throws: ValidationError if the reference is invalid
  func validateTypeReference(_ typeName: String, inMessage message: MessageNode?) throws {
    // Handle fully qualified names (starting with dot)
    let typeToCheck = typeName.hasPrefix(".") ? String(typeName.dropFirst()) : typeName

    // Split into components
    let components = typeToCheck.split(separator: ".")

    if components.count > 1 {
      // Handle nested type references
      try validateNestedTypeReference(components, referencedIn: message?.name ?? "service")
      return
    }

    // Search in order:
    // 1. Current message scope (if within message)
    // 2. Current package
    // 3. Root scope
    // 4. Imported types

    // 1. Check current message scope if available
    if message != nil {
      for scope in state.scopeStack.reversed() {
        let fullName = "\(scope.typeName).\(typeToCheck)"
        if state.definedTypes[fullName] != nil {
          return
        }
      }
    }

    // 2. Check current package
    if let currentPackage = state.currentPackage {
      let fullName = "\(currentPackage).\(typeToCheck)"
      if state.definedTypes[fullName] != nil {
        return
      }
    }

    // 3. Check root scope
    if state.definedTypes[typeToCheck] != nil {
      return
    }

    // 4. Check imported types
    if state.importedTypes[typeToCheck] != nil {
      return
    }

    throw ValidationError.undefinedType(typeName, referencedIn: message?.name ?? "service")
  }

  /// Validate cross references in a file
  /// - Parameter file: The file node
  /// - Throws: ValidationError if validation fails
  func validateCrossReferences(_ file: FileNode) throws {
    // Validate all type references are resolvable
    for message in file.messages {
      for field in message.fields {
        if case .named(let typeName) = field.type {
          let resolvedName = resolveTypeName(typeName)
          if state.definedTypes[resolvedName] == nil && state.importedTypes[resolvedName] == nil {
            throw ValidationError.undefinedType(typeName, referencedIn: message.name)
          }
        }
      }
    }

    // Validate service type references
    for service in file.services {
      for rpc in service.rpcs {
        // Validate input type
        let inputType = resolveTypeName(rpc.inputType)
        if state.definedTypes[inputType] == nil && state.importedTypes[inputType] == nil {
          throw ValidationError.undefinedType(rpc.inputType, referencedIn: service.name)
        }

        // Validate output type
        let outputType = resolveTypeName(rpc.outputType)
        if state.definedTypes[outputType] == nil && state.importedTypes[outputType] == nil {
          throw ValidationError.undefinedType(rpc.outputType, referencedIn: service.name)
        }
      }
    }
  }

  // MARK: - Private Helper Methods

  /// Validate nested type reference
  /// - Parameters:
  ///   - components: The components of the type name
  ///   - referencedIn: The name of the containing type
  /// - Throws: ValidationError if validation fails
  private func validateNestedTypeReference(_ components: [Substring], referencedIn: String) throws {
    var currentPath = ""

    // Handle first component
    let firstComponent = String(components[0])
    if let currentPackage = state.currentPackage {
      // Try package-qualified first
      let packageQualified = "\(currentPackage).\(firstComponent)"
      if state.definedTypes[packageQualified] != nil {
        currentPath = packageQualified
      }
    }

    // If not found in package, try root scope
    if currentPath.isEmpty {
      if state.definedTypes[firstComponent] != nil {
        currentPath = firstComponent
      } else {
        throw ValidationError.undefinedType(firstComponent, referencedIn: referencedIn)
      }
    }

    // Validate remaining components
    for component in components.dropFirst() {
      currentPath = "\(currentPath).\(component)"
      if state.definedTypes[currentPath] == nil {
        throw ValidationError.undefinedType(currentPath, referencedIn: referencedIn)
      }
    }
  }

  /// Resolve a type name to its fully qualified form
  /// - Parameter typeName: The type name to resolve
  /// - Returns: The fully qualified type name
  private func resolveTypeName(_ typeName: String) -> String {
    if typeName.hasPrefix(".") {
      return String(typeName.dropFirst())
    }

    if typeName.contains(".") {
      return typeName
    }

    if let currentPackage = state.currentPackage {
      return "\(currentPackage).\(typeName)"
    }

    return typeName
  }
}
