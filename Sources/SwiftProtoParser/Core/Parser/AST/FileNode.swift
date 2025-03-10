import Foundation

/// Represents a complete proto file.
public final class FileNode: Node, DefinitionContainer {
  /// The location in source where this file node begins.
  public let location: SourceLocation

  /// Comments that appear at the start of the file.
  public let leadingComments: [String]

  /// The syntax version specified in the file (e.g., "proto3").
  public let syntax: String

  /// The package name specified in the file.
  public let package: String?

  /// The path to the file.
  public let filePath: String?

  /// The list of import statements.
  public let imports: [ImportNode]

  /// The list of file-level options.
  public let options: [OptionNode]

  /// All top-level message definitions.
  public private(set) var messages: [MessageNode]

  /// All top-level enum definitions.
  public private(set) var enums: [EnumNode]

  /// All service definitions.
  public private(set) var services: [ServiceNode]

  /// All extend statements.
  public private(set) var extensions: [ExtendNode]

  /// Creates a new file node.
  /// - Parameters:.
  ///   - location: The source location where this file begins.
  ///   - leadingComments: Any comments at the start of the file.
  ///   - syntax: The syntax version specified.
  ///   - package: The optional package name.
  ///   - filePath: The path to the file.
  ///   - imports: List of import statements.
  ///   - options: List of file-level options.
  ///   - definitions: List of top-level definitions.
  ///   - extensions: List of extend statements.
  public init(
    location: SourceLocation = SourceLocation(line: 1, column: 1),
    leadingComments: [String] = [],
    syntax: String,
    package: String? = nil,
    filePath: String? = nil,
    imports: [ImportNode] = [],
    options: [OptionNode] = [],
    definitions: [DefinitionNode] = [],
    extensions: [ExtendNode] = []
  ) {
    self.location = location
    self.leadingComments = leadingComments
    self.syntax = syntax
    self.package = package
    self.filePath = filePath
    self.imports = imports
    self.options = options
    self.extensions = extensions

    // Sort definitions into their respective collections
    var messages: [MessageNode] = []
    var enums: [EnumNode] = []
    var services: [ServiceNode] = []

    for definition in definitions {
      switch definition {
      case let message as MessageNode:
        messages.append(message)
      case let enumDef as EnumNode:
        enums.append(enumDef)
      case let service as ServiceNode:
        services.append(service)
      default:
        // This shouldn't happen if the parser is working correctly
        fatalError("Unexpected definition type: \(type(of: definition))")
      }
    }

    self.messages = messages
    self.enums = enums
    self.services = services
  }

  /// The trailingComment for a file node is always nil as it represents a complete file.
  public var trailingComment: String? {
    return nil
  }

  // MARK: - Helper Methods

  /// Returns all types defined in this file, including nested types.
  public var allDefinedTypes: [DefinitionNode] {
    var types: [DefinitionNode] = []

    // Add top-level types
    types.append(contentsOf: messages as [DefinitionNode])
    types.append(contentsOf: enums as [DefinitionNode])

    // Add nested types recursively
    types.append(contentsOf: allNestedDefinitions)

    return types
  }

  /// Returns a map of fully qualified names to their definitions.
  public var typeMap: [String: DefinitionNode] {
    var map: [String: DefinitionNode] = [:]

    for type in allDefinedTypes {
      map[type.fullName(inPackage: package)] = type
    }

    return map
  }

  /// Returns all imported file paths.
  public var importedFiles: [String] {
    return imports.map { $0.path }
  }

  /// Returns all public imported file paths.
  public var publicImports: [String] {
    return
      imports
      .filter { $0.modifier == .public }
      .map { $0.path }
  }

  /// Returns all weak imported file paths.
  public var weakImports: [String] {
    return
      imports
      .filter { $0.modifier == .weak }
      .map { $0.path }
  }

  /// Checks if this file has a specific option.
  /// - Parameter name: The name of the option to check for.
  /// - Returns: The option's value if found, nil otherwise.
  public func hasOption(_ name: String) -> OptionNode.Value? {
    return options.first { $0.name == name }?.value
  }

  /// Returns a type definition by its fully qualified name.
  /// - Parameter name: The fully qualified name of the type.
  /// - Returns: The type definition if found, nil otherwise.
  public func findType(_ name: String) -> DefinitionNode? {
    return typeMap[name]
  }

  // MARK: - Validation

  /// Validates the file node according to proto3 rules.
  /// - Throws: ParserError if validation fails.
  public func validate() throws {
    // Validate syntax version
    guard syntax == "proto3" else {
      throw ParserError.invalidSyntaxVersion(syntax)
    }

    // Validate package name format if present
    if let package = package {
      let components = package.split(separator: ".")
      for component in components {
        guard component.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }),
          let first = component.first,
          first.isLetter || first == "_"
        else {
          throw ParserError.invalidPackageName(package)
        }
      }
    }

    // Collect extended type names to exclude from duplicate check
    var extendedTypeNames = Set<String>()
    for ext in extensions {
      // Get the fully qualified name of the extended type
      let extendedTypeName = ext.typeName
      if extendedTypeName.contains(".") {
        extendedTypeNames.insert(extendedTypeName)
      }
      else if let package = package, !package.isEmpty {
        extendedTypeNames.insert("\(package).\(extendedTypeName)")
      }
      else {
        extendedTypeNames.insert(extendedTypeName)
      }
    }

    // Validate type names are unique within their scope
    var seenTypes: Set<String> = []
    for type in allDefinedTypes {
      let fullName = type.fullName(inPackage: package)

      // Skip the check if this is an extended type
      if extendedTypeNames.contains(fullName) {
        continue
      }

      guard !seenTypes.contains(fullName) else {
        throw ParserError.duplicateTypeName(fullName)
      }
      seenTypes.insert(fullName)
    }

    // Validate all messages
    for msg in messages {
      try msg.validate()
    }

    // Validate all enums
    for e in enums {
      try e.validate()
    }

    // Validate all services
    for svc in services {
      try svc.validate()
    }

    // Validate all extensions
    for ext in extensions {
      try validateExtension(ext)
    }
  }

  /// Validates an extension.
  /// - Parameter extension: The extension to validate.
  /// - Throws: ParserError if validation fails.
  private func validateExtension(_ extension: ExtendNode) throws {
    // Validate that the extended type is a valid identifier
    let components = `extension`.typeName.split(separator: ".")
    for component in components {
      guard component.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }),
        let first = component.first,
        first.isLetter || first == "_"
      else {
        throw ParserError.custom("Invalid extended type name: \(`extension`.typeName)")
      }
    }

    // Validate that there is at least one field
    guard !`extension`.fields.isEmpty else {
      throw ParserError.custom(
        "Extension of \(`extension`.typeName) must contain at least one field"
      )
    }

    // Validate each field
    for field in `extension`.fields {
      try field.validate()
    }
  }
}
