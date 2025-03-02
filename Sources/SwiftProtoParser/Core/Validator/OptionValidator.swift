import Foundation

/// Implementation of option validation
class OptionValidator: OptionValidating {
  // Reference to the shared validation state
  private let state: ValidationState

  /// Initialize with a validation state
  /// - Parameter state: The validation state
  init(state: ValidationState) {
    self.state = state
  }

  /// Validate file options
  /// - Parameter options: The options to validate
  /// - Throws: ValidationError if validation fails
  func validateFileOptions(_ options: [OptionNode]) throws {
    var seenOptions = Set<String>()  // Track options to prevent duplicates

    for option in options {
      // Check for duplicate options
      if !seenOptions.insert(option.name).inserted {
        throw ValidationError.duplicateOption(option.name)
      }

      switch option.name {
      case "java_package":
        guard case .string = option.value else {
          throw ValidationError.invalidOptionValue("java_package must be a string")
        }

      case "java_outer_classname":
        guard case .string = option.value else {
          throw ValidationError.invalidOptionValue("java_outer_classname must be a string")
        }

      case "optimize_for":
        guard case .identifier(let value) = option.value,
          ["SPEED", "CODE_SIZE", "LITE_RUNTIME"].contains(value.uppercased())
        else {
          throw ValidationError.invalidOptionValue(
            "optimize_for must be SPEED, CODE_SIZE, or LITE_RUNTIME")
        }

      case "cc_enable_arenas":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("cc_enable_arenas must be a boolean")
        }

      default:
        if option.name.hasPrefix("(") {
          try validateCustomOption(option)
        } else {
          throw ValidationError.unknownOption(option.name)
        }
      }
    }
  }

  /// Validate message options
  /// - Parameter options: The options to validate
  /// - Throws: ValidationError if validation fails
  func validateMessageOptions(_ options: [OptionNode]) throws {
    var messageOptions = Set<String>()  // Track for duplicates

    for option in options {
      // Check for duplicate options
      if !messageOptions.insert(option.name).inserted {
        throw ValidationError.duplicateOption(option.name)
      }

      switch option.name {
      case "message_set_wire_format":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue(
            "message_set_wire_format must be a boolean")
        }

      case "no_standard_descriptor_accessor":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue(
            "no_standard_descriptor_accessor must be a boolean")
        }

      case "deprecated":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("deprecated must be a boolean")
        }

      default:
        if option.name.hasPrefix("(") {
          try validateCustomOption(option)
        } else {
          throw ValidationError.unknownOption(option.name)
        }
      }
    }
  }

  /// Validate field options
  /// - Parameter options: The options to validate
  /// - Throws: ValidationError if validation fails
  func validateFieldOptions(_ options: [OptionNode]) throws {
    var seenOptions = Set<String>()  // Track for duplicates

    for option in options {
      // Check for duplicate options
      if !seenOptions.insert(option.name).inserted {
        throw ValidationError.duplicateOption(option.name)
      }

      switch option.name {
      case "deprecated":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("deprecated must be a boolean")
        }

      case "packed":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("packed must be a boolean")
        }

      case "json_name":
        guard case .string = option.value else {
          throw ValidationError.invalidOptionValue("json_name must be a string")
        }

      case "ctype":
        guard case .identifier(let value) = option.value,
          ["STRING", "CORD", "STRING_PIECE"].contains(value.uppercased())
        else {
          throw ValidationError.invalidOptionValue("ctype must be STRING, CORD, or STRING_PIECE")
        }

      default:
        if option.name.hasPrefix("(") {
          try validateCustomOption(option)
        } else {
          throw ValidationError.unknownOption(option.name)
        }
      }
    }
  }

  /// Validate enum options
  /// - Parameter options: The options to validate
  /// - Throws: ValidationError if validation fails
  func validateEnumOptions(_ options: [OptionNode]) throws {
    var enumOptions = Set<String>()  // Track for duplicates

    for option in options {
      // Check for duplicate options
      if !enumOptions.insert(option.name).inserted {
        throw ValidationError.duplicateOption(option.name)
      }

      switch option.name {
      case "allow_alias":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("allow_alias must be a boolean")
        }

      case "deprecated":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("deprecated must be a boolean")
        }

      default:
        if option.name.hasPrefix("(") {
          try validateCustomOption(option)
        } else {
          throw ValidationError.unknownOption(option.name)
        }
      }
    }
  }

  /// Validate enum value options
  /// - Parameter options: The options to validate
  /// - Throws: ValidationError if validation fails
  func validateEnumValueOptions(_ options: [OptionNode]) throws {
    var enumValueOptions = Set<String>()  // Track for duplicates

    for option in options {
      // Check for duplicate options
      if !enumValueOptions.insert(option.name).inserted {
        throw ValidationError.duplicateOption(option.name)
      }

      switch option.name {
      case "deprecated":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("deprecated must be a boolean")
        }

      default:
        if option.name.hasPrefix("(") {
          try validateCustomOption(option)
        } else {
          throw ValidationError.unknownOption(option.name)
        }
      }
    }
  }

  /// Validate service options
  /// - Parameter options: The options to validate
  /// - Throws: ValidationError if validation fails
  func validateServiceOptions(_ options: [OptionNode]) throws {
    var serviceOptions = Set<String>()  // Track for duplicates

    for option in options {
      // Check for duplicate options
      if !serviceOptions.insert(option.name).inserted {
        throw ValidationError.duplicateOption(option.name)
      }

      switch option.name {
      case "deprecated":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("deprecated must be a boolean")
        }

      default:
        if option.name.hasPrefix("(") {
          try validateCustomOption(option)
        } else {
          throw ValidationError.unknownOption(option.name)
        }
      }
    }
  }

  /// Validate method options
  /// - Parameter options: The options to validate
  /// - Throws: ValidationError if validation fails
  func validateMethodOptions(_ options: [OptionNode]) throws {
    var methodOptions = Set<String>()  // Track for duplicates

    for option in options {
      // Check for duplicate options
      if !methodOptions.insert(option.name).inserted {
        throw ValidationError.duplicateOption(option.name)
      }

      switch option.name {
      case "deprecated":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("deprecated must be a boolean")
        }

      case "idempotency_level":
        guard case .identifier(let value) = option.value,
          ["IDEMPOTENCY_UNKNOWN", "NO_SIDE_EFFECTS", "IDEMPOTENT"].contains(value)
        else {
          throw ValidationError.invalidOptionValue(
            "idempotency_level must be IDEMPOTENCY_UNKNOWN, NO_SIDE_EFFECTS, or IDEMPOTENT"
          )
        }

      default:
        if option.name.hasPrefix("(") {
          try validateCustomOption(option)
        } else {
          throw ValidationError.unknownOption(option.name)
        }
      }
    }
  }

  // MARK: - Private Helper Methods

  /// Validate a custom option
  /// - Parameter option: The option to validate
  /// - Throws: ValidationError if validation fails
  private func validateCustomOption(_ option: OptionNode) throws {
    // Custom option format must be (foo.bar.baz)
    let name = option.name.dropFirst().dropLast()  // Remove ( )
    let components = name.split(separator: ".")

    // Must have at least one component
    guard !components.isEmpty else {
      throw ValidationError.invalidOptionName(option.name)
    }

    // Each component must be valid identifier
    for component in components {
      guard let first = component.first,
        first.isLetter || first == "_",
        component.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" })
      else {
        throw ValidationError.invalidOptionName(option.name)
      }
    }

    // This is a simplified implementation
    // In a real implementation, we would validate that the option is actually declared
  }
}
