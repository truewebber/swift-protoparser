import Foundation

// MARK: - File Validation

/// Protocol for file-level validation
protocol FileValidating {
  /// Validate the syntax version of a proto file
  /// - Parameter syntax: The syntax version string
  /// - Throws: ValidationError if the syntax version is invalid
  func validateSyntaxVersion(_ syntax: String) throws

  /// Validate a file node
  /// - Parameter file: The file node to validate
  /// - Throws: ValidationError if validation fails
  func validateFile(_ file: FileNode) throws

  /// Validate package name
  /// - Parameter package: The package name
  /// - Throws: ValidationError if the package name is invalid
  func validatePackageName(_ package: String) throws

  /// Validate import statement
  /// - Parameter imp: The import node
  /// - Throws: ValidationError if the import is invalid
  func validateImport(_ imp: ImportNode) throws
}

// MARK: - Message Validation

/// Protocol for message-level validation
protocol MessageValidating {
  /// Validate message semantics
  /// - Parameter message: The message node to validate
  /// - Throws: ValidationError if validation fails
  func validateMessageSemantics(_ message: MessageNode) throws

  /// Validate nested message
  /// - Parameter message: The message node to validate
  /// - Throws: ValidationError if validation fails
  func validateNestedMessage(_ message: MessageNode) throws

  /// Validate a message node
  /// - Parameter message: The message node to validate
  /// - Throws: ValidationError if validation fails
  func validateMessage(_ message: MessageNode) throws

  /// Validate reserved fields in a message
  /// - Parameter message: The message node to validate
  /// - Throws: ValidationError if validation fails
  func validateReservedFields(_ message: MessageNode) throws

  /// Validate extension rules for a message
  /// - Parameter message: The message node to validate
  /// - Throws: ValidationError if validation fails
  func validateExtensionRules(_ message: MessageNode) throws
}

// MARK: - Enum Validation

/// Protocol for enum-level validation
protocol EnumValidating {
  /// Validate enum semantics
  /// - Parameter enumType: The enum node to validate
  /// - Throws: ValidationError if validation fails
  func validateEnumSemantics(_ enumType: EnumNode) throws

  /// Validate enum value semantics
  /// - Parameter enumType: The enum node to validate
  /// - Throws: ValidationError if validation fails
  func validateEnumValueSemantics(_ enumType: EnumNode) throws

  /// Validate enum values uniqueness
  /// - Parameter enumType: The enum node to validate
  /// - Throws: ValidationError if validation fails
  func validateEnumValuesUniqueness(_ enumType: EnumNode) throws

  /// Validate an enum node
  /// - Parameter enumType: The enum node to validate
  /// - Throws: ValidationError if validation fails
  func validateEnum(_ enumType: EnumNode) throws
}

// MARK: - Field Validation

/// Protocol for field-level validation
protocol FieldValidating {
  /// Validate a field
  /// - Parameters:
  ///   - field: The field node to validate
  ///   - message: The message containing the field
  /// - Throws: ValidationError if validation fails
  func validateField(_ field: FieldNode, inMessage message: MessageNode) throws

  /// Validate field number
  /// - Parameters:
  ///   - number: The field number
  ///   - location: The source location
  /// - Throws: ValidationError if the field number is invalid
  func validateFieldNumber(_ number: Int, location: SourceLocation) throws

  /// Validate field name
  /// - Parameters:
  ///   - name: The field name
  ///   - message: The message containing the field
  /// - Throws: ValidationError if the field name is invalid
  func validateFieldName(_ name: String, inMessage message: MessageNode) throws

  /// Validate field type
  /// - Parameters:
  ///   - type: The field type
  ///   - field: The field node
  /// - Throws: ValidationError if the field type is invalid
  func validateFieldType(_ type: TypeNode, field: FieldNode) throws

  /// Validate oneof field
  /// - Parameters:
  ///   - oneof: The oneof node
  ///   - message: The message containing the oneof
  /// - Throws: ValidationError if the oneof is invalid
  func validateOneof(_ oneof: OneofNode, in message: MessageNode) throws
}

// MARK: - Service Validation

/// Protocol for service-level validation
protocol ServiceValidating {
  /// Validate service semantics
  /// - Parameter service: The service node to validate
  /// - Throws: ValidationError if validation fails
  func validateServiceSemantics(_ service: ServiceNode) throws

  /// Validate method uniqueness in a service
  /// - Parameter service: The service node to validate
  /// - Throws: ValidationError if validation fails
  func validateMethodUniqueness(_ service: ServiceNode) throws

  /// Validate a service node
  /// - Parameter service: The service node to validate
  /// - Throws: ValidationError if validation fails
  func validateService(_ service: ServiceNode) throws

  /// Validate streaming rules for an RPC
  /// - Parameter rpc: The RPC node to validate
  /// - Throws: ValidationError if validation fails
  func validateStreamingRules(_ rpc: RPCNode) throws
}

// MARK: - Option Validation

/// Protocol for option validation
protocol OptionValidating {
  /// Validate file options
  /// - Parameter options: The options to validate
  /// - Throws: ValidationError if validation fails
  func validateFileOptions(_ options: [OptionNode]) throws

  /// Validate message options
  /// - Parameter options: The options to validate
  /// - Throws: ValidationError if validation fails
  func validateMessageOptions(_ options: [OptionNode]) throws

  /// Validate field options
  /// - Parameter options: The options to validate
  /// - Throws: ValidationError if validation fails
  func validateFieldOptions(_ options: [OptionNode]) throws

  /// Validate enum options
  /// - Parameter options: The options to validate
  /// - Throws: ValidationError if validation fails
  func validateEnumOptions(_ options: [OptionNode]) throws

  /// Validate enum value options
  /// - Parameter options: The options to validate
  /// - Throws: ValidationError if validation fails
  func validateEnumValueOptions(_ options: [OptionNode]) throws

  /// Validate service options
  /// - Parameter options: The options to validate
  /// - Throws: ValidationError if validation fails
  func validateServiceOptions(_ options: [OptionNode]) throws

  /// Validate method options
  /// - Parameter options: The options to validate
  /// - Throws: ValidationError if validation fails
  func validateMethodOptions(_ options: [OptionNode]) throws
}

// MARK: - Reference Validation

/// Protocol for reference validation
protocol ReferenceValidating {
  /// Register types in a file
  /// - Parameter file: The file node
  /// - Throws: ValidationError if registration fails
  func registerTypes(_ file: FileNode) throws

  /// Validate type reference
  /// - Parameters:
  ///   - typeName: The type name
  ///   - message: The message containing the reference
  /// - Throws: ValidationError if the reference is invalid
  func validateTypeReference(_ typeName: String, inMessage message: MessageNode?) throws

  /// Validate cross references in a file
  /// - Parameter file: The file node
  /// - Throws: ValidationError if validation fails
  func validateCrossReferences(_ file: FileNode) throws
}

// MARK: - Dependency Validation

/// Protocol for dependency validation
protocol DependencyValidating {
  /// Build dependency graph for a file
  /// - Parameter file: The file node
  /// - Throws: ValidationError if building fails
  func buildDependencyGraph(_ file: FileNode) throws

  /// Check for cyclic dependencies
  /// - Throws: ValidationError if cycles are detected
  func checkCyclicDependencies() throws
}

// MARK: - Semantic Validation

/// Protocol for semantic validation
protocol SemanticValidating {
  /// Validate semantic rules for a file
  /// - Parameter file: The file node
  /// - Throws: ValidationError if validation fails
  func validateSemanticRules(_ file: FileNode) throws
}
