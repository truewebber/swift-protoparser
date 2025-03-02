import Foundation

/// Implementation of field-level validation
class FieldValidator: FieldValidating {
  // Reference to the shared validation state
  private let state: ValidationState

  /// Initialize with a validation state
  /// - Parameter state: The validation state
  init(state: ValidationState) {
    self.state = state
  }

  /// Validate a field
  /// - Parameters:
  ///   - field: The field node to validate
  ///   - message: The message containing the field
  /// - Throws: ValidationError if validation fails
  func validateField(_ field: FieldNode, inMessage message: MessageNode) throws {
    // Validate field number
    try validateFieldNumber(field.number, location: field.location)

    // Validate name
    try validateFieldName(field.name, inMessage: message)

    // Validate type
    try validateFieldType(field.type, field: field)

    // Validate map fields
    if case .map(let keyType, _) = field.type {
      // Validate map key type
      try validateMapKeyType(keyType)

      // Map fields cannot be repeated
      if field.isRepeated {
        throw ValidationError.repeatedMapField(field.name)
      }

      // Map fields cannot be optional
      if field.isOptional {
        throw ValidationError.optionalMapField(field.name)
      }
    }

    // Validate Proto3 specific rules
    try validateProto3Rules(field)
  }

  /// Validate field number
  /// - Parameters:
  ///   - number: The field number
  ///   - location: The source location
  /// - Throws: ValidationError if the field number is invalid
  func validateFieldNumber(_ number: Int, location: SourceLocation) throws {
    // Check basic range
    guard number > 0 else {
      throw ValidationError.invalidFieldNumber(number, location: location)
    }

    guard number <= 536_870_911 else {
      throw ValidationError.invalidFieldNumber(number, location: location)
    }

    // Check reserved range
    if (19000...19999).contains(number) {
      throw ValidationError.invalidFieldNumber(number, location: location)
    }
  }

  /// Validate field name
  /// - Parameters:
  ///   - name: The field name
  ///   - message: The message containing the field
  /// - Throws: ValidationError if the field name is invalid
  func validateFieldName(_ name: String, inMessage message: MessageNode) throws {
    // Check name format
    guard isValidFieldName(name) else {
      throw ValidationError.invalidFieldName(name)
    }

    // Check for reserved names
    if message.reservedNames.contains(name) {
      throw ValidationError.reservedFieldName(name)
    }
  }

  /// Validate field type
  /// - Parameters:
  ///   - type: The field type
  ///   - field: The field node
  /// - Throws: ValidationError if the field type is invalid
  func validateFieldType(_ type: TypeNode, field: FieldNode) throws {
    switch type {
    case .scalar:
      return  // All scalar types are valid

    case .map(let keyType, let valueType):
      // Validate key type
      try validateMapKeyType(keyType)

      // Recursively validate value type
      try validateFieldType(valueType, field: field)

    case .named(_):
      // Named types would be validated during reference validation
      // This is a simplified implementation
      break
    }
  }

  /// Validate map key type
  /// - Parameter keyType: The map key type
  /// - Throws: ValidationError if the map key type is invalid
  func validateMapKeyType(_ keyType: TypeNode.ScalarType) throws {
    // Only certain scalar types can be used as map keys
    switch keyType {
    case .int32, .int64, .uint32, .uint64,
      .sint32, .sint64, .fixed32, .fixed64,
      .sfixed32, .sfixed64, .bool, .string:
      return  // These types are valid map keys
    case .double, .float, .bytes:
      throw ValidationError.invalidMapKeyType(String(describing: keyType))
    }
  }

  /// Validate oneof field
  /// - Parameters:
  ///   - oneof: The oneof node
  ///   - message: The message containing the oneof
  /// - Throws: ValidationError if the oneof is invalid
  func validateOneof(_ oneof: OneofNode, in message: MessageNode) throws {
    var fieldNames = Set<String>()
    var fieldNumbers = Set<Int>()

    for field in oneof.fields {
      if !fieldNames.insert(field.name).inserted {
        throw ValidationError.duplicateFieldName(field.name, inType: message.name)
      }

      if !fieldNumbers.insert(field.number).inserted {
        throw ValidationError.custom(
          "Duplicate field number \(field.number) in oneof '\(oneof.name)'")
      }

      // Oneof fields cannot be repeated
      if field.isRepeated {
        throw ValidationError.custom(
          "Field '\(field.name)' in oneof '\(oneof.name)' cannot be repeated")
      }
    }
  }

  // MARK: - Private Helper Methods

  /// Validate Proto3 specific rules for a field
  /// - Parameter field: The field to validate
  /// - Throws: ValidationError if validation fails
  private func validateProto3Rules(_ field: FieldNode) throws {
    // Handle scalar fields
    if case .scalar(let scalarType) = field.type {
      // Check packed option for repeated fields
      if field.isRepeated {
        let hasPacked = field.options.contains { option in
          option.name == "packed" && option.value == .identifier("true")
        }

        // Only numeric types and enums can be packed
        let packableTypes: [TypeNode.ScalarType] = [
          .int32, .int64, .uint32, .uint64,
          .sint32, .sint64, .fixed32, .fixed64,
          .sfixed32, .sfixed64, .float, .double,
          .bool,  // bool is packable too
        ]

        if hasPacked && !packableTypes.contains(scalarType) {
          throw ValidationError.unpackableFieldType(field.name, scalarType)
        }
      }
    }

    // Handle oneof fields
    if field.oneof != nil {
      // Oneof fields cannot be repeated
      if field.isRepeated {
        throw ValidationError.repeatedOneof(field.name)
      }

      // Oneof fields cannot be optional
      if field.isOptional {
        throw ValidationError.optionalOneof(field.name)
      }
    }
  }

  /// Check if a field name is valid
  /// - Parameter name: The field name to check
  /// - Returns: True if the field name is valid
  private func isValidFieldName(_ name: String) -> Bool {
    guard !name.isEmpty else { return false }

    // First character must be lowercase letter or underscore
    guard let first = name.first,
      first.isLowercase || first == "_"
    else {
      return false
    }

    // Remaining characters must be letters, digits, or underscores
    return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
  }
}
