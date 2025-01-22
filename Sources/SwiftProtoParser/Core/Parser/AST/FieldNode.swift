import Foundation

/// Represents a field in a message or oneof
public final class FieldNode: Node {
  /// Source location of this field
  public let location: SourceLocation

  /// Comments that appear before this field
  public let leadingComments: [String]

  /// Comment that appears after the field definition
  public let trailingComment: String?

  /// Name of the field
  public let name: String

  /// Type of the field
  public let type: TypeNode

  /// Field number
  public let number: Int

  /// Whether the field is repeated
  public let isRepeated: Bool

  /// Whether the field is optional (proto3 field presence)
  public let isOptional: Bool

  /// The oneof this field belongs to, if any
  public private(set) weak var oneof: OneofNode?

  /// Options applied to this field
  public let options: [OptionNode]

  /// JSON name for this field (can be explicitly set via option)
  public let jsonName: String?

  public init(
    location: SourceLocation,
    leadingComments: [String] = [],
    trailingComment: String? = nil,
    name: String,
    type: TypeNode,
    number: Int,
    isRepeated: Bool = false,
    isOptional: Bool = false,
    oneof: OneofNode? = nil,
    options: [OptionNode] = [],
    jsonName: String? = nil
  ) {
    self.location = location
    self.leadingComments = leadingComments
    self.trailingComment = trailingComment
    self.name = name
    self.type = type
    self.number = number
    self.isRepeated = isRepeated
    self.isOptional = isOptional
    self.oneof = oneof
    self.options = options
    self.jsonName = jsonName
  }

  // MARK: - Field Validation

  /// Validates the field according to proto3 rules
  /// - Throws: ParserError if validation fails
  public func validate() throws {
    // Validate field name
    guard isValidFieldName(name) else {
      throw ParserError.invalidFieldName(name)
    }

    // Validate field number
    try validateFieldNumber(number)

    // Validate field type
    try validateFieldType()

    // Validate field options
    try validateFieldOptions()

    // Validate proto3 specific rules
    try validateProto3Rules()
  }

  private func validateFieldNumber(_ number: Int) throws {
    // Field numbers must be positive
    guard number > 0 else {
      throw ParserError.invalidFieldNumber(number, location: location)
    }

    // Field numbers cannot be greater than max allowed
    guard number <= 536_870_911 else {
      throw ParserError.invalidFieldNumber(number, location: location)
    }

    // Check reserved ranges
    if (19000...19999).contains(number) {
      throw ParserError.reservedFieldNumber(number)
    }
  }

  private func validateFieldType() throws {
    switch type {
    case .map(let keyType, _):
      // Validate map key type
      guard keyType.canBeMapKey else {
        throw ParserError.invalidMapKeyType(String(describing: keyType))
      }
      // Maps cannot be repeated
      guard !isRepeated else {
        throw ParserError.repeatedMapField(name)
      }

    case .scalar:
      // All scalar types are valid
      break

    case .named(let typeName):
      // Validate type name format
      guard isValidTypeName(typeName) else {
        throw ParserError.invalidTypeName(typeName)
      }
    }
  }

  private func validateFieldOptions() throws {
    for option in options {
      switch option.name {
      case "deprecated":
        switch option.value {
        case .identifier(let value) where value == "true" || value == "false":
          break  // Valid boolean value
        default:
          throw ParserError.invalidFieldOption(option.name, "must be a boolean")
        }

      case "packed":
        switch option.value {
        case .identifier(let value) where value == "true" || value == "false":
          break  // Valid boolean value
        default:
          throw ParserError.invalidFieldOption(option.name, "must be a boolean")
        }

        // packed can only be specified for repeated scalar fields
        if case .scalar = type {
          guard isRepeated else {
            throw ParserError.invalidFieldOption(
              option.name, "can only be specified for repeated scalar fields")
          }
        } else {
          throw ParserError.invalidFieldOption(
            option.name, "can only be specified for scalar types")
        }

      case "json_name":
        guard case .string = option.value else {
          throw ParserError.invalidFieldOption(option.name, "must be a string")
        }

      default:
        // Custom options are allowed without specific validation
        break
      }
    }
  }

  private func validateProto3Rules() throws {
    // In proto3, fields cannot be required
    if options.first(where: { $0.name == "required" }) != nil {
      throw ParserError.invalidFieldOption("required", "proto3 fields cannot be required")
    }

    // In proto3, fields can be optional only with explicit 'optional' keyword
    if options.first(where: { $0.name == "optional" }) != nil {
      guard isOptional else {
        throw ParserError.invalidFieldOption("optional", "use 'optional' keyword instead of option")
      }
    }
  }
}

/// Represents a oneof definition in a message
public final class OneofNode: Node {
  /// Source location of this oneof
  public let location: SourceLocation

  /// Comments that appear before this oneof
  public let leadingComments: [String]

  /// Comment that appears after the oneof name
  public let trailingComment: String?

  /// Name of the oneof
  public let name: String

  /// Fields in this oneof
  public private(set) var fields: [FieldNode]

  /// Options applied to this oneof
  public let options: [OptionNode]

  public init(
    location: SourceLocation,
    leadingComments: [String] = [],
    trailingComment: String? = nil,
    name: String,
    fields: [FieldNode] = [],
    options: [OptionNode] = []
  ) {
    self.location = location
    self.leadingComments = leadingComments
    self.trailingComment = trailingComment
    self.name = name
    self.fields = fields
    self.options = options
  }

  // MARK: - Oneof Validation

  /// Validates the oneof according to proto3 rules
  /// - Throws: ParserError if validation fails
  public func validate() throws {
    // Validate oneof name
    guard isValidOneofName(name) else {
      throw ParserError.invalidOneofName(name)
    }

    // Oneof must have at least one field
    guard !fields.isEmpty else {
      throw ParserError.emptyOneof(name)
    }

    // Validate all fields
    var seenNames = Set<String>()
    var seenNumbers = Set<Int>()

    for field in fields {
      // Check for duplicate names
      guard !seenNames.contains(field.name) else {
        throw ParserError.duplicateFieldName(field.name)
      }
      seenNames.insert(field.name)

      // Check for duplicate numbers
      guard !seenNumbers.contains(field.number) else {
        throw ParserError.duplicateFieldNumber(field.number)
      }
      seenNumbers.insert(field.number)

      // Fields in oneof cannot be repeated
      guard !field.isRepeated else {
        throw ParserError.repeatedOneofField(field.name)
      }

      // Fields in oneof cannot be optional
      guard !field.isOptional else {
        throw ParserError.optionalOneofField(field.name)
      }

      try field.validate()
    }
  }
}

// MARK: - Additional Error Types

extension ParserError {
  static func invalidTypeName(_ name: String) -> ParserError {
    return .custom("Invalid type name: '\(name)'")
  }

  static func invalidOneofName(_ name: String) -> ParserError {
    return .custom("Invalid oneof name: '\(name)'")
  }

  static func invalidFieldOption(_ option: String, _ reason: String) -> ParserError {
    return .custom("Invalid service option '\(option)': \(reason)")
  }

  static func emptyOneof(_ name: String) -> ParserError {
    return .custom("Oneof '\(name)' must have at least one field")
  }

  static func repeatedOneofField(_ name: String) -> ParserError {
    return .custom("Field '\(name)' cannot be repeated in oneof")
  }

  static func optionalOneofField(_ name: String) -> ParserError {
    return .custom("Field '\(name)' cannot be optional in oneof")
  }

  static func duplicateFieldNumber(_ number: Int) -> ParserError {
    return .custom("Duplicate field number: \(number)")
  }

  static func duplicateFieldName(_ name: String) -> ParserError {
    return .custom("Duplicate field name: '\(name)'")
  }
}

// MARK: - Helper Functions

private func isValidFieldName(_ name: String) -> Bool {
  guard let first = name.first else { return false }
  return (first.isLowercase || first == "_")
    && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
}

private func isValidOneofName(_ name: String) -> Bool {
  guard let first = name.first else { return false }
  return (first.isLowercase || first == "_")
    && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
}

private func isValidTypeName(_ name: String) -> Bool {
  let components = name.split(separator: ".")
  guard !components.isEmpty else { return false }
  return components.allSatisfy { component in
    guard let first = component.first else { return false }
    return first.isUppercase && component.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
  }
}
