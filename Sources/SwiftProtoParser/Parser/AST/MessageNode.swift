import Foundation

// MARK: - ExtensionRangeNode

/// Represents a single extension range declaration inside a proto2 message.
///
/// Extension ranges allow external `.proto` files to add fields to a message
/// using the `extend` keyword. The `end` value is stored **exclusive** (as
/// required by the protobuf descriptor format), i.e. the parsed `M` in
/// `extensions N to M` is stored as `M + 1`, and `max` maps to `536870912`.
struct ExtensionRangeNode: Equatable {
  /// The first field number in the range (inclusive).
  let start: Int32
  /// One past the last field number in the range (exclusive), matching the descriptor format.
  let end: Int32
}

// MARK: - MessageNode

/// Represents a protobuf message definition.
struct MessageNode: Equatable {
  /// The message name.
  let name: String

  /// The message fields.
  let fields: [FieldNode]

  /// Nested message definitions.
  let nestedMessages: [MessageNode]

  /// Nested enum definitions.
  let nestedEnums: [EnumNode]

  /// Oneof groups.
  let oneofGroups: [OneofNode]

  /// Message-specific options.
  let options: [OptionNode]

  /// Reserved field numbers and names.
  let reservedNumbers: [Int32]
  let reservedNames: [String]

  /// Extension ranges declared inside this message (proto2 only).
  let extensionRanges: [ExtensionRangeNode]

  /// Extend blocks declared inside this message body (nested extends).
  ///
  /// Fields from these extend blocks go into `DescriptorProto.extension` of this message,
  /// not into `FileDescriptorProto.extension`.
  let nestedExtends: [ExtendNode]

  init(
    name: String,
    fields: [FieldNode] = [],
    nestedMessages: [MessageNode] = [],
    nestedEnums: [EnumNode] = [],
    oneofGroups: [OneofNode] = [],
    options: [OptionNode] = [],
    reservedNumbers: [Int32] = [],
    reservedNames: [String] = [],
    extensionRanges: [ExtensionRangeNode] = [],
    nestedExtends: [ExtendNode] = []
  ) {
    self.name = name
    self.fields = fields
    self.nestedMessages = nestedMessages
    self.nestedEnums = nestedEnums
    self.oneofGroups = oneofGroups
    self.options = options
    self.reservedNumbers = reservedNumbers
    self.reservedNames = reservedNames
    self.extensionRanges = extensionRanges
    self.nestedExtends = nestedExtends
  }

  /// Returns all field numbers used in this message (including oneof fields).
  var usedFieldNumbers: Set<Int32> {
    var numbers = Set(fields.map { $0.number })

    for oneof in oneofGroups {
      numbers.formUnion(Set(oneof.fields.map { $0.number }))
    }

    return numbers
  }

  /// Returns all field names used in this message (including oneof fields).
  var usedFieldNames: Set<String> {
    var names = Set(fields.map { $0.name })

    for oneof in oneofGroups {
      names.formUnion(Set(oneof.fields.map { $0.name }))
    }

    return names
  }

  /// Returns the field with the given name, if it exists.
  func field(named name: String) -> FieldNode? {
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
  func field(withNumber number: Int32) -> FieldNode? {
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
struct OneofNode: Equatable {
  /// The oneof group name.
  let name: String

  /// The fields within this oneof group.
  let fields: [FieldNode]

  /// Oneof-specific options.
  let options: [OptionNode]

  init(
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
  var description: String {
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
  var description: String {
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
