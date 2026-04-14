import Foundation

/// Represents a protobuf option declaration.
struct OptionNode: Equatable {
  /// The option name (e.g., "java_package", "deprecated", or "buf.validate.field" for custom options).
  let name: String

  /// Sub-field path after the closing parenthesis.
  ///
  /// For `(buf.validate.field).int32.gt`, `name` is `"buf.validate.field"` and
  /// `subFieldPath` is `["int32", "gt"]`.
  /// For plain options such as `deprecated` or `(my_ext)` this array is empty.
  let subFieldPath: [String]

  /// The option value.
  let value: OptionValue

  /// Whether this is a custom option (starts with parentheses).
  let isCustom: Bool

  init(name: String, subFieldPath: [String] = [], value: OptionValue, isCustom: Bool = false) {
    self.name = name
    self.subFieldPath = subFieldPath
    self.value = value
    self.isCustom = isCustom
  }
}

/// Represents the value of a protobuf option.
enum OptionValue: Equatable {
  case string(String)
  case number(Double)
  case boolean(Bool)
  case identifier(String)
  /// A message literal value: the raw balanced-block text including braces, e.g. `{ max_len: 1024 }`.
  case messageLiteral(String)

  /// Returns the string representation of the value as it would appear in a .proto file.
  var protoRepresentation: String {
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
    case .messageLiteral(let block):
      return block
    }
  }
}

// MARK: - CustomStringConvertible
extension OptionNode: CustomStringConvertible {
  var description: String {
    let baseName = isCustom ? "(\(name))" : name
    let suffix = subFieldPath.isEmpty ? "" : "." + subFieldPath.joined(separator: ".")
    return "option \(baseName)\(suffix) = \(value.protoRepresentation);"
  }
}

// MARK: - CustomStringConvertible
extension OptionValue: CustomStringConvertible {
  var description: String {
    return protoRepresentation
  }
}
