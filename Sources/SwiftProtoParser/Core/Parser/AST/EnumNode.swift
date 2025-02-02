import Foundation

/// Represents an enum value definition in a proto file
public class EnumValueNode: Node {
  /// Source location of this enum value
  public let location: SourceLocation

  /// Comments that appear before this enum value
  public let leadingComments: [String]

  /// Comment that appears after this enum value
  public let trailingComment: String?

  /// Name of the enum value
  public let name: String

  /// Numeric value of the enum value
  public let number: Int

  /// Options applied to this enum value
  public let options: [OptionNode]

  public init(
    location: SourceLocation,
    leadingComments: [String] = [],
    trailingComment: String? = nil,
    name: String,
    number: Int,
    options: [OptionNode] = []
  ) {
    self.location = location
    self.leadingComments = leadingComments
    self.trailingComment = trailingComment
    self.name = name
    self.number = number
    self.options = options
  }
}

/// Represents an enum definition in a proto file
public final class EnumNode: DefinitionNode {
  /// Source location of this enum
  public let location: SourceLocation

  /// Comments that appear before this enum
  public let leadingComments: [String]

  /// Comment that appears after the enum name
  public let trailingComment: String?

  /// Name of the enum
  public let name: String

  /// Values defined in this enum
  public private(set) var values: [EnumValueNode]

  /// Options applied to this enum
  public private(set) var options: [OptionNode]

  /// Whether this enum allows alias values
  public private(set) var allowAlias: Bool

  public init(
    location: SourceLocation,
    leadingComments: [String] = [],
    trailingComment: String? = nil,
    name: String,
    values: [EnumValueNode] = [],
    options: [OptionNode] = [],
    allowAlias: Bool = false
  ) {
    self.location = location
    self.leadingComments = leadingComments
    self.trailingComment = trailingComment
    self.name = name
    self.values = values
    self.options = options
    self.allowAlias = allowAlias
  }

  // MARK: - Value Management

  /// Gets all used value numbers in this enum
  public var usedNumbers: Set<Int> {
    return Set(values.map { $0.number })
  }

  /// Gets all used value names in this enum
  public var usedNames: Set<String> {
    return Set(values.map { $0.name })
  }

  /// Finds an enum value by name
  /// - Parameter name: The name to look for
  /// - Returns: The enum value if found
  public func findValue(named name: String) -> EnumValueNode? {
    return values.first { $0.name == name }
  }

  /// Finds enum values by number
  /// - Parameter number: The number to look for
  /// - Returns: All enum values with the given number (can be multiple if aliases are allowed)
  public func findValues(withNumber number: Int) -> [EnumValueNode] {
    return values.filter { $0.number == number }
  }

  // MARK: - Validation

  /// Validates the enum according to proto3 rules
  /// - Throws: ParserError if validation fails
  public func validate() throws {
    // Validate enum name
    guard isValidEnumName(name) else {
      throw ParserError.invalidEnumName(name)
    }

    // Validate that there is at least one value
    guard !values.isEmpty else {
      throw ParserError.emptyEnum(name)
    }

    // Validate that first value is zero (proto3 requirement)
    guard let firstValue = values.first, firstValue.number == 0 else {
      throw ParserError.firstEnumValueNotZero(name)
    }

    // Validate value names and numbers
    var seenNames = Set<String>()
    var seenNumbers = Set<Int>()

    for value in values {
      // Validate value name format
      guard isValidEnumValueName(value.name) else {
        throw ParserError.invalidEnumValueName(value.name)
      }

      // Check for duplicate names
      guard !seenNames.contains(value.name) else {
        throw ParserError.duplicateEnumValueName(value.name)
      }
      seenNames.insert(value.name)

      // Check for duplicate numbers (unless allow_alias is set)
      if !allowAlias {
        guard !seenNumbers.contains(value.number) else {
          throw ParserError.duplicateEnumValueNumber(value.number)
        }
      }
      seenNumbers.insert(value.number)

      // Validate options
      for option in value.options {
        try validateOption(option)
      }
    }

    // Validate enum options
    for option in options {
      try validateOption(option)
    }
  }

  private func validateOption(_ option: OptionNode) throws {
    // Add any enum-specific option validation here
    // For example, validate that allow_alias is a boolean value
    if option.name == "allow_alias" {
      switch option.value {
      case .identifier(let value) where value == "true" || value == "false":
        break  // Valid boolean value
      default:
        throw ParserError.invalidEnumOption(option.name, "must be a boolean")
      }
    }
  }
}

// MARK: - Additional Error Types

extension ParserError {
  static func emptyEnum(_ name: String) -> ParserError {
    return .custom("Enum '\(name)' must have at least one value")
  }

  static func firstEnumValueNotZero(_ name: String) -> ParserError {
    return .custom("First enum value in '\(name)' must be zero in proto3")
  }

  static func duplicateEnumValueName(_ name: String) -> ParserError {
    return .custom("Duplicate enum value name: '\(name)'")
  }

  static func duplicateEnumValueNumber(_ number: Int) -> ParserError {
    return .custom("Duplicate enum value number: \(number) (consider using allow_alias)")
  }

  static func invalidEnumValueName(_ name: String) -> ParserError {
    return .custom("Invalid enum value name: '\(name)'")
  }

  static func invalidEnumOption(_ option: String, _ reason: String) -> ParserError {
    return .custom("Invalid enum option '\(option)': \(reason)")
  }
}

// MARK: - Helper Functions

private func isValidEnumName(_ name: String) -> Bool {
  guard let first = name.first else { return false }
  return first.isUppercase && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
}

private func isValidEnumValueName(_ name: String) -> Bool {
  guard let first = name.first else { return false }
  return first.isUppercase && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
}
