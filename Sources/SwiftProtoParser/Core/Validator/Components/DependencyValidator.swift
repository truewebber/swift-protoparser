import Foundation

/// Implementation of dependency validation
class DependencyValidator: DependencyValidating {
  // Reference to the shared validation state
  private let state: ValidationState
  
  /// Initialize with a validation state
  /// - Parameter state: The validation state
  init(state: ValidationState) {
    self.state = state
  }
  
  /// Build dependency graph for a file
  /// - Parameter file: The file node
  /// - Throws: ValidationError if building fails
  func buildDependencyGraph(_ file: FileNode) throws {
    for message in file.messages {
      let fullName = getFullyQualifiedName(message.name)
      var deps = Set<String>()
      
      // Add field type dependencies
      for field in message.fields {
        if case .named(let typeName) = field.type {
          deps.insert(resolveTypeName(typeName))
        }
      }
      
      state.dependencies[fullName] = deps
    }
  }
  
  /// Check for cyclic dependencies
  /// - Throws: ValidationError if cycles are detected
  func checkCyclicDependencies() throws {
    var visited = Set<String>()
    var stack = Set<String>()
    
    func dfs(_ type: String, path: [String]) throws {
      if stack.contains(type) {
        throw ValidationError.cyclicDependency(path + [type])
      }
      if visited.contains(type) {
        return
      }
      
      visited.insert(type)
      stack.insert(type)
      
      if let deps = state.dependencies[type] {
        for dep in deps {
          try dfs(dep, path: path + [type])
        }
      }
      
      stack.remove(type)
    }
    
    for type in state.definedTypes.keys {
      try dfs(type, path: [])
    }
  }
  
  // MARK: - Private Helper Methods
  
  /// Get the fully qualified name for a type
  /// - Parameter name: The type name
  /// - Returns: The fully qualified name
  private func getFullyQualifiedName(_ name: String) -> String {
    if name.hasPrefix(".") {
      return String(name.dropFirst())
    }
    
    if let currentPackage = state.currentPackage, !currentPackage.isEmpty {
      return "\(currentPackage).\(name)"
    }
    
    return name
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