import Foundation

/// Implementation of semantic validation
class SemanticValidator: SemanticValidating {
  // Reference to the shared validation state
  private let state: ValidationState

  /// Initialize with a validation state
  /// - Parameter state: The validation state
  init(state: ValidationState) {
    self.state = state
  }

  /// Validate semantic rules for a file
  /// - Parameter file: The file node
  /// - Throws: ValidationError if validation fails
  func validateSemanticRules(_ file: FileNode) throws {
    // Validate syntax version
    if file.syntax != "proto3" {
      throw ValidationError.invalidSyntaxVersion(file.syntax)
    }

    // Validate enums
    for enumType in file.enums {
      try validateEnumSemantics(enumType)
    }

    // Validate messages
    for message in file.messages {
      try validateMessageSemantics(message)
    }

    // Validate services
    for service in file.services {
      try validateServiceSemantics(service)
    }
  }

  // MARK: - Private Helper Methods

  /// Validate enum semantics
  /// - Parameter enumType: The enum node to validate
  /// - Throws: ValidationError if validation fails
  private func validateEnumSemantics(_ enumType: EnumNode) throws {
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

    // Check for duplicate values unless allow_alias is enabled
    let allowAlias = enumType.options.contains { option in
      option.name == "allow_alias" && option.value == .identifier("true")
    }

    var usedNumbers = Set<Int>()
    for value in enumType.values {
      if !allowAlias && !usedNumbers.insert(value.number).inserted {
        throw ValidationError.duplicateEnumValue(value.name, value: value.number)
      }
    }
  }

  /// Validate message semantics
  /// - Parameter message: The message node to validate
  /// - Throws: ValidationError if validation fails
  private func validateMessageSemantics(_ message: MessageNode) throws {
    // Check empty oneof
    for oneof in message.oneofs {
      guard !oneof.fields.isEmpty else {
        throw ValidationError.emptyOneof(oneof.name)
      }
    }

    // Check field numbers
    var usedNumbers = Set<Int>()
    for field in message.fields {
      // Check number range
      guard field.number > 0 && field.number <= 536_870_911 else {
        throw ValidationError.invalidFieldNumber(field.number, location: field.location)
      }

      // Check reserved range
      if (19000...19999).contains(field.number) {
        throw ValidationError.invalidFieldNumber(field.number, location: field.location)
      }

      // Check duplicates
      if !usedNumbers.insert(field.number).inserted {
        throw ValidationError.duplicateMessageFieldNumber(field.number, messageName: message.name)
      }

      // Check map field rules
      if case .map = field.type {
        if field.isRepeated {
          throw ValidationError.repeatedMapField(field.name)
        }
      }
    }

    // Recursively validate nested messages
    for nestedMessage in message.messages {
      try validateMessageSemantics(nestedMessage)
    }

    // Recursively validate nested enums
    for nestedEnum in message.enums {
      try validateEnumSemantics(nestedEnum)
    }
  }

  /// Validate service semantics
  /// - Parameter service: The service node to validate
  /// - Throws: ValidationError if validation fails
  private func validateServiceSemantics(_ service: ServiceNode) throws {
    // Check duplicate method names
    var methodNames = Set<String>()
    for rpc in service.rpcs {
      if !methodNames.insert(rpc.name).inserted {
        throw ValidationError.duplicateMethodName(rpc.name)
      }
    }

    // Input/output type validation will be done later during type resolution
  }
}
