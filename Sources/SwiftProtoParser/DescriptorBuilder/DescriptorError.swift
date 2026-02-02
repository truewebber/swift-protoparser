import Foundation

/// Errors that can occur during descriptor building.
public enum DescriptorError: LocalizedError, Equatable {
  /// Unable to convert AST node to descriptor.
  case conversionFailed(reason: String)

  /// Missing required field in AST node.
  case missingRequiredField(field: String, in: String)

  /// Invalid field type for descriptor conversion.
  case invalidFieldType(type: String, context: String)

  /// Duplicate element found during conversion.
  case duplicateElement(name: String, type: String)

  /// Unsupported feature for descriptor conversion.
  case unsupportedFeature(feature: String, context: String)

  /// Invalid map type configuration.
  case invalidMapType(String)

  /// Internal error during descriptor building.
  case internalError(message: String)

  public var errorDescription: String? {
    switch self {
    case .conversionFailed(let reason):
      return "Descriptor conversion failed: \(reason)"
    case .missingRequiredField(let field, let context):
      return "Missing required field '\(field)' in \(context)"
    case .invalidFieldType(let type, let context):
      return "Invalid field type '\(type)' in \(context)"
    case .duplicateElement(let name, let type):
      return "Duplicate \(type) '\(name)' found during conversion"
    case .unsupportedFeature(let feature, let context):
      return "Unsupported feature '\(feature)' in \(context)"
    case .invalidMapType(let message):
      return "Invalid map type: \(message)"
    case .internalError(let message):
      return "Internal descriptor builder error: \(message)"
    }
  }
}

// MARK: - Convenience Methods

extension DescriptorError {
  /// Create a conversion failed error.
  public static func conversionFailed(_ reason: String) -> DescriptorError {
    return .conversionFailed(reason: reason)
  }

  /// Create a missing required field error.
  public static func missingField(_ field: String, in context: String) -> DescriptorError {
    return .missingRequiredField(field: field, in: context)
  }

  /// Create an invalid field type error.
  public static func invalidType(_ type: String, in context: String) -> DescriptorError {
    return .invalidFieldType(type: type, context: context)
  }

  /// Create a duplicate element error.
  public static func duplicate(_ name: String, type: String) -> DescriptorError {
    return .duplicateElement(name: name, type: type)
  }

  /// Create an unsupported feature error.
  public static func unsupported(_ feature: String, in context: String) -> DescriptorError {
    return .unsupportedFeature(feature: feature, context: context)
  }

  /// Create an internal error.
  public static func internalError(_ message: String) -> DescriptorError {
    return .internalError(message: message)
  }
}
