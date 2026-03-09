import Foundation

/// Represents the label/cardinality of a protobuf field.
enum FieldLabel: String, CaseIterable, Equatable {
  /// Field appears exactly once (default in proto3, implicit).
  case singular = "singular"

  /// Field can appear zero or more times.
  case repeated = "repeated"

  /// Field can appear zero or one time (explicit optional).
  case optional = "optional"

  /// Field is required (proto2 only).
  case required = "required"

  /// Returns true if this label allows multiple values.
  var allowsMultipleValues: Bool {
    switch self {
    case .repeated:
      return true
    case .singular, .optional, .required:
      return false
    }
  }

  /// Returns true if this field is required (proto2 only).
  var isRequired: Bool {
    return self == .required
  }

  /// Returns the string representation as it would appear in a .proto file.
  var protoKeyword: String {
    switch self {
    case .singular:
      return ""  // singular is implicit in proto3
    case .repeated:
      return "repeated"
    case .optional:
      return "optional"
    case .required:
      return "required"
    }
  }
}

// MARK: - CustomStringConvertible
extension FieldLabel: CustomStringConvertible {
  var description: String {
    return protoKeyword
  }
}
