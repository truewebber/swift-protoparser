import Foundation

/// Implementation of service-level validation
class ServiceValidator: ServiceValidating {
  // Reference to the shared validation state
  private let state: ValidationState
  
  /// Initialize with a validation state
  /// - Parameter state: The validation state
  init(state: ValidationState) {
    self.state = state
  }
  
  /// Validate service semantics
  /// - Parameter service: The service node to validate
  /// - Throws: ValidationError if validation fails
  func validateServiceSemantics(_ service: ServiceNode) throws {
    // Check duplicate method names
    var methodNames = Set<String>()
    for rpc in service.rpcs {
      if !methodNames.insert(rpc.name).inserted {
        throw ValidationError.duplicateMethodName(rpc.name)
      }
    }
    
    // Input/output type validation will be done later during type resolution
  }
  
  /// Validate method uniqueness in a service
  /// - Parameter service: The service node to validate
  /// - Throws: ValidationError if validation fails
  func validateMethodUniqueness(_ service: ServiceNode) throws {
    var methodNames = Set<String>()
    
    for rpc in service.rpcs {
      // Validate method name format
      guard isValidMethodName(rpc.name) else {
        throw ValidationError.invalidMethodName(rpc.name)
      }
      
      // Check for duplicate method names
      if !methodNames.insert(rpc.name).inserted {
        throw ValidationError.duplicateMethodName(rpc.name)
      }
    }
  }
  
  /// Validate a service node
  /// - Parameter service: The service node to validate
  /// - Throws: ValidationError if validation fails
  func validateService(_ service: ServiceNode) throws {
    // Check duplicate method names
    var methodNames = Set<String>()
    for rpc in service.rpcs {
      if !methodNames.insert(rpc.name).inserted {
        throw ValidationError.duplicateMethodName(rpc.name)
      }
      
      // Validate input type
      // This would typically call a reference validator
      
      // Validate output type
      // This would typically call a reference validator
      
      // Validate RPC options
      // This would typically call an option validator
    }
  }
  
  /// Validate streaming rules for an RPC
  /// - Parameter rpc: The RPC node to validate
  /// - Throws: ValidationError if validation fails
  func validateStreamingRules(_ rpc: RPCNode) throws {
    // Validate streaming configuration
    if rpc.clientStreaming {
      // Validate client streaming configuration
      // This is a simplified implementation
    }
    
    if rpc.serverStreaming {
      // Validate server streaming configuration
      // This is a simplified implementation
    }
    
    // Validate bidirectional streaming specific rules
    if rpc.clientStreaming && rpc.serverStreaming {
      // Validate bidirectional streaming
      // This is a simplified implementation
    }
  }
  
  // MARK: - Private Helper Methods
  
  /// Check if a method name is valid
  /// - Parameter name: The method name to check
  /// - Returns: True if the method name is valid
  private func isValidMethodName(_ name: String) -> Bool {
    guard !name.isEmpty else { return false }
    
    // First character must be a letter
    guard let first = name.first,
          first.isLetter else {
      return false
    }
    
    // Remaining characters must be letters, digits, or underscores
    return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
  }
} 