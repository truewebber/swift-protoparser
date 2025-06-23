import Foundation

/// Represents a protobuf extend statement for custom options (proto3 only).
///
/// In proto3, extend statements are only allowed for extending Well-Known Types
/// like google.protobuf.FileOptions, google.protobuf.MessageOptions, etc.
/// for custom options.
public struct ExtendNode: Equatable {
  /// The type being extended (e.g., "google.protobuf.FileOptions").
  public let extendedType: String
  
  /// The custom option fields being added to the extended type.
  public let fields: [FieldNode]
  
  /// Extend-specific options.
  public let options: [OptionNode]
  
  /// Position in the source file for error reporting.
  public let position: Token.Position
  
  public init(
    extendedType: String,
    fields: [FieldNode] = [],
    options: [OptionNode] = [],
    position: Token.Position
  ) {
    self.extendedType = extendedType
    self.fields = fields
    self.options = options
    self.position = position
  }
  
  /// Returns all field numbers used in this extend statement.
  public var usedFieldNumbers: Set<Int32> {
    return Set(fields.map { $0.number })
  }
  
  /// Returns all field names used in this extend statement.
  public var usedFieldNames: Set<String> {
    return Set(fields.map { $0.name })
  }
  
  /// Returns the field with the given name, if it exists.
  public func field(named name: String) -> FieldNode? {
    return fields.first(where: { $0.name == name })
  }
  
  /// Returns the field with the given number, if it exists.
  public func field(withNumber number: Int32) -> FieldNode? {
    return fields.first(where: { $0.number == number })
  }
  
  /// Validates that the extended type is allowed in proto3.
  /// Only google.protobuf.* types are allowed for custom options.
  public var isValidProto3ExtendTarget: Bool {
    return extendedType.hasPrefix("google.protobuf.")
  }
  
  /// Returns the canonical name for the extended type.
  public var canonicalExtendedType: String {
    return extendedType
  }
}

// MARK: - CustomStringConvertible
extension ExtendNode: CustomStringConvertible {
  public var description: String {
    var lines: [String] = []
    
    lines.append("extend \(extendedType) {")
    
    // Add options
    for option in options {
      lines.append("  \(option.description)")
    }
    
    // Add fields
    for field in fields {
      lines.append("  \(field.description)")
    }
    
    lines.append("}")
    
    return lines.joined(separator: "\n")
  }
}
