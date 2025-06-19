import Foundation

/// Represents a protobuf message definition.
public struct MessageNode: Equatable {
  /// The message name.
  public let name: String

  /// The message fields.
  public let fields: [FieldNode]

  /// Nested message definitions.
  public let nestedMessages: [MessageNode]

  /// Nested enum definitions.
  public let nestedEnums: [EnumNode]

  /// Oneof groups.
  public let oneofGroups: [OneofNode]

  /// Message-specific options.
  public let options: [OptionNode]

  /// Reserved field numbers and names.
  public let reservedNumbers: [Int32]
  public let reservedNames: [String]

  public init(
    name: String,
    fields: [FieldNode] = [],
    nestedMessages: [MessageNode] = [],
    nestedEnums: [EnumNode] = [],
    oneofGroups: [OneofNode] = [],
    options: [OptionNode] = [],
    reservedNumbers: [Int32] = [],
    reservedNames: [String] = []
  ) {
    self.name = name
    self.fields = fields
    self.nestedMessages = nestedMessages
    self.nestedEnums = nestedEnums
    self.oneofGroups = oneofGroups
    self.options = options
    self.reservedNumbers = reservedNumbers
    self.reservedNames = reservedNames
  }

  /// Returns all field numbers used in this message (including oneof fields).
  public var usedFieldNumbers: Set<Int32> {
    var numbers = Set(fields.map { $0.number })

    for oneof in oneofGroups {
      numbers.formUnion(Set(oneof.fields.map { $0.number }))
    }

    return numbers
  }

  /// Returns all field names used in this message (including oneof fields).
  public var usedFieldNames: Set<String> {
    var names = Set(fields.map { $0.name })

    for oneof in oneofGroups {
      names.formUnion(Set(oneof.fields.map { $0.name }))
    }

    return names
  }

  /// Returns the field with the given name, if it exists.
  public func field(named name: String) -> FieldNode? {
    // Check regular fields
    if let field = fields.first(where: { $0.name == name }) {
      return field
    }

    // Check oneof fields
    for oneof in oneofGroups {
      if let field = oneof.fields.first(where: { $0.name == name }) {
        return field
      }
    }

    return nil
  }

  /// Returns the field with the given number, if it exists.
  public func field(withNumber number: Int32) -> FieldNode? {
    // Check regular fields
    if let field = fields.first(where: { $0.number == number }) {
      return field
    }

    // Check oneof fields
    for oneof in oneofGroups {
      if let field = oneof.fields.first(where: { $0.number == number }) {
        return field
      }
    }

    return nil
  }
}

/// Represents a oneof group within a protobuf message.
public struct OneofNode: Equatable {
  /// The oneof group name.
  public let name: String

  /// The fields within this oneof group.
  public let fields: [FieldNode]

  /// Oneof-specific options.
  public let options: [OptionNode]

  public init(
    name: String,
    fields: [FieldNode] = [],
    options: [OptionNode] = []
  ) {
    self.name = name
    self.fields = fields
    self.options = options
  }
}

// MARK: - CustomStringConvertible
extension MessageNode: CustomStringConvertible {
  public var description: String {
    var lines: [String] = []

    lines.append("message \(name) {")

    // Add options
    for option in options {
      lines.append("  \(option.description)")
    }

    // Add reserved numbers
    if !reservedNumbers.isEmpty {
      lines.append("  reserved \(reservedNumbers.map(String.init).joined(separator: ", "));")
    }

    // Add reserved names
    if !reservedNames.isEmpty {
      let quotedNames = reservedNames.map { "\"\($0)\"" }
      lines.append("  reserved \(quotedNames.joined(separator: ", "));")
    }

    // Add nested enums
    for nestedEnum in nestedEnums {
      let enumLines = nestedEnum.description.split(separator: "\n")
      for line in enumLines {
        lines.append("  \(line)")
      }
      lines.append("")
    }

    // Add nested messages
    for nestedMessage in nestedMessages {
      let messageLines = nestedMessage.description.split(separator: "\n")
      for line in messageLines {
        lines.append("  \(line)")
      }
      lines.append("")
    }

    // Add oneof groups
    for oneof in oneofGroups {
      let oneofLines = oneof.description.split(separator: "\n")
      for line in oneofLines {
        lines.append("  \(line)")
      }
      lines.append("")
    }

    // Add fields
    for field in fields {
      lines.append("  \(field.description)")
    }

    lines.append("}")

    return lines.joined(separator: "\n")
  }
}

// MARK: - CustomStringConvertible
extension OneofNode: CustomStringConvertible {
  public var description: String {
    var lines: [String] = []

    lines.append("oneof \(name) {")

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
