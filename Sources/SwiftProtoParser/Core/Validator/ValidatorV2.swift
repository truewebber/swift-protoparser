import Foundation

/// Main validator class that coordinates the validation process
/// This class serves as the entry point for validation and delegates to specialized components
public final class ValidatorV2 {
  // State management
  private var state: ValidationState

  // Components
  private let fileValidator: FileValidating
  private let messageValidator: MessageValidating
  private let enumValidator: EnumValidating
  private let fieldValidator: FieldValidating
  private let serviceValidator: ServiceValidating
  private let optionValidator: OptionValidating
  private let referenceValidator: ReferenceValidating
  private let dependencyValidator: DependencyValidating
  private let semanticValidator: SemanticValidating

  /// Initialize a new validator
  public init() {
    self.state = ValidationState()

    // Initialize components
    self.fileValidator = FileValidator(state: state)
    self.messageValidator = MessageValidator(state: state)
    self.enumValidator = EnumValidator(state: state)
    self.fieldValidator = FieldValidator(state: state)
    self.serviceValidator = ServiceValidator(state: state)
    self.optionValidator = OptionValidator(state: state)
    self.referenceValidator = ReferenceValidator(state: state)
    self.dependencyValidator = DependencyValidator(state: state)
    self.semanticValidator = SemanticValidator(state: state)
  }

  /// Set imported types in the validation state
  /// - Parameter types: Dictionary mapping type names to their import paths
  public func setImportedTypes(_ types: [String: String]) {
    for (typeName, importPath) in types {
      state.importedTypes[typeName] = importPath
    }
  }

  /// Validates a proto file according to proto3 rules
  /// - Parameter file: The file node to validate
  /// - Throws: ValidationError if validation fails
  public func validate(_ file: FileNode) throws {
    // Reset state
    state.reset()

    // Store current package
    state.currentPackage = file.package

    // 1. Basic validation
    try fileValidator.validateSyntaxVersion(file.syntax)

    // 1.1 Validate package name
    if let package = file.package {
      try fileValidator.validatePackageName(package)
    }

    // 2. Validate file options
    try optionValidator.validateFileOptions(file.options)

    // 3. Register types before validation to allow for forward references
    try referenceValidator.registerTypes(file)

    // 4. Validate enums first (to catch enum value errors)
    for enum_ in file.enums {
      try enumValidator.validateEnumSemantics(enum_)
      try enumValidator.validateEnumValueSemantics(enum_)
      try enumValidator.validateEnumValuesUniqueness(enum_)
      try optionValidator.validateEnumOptions(enum_.options)

      // Validate enum values options
      for value in enum_.values {
        try optionValidator.validateEnumValueOptions(value.options)
      }
    }

    // 5. Validate messages
    for message in file.messages {
      state.pushScope(message)
      try messageValidator.validateMessageSemantics(message)
      try messageValidator.validateNestedMessage(message)
      state.popScope()
    }

    // 6. Validate services
    for service in file.services {
      try serviceValidator.validateServiceSemantics(service)
      try serviceValidator.validateMethodUniqueness(service)
      try optionValidator.validateServiceOptions(service.options)

      for rpc in service.rpcs {
        try referenceValidator.validateTypeReference(rpc.inputType, inMessage: nil)
        try referenceValidator.validateTypeReference(rpc.outputType, inMessage: nil)
        try optionValidator.validateMethodOptions(rpc.options)
      }
    }

    // 7. Final validations
    try dependencyValidator.buildDependencyGraph(file)
    try dependencyValidator.checkCyclicDependencies()
    try referenceValidator.validateCrossReferences(file)
  }
}
