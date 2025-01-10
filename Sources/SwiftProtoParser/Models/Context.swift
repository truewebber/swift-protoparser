import Foundation

/// Represents the current parsing context and state
public final class Context {
  /// Current package being parsed
  public private(set) var currentPackage: String?

  /// Stack of message contexts for nested definitions
  private var messageStack: [MessageContext] = []

  /// Symbol table for type resolution
  private var symbolTable: SymbolTable

  /// Import resolver for handling imports
  private var importResolver: ImportResolver

  /// Set of imported files to prevent circular imports
  private var importedFiles: Set<String> = []

  /// Initialize a new context
  /// - Parameters:
  ///   - symbolTable: The symbol table to use
  ///   - importResolver: The import resolver to use
  public init(symbolTable: SymbolTable, importResolver: ImportResolver) {
    self.symbolTable = symbolTable
    self.importResolver = importResolver
  }

  /// Enter a package scope
  /// - Parameter package: The package name
  public func enterPackage(_ package: String) {
    currentPackage = package
  }

  /// Exit the current package scope
  public func exitPackage() {
    currentPackage = nil
  }

  /// Enter a message scope
  /// - Parameter message: The message node
  public func enterMessage(_ message: MessageNode) {
    let context = MessageContext(message: message)
    messageStack.append(context)
  }

  /// Exit the current message scope
  public func exitMessage() {
    _ = messageStack.popLast()
  }

  /// Get the current message context
  public var currentMessage: MessageContext? {
    return messageStack.last
  }

  /// Register an imported file
  /// - Parameter path: The file path
  /// - Throws: ContextError if circular import detected
  public func registerImport(_ path: String) throws {
    guard !importedFiles.contains(path) else {
      throw ContextError.circularImport(path)
    }
    importedFiles.insert(path)
  }

  /// Resolve a type name in the current context
  /// - Parameter name: The type name to resolve
  /// - Returns: The resolved type name
  /// - Throws: ContextError if type cannot be resolved
  public func resolveType(_ name: String) throws -> String {
    // If the name is already fully qualified, return it
    if name.hasPrefix(".") {
      return String(name.dropFirst())
    }

    // Check current message scope first
    for context in messageStack.reversed() {
      if let resolved = context.resolveType(name) {
        return resolved
      }
    }

    // Try to resolve in current package
    if let package = currentPackage {
      let fullName = "\(package).\(name)"
      if symbolTable.lookupType(fullName) != nil {
        return fullName
      }
    }

    // Try to resolve in symbol table
    if symbolTable.lookupType(name) != nil {
      return name
    }

    // Try to resolve in imported files
    if let resolved = try importResolver.resolveType(name) {
      return resolved
    }

    throw ContextError.unresolvableType(name)
  }

  /// Check if a field number is valid in the current context
  /// - Parameter number: The field number to check
  /// - Returns: True if the field number is valid
  public func isFieldNumberValid(_ number: Int) -> Bool {
    guard let current = currentMessage else { return true }
    return current.isFieldNumberValid(number)
  }

  /// Register a field number in the current context
  /// - Parameter number: The field number to register
  /// - Throws: ContextError if field number is invalid or already used
  public func registerFieldNumber(_ number: Int) throws {
    guard let current = currentMessage else { return }
    try current.registerFieldNumber(number)
  }

  /// Check if a field name is valid in the current context
  /// - Parameter name: The field name to check
  /// - Returns: True if the field name is valid
  public func isFieldNameValid(_ name: String) -> Bool {
    guard let current = currentMessage else { return true }
    return current.isFieldNameValid(name)
  }

  /// Register a field name in the current context
  /// - Parameter name: The field name to register
  /// - Throws: ContextError if field name is invalid or already used
  public func registerFieldName(_ name: String) throws {
    guard let current = currentMessage else { return }
    try current.registerFieldName(name)
  }
}

/// Context for a message scope
public final class MessageContext {
  /// The message node
  private let message: MessageNode

  /// Set of used field numbers
  private var usedFieldNumbers: Set<Int> = []

  /// Set of used field names
  private var usedFieldNames: Set<String> = []

  /// Set of reserved field numbers
  private var reservedNumbers: Set<Int> = []

  /// Set of reserved field names
  private var reservedNames: Set<String> = []

  /// Initialize a new message context
  /// - Parameter message: The message node
  init(message: MessageNode) {
    self.message = message

    // Collect reserved numbers and names
    for reserved in message.reserved {
      for range in reserved.ranges {
        switch range {
        case .single(let number):
          reservedNumbers.insert(number)
        case .range(let start, let end):
          reservedNumbers.formUnion(start...end)
        case .name(let name):
          reservedNames.insert(name)
        }
      }
    }
  }

  /// Resolve a type name in this message context
  /// - Parameter name: The type name to resolve
  /// - Returns: The resolved type name if found
  func resolveType(_ name: String) -> String? {
    // Check nested types
    if message.findNestedType(name) != nil {
      return "\(message.name).\(name)"
    }
    return nil
  }

  /// Check if a field number is valid
  /// - Parameter number: The field number to check
  /// - Returns: True if the field number is valid
  func isFieldNumberValid(_ number: Int) -> Bool {
    // Check if number is in valid range
    guard number > 0 && number < 536_870_911 else {
      return false
    }

    // Check if number is in reserved range
    guard !(19000...19999).contains(number) else {
      return false
    }

    // Check if number is reserved
    guard !reservedNumbers.contains(number) else {
      return false
    }

    // Check if number is already used
    return !usedFieldNumbers.contains(number)
  }

  /// Register a field number
  /// - Parameter number: The field number to register
  /// - Throws: ContextError if number is invalid or already used
  func registerFieldNumber(_ number: Int) throws {
    guard isFieldNumberValid(number) else {
      throw ContextError.invalidFieldNumber(number)
    }
    usedFieldNumbers.insert(number)
  }

  /// Check if a field name is valid
  /// - Parameter name: The field name to check
  /// - Returns: True if the field name is valid
  func isFieldNameValid(_ name: String) -> Bool {
    // Check if name is reserved
    guard !reservedNames.contains(name) else {
      return false
    }

    // Check if name is already used
    return !usedFieldNames.contains(name)
  }

  /// Register a field name
  /// - Parameter name: The field name to register
  /// - Throws: ContextError if name is invalid or already used
  func registerFieldName(_ name: String) throws {
    guard isFieldNameValid(name) else {
      throw ContextError.invalidFieldName(name)
    }
    usedFieldNames.insert(name)
  }
}

/// Errors that can occur in parsing context
public enum ContextError: Error, CustomStringConvertible {
  case circularImport(String)
  case unresolvableType(String)
  case invalidFieldNumber(Int)
  case invalidFieldName(String)
  case duplicateFieldNumber(Int)
  case duplicateFieldName(String)

  public var description: String {
    switch self {
    case .circularImport(let path):
      return "Circular import detected: \(path)"
    case .unresolvableType(let name):
      return "Unable to resolve type: \(name)"
    case .invalidFieldNumber(let number):
      return "Invalid field number: \(number)"
    case .invalidFieldName(let name):
      return "Invalid field name: \(name)"
    case .duplicateFieldNumber(let number):
      return "Duplicate field number: \(number)"
    case .duplicateFieldName(let name):
      return "Duplicate field name: \(name)"
    }
  }
}
