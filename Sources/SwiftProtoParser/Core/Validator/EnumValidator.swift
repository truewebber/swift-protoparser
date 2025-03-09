import Foundation

/// Implementation of enum-level validation.
class EnumValidator: EnumValidating {
  // Reference to the shared validation state
  private let state: ValidationState

  /// Initialize with a validation state.
  /// - Parameter state: The validation state.
  init(state: ValidationState) {
    self.state = state
  }

  /// Validate enum semantics.
  /// - Parameter enumType: The enum node to validate.
  /// - Throws: ValidationError if validation fails.
  func validateEnumSemantics(_ enumType: EnumNode) throws {
    // Must have at least one value
    guard !enumType.values.isEmpty else {
      throw ValidationError.emptyEnum(enumType.name)
    }

    // Validate enum name format (CamelCase)
    guard isValidEnumName(enumType.name) else {
      throw ValidationError.invalidEnumName(enumType.name)
    }

    // First value must be zero in proto3
    guard let firstValue = enumType.values.first,
      firstValue.number == 0
    else {
      throw ValidationError.firstEnumValueNotZero(enumType.name)
    }

    // Check for duplicate values unless allow_alias is enabled
    let allowAlias = enumType.options.contains { option in
      option.name == "allow_alias" && option.value == .identifier("true")
    }

    var usedNumbers = Set<Int>()
    for value in enumType.values where !allowAlias && !usedNumbers.insert(value.number).inserted {
      throw ValidationError.duplicateEnumValue(value.name, value: value.number)
    }
  }

  /// Validate enum value semantics.
  /// - Parameter enumType: The enum node to validate.
  /// - Throws: ValidationError if validation fails.
  func validateEnumValueSemantics(_ enumType: EnumNode) throws {
    // Must have at least one value
    guard !enumType.values.isEmpty else {
      throw ValidationError.emptyEnum(enumType.name)
    }

    // First value must be zero in proto3
    guard let firstValue = enumType.values.first,
      firstValue.number == 0
    else {
      throw ValidationError.firstEnumValueNotZero(enumType.name)
    }

    var usedNames = Set<String>()

    for value in enumType.values {
      // Validate enum value name format
      guard isValidEnumValueName(value.name) else {
        throw ValidationError.invalidEnumValueName(value.name)
      }

      // Check for duplicate names
      if !usedNames.insert(value.name).inserted {
        throw ValidationError.duplicateEnumValue(value.name, value: value.number)
      }

      // In proto3, enum values must be non-negative
      if value.number < 0 {
        throw ValidationError.custom(
          "Enum value '\(value.name)' has negative number (\(value.number)). Proto3 only allows non-negative enum values"
        )
      }
    }
  }

  /// Validate enum values uniqueness.
  /// - Parameter enumType: The enum node to validate.
  /// - Throws: ValidationError if validation fails.
  func validateEnumValuesUniqueness(_ enumType: EnumNode) throws {
    var usedNames = Set<String>()
    var valueToNames: [Int: Set<String>] = [:]  // Track all names for each value number

    // Check if allow_alias is enabled
    let allowAlias = enumType.options.contains { option in
      option.name == "allow_alias" && option.value == .identifier("true")
    }

    for value in enumType.values {
      // Names must always be unique regardless of allow_alias
      if !usedNames.insert(value.name).inserted {
        throw ValidationError.custom(
          "Duplicate enum value name '\(value.name)' in enum '\(enumType.name)'"
        )
      }

      // Track all names associated with each number
      if valueToNames[value.number] == nil {
        valueToNames[value.number] = []
      }
      valueToNames[value.number]?.insert(value.name)

      // If allow_alias is false, no number can have multiple names
      if !allowAlias && valueToNames[value.number]?.count ?? 0 > 1 {
        let aliasedNames = valueToNames[value.number]?.joined(separator: ", ") ?? ""
        throw ValidationError.custom(
          "Enum value number \(value.number) has multiple names (\(aliasedNames)) "
            + "but allow_alias is not set in enum '\(enumType.name)'"
        )
      }
    }

    // Additional validation for allow_alias
    // In proto3, we allow aliases for all values when allow_alias is set
    // (Removing the restriction on value 0)
  }

  /// Validate an enum node.
  /// - Parameter enumType: The enum node to validate.
  /// - Throws: ValidationError if validation fails.
  func validateEnum(_ enumType: EnumNode) throws {
    // Must have at least one value
    guard !enumType.values.isEmpty else {
      throw ValidationError.emptyEnum(enumType.name)
    }

    // First value must be zero in proto3
    guard let firstValue = enumType.values.first,
      firstValue.number == 0
    else {
      throw ValidationError.firstEnumValueNotZero(enumType.name)
    }

    var usedNames = Set<String>()
    var usedNumbers = Set<Int>()

    // Track if allow_alias is enabled
    let allowAlias = enumType.options.contains { option in
      option.name == "allow_alias" && option.value == .identifier("true")
    }

    for value in enumType.values {
      // Check name uniqueness
      if !usedNames.insert(value.name).inserted {
        throw ValidationError.duplicateEnumValue(value.name, value: value.number)
      }

      // Check number uniqueness unless allow_alias is true
      if !allowAlias && !usedNumbers.insert(value.number).inserted {
        throw ValidationError.duplicateEnumValue(value.name, value: value.number)
      }
    }
  }

  // MARK: - Private Helper Methods

  /// Check if an enum value name is valid.
  /// - Parameter name: The enum value name to check.
  /// - Returns: True if the enum value name is valid.
  private func isValidEnumValueName(_ name: String) -> Bool {
    guard !name.isEmpty else { return false }

    // First character must be uppercase letter (not underscore)
    guard let first = name.first,
      first.isUppercase
    else {
      return false
    }

    // Enum values are typically in UPPERCASE_WITH_UNDERSCORES format
    return name.allSatisfy { $0.isUppercase || $0.isNumber || $0 == "_" }
  }

  /// Check if an enum name is valid.
  /// - Parameter name: The enum name to check.
  /// - Returns: True if the enum name is valid.
  private func isValidEnumName(_ name: String) -> Bool {
    guard !name.isEmpty else { return false }

    // First character must be uppercase letter (not underscore)
    guard let first = name.first,
      first.isUppercase
    else {
      return false
    }

    // Enum names are typically in CamelCase format
    // Letters, numbers, and underscores are allowed

    // Reject all-uppercase names with underscores (SCREAMING_SNAKE_CASE)
    if name.allSatisfy({ $0.isUppercase || $0.isNumber || $0 == "_" }) && name.contains("_") {
      return false
    }

    return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
  }
}
