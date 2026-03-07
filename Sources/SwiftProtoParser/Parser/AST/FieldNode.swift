import Foundation

/// Represents a field within a protobuf message.
struct FieldNode: Equatable {
  /// The field name.
  let name: String

  /// The field type.
  let type: FieldType

  /// The field number (must be unique within the message).
  let number: Int32

  /// The field label (repeated, optional, or singular).
  let label: FieldLabel

  /// Field-specific options.
  let options: [OptionNode]

  init(
    name: String,
    type: FieldType,
    number: Int32,
    label: FieldLabel = .singular,
    options: [OptionNode] = []
  ) {
    self.name = name
    self.type = type
    self.number = number
    self.label = label
    self.options = options
  }

  /// Returns true if this field is repeated.
  var isRepeated: Bool {
    return label == .repeated
  }

  /// Returns true if this field is optional.
  var isOptional: Bool {
    return label == .optional
  }

  /// Returns true if this field is a map field.
  var isMap: Bool {
    switch type {
    case .map:
      return true
    default:
      return false
    }
  }

  /// Returns true if this field number is in the reserved range.
  var isReservedFieldNumber: Bool {
    return (19000...19999).contains(number)
  }

  /// Returns true if this field number is valid for protobuf.
  var hasValidFieldNumber: Bool {
    return number > 0 && number <= 536_870_911 && !isReservedFieldNumber
  }
}

// MARK: - CustomStringConvertible
extension FieldNode: CustomStringConvertible {
  var description: String {
    var components: [String] = []

    // Add label if not singular
    if label != .singular {
      components.append(label.protoKeyword)
    }

    // Add type and name
    components.append("\(type.protoTypeName) \(name) = \(number)")

    // Add options if any
    if !options.isEmpty {
      let optionStrings = options.map { option in
        let optionName = option.isCustom ? "(\(option.name))" : option.name
        return "\(optionName) = \(option.value.protoRepresentation)"
      }
      components.append("[\(optionStrings.joined(separator: ", "))]")
    }

    return components.joined(separator: " ") + ";"
  }
}
