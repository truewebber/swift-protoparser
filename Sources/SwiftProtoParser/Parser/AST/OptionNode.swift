import Foundation

/// Represents a protobuf option declaration
public struct OptionNode: Equatable {
  /// The option name (e.g., "java_package", "deprecated")
  public let name: String

  /// The option value
  public let value: OptionValue

  /// Whether this is a custom option (starts with parentheses)
  public let isCustom: Bool

  public init(name: String, value: OptionValue, isCustom: Bool = false) {
    self.name = name
    self.value = value
    self.isCustom = isCustom
  }
}

/// Represents the value of a protobuf option
public enum OptionValue: Equatable {
  case string(String)
  case number(Double)
  case boolean(Bool)
  case identifier(String)

  /// Returns the string representation of the value as it would appear in a .proto file
  public var protoRepresentation: String {
    switch self {
    case .string(let str):
      return "\"\(str)\""
    case .number(let num):
      if num.truncatingRemainder(dividingBy: 1) == 0 {
        return String(Int(num))
      }
      else {
        return String(num)
      }
    case .boolean(let bool):
      return bool ? "true" : "false"
    case .identifier(let id):
      return id
    }
  }
}

// MARK: - CustomStringConvertible
extension OptionNode: CustomStringConvertible {
  public var description: String {
    let optionName = isCustom ? "(\(name))" : name
    return "option \(optionName) = \(value.protoRepresentation);"
  }
}

// MARK: - CustomStringConvertible
extension OptionValue: CustomStringConvertible {
  public var description: String {
    return protoRepresentation
  }
}
