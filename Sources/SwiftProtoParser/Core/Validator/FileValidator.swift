import Foundation

/// Implementation of file-level validation
class FileValidator: FileValidating {
  // Reference to the shared validation state
  private let state: ValidationState

  /// Initialize with a validation state
  /// - Parameter state: The validation state
  init(state: ValidationState) {
    self.state = state
  }

  /// Validate the syntax version of a proto file
  /// - Parameter syntax: The syntax version string
  /// - Throws: ValidationError if the syntax version is invalid
  func validateSyntaxVersion(_ syntax: String) throws {
    guard syntax == "proto3" else {
      throw ValidationError.invalidSyntaxVersion(syntax)
    }
  }

  /// Validate a file node
  /// - Parameter file: The file node to validate
  /// - Throws: ValidationError if validation fails
  func validateFile(_ file: FileNode) throws {
    // Validate package name if present
    if let package = file.package {
      try validatePackageName(package)
    }

    // Validate imports
    for imp in file.imports {
      try validateImport(imp)
    }
  }

  /// Validate package name
  /// - Parameter package: The package name
  /// - Throws: ValidationError if the package name is invalid
  func validatePackageName(_ package: String) throws {
    // If package is nil, it's valid (no package)
    guard !package.isEmpty else {
      return
    }

    let components = package.split(separator: ".")

    // Check for empty package name
    guard !components.isEmpty else {
      throw ValidationError.invalidPackageName(package)
    }

    // Check for leading or trailing dots
    if package.hasPrefix(".") || package.hasSuffix(".") {
      throw ValidationError.invalidPackageName(package)
    }

    // Check for consecutive dots
    if package.contains("..") {
      throw ValidationError.invalidPackageName(package)
    }

    // Check each component
    for component in components {
      // Component can't be empty
      guard !component.isEmpty else {
        throw ValidationError.invalidPackageName(package)
      }

      // First character must be a lowercase letter (not underscore)
      guard let firstChar = component.first,
        firstChar.isLetter && firstChar.isLowercase
      else {
        throw ValidationError.invalidPackageName(package)
      }

      // Remaining characters must be lowercase letters, digits, or underscores
      for char in component {
        guard (char.isLetter && char.isLowercase) || char.isNumber || char == "_" else {
          throw ValidationError.invalidPackageName(package)
        }
      }
    }
  }

  /// Validate import statement
  /// - Parameter imp: The import node
  /// - Throws: ValidationError if the import is invalid
  func validateImport(_ imp: ImportNode) throws {
    // Import path must be a valid string
    guard !imp.path.isEmpty else {
      throw ValidationError.invalidImport("Import path cannot be empty")
    }

    // Check for valid import modifier
    switch imp.modifier {
    case .none, .public, .weak:
      // Valid import modifiers
      break
    }
  }

  // MARK: - Helper Methods

  /// Check if a string is a valid identifier
  /// - Parameter identifier: The string to check
  /// - Returns: True if the string is a valid identifier
  private func isValidIdentifier(_ identifier: String) -> Bool {
    guard !identifier.isEmpty else { return false }

    // First character must be a letter or underscore
    guard let firstChar = identifier.first,
      firstChar.isLetter || firstChar == "_"
    else {
      return false
    }

    // Remaining characters must be letters, digits, or underscores
    for char in identifier.dropFirst() {
      guard char.isLetter || char.isNumber || char == "_" else {
        return false
      }
    }

    return true
  }
}
