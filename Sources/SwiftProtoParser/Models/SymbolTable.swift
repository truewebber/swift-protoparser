import Foundation

/// Represents a symbol in the proto file
public final class Symbol {
  /// Type of the symbol
  public enum Kind {
    case message
    case enumeration
    case service
    case field
    case enumValue
    case oneof
    case rpc
    case extensionField
  }

  /// The fully qualified name of the symbol
  public let fullName: String

  /// The kind of symbol
  public let kind: Kind

  /// The node associated with this symbol
  public let node: Node

  /// The package this symbol belongs to
  public let package: String?

  /// The parent symbol, if any (for nested types)
  public weak var parent: Symbol?

  /// Child symbols (for nested types)
  public private(set) var children: [Symbol] = []
  
  /// For extension symbols, this stores the field number
  public let fieldNumber: Int?
  
  /// For extension symbols, this stores the target type being extended
  public let extendedType: String?

  /// Initialize a new symbol
  /// - Parameters:
  ///   - fullName: Fully qualified name
  ///   - kind: Kind of symbol
  ///   - node: Associated node
  ///   - package: Package name
  ///   - parent: Parent symbol
  ///   - fieldNumber: Field number (for extensions)
  ///   - extendedType: Type being extended (for extensions)
  public init(
    fullName: String,
    kind: Kind,
    node: Node,
    package: String?,
    parent: Symbol? = nil,
    fieldNumber: Int? = nil,
    extendedType: String? = nil
  ) {
    self.fullName = fullName
    self.kind = kind
    self.node = node
    self.package = package
    self.parent = parent
    self.fieldNumber = fieldNumber
    self.extendedType = extendedType
  }

  /// Add a child symbol
  /// - Parameter child: The child symbol to add
  func addChild(_ child: Symbol) {
    children.append(child)
  }
}

/// Manages symbol resolution and tracking
public final class SymbolTable {
  /// Map of fully qualified names to symbols
  private var symbols: [String: Symbol] = [:]

  /// Map of package names to symbols in that package
  private var packageSymbols: [String: Set<Symbol>] = [:]
  
  /// Map of extended types to their extensions
  private var extensions: [String: [Symbol]] = [:]

  /// Initialize a new symbol table
  public init() {}

  /// Add a symbol to the table
  /// - Parameters:
  ///   - node: The node to add
  ///   - kind: The kind of symbol
  ///   - package: The package name
  ///   - parent: The parent symbol, if any
  /// - Throws: SymbolTableError if symbol already exists
  public func addSymbol(
    _ node: Node,
    kind: Symbol.Kind,
    package: String?,
    parent: Symbol? = nil
  ) throws {
    let name = parent.map { "\($0.fullName).\(getName(for: node))" } ?? getName(for: node)
    let fullName = package.map { "\($0).\(name)" } ?? name

    guard symbols[fullName] == nil else {
      throw SymbolTableError.duplicateSymbol(fullName)
    }

    let symbol = Symbol(
      fullName: fullName,
      kind: kind,
      node: node,
      package: package,
      parent: parent
    )

    // Add to parent's children if nested
    if let parent = parent {
      parent.addChild(symbol)
    }

    symbols[fullName] = symbol

    // Add to package symbols
    if let package = package {
      var packageSet = packageSymbols[package, default: Set()]
      packageSet.insert(symbol)
      packageSymbols[package] = packageSet
    }
  }
  
  /// Add an extension field to the table
  /// - Parameters:
  ///   - field: The field node
  ///   - extendedType: The type being extended
  ///   - package: The package name
  ///   - parent: The parent symbol, if any
  /// - Throws: SymbolTableError if extension already exists
  public func addExtension(
    _ field: FieldNode,
    extendedType: String,
    package: String?,
    parent: Symbol? = nil
  ) throws {
    let name = field.name
    let fullName = package.map { "\($0).\(name)" } ?? name
    
    guard symbols[fullName] == nil else {
      throw SymbolTableError.duplicateSymbol(fullName)
    }
    
    // Create a symbol for the extension
    let symbol = Symbol(
      fullName: fullName,
      kind: .extensionField,
      node: field,
      package: package,
      parent: parent,
      fieldNumber: field.number,
      extendedType: extendedType
    )
    
    // Add to symbols
    symbols[fullName] = symbol
    
    // Add to extensions map
    var extensionList = extensions[extendedType, default: []]
    extensionList.append(symbol)
    extensions[extendedType] = extensionList
    
    // Add to package symbols
    if let package = package {
      var packageSet = packageSymbols[package, default: Set()]
      packageSet.insert(symbol)
      packageSymbols[package] = packageSet
    }
  }
  
  /// Look up extensions for a specific type
  /// - Parameter typeName: The fully qualified name of the type
  /// - Returns: Array of extension symbols
  public func lookupExtensions(for typeName: String) -> [Symbol] {
    return extensions[typeName] ?? []
  }
  
  /// Resolve an option extension name to its field type
  /// - Parameter extensionName: The fully qualified name of the extension
  /// - Returns: The field type if found
  public func resolveOptionType(for extensionName: String) -> TypeNode? {
    guard let symbol = symbols[extensionName], symbol.kind == .extensionField else {
      return nil
    }
    
    // Cast to FieldNode to get the type
    if let fieldNode = symbol.node as? FieldNode {
      return fieldNode.type
    }
    
    return nil
  }
  
  /// Check if a name is an extension field
  /// - Parameter name: The name to check
  /// - Returns: True if the name is an extension field
  public func isExtension(_ name: String) -> Bool {
    guard let symbol = symbols[name] else { return false }
    return symbol.kind == .extensionField
  }

  /// Look up a symbol by its fully qualified name
  /// - Parameter name: The name to look up
  /// - Returns: The symbol if found
  public func lookup(_ name: String) -> Symbol? {
    return symbols[name]
  }

  /// Look up a type by its fully qualified name
  /// - Parameter name: The name to look up
  /// - Returns: The symbol if found and it's a type (message or enum)
  public func lookupType(_ name: String) -> Symbol? {
    guard let symbol = symbols[name] else { return nil }
    switch symbol.kind {
    case .message, .enumeration:
      return symbol
    default:
      return nil
    }
  }

  /// Look up symbols in a package
  /// - Parameter package: The package name
  /// - Returns: Set of symbols in the package
  public func lookupPackage(_ package: String) -> Set<Symbol> {
    return packageSymbols[package] ?? []
  }

  /// Check if a name is already used in the current scope
  /// - Parameters:
  ///   - name: The name to check
  ///   - parent: The parent symbol for nested scope
  /// - Returns: True if the name is already used
  public func isNameUsed(_ name: String, parent: Symbol?) -> Bool {
    if let parent = parent {
      let fullName = "\(parent.fullName).\(name)"
      return symbols[fullName] != nil
    } else {
      return symbols[name] != nil
    }
  }

  /// Get all symbols of a specific kind
  /// - Parameter kind: The kind of symbols to get
  /// - Returns: Array of matching symbols
  public func getSymbols(ofKind kind: Symbol.Kind) -> [Symbol] {
    return symbols.values.filter { $0.kind == kind }
  }

  /// Clear all symbols
  public func clear() {
    symbols.removeAll()
    packageSymbols.removeAll()
    extensions.removeAll()
  }

  // MARK: - Private Helper Methods

  private func getName(for node: Node) -> String {
    switch node {
    case let node as MessageNode:
      return node.name
    case let node as EnumNode:
      return node.name
    case let node as ServiceNode:
      return node.name
    case let node as FieldNode:
      return node.name
    case let node as EnumValueNode:
      return node.name
    case let node as OneofNode:
      return node.name
    case let node as RPCNode:
      return node.name
    default:
      fatalError("Unexpected node type: \(type(of: node))")
    }
  }
}

/// Errors that can occur in symbol table operations
public enum SymbolTableError: Error, CustomStringConvertible {
  case duplicateSymbol(String)
  case invalidSymbolName(String)
  case undefinedSymbol(String)
  case invalidExtension(String)
  case invalidOptionType(String)

  public var description: String {
    switch self {
    case .duplicateSymbol(let name):
      return "Duplicate symbol: \(name)"
    case .invalidSymbolName(let name):
      return "Invalid symbol name: \(name)"
    case .undefinedSymbol(let name):
      return "Undefined symbol: \(name)"
    case .invalidExtension(let name):
      return "Invalid extension: \(name)"
    case .invalidOptionType(let name):
      return "Invalid option type: \(name)"
    }
  }
}

// MARK: - Symbol Equatable & Hashable

extension Symbol: Equatable {
  public static func == (lhs: Symbol, rhs: Symbol) -> Bool {
    return lhs.fullName == rhs.fullName
  }
}

extension Symbol: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(fullName)
  }
}
