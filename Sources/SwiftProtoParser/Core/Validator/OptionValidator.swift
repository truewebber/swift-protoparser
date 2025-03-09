import Foundation

/// Implementation of option validation.
class OptionValidator: OptionValidating {
  // Reference to the shared validation state
  private let state: ValidationState

  /// Initialize with a validation state.
  /// - Parameter state: The validation state.
  init(state: ValidationState) {
    self.state = state
  }

  /// Validate file options.
  /// - Parameter options: The options to validate.
  /// - Throws: ValidationError if validation fails.
  func validateFileOptions(_ options: [OptionNode]) throws {
    var seenOptions = Set<String>()  // Track options to prevent duplicates

    for option in options {
      // Check for duplicate options
      if !seenOptions.insert(option.name).inserted {
        throw ValidationError.duplicateOption(option.name)
      }

      // If it's a custom option, validate it but don't throw an error for unknown options
      if option.isCustomOption {
        try validateCustomOption(option, symbolTable: state.symbolTable)
        continue
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
            "optimize_for must be SPEED, CODE_SIZE, or LITE_RUNTIME"
          )
        }

      case "cc_enable_arenas":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("cc_enable_arenas must be a boolean")
        }

      default:
        throw ValidationError.unknownOption(option.name)
      }
    }
  }

  /// Validate message options.
  /// - Parameter options: The options to validate.
  /// - Throws: ValidationError if validation fails.
  func validateMessageOptions(_ options: [OptionNode]) throws {
    var seenOptions = Set<String>()  // Track options to prevent duplicates

    for option in options {
      // Check for duplicate options
      if !seenOptions.insert(option.name).inserted {
        throw ValidationError.duplicateOption(option.name)
      }

      // If it's a custom option, validate it but don't throw an error for unknown options
      if option.isCustomOption {
        try validateCustomOption(option, symbolTable: state.symbolTable)
        continue
      }

      switch option.name {
      case "deprecated":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("deprecated must be a boolean")
        }

      case "map_entry":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("map_entry must be a boolean")
        }

      default:
        throw ValidationError.unknownOption(option.name)
      }
    }
  }

  /// Validate field options.
  /// - Parameter options: The options to validate.
  /// - Throws: ValidationError if validation fails.
  func validateFieldOptions(_ options: [OptionNode]) throws {
    var seenOptions = Set<String>()  // Track options to prevent duplicates

    for option in options {
      // Check for duplicate options
      if !seenOptions.insert(option.name).inserted {
        throw ValidationError.duplicateOption(option.name)
      }

      // If it's a custom option, validate it but don't throw an error for unknown options
      if option.isCustomOption {
        try validateCustomOption(option, symbolTable: state.symbolTable)
        continue
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

      default:
        throw ValidationError.unknownOption(option.name)
      }
    }
  }

  /// Validate enum options.
  /// - Parameter options: The options to validate.
  /// - Throws: ValidationError if validation fails.
  func validateEnumOptions(_ options: [OptionNode]) throws {
    var seenOptions = Set<String>()  // Track options to prevent duplicates

    for option in options {
      // Check for duplicate options
      if !seenOptions.insert(option.name).inserted {
        throw ValidationError.duplicateOption(option.name)
      }

      // If it's a custom option, validate it but don't throw an error for unknown options
      if option.isCustomOption {
        try validateCustomOption(option, symbolTable: state.symbolTable)
        continue
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
        throw ValidationError.unknownOption(option.name)
      }
    }
  }

  /// Validate enum value options.
  /// - Parameter options: The options to validate.
  /// - Throws: ValidationError if validation fails.
  func validateEnumValueOptions(_ options: [OptionNode]) throws {
    var seenOptions = Set<String>()  // Track options to prevent duplicates

    for option in options {
      // Check for duplicate options
      if !seenOptions.insert(option.name).inserted {
        throw ValidationError.duplicateOption(option.name)
      }

      // If it's a custom option, validate it but don't throw an error for unknown options
      if option.isCustomOption {
        try validateCustomOption(option, symbolTable: state.symbolTable)
        continue
      }

      switch option.name {
      case "deprecated":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("deprecated must be a boolean")
        }

      default:
        throw ValidationError.unknownOption(option.name)
      }
    }
  }

  /// Validate service options.
  /// - Parameter options: The options to validate.
  /// - Throws: ValidationError if validation fails.
  func validateServiceOptions(_ options: [OptionNode]) throws {
    var seenOptions = Set<String>()  // Track options to prevent duplicates

    for option in options {
      // Check for duplicate options
      if !seenOptions.insert(option.name).inserted {
        throw ValidationError.duplicateOption(option.name)
      }

      // If it's a custom option, validate it but don't throw an error for unknown options
      if option.isCustomOption {
        try validateCustomOption(option, symbolTable: state.symbolTable)
        continue
      }

      switch option.name {
      case "deprecated":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("deprecated must be a boolean")
        }

      default:
        throw ValidationError.unknownOption(option.name)
      }
    }
  }

  /// Validate method options.
  /// - Parameter options: The options to validate.
  /// - Throws: ValidationError if validation fails.
  func validateMethodOptions(_ options: [OptionNode]) throws {
    var seenOptions = Set<String>()  // Track options to prevent duplicates

    for option in options {
      // Check for duplicate options
      if !seenOptions.insert(option.name).inserted {
        throw ValidationError.duplicateOption(option.name)
      }

      // If it's a custom option, validate it but don't throw an error for unknown options
      if option.isCustomOption {
        try validateCustomOption(option, symbolTable: state.symbolTable)
        continue
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
          ["IDEMPOTENCY_UNKNOWN", "NO_SIDE_EFFECTS", "IDEMPOTENT"].contains(value.uppercased())
        else {
          throw ValidationError.invalidOptionValue(
            "idempotency_level must be IDEMPOTENCY_UNKNOWN, NO_SIDE_EFFECTS, or IDEMPOTENT"
          )
        }

      default:
        throw ValidationError.unknownOption(option.name)
      }
    }
  }

  // MARK: - Private Helper Methods

  /// Validate a custom option.
  /// - Parameters:.
  ///   - option: The option to validate.
  ///   - symbolTable: The symbol table for type resolution.
  /// - Throws: ValidationError if validation fails.
  func validateCustomOption(_ option: OptionNode, symbolTable: SymbolTable?) throws {
    // Basic syntax validation
    try validateCustomOptionSyntax(option)

    // If we don't have a symbol table, we can't validate the option type
    guard let symbolTable = symbolTable else {
      return
    }

    // Validate that the extension exists in the symbol table
    if option.isCustomOption && !option.pathParts.isEmpty {
      let extensionName = option.pathParts[0].name

      // Check if the extension exists
      if !symbolTable.isExtension(extensionName) {
        throw ValidationError.unknownOption("(\(extensionName))")
      }

      // Validate the option value type against the extension field type
      if let fieldType = symbolTable.resolveOptionType(for: extensionName) {
        try validateOptionValueType(
          option.value,
          expectedType: fieldType,
          optionName: extensionName
        )
      }

      // If there are nested fields, validate them
      if option.pathParts.count > 1 {
        try validateNestedOptionFields(
          option.pathParts.dropFirst(),
          extensionName: extensionName,
          symbolTable: symbolTable
        )
      }
    }
  }

  /// Validate nested option fields.
  /// - Parameters:.
  ///   - pathParts: The nested field path parts.
  ///   - extensionName: The name of the extension.
  ///   - symbolTable: The symbol table for type resolution.
  /// - Throws: ValidationError if validation fails.
  private func validateNestedOptionFields(
    _ pathParts: ArraySlice<OptionNode.PathPart>,
    extensionName: String,
    symbolTable: SymbolTable
  ) throws {
    // Get the extension field type
    guard let fieldType = symbolTable.resolveOptionType(for: extensionName) else {
      return
    }

    // For nested fields, the extension field must be a message type
    guard case .named(let typeName) = fieldType else {
      throw ValidationError.invalidOptionValue(
        "Extension field \(extensionName) must be a message type to have nested fields"
      )
    }

    // Validate that each nested field exists in the message type
    var currentType = typeName

    for pathPart in pathParts {
      // If this part is an extension, it must extend the current type
      if pathPart.isExtension {
        if !symbolTable.hasExtension(for: currentType, named: pathPart.name) {
          throw ValidationError.unknownOption("(\(pathPart.name)) for type \(currentType)")
        }

        // Update current type to the extension field type
        if let nextType = symbolTable.resolveOptionType(for: pathPart.name) {
          if case .named(let name) = nextType {
            currentType = name
          }
          else {
            throw ValidationError.invalidOptionValue(
              "Extension field \(pathPart.name) must be a message type to have nested fields"
            )
          }
        }
      }
      else {
        // Regular field - should be a field of the current message type
        if !symbolTable.hasField(in: currentType, named: pathPart.name) {
          throw ValidationError.unknownOption("\(pathPart.name) in type \(currentType)")
        }

        // Update current type to the field type
        if let nextType = symbolTable.resolveFieldType(in: currentType, named: pathPart.name) {
          if case .named(let name) = nextType {
            currentType = name
          }
          else {
            // If this is the last part, it can be a scalar type
            if pathPart == pathParts.last {
              // No need to update currentType
            }
            else {
              throw ValidationError.invalidOptionValue(
                "Field \(pathPart.name) must be a message type to have nested fields"
              )
            }
          }
        }
      }
    }
  }

  /// Validate that an option value matches the expected type.
  /// - Parameters:.
  ///   - value: The option value.
  ///   - expectedType: The expected type.
  ///   - optionName: The name of the option for error messages.
  /// - Throws: ValidationError if the value doesn't match the expected type.
  internal func validateOptionValueType(
    _ value: OptionNode.Value,
    expectedType: TypeNode,
    optionName: String
  ) throws {
    switch expectedType {
    case .scalar(let scalarType):
      switch scalarType {
      case .string, .bytes:
        guard case .string = value else {
          throw ValidationError.invalidOptionValue("Option (\(optionName)) must be a string")
        }

      case .int32, .int64, .uint32, .uint64, .sint32, .sint64, .fixed32, .fixed64, .sfixed32,
        .sfixed64, .float, .double:
        guard case .number = value else {
          throw ValidationError.invalidOptionValue("Option (\(optionName)) must be a number")
        }

      case .bool:
        guard case .identifier(let id) = value, id == "true" || id == "false" else {
          throw ValidationError.invalidOptionValue(
            "Option (\(optionName)) must be a boolean (true or false)"
          )
        }
      }

    case .named(let typeName):
      // For enum types, the value should be an identifier
      if typeName.contains("Enum") || typeName.contains("ENUM") {
        guard case .identifier = value else {
          throw ValidationError.invalidOptionValue("Option (\(optionName)) must be an enum value")
        }
      }

    case .map:
      throw ValidationError.invalidOptionValue("Map types are not supported for options")
    }
  }

  /// Validate the syntax of a custom option.
  /// - Parameter option: The option to validate.
  /// - Throws: ValidationError if validation fails.
  private func validateCustomOptionSyntax(_ option: OptionNode) throws {
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
