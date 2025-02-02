import Foundation

/// Represents a message definition in a proto file
public final class MessageNode: DefinitionNode, DefinitionContainer {
  /// Source location where this message begins
  public let location: SourceLocation

  /// Comments that appear before this message
  public let leadingComments: [String]

  /// Comment that appears after the message name
  public let trailingComment: String?

  /// Name of the message
  public let name: String

  /// Fields defined in the message
  public private(set) var fields: [FieldNode]

  /// Oneof definitions in the message
  public private(set) var oneofs: [OneofNode]

  /// Message-level options
  public private(set) var options: [OptionNode]

  /// Reserved field numbers and names
  public private(set) var reserved: [ReservedNode]

  // Parent node (for nested messages)
  public weak var parent: Node?

  /// Nested message definitions
  public private(set) var messages: [MessageNode]

  /// Nested enum definitions
  public private(set) var enums: [EnumNode]

  /// Creates a new message node
  /// - Parameters:
  ///   - location: Source location of the message
  ///   - leadingComments: Comments before the message
  ///   - trailingComment: Comment after the message name
  ///   - name: Message name
  ///   - fields: Fields in the message
  ///   - oneofs: Oneof definitions
  ///   - options: Message options
  ///   - reserved: Reserved fields
  ///   - messages: Nested messages
  ///   - enums: Nested enums
  public init(
    location: SourceLocation,
    leadingComments: [String] = [],
    trailingComment: String? = nil,
    name: String,
    fields: [FieldNode] = [],
    oneofs: [OneofNode] = [],
    options: [OptionNode] = [],
    reserved: [ReservedNode] = [],
    parent: Node? = nil,
    messages: [MessageNode] = [],
    enums: [EnumNode] = []
  ) {
    self.location = location
    self.leadingComments = leadingComments
    self.trailingComment = trailingComment
    self.name = name
    self.fields = fields
    self.oneofs = oneofs
    self.options = options
    self.reserved = reserved
    self.parent = parent
    self.messages = messages
    self.enums = enums
  }
}

// MARK: - Field Management

extension MessageNode {
  /// All field numbers used in this message, including oneof fields
  public var usedFieldNumbers: Set<Int> {
    var numbers = Set(fields.map { $0.number })
    for oneof in oneofs {
      numbers.formUnion(oneof.fields.map { $0.number })
    }
    return numbers
  }

  /// All field names used in this message, including oneof fields
  public var usedFieldNames: Set<String> {
    var names = Set(fields.map { $0.name })
    for oneof in oneofs {
      names.formUnion(oneof.fields.map { $0.name })
    }
    return names
  }

  /// Reserved field numbers
  public var reservedNumbers: Set<Int> {
    var numbers: Set<Int> = []
    for reservedNode in reserved {
      for range in reservedNode.ranges {
        switch range {
        case .single(let num):
          numbers.insert(num)
        case .range(let start, let end):
          numbers.formUnion(start...end)
        case .name:
          continue
        }
      }
    }
    return numbers
  }

  /// Reserved field names
  public var reservedNames: Set<String> {
    var names: Set<String> = []
    for reservedNode in reserved {
      for range in reservedNode.ranges {
        if case .name(let name) = range {
          names.insert(name)
        }
      }
    }
    return names
  }
}

// MARK: - Type Management

extension MessageNode {
  /// Returns all type references used in this message's fields
  public var typeReferences: Set<String> {
    var references: Set<String> = []

    // Add references from regular fields
    for field in fields {
      if case .named(let typeName) = field.type {
        references.insert(typeName)
      } else if case .map(_, let valueType) = field.type {
        if case .named(let typeName) = valueType {
          references.insert(typeName)
        }
      }
    }

    // Add references from oneof fields
    for oneof in oneofs {
      for field in oneof.fields {
        if case .named(let typeName) = field.type {
          references.insert(typeName)
        }
      }
    }

    return references
  }

  /// Finds a nested type by name
  /// - Parameter name: The name to look for
  /// - Returns: The nested type if found
  public func findNestedType(_ name: String) -> DefinitionNode? {
    if let message = messages.first(where: { $0.name == name }) {
      return message
    }
    if let enumType = enums.first(where: { $0.name == name }) {
      return enumType
    }
    return nil
  }
}

// MARK: - Validation

extension MessageNode {
  /// Validates the message according to proto3 rules
  /// - Throws: ParserError if validation fails
  public func validate() throws {
    // Validate message name
    guard isValidMessageName(name) else {
      throw ParserError.invalidMessageName(name)
    }

    // Validate field numbers
    let allFieldNumbers = usedFieldNumbers
    try validateFieldNumbers(allFieldNumbers)

    // Validate no field number or name conflicts with reserved ones
    let reservedNums = reservedNumbers
    let reservedNames = reservedNames

    for field in fields {
      try validateField(field, reservedNumbers: reservedNums, reservedNames: reservedNames)
    }

    for oneof in oneofs {
      for field in oneof.fields {
        try validateField(field, reservedNumbers: reservedNums, reservedNames: reservedNames)
      }
    }

    // Validate nested types
    for msg in messages {
      try msg.validate()
    }

    for e in enums {
      try e.validate()
    }

    // Validate no duplicate nested type names
    var seenNames: Set<String> = []
    for nestedType in allNestedDefinitions {
      guard !seenNames.contains(nestedType.name) else {
        throw ParserError.duplicateNestedTypeName(nestedType.name)
      }
      seenNames.insert(nestedType.name)
    }
  }

  private func validateFieldNumbers(_ numbers: Set<Int>) throws {
    for number in numbers {
      guard number >= 1 else {
        throw ParserError.invalidFieldNumber(number, location: location)
      }

      guard number <= 536_870_911 else {
        throw ParserError.invalidFieldNumber(number, location: location)
      }

      // Check reserved range for internal use
      guard !(19_000...19_999).contains(number) else {
        throw ParserError.invalidFieldNumber(number, location: location)
      }
    }
  }

  private func validateField(
    _ field: FieldNode,
    reservedNumbers: Set<Int>,
    reservedNames: Set<String>
  ) throws {
    // Check if field number is reserved
    guard !reservedNumbers.contains(field.number) else {
      throw ParserError.reservedFieldNumber(field.number)
    }

    // Check if field name is reserved
    guard !reservedNames.contains(field.name) else {
      throw ParserError.reservedFieldName(field.name)
    }

    // Validate field name format
    guard isValidFieldName(field.name) else {
      throw ParserError.invalidFieldName(field.name)
    }

    // Validate map fields
    if case .map(let keyType, _) = field.type {
      guard keyType.canBeMapKey else {
        throw ParserError.invalidMapKeyType(String(describing: keyType))
      }
      guard !field.isRepeated else {
        throw ParserError.repeatedMapField(field.name)
      }
    }
  }
}

// MARK: - Additional Error Types

extension ParserError {
  static func reservedFieldNumber(_ number: Int) -> ParserError {
    return .custom("Field number \(number) is reserved")
  }

  static func reservedFieldName(_ name: String) -> ParserError {
    return .custom("Field name '\(name)' is reserved")
  }

  static func repeatedMapField(_ name: String) -> ParserError {
    return .custom("Map field '\(name)' cannot be repeated")
  }

  static func duplicateNestedTypeName(_ name: String) -> ParserError {
    return .custom("Duplicate nested type name: \(name)")
  }
}

// MARK: - Helper Functions

private func isValidMessageName(_ name: String) -> Bool {
  guard let first = name.first else { return false }
  return first.isUppercase && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
}

private func isValidFieldName(_ name: String) -> Bool {
  guard let first = name.first else { return false }
  return (first.isLowercase || first == "_")
    && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
}
