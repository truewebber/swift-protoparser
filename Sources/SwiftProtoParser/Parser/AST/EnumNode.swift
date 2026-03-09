import Foundation

/// Represents a protobuf enum definition.
struct EnumNode: Equatable {
  /// The enum name.
  let name: String

  /// The enum values.
  let values: [EnumValueNode]

  /// Enum-specific options.
  let options: [OptionNode]

  /// Reserved enum value numbers (stored as closed ranges).
  ///
  /// Use `reserved 1 to max;` to reserve all values; `max` is represented by `ReservedNumberRange.maxSentinel`.
  let reservedRanges: [ReservedNumberRange]

  /// Reserved enum value names (from `reserved "NAME";` statements).
  let reservedNames: [String]

  /// Backward-compatible expansion of reserved ranges into individual numbers.
  ///
  /// Does not expand `max` ranges (returns only `start` for those).
  var reservedNumbers: [Int32] {
    reservedRanges.flatMap { r -> [Int32] in
      guard !r.endIsMax else { return [r.start] }
      return Array(r.start...r.end)
    }
  }

  init(
    name: String,
    values: [EnumValueNode] = [],
    options: [OptionNode] = [],
    reservedRanges: [ReservedNumberRange] = [],
    reservedNames: [String] = []
  ) {
    self.name = name
    self.values = values
    self.options = options
    self.reservedRanges = reservedRanges
    self.reservedNames = reservedNames
  }

  /// Returns true if this enum has a zero value (required in proto3).
  var hasZeroValue: Bool {
    return values.contains { $0.number == 0 }
  }

  /// Returns the enum value with the given name, if it exists.
  func value(named name: String) -> EnumValueNode? {
    return values.first { $0.name == name }
  }

  /// Returns the enum value with the given number, if it exists.
  func value(withNumber number: Int32) -> EnumValueNode? {
    return values.first { $0.number == number }
  }
}

/// Represents a value within a protobuf enum.
struct EnumValueNode: Equatable {
  /// The value name.
  let name: String

  /// The value number.
  let number: Int32

  /// Value-specific options.
  let options: [OptionNode]

  init(
    name: String,
    number: Int32,
    options: [OptionNode] = []
  ) {
    self.name = name
    self.number = number
    self.options = options
  }
}

// MARK: - CustomStringConvertible
extension EnumNode: CustomStringConvertible {
  var description: String {
    var lines: [String] = []

    lines.append("enum \(name) {")

    // Add options
    for option in options {
      lines.append("  \(option.description)")
    }

    // Add values
    for value in values {
      lines.append("  \(value.description)")
    }

    lines.append("}")

    return lines.joined(separator: "\n")
  }
}

// MARK: - CustomStringConvertible
extension EnumValueNode: CustomStringConvertible {
  var description: String {
    var components = ["\(name) = \(number)"]

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
