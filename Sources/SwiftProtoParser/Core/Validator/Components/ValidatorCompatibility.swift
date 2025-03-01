import Foundation

/// Feature flag to control which validator implementation to use
public enum ValidatorImplementation {
  /// Use the original monolithic validator
  case original
  
  /// Use the new component-based validator
  case componentBased
  
  /// The current implementation to use
  public static var current: ValidatorImplementation = .componentBased
}

/// Compatibility layer for the Validator class
/// This class provides a way to gradually migrate from the original Validator to the new ValidatorV2
public final class ValidatorFactory {
  /// Create a validator instance based on the current implementation setting
  /// - Returns: A validator that conforms to the ValidatorProtocol
  public static func createValidator() -> ValidatorProtocol {
    switch ValidatorImplementation.current {
    case .original:
      return OriginalValidatorWrapper()
    case .componentBased:
      return ValidatorV2()
    }
  }
}

/// Protocol that both validator implementations must conform to
public protocol ValidatorProtocol {
  /// Validates a proto file according to proto3 rules
  /// - Parameter file: The file node to validate
  /// - Throws: ValidationError if validation fails
  func validate(_ file: FileNode) throws
}

/// Wrapper for the original Validator class
private final class OriginalValidatorWrapper: ValidatorProtocol {
  private let validator = Validator()
  
  func validate(_ file: FileNode) throws {
    try validator.validate(file)
  }
}

// Make ValidatorV2 conform to ValidatorProtocol
extension ValidatorV2: ValidatorProtocol {
  // No additional implementation needed as ValidatorV2 already has a validate method
}

// Usage example:
/*
 // Configure which implementation to use
 ValidatorImplementation.current = .componentBased
 
 // Create a validator using the factory
 let validator = ValidatorFactory.createValidator()
 
 // Use the validator
 try validator.validate(fileNode)
 */ 