import Foundation

/// Represents the label/cardinality of a protobuf field.
enum FieldLabel: String, CaseIterable, Equatable {
  /// Field appears exactly once (default in proto3).
  case singular = "singular"

  /// Field can appear zero or more times.
  case repeated = "repeated"

  /// Field can appear zero or one time (explicit optional in proto3).
  case optional = "optional"

  /// Returns true if this label allows multiple values.
  var allowsMultipleValues: Bool {
    switch self {
    case .repeated:
      return true
    case .singular, .optional:
      return false
    }
  }

  /// Returns true if this field is required (always false in proto3).
  var isRequired: Bool {
    // Proto3 doesn't have required fields
    return false
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
    }
  }
}

// MARK: - CustomStringConvertible
extension FieldLabel: CustomStringConvertible {
  var description: String {
    return protoKeyword
  }
}
