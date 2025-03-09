import Foundation

/// Represents an extend statement in a proto file.
public final class ExtendNode: Node, DefinitionContainer {
  /// The source location of this node.
  public let location: SourceLocation

  /// Comments that appear before this node.
  public let leadingComments: [String]

  /// Comment that appears on the same line after this node.
  public let trailingComment: String?

  /// The name of the type being extended.
  public let typeName: String

  /// The fields being added to the extended type.
  public let fields: [FieldNode]

  /// Whether this extension is defined at the top level of a file.
  public private(set) var isTopLevel: Bool = true

  /// The parent message if this extension is nested within a message.
  public private(set) weak var parentMessage: MessageNode?

  /// Nested message definitions (required for DefinitionContainer).
  public let messages: [MessageNode] = []

  /// Nested enum definitions (required for DefinitionContainer).
  public let enums: [EnumNode] = []

  /// Creates a new extend node.
  /// - Parameters:.
  ///   - location: The source location of the extend statement
  ///   - leadingComments: Any comments that appear before the extend statement
  ///   - trailingComment: Any comment that appears after the extend statement on the same line.
  ///   - typeName: The name of the type being extended.
  ///   - fields: The fields being added to the extended type.
  ///   - isTopLevel: Whether this extension is defined at the top level of a file.
  ///   - parentMessage: The parent message if this extension is nested within a message.
  public init(
    location: SourceLocation,
    leadingComments: [String] = [],
    trailingComment: String? = nil,
    typeName: String,
    fields: [FieldNode],
    isTopLevel: Bool = true,
    parentMessage: MessageNode? = nil
  ) {
    self.location = location
    self.leadingComments = leadingComments
    self.trailingComment = trailingComment
    self.typeName = typeName
    self.fields = fields
    self.isTopLevel = isTopLevel
    self.parentMessage = parentMessage
  }

  /// Sets the parent message for this extension.
  /// - Parameter message: The parent message.
  public func setParentMessage(_ message: MessageNode) {
    parentMessage = message
    isTopLevel = false
  }

  /// Validates the extension according to proto3 rules.
  /// - Throws: ValidationError if validation fails.
  public func validate() throws {
    // Validate that the extended type is a valid identifier
    guard isValidTypeName(typeName) else {
      throw ValidationError.custom("Invalid extended type name: \(typeName)")
    }

    // Validate that there is at least one field
    guard !fields.isEmpty else {
      throw ValidationError.custom("Extension of \(typeName) must contain at least one field")
    }

    // Validate each field
    for field in fields {
      try field.validate()
    }
  }

  /// Checks if a type name is valid.
  /// - Parameter name: The type name to check.
  /// - Returns: Whether the name is valid.
  private func isValidTypeName(_ name: String) -> Bool {
    let components = name.split(separator: ".")
    guard !components.isEmpty else { return false }

    for component in components {
      guard !component.isEmpty else { return false }
      guard component.first!.isLetter || component.first! == "_" else { return false }
      guard component.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else { return false }
    }

    return true
  }

  /// Returns the fully qualified name of the extended type.
  /// - Parameter packageName: The package name to prepend.
  /// - Returns: The fully qualified name.
  public func fullExtendedName(inPackage packageName: String?) -> String {
    // If the type name already starts with a dot, it's already fully qualified
    if typeName.hasPrefix(".") {
      return typeName
    }

    // If the type name contains dots but doesn't start with one, it might be relative to the current package
    if typeName.contains(".") {
      if let packageName = packageName, !packageName.isEmpty {
        return ".\(packageName).\(typeName)"
      }
      else {
        return ".\(typeName)"
      }
    }

    // If we have a parent message, the type is relative to that message
    if let parentMessage = parentMessage {
      let parentFullName = parentMessage.fullName(inPackage: packageName)
      return "\(parentFullName).\(typeName)"
    }

    // Otherwise, it's relative to the current package
    if let packageName = packageName, !packageName.isEmpty {
      return ".\(packageName).\(typeName)"
    }
    else {
      return ".\(typeName)"
    }
  }
}

// MARK: - CustomStringConvertible

extension ExtendNode: CustomStringConvertible {
  public var description: String {
    return "ExtendNode(typeName: \(typeName), fields: \(fields))"
  }
}
