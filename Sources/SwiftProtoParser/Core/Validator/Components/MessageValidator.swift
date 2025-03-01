import Foundation

/// Implementation of message-level validation
class MessageValidator: MessageValidating {
  // Reference to the shared validation state
  private let state: ValidationState
  
  /// Initialize with a validation state
  /// - Parameter state: The validation state
  init(state: ValidationState) {
    self.state = state
  }
  
  /// Validate message semantics
  /// - Parameter message: The message node to validate
  /// - Throws: ValidationError if validation fails
  func validateMessageSemantics(_ message: MessageNode) throws {
    // Validate message name format (CamelCase)
    guard isValidMessageName(message.name) else {
      throw ValidationError.invalidMessageName(message.name)
    }
    
    // Check empty oneof
    for oneof in message.oneofs {
      guard !oneof.fields.isEmpty else {
        throw ValidationError.emptyOneof(oneof.name)
      }
    }
    
    // Check field names
    for field in message.fields {
      guard isValidFieldName(field.name) else {
        throw ValidationError.invalidFieldName(field.name)
      }
    }
    
    // Check field numbers
    var usedNumbers = Set<Int>()
    for field in message.fields {
      // Check number range
      guard field.number > 0 && field.number <= 536_870_911 else {
        throw ValidationError.invalidFieldNumber(field.number, location: field.location)
      }
      
      // Check reserved range
      if (19000...19999).contains(field.number) {
        throw ValidationError.invalidFieldNumber(field.number, location: field.location)
      }
      
      // Check duplicates
      if !usedNumbers.insert(field.number).inserted {
        throw ValidationError.duplicateMessageFieldNumber(field.number, messageName: message.name)
      }
      
      // Check map field rules
      if case .map = field.type {
        if field.isRepeated {
          throw ValidationError.repeatedMapField(field.name)
        }
      }
    }
    
    // Recursively validate nested messages
    for nestedMessage in message.messages {
      try validateMessageSemantics(nestedMessage)
    }
  }
  
  /// Validate nested message
  /// - Parameter message: The message node to validate
  /// - Throws: ValidationError if validation fails
  func validateNestedMessage(_ message: MessageNode) throws {
    // Track names used in this scope
    var usedNames = Set<String>()
    
    // Check nested message names
    for nestedMessage in message.messages {
      if !usedNames.insert(nestedMessage.name).inserted {
        throw ValidationError.duplicateNestedTypeName(nestedMessage.name)
      }
    }
    
    // Check nested enum names
    for nestedEnum in message.enums {
      if !usedNames.insert(nestedEnum.name).inserted {
        throw ValidationError.duplicateNestedTypeName(nestedEnum.name)
      }
    }
    
    // Check field names
    var usedFieldNames = Set<String>()
    for field in message.fields {
      if !usedFieldNames.insert(field.name).inserted {
        throw ValidationError.duplicateFieldName(field.name, inType: message.name)
      }
    }
    
    // Check oneof field names
    for oneof in message.oneofs {
      for field in oneof.fields {
        if !usedFieldNames.insert(field.name).inserted {
          throw ValidationError.duplicateFieldName(field.name, inType: message.name)
        }
      }
    }
    
    // Recursively validate nested messages
    for nestedMessage in message.messages {
      try validateNestedMessage(nestedMessage)
    }
  }
  
  /// Validate a message node
  /// - Parameter message: The message node to validate
  /// - Throws: ValidationError if validation fails
  func validateMessage(_ message: MessageNode) throws {
    // Validate fields
    for field in message.fields {
      try validateField(field, inMessage: message)
    }
    
    // Validate oneofs
    for oneof in message.oneofs {
      try validateOneof(oneof, in: message)
    }
    
    // Validate nested messages
    for nestedMessage in message.messages {
      try validateMessage(nestedMessage)
    }
  }
  
  /// Validate reserved fields in a message
  /// - Parameter message: The message node to validate
  /// - Throws: ValidationError if validation fails
  func validateReservedFields(_ message: MessageNode) throws {
    var allReservedNumbers = Set<Int>()
    var allReservedNames = Set<String>()
    
    for reserved in message.reserved {
      for range in reserved.ranges {
        switch range {
        case .single(let number):
          // Validate number is in valid range
          guard number > 0 && number <= 536_870_911 else {
            throw ValidationError.invalidFieldNumber(number, location: reserved.location)
          }
          
          // Check for duplicate reserved numbers
          guard allReservedNumbers.insert(number).inserted else {
            throw ValidationError.custom("Duplicate reserved field number: \(number)")
          }
          
        case .range(let start, let end):
          // Validate range bounds
          guard start > 0 && end <= 536_870_911 && start < end else {
            throw ValidationError.custom("Invalid reserved range: \(start) to \(end)")
          }
          
          // Check for overlaps with existing reserved numbers
          for num in start...end {
            guard allReservedNumbers.insert(num).inserted else {
              throw ValidationError.custom("Overlapping reserved field numbers at \(num)")
            }
          }
          
        case .name(let name):
          // Check for duplicate reserved names
          guard allReservedNames.insert(name).inserted else {
            throw ValidationError.custom("Duplicate reserved field name: \(name)")
          }
        }
      }
    }
    
    // Validate no conflicts with actual fields
    for field in message.fields {
      if allReservedNumbers.contains(field.number) {
        throw ValidationError.custom("Field number \(field.number) conflicts with reserved number")
      }
      if allReservedNames.contains(field.name) {
        throw ValidationError.reservedFieldName(field.name)
      }
    }
  }
  
  /// Validate extension rules for a message
  /// - Parameter message: The message node to validate
  /// - Throws: ValidationError if validation fails
  func validateExtensionRules(_ message: MessageNode) throws {
    // In proto3, extensions are only allowed in the following contexts:
    // 1. Custom options (extending google.protobuf.*)
    // 2. Must be within a defined extension range of the target message
    // 3. Cannot extend a non-custom message type
    
    // This is a simplified implementation - would need to be expanded
    // based on the actual extension rules in the codebase
  }
  
  // MARK: - Private Helper Methods
  
  /// Validate a field within a message
  /// - Parameters:
  ///   - field: The field to validate
  ///   - message: The containing message
  /// - Throws: ValidationError if validation fails
  private func validateField(_ field: FieldNode, inMessage message: MessageNode) throws {
    // This would typically delegate to a FieldValidator
    // For now, just implement basic validation
    
    // Validate field name format
    guard isValidFieldName(field.name) else {
      throw ValidationError.invalidFieldName(field.name)
    }
    
    // Validate field number
    guard field.number > 0 && field.number <= 536_870_911 else {
      throw ValidationError.invalidFieldNumber(field.number, location: field.location)
    }
    
    // Check reserved range
    if (19000...19999).contains(field.number) {
      throw ValidationError.invalidFieldNumber(field.number, location: field.location)
    }
  }
  
  /// Validate a oneof field
  /// - Parameters:
  ///   - oneof: The oneof to validate
  ///   - message: The containing message
  /// - Throws: ValidationError if validation fails
  private func validateOneof(_ oneof: OneofNode, in message: MessageNode) throws {
    // Check that oneof has at least one field
    guard !oneof.fields.isEmpty else {
      throw ValidationError.emptyOneof(oneof.name)
    }
    
    // Check for duplicate field names or numbers
    var fieldNames = Set<String>()
    var fieldNumbers = Set<Int>()
    
    for field in oneof.fields {
      if !fieldNames.insert(field.name).inserted {
        throw ValidationError.duplicateFieldName(field.name, inType: message.name)
      }
      
      if !fieldNumbers.insert(field.number).inserted {
        throw ValidationError.duplicateMessageFieldNumber(field.number, messageName: message.name)
      }
      
      // Oneof fields cannot be repeated
      if field.isRepeated {
        throw ValidationError.repeatedOneof(field.name)
      }
    }
  }
  
  /// Check if a message name is valid
  /// - Parameter name: The message name to check
  /// - Returns: True if the message name is valid
  private func isValidMessageName(_ name: String) -> Bool {
    guard !name.isEmpty else { return false }
    
    // First character must be uppercase letter (not underscore)
    guard let first = name.first,
          first.isUppercase else {
      return false
    }
    
    // Message names are typically in CamelCase format
    // Letters, numbers, and underscores are allowed
    // Reject all-uppercase names with underscores (SCREAMING_SNAKE_CASE)
    if name.allSatisfy({ $0.isUppercase || $0.isNumber || $0 == "_" }) && name.contains("_") {
      return false
    }
    
    return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
  }

  /// Check if a field name is valid
  /// - Parameter name: The field name to check
  /// - Returns: True if the field name is valid
  private func isValidFieldName(_ name: String) -> Bool {
    guard !name.isEmpty else { return false }
    
    // First character must be lowercase letter (not underscore)
    guard let first = name.first,
          first.isLowercase else {
      return false
    }
    
    // Field names are typically in snake_case format
    // Only lowercase letters, digits, and underscores are allowed
    return name.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "_" }
  }
} 