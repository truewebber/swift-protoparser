import Foundation

public final class Validator {
  // Current package being validated
  private var currentPackage: String?

  // Track all defined types
  private var definedTypes: [String: DefinitionNode] = [:]

  // Track scope stack for nested type resolution
  private struct Scope {
    let typeName: String  // Fully qualified name of the type
    let node: DefinitionNode  // The definition node
  }

  private var scopeStack: [Scope] = []

  // Track imported types
  private var importedTypes: [String: String] = [:]

  // Track imported definitions
  private var importedDefinitions: [String: [DefinitionNode]] = [:]

  // Track dependencies between types
  private var dependencies: [String: Set<String>] = [:]

  /// Validates a proto file according to proto3 rules
  /// - Parameter file: The file node to validate
  /// - Throws: ValidationError if validation fails
  public func validate(_ file: FileNode) throws {
    // 1. Reset and initialize state
    definedTypes.removeAll()
    scopeStack.removeAll()
    importedTypes.removeAll()
    importedDefinitions.removeAll()
    dependencies.removeAll()
    currentPackage = file.package

    // 2. Basic structure validation
    guard file.syntax == "proto3" else {
      throw ValidationError.invalidSyntaxVersion(file.syntax)
    }

    if let package = file.package {
      try validatePackageSemantics(package)
    }

    // 3. Imports validation and collection
    var publicImportPaths = Set<String>()
    for import_ in file.imports {
      try validateImportSemantics(import_)
      if import_.modifier == .public {
        publicImportPaths.insert(import_.path)
      }
    }

    // 4. Collect and validate types
    try collectDefinedTypes(file)
    try collectImportedTypes(file)

    // 5. File options validation
    try validateFileOptions(file.options)

    // 6. Message validation
    for message in file.messages {
      // Push scope for nested type resolution
      pushScope(message)

      // Validate message structure and semantics
      try validateMessageSemantics(message)
      try validateReservedFields(message)
      try validateExtensionRules(message)
      try validateMessageOptions(message.options)

      // Validate fields
      var usedFieldNumbers = Set<Int>()
      for field in message.fields {
        // Validate field number uniqueness
        if !usedFieldNumbers.insert(field.number).inserted {
          throw ValidationError.duplicateMessageFieldNumber(field.number, messageName: message.name)
        }

        // Validate field type reference
        try validateFieldTypeReference(field.type, inMessage: message)

        // Validate field options
        try validateFieldOptions(field.options)
      }

      // Validate oneofs
      for oneof in message.oneofs {
        try validateOneofSemantics(oneof)
        for field in oneof.fields {
          if !usedFieldNumbers.insert(field.number).inserted {
            throw ValidationError.duplicateMessageFieldNumber(
              field.number, messageName: message.name)
          }
        }
      }

      // Recursively validate nested messages
      for nestedMessage in message.messages {
        try validateNestedMessage(nestedMessage)
      }

      // Validate nested enums
      for nestedEnum in message.enums {
        try validateEnumSemantics(nestedEnum)
        try validateEnumValueSemantics(nestedEnum)
        try validateEnumValuesUniqueness(nestedEnum)
        try validateEnumOptions(nestedEnum.options)
      }

      // Pop scope after nested validation
      popScope()
    }

    // 7. Top-level enum validation
    for enum_ in file.enums {
      try validateEnumSemantics(enum_)
      try validateEnumValueSemantics(enum_)
      try validateEnumValuesUniqueness(enum_)
      try validateEnumOptions(enum_.options)

      // Validate enum values options
      for value in enum_.values {
        try validateEnumValueOptions(value.options)
      }
    }

    // 8. Service validation
    for service in file.services {
      // Validate service structure
      try validateServiceSemantics(service)
      try validateMethodUniqueness(service)
      try validateServiceOptions(service.options)

      // Validate each RPC method
      for rpc in service.rpcs {
        // Validate method types
        try validateTypeReference(rpc.inputType, inMessage: nil)
        try validateTypeReference(rpc.outputType, inMessage: nil)

        // Validate streaming configuration
        if rpc.clientStreaming || rpc.serverStreaming {
          try validateStreamingRules(rpc)
        }

        // Validate method options
        try validateMethodOptions(rpc.options)
      }
    }

    // 9. Dependency validation
    try buildDependencyGraph(file)
    try checkCyclicDependencies()

    // 10. Final cross-reference validation
    try validateCrossReferences(file)
  }

  // Add new helper function for nested message validation
  private func validateNestedMessage(_ message: MessageNode) throws {
    pushScope(message)
    defer { popScope() }

    // Validate message structure and semantics
    try validateMessageSemantics(message)
    try validateReservedFields(message)
    try validateExtensionRules(message)
    try validateMessageOptions(message.options)

    // Validate fields
    var usedFieldNumbers = Set<Int>()
    for field in message.fields {
      if !usedFieldNumbers.insert(field.number).inserted {
        throw ValidationError.duplicateMessageFieldNumber(field.number, messageName: message.name)
      }
      try validateFieldTypeReference(field.type, inMessage: message)
      try validateFieldOptions(field.options)
    }

    // Validate oneofs
    for oneof in message.oneofs {
      try validateOneofSemantics(oneof)
      for field in oneof.fields {
        if !usedFieldNumbers.insert(field.number).inserted {
          throw ValidationError.duplicateMessageFieldNumber(
            field.number, messageName: message.name)
        }
      }
    }

    // Recursively validate nested messages
    for nestedMessage in message.messages {
      try validateNestedMessage(nestedMessage)
    }

    // Validate nested enums
    for nestedEnum in message.enums {
      try validateEnumSemantics(nestedEnum)
      try validateEnumValueSemantics(nestedEnum)
      try validateEnumValuesUniqueness(nestedEnum)
      try validateEnumOptions(nestedEnum.options)
    }
  }

  // Add new helper function for field type reference validation
  private func validateFieldTypeReference(_ type: TypeNode, inMessage message: MessageNode?)
    throws
  {
    switch type {
    case .scalar:
      return  // Scalar types are always valid
    case .map(let keyType, let valueType):
      // Validate map key type is valid
      guard keyType.canBeMapKey else {
        throw ValidationError.invalidMapKeyType(String(describing: keyType))
      }
      // Recursively validate value type
      try validateFieldTypeReference(valueType, inMessage: message)
    case .named(let typeName):
      try validateTypeReference(typeName, inMessage: message)
    }
  }

  // Helper function to build dependency graph
  private func buildDependencyGraph(_ file: FileNode) throws {
    for message in file.messages {
      let fullName = message.fullName(inPackage: currentPackage)
      var deps = Set<String>()

      // Add field type dependencies
      for field in message.fields {
        if case .named(let typeName) = field.type {
          deps.insert(resolveTypeName(typeName))
        }
      }

      dependencies[fullName] = deps
    }
  }

  // Helper function for final cross-reference validation
  private func validateCrossReferences(_ file: FileNode) throws {
    // Validate all type references are resolvable
    for message in file.messages {
      for field in message.fields {
        if case .named(let typeName) = field.type {
          let resolvedName = resolveTypeName(typeName)
          if definedTypes[resolvedName] == nil && importedTypes[resolvedName] == nil {
            throw ValidationError.undefinedType(typeName, referencedIn: message.name)
          }
        }
      }
    }

    // Validate service type references
    for service in file.services {
      for rpc in service.rpcs {
        // Validate input type
        let inputType = resolveTypeName(rpc.inputType)
        if definedTypes[inputType] == nil && importedTypes[inputType] == nil {
          throw ValidationError.undefinedType(rpc.inputType, referencedIn: service.name)
        }

        // Validate output type
        let outputType = resolveTypeName(rpc.outputType)
        if definedTypes[outputType] == nil && importedTypes[outputType] == nil {
          throw ValidationError.undefinedType(rpc.outputType, referencedIn: service.name)
        }
      }
    }
  }

  //  // Helper function to resolve type names
  //  private func resolveTypeName(_ name: String) -> String {
  //    if name.hasPrefix(".") {
  //      return String(name.dropFirst())
  //    }
  //    if let currentPackage = currentPackage, !currentPackage.isEmpty {
  //      return "\(currentPackage).\(name)"
  //    }
  //    return name
  //  }

  private func validateTypeReference(_ typeName: String, inMessage message: MessageNode?) throws {
    // Handle fully qualified names (starting with dot)
    let typeToCheck = typeName.hasPrefix(".") ? String(typeName.dropFirst()) : typeName

    // Split into components
    let components = typeToCheck.split(separator: ".")

    if components.count > 1 {
      // Handle nested type references
      try validateNestedTypeReference(components, referencedIn: message?.name ?? "service")
      return
    }

    // Search in order:
    // 1. Current message scope (if within message)
    // 2. Current package
    // 3. Root scope
    // 4. Imported types

    // 1. Check current message scope if available
    if message != nil {
      for scope in scopeStack.reversed() {
        let fullName = "\(scope.typeName).\(typeToCheck)"
        if definedTypes[fullName] != nil {
          return
        }
      }
    }

    // 2. Check current package
    if let currentPackage = currentPackage {
      let fullName = "\(currentPackage).\(typeToCheck)"
      if definedTypes[fullName] != nil {
        return
      }
    }

    // 3. Check root scope
    if definedTypes[typeToCheck] != nil {
      return
    }

    // 4. Check imported types
    if importedTypes[typeToCheck] != nil {
      return
    }

    throw ValidationError.undefinedType(typeName, referencedIn: message?.name ?? "service")
  }

  private func validateNestedTypeReference(_ components: [Substring], referencedIn: String) throws {
    var currentPath = ""

    // Handle first component
    let firstComponent = String(components[0])
    if let currentPackage = currentPackage {
      // Try package-qualified first
      let packageQualified = "\(currentPackage).\(firstComponent)"
      if definedTypes[packageQualified] != nil {
        currentPath = packageQualified
      }
    }

    // If not found in package, try root scope
    if currentPath.isEmpty {
      if definedTypes[firstComponent] != nil {
        currentPath = firstComponent
      } else {
        throw ValidationError.undefinedType(firstComponent, referencedIn: referencedIn)
      }
    }

    // Validate remaining components
    for component in components.dropFirst() {
      currentPath = "\(currentPath).\(component)"
      if definedTypes[currentPath] == nil {
        throw ValidationError.undefinedType(currentPath, referencedIn: referencedIn)
      }
    }
  }

  // Managing scope stack
  private func pushScope(_ node: DefinitionNode) {
    let name = getScopedName(for: node)
    scopeStack.append(Scope(typeName: name, node: node))
  }

  private func popScope() {
    scopeStack.removeLast()
  }

  private func getScopedName(for node: DefinitionNode) -> String {
    if scopeStack.isEmpty {
      return currentPackage.map { "\($0).\(node.name)" } ?? node.name
    }
    return "\(scopeStack.last!.typeName).\(node.name)"
  }

  private func validateSemanticRules(_ file: FileNode) throws {
    // Validate syntax version
    if file.syntax != "proto3" {
      throw ValidationError.invalidSyntaxVersion(file.syntax)
    }

    // Validate enums
    for enumType in file.enums {
      try validateEnumSemantics(enumType)
    }

    // Validate messages
    for message in file.messages {
      try validateMessageSemantics(message)
    }

    // Validate services
    for service in file.services {
      try validateServiceSemantics(service)
    }
  }

  private func validateEnumSemantics(_ enumType: EnumNode) throws {
    // Must have at least one value
    guard !enumType.values.isEmpty else {
      throw ValidationError.emptyEnum(enumType.name)
    }

    // First value must be zero in proto3
    guard let firstValue = enumType.values.first,
      firstValue.number == 0
    else {
      throw ValidationError.firstEnumValueNotZero(enumType.name)
    }

    // Check for duplicate values unless allow_alias is enabled
    let allowAlias = enumType.options.contains { option in
      option.name == "allow_alias" && option.value == .identifier("true")
    }

    var usedNumbers = Set<Int>()
    for value in enumType.values {
      if !allowAlias && !usedNumbers.insert(value.number).inserted {
        throw ValidationError.duplicateEnumValue(value.name, value: value.number)
      }
    }
  }

  private func validateMessageSemantics(_ message: MessageNode) throws {
    // Check empty oneof
    for oneof in message.oneofs {
      guard !oneof.fields.isEmpty else {
        throw ValidationError.emptyOneof(oneof.name)
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

    // Recursively validate nested enums
    for nestedEnum in message.enums {
      try validateEnumSemantics(nestedEnum)
    }
  }

  private func validateServiceSemantics(_ service: ServiceNode) throws {
    // Check duplicate method names
    var methodNames = Set<String>()
    for rpc in service.rpcs {
      if !methodNames.insert(rpc.name).inserted {
        throw ValidationError.duplicateMethodName(rpc.name)
      }
    }

    // Input/output type validation will be done later during type resolution
  }

  private func validateFile(_ file: FileNode) throws {
    // Validate syntax version
    if file.syntax != "proto3" {
      throw ValidationError.invalidSyntaxVersion(file.syntax)
    }

    // Validate package if present
    if let package = file.package {
      try validatePackageName(package)
    }

    // Validate imports
    for imp in file.imports {
      try validateImport(imp)
    }

    // Validate all options
    for option in file.options {
      try validateFileOption(option)
    }

    // Validate all messages
    for message in file.messages {
      try validateMessage(message)
    }

    // Validate all enums
    for enumType in file.enums {
      try validateEnum(enumType)
    }

    // Validate all services
    for service in file.services {
      try validateService(service)
    }
  }

  // MARK: - Field Validation

  private func validateField(_ field: FieldNode, inMessage message: MessageNode) throws {
    // Validate field number
    try validateFieldNumber(field.number, location: field.location)

    // Validate name
    try validateFieldName(field.name, inMessage: message)

    // Validate type
    try validateFieldType(field.type, inField: field.name, inMessage: message)

    // Validate field rules (repeated/optional)
    try validateFieldRules(field)

    // Validate options
    try validateFieldOptions(field.options)
  }

  private func validateFieldNumber(_ number: Int, location: SourceLocation) throws {
    // Check basic range
    guard number > 0 else {
      throw ValidationError.invalidFieldNumber(number, location: location)
    }

    guard number <= 536_870_911 else {
      throw ValidationError.invalidFieldNumber(number, location: location)
    }

    // Check reserved range
    if (19000...19999).contains(number) {
      throw ValidationError.invalidFieldNumber(number, location: location)
    }
  }

  private func validateFieldName(_ name: String, inMessage message: MessageNode) throws {
    // Check name format
    guard isValidFieldName(name) else {
      throw ValidationError.invalidFieldName(name)
    }

    // Check for reserved names
    if message.reservedNames.contains(name) {
      throw ValidationError.reservedFieldName(name)
    }

    // Check for duplicates
    if message.usedFieldNames.contains(name) {
      throw ValidationError.duplicateFieldName(name, inType: message.name)
    }
  }

  private func validateFieldType(
    _ type: TypeNode, inField field: String, inMessage message: MessageNode
  ) throws {
    switch type {
    case .scalar:
      return  // All scalar types are valid
    case .map(let keyType, let valueType):
      try validateMapKeyType(keyType, inField: field)
      try validateFieldType(valueType, inField: field, inMessage: message)
    case .named(let typeName):
      try validateTypeReference(typeName, inMessage: message)
    }
  }

  private func validateMapKeyType(_ type: TypeNode.ScalarType, inField field: String) throws {
    switch type {
    case .int32, .int64, .uint32, .uint64, .sint32, .sint64,
      .fixed32, .fixed64, .sfixed32, .sfixed64,
      .bool, .string:
      return  // Valid map key types
    case .float, .double, .bytes:
      throw
        ValidationError
        .invalidMapKeyType(String(describing: type))
    }
  }

  //  private func validateFieldRules(_ field: FieldNode) throws {
  //    // Map fields can't be repeated
  //    if field.isRepeated {
  //      if case .map = field.type {
  //        throw ValidationError.repeatedMapField(field.name)
  //      }
  //    }
  //  }

  // MARK: - Type Collection

  private func collectDefinedTypes(_ file: FileNode) throws {
    for type in file.allDefinedTypes {
      let fullName = type.fullName(inPackage: currentPackage)
      if definedTypes[fullName] != nil {
        throw ValidationError.duplicateTypeName(fullName)
      }
      definedTypes[fullName] = type
    }
  }

  // MARK: - Field Validation

  private func validateField(_ field: FieldNode, in message: MessageNode) throws {
    // Validate field name format
    if !isValidFieldName(field.name) {
      throw ValidationError.custom("Invalid field name: '\(field.name)'")
    }

    try validateFieldNumber(field.number, location: field.location)

    // Validate map fields
    if case .map(let keyType, _) = field.type {
      if !keyType.canBeMapKey {
        throw ValidationError.invalidMapKeyType(String(describing: keyType))
      }
      if field.isRepeated {
        throw ValidationError.repeatedMapField(field.name)
      }
    }

    // Validate options
    for option in field.options {
      try validateFieldOption(option)
    }
  }

  private func validateOneof(_ oneof: OneofNode, in message: MessageNode) throws {
    var fieldNames = Set<String>()
    var fieldNumbers = Set<Int>()

    for field in oneof.fields {
      if !fieldNames.insert(field.name).inserted {
        throw ValidationError.duplicateFieldName(field.name, inType: message.name)
      }

      if !fieldNumbers.insert(field.number).inserted {
        throw ValidationError.custom(
          "Duplicate field number \(field.number) in oneof '\(oneof.name)'")
      }

      // Oneof fields cannot be repeated
      if field.isRepeated {
        throw ValidationError.custom(
          "Field '\(field.name)' in oneof '\(oneof.name)' cannot be repeated")
      }
    }
  }

  private func resolveTypeName(_ name: String) -> String {
    if name.contains(".") {
      return name
    }
    if let package = currentPackage {
      return "\(package).\(name)"
    }
    return name
  }

  private func isValidFieldName(_ name: String) -> Bool {
    guard let first = name.first else { return false }
    return (first.isLowercase || first == "_")
      && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
  }

  //  private func validateFieldOptions(_ options: [OptionNode]) throws {
  //    for option in options {
  //      switch option.name {
  //      case "deprecated":
  //        // deprecated must be boolean
  //        guard case .identifier(let value) = option.value,
  //          value == "true" || value == "false"
  //        else {
  //          throw ValidationError.invalidOptionValue("deprecated must be a boolean")
  //        }
  //
  //      case "packed":
  //        // packed can be only used with repeated scalar fields
  //        guard case .identifier(let value) = option.value,
  //          value == "true" || value == "false"
  //        else {
  //          throw ValidationError.invalidOptionValue("packed must be a boolean")
  //        }
  //
  //      case "json_name":
  //        // json_name must be string
  //        guard case .string = option.value else {
  //          throw ValidationError.invalidOptionValue("json_name must be a string")
  //        }
  //
  //      default:
  //        // Handle custom options (ones in parentheses)
  //        if option.name.hasPrefix("(") {
  //          // Validate custom option format - must be (package.option_name) or (option_name)
  //          let name = String(option.name.dropFirst().dropLast())
  //          let components = name.split(separator: ".")
  //          guard !components.isEmpty else {
  //            throw ValidationError.invalidOptionName(option.name)
  //          }
  //          // Custom option validation would go here
  //        } else {
  //          throw ValidationError.unknownOption(option.name)
  //        }
  //      }
  //    }
  //  }

  func resolveСurrentScope(
    currentScope: String,
    typeName: String,
    messageName: String
  ) throws -> String {
    if definedTypes[currentScope] != nil {
      return currentScope
    }

    // Если не найден, а пакет доступен — формируем комбинированное имя
    guard let package = currentPackage else {
      throw ValidationError.undefinedType(typeName, referencedIn: messageName)
    }

    let combinedScope = "\(package).\(currentScope)"
    if definedTypes[combinedScope] == nil {
      throw ValidationError.undefinedType(typeName, referencedIn: messageName)
    }

    return combinedScope
  }
}

extension Validator {
  private func collectImportedTypes(_ file: FileNode) throws {
    for imp in file.imports {
      // We need some kind of import resolver here to get imported file content
      // For now, assume imported types are already resolved
      // This should be replaced with proper import resolution
      let imported = importedDefinitions[imp.path] ?? []
      for type in imported {
        importedTypes[type.name] = imp.path
      }
    }
  }

  private func validatePackageName(_ package: String) throws {
    let components = package.split(separator: ".")

    // Package name can't be empty
    guard !components.isEmpty else {
      throw ValidationError.invalidPackageName(package)
    }

    // Each component must be a valid identifier
    for component in components {
      // Must start with letter or underscore
      guard let first = component.first,
        first.isLetter || first == "_"
      else {
        throw ValidationError.invalidPackageName(package)
      }

      // Can only contain letters, numbers, and underscores
      guard component.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
        throw ValidationError.invalidPackageName(package)
      }
    }
  }

  private func validateImport(_ imp: ImportNode) throws {
    // Import path can't be empty
    guard !imp.path.isEmpty else {
      throw ValidationError.invalidImport("Empty import path")
    }

    // Path can't contain ../
    guard !imp.path.contains("../") else {
      throw ValidationError.invalidImport("Import path cannot contain '../'")
    }

    // Check for circular imports (would need import resolver)
    // For now just mark as TODO
    // TODO: Implement circular import detection
  }

  private func validateFileOption(_ option: OptionNode) throws {
    // Built-in file options
    switch option.name {
    case "java_package":
      guard case .string = option.value else {
        throw ValidationError.invalidOptionValue("java_package must be a string")
      }

    case "java_outer_classname":
      guard case .string = option.value else {
        throw ValidationError.invalidOptionValue("java_outer_classname must be a string")
      }

    case "optimize_for":
      guard case .identifier(let value) = option.value,
        ["SPEED", "CODE_SIZE", "LITE_RUNTIME"].contains(value.uppercased())
      else {
        throw ValidationError.invalidOptionValue(
          "optimize_for must be SPEED, CODE_SIZE, or LITE_RUNTIME")
      }

    case "cc_enable_arenas":
      guard case .identifier(let value) = option.value,
        value == "true" || value == "false"
      else {
        throw ValidationError.invalidOptionValue("cc_enable_arenas must be a boolean")
      }

    // Add other built-in options...

    default:
      if option.name.hasPrefix("(") {
        try validateCustomOption(option)
      } else {
        throw ValidationError.unknownOption(option.name)
      }
    }
  }

  private func validateEnum(_ enumType: EnumNode) throws {
    // Must have at least one value
    guard !enumType.values.isEmpty else {
      throw ValidationError.emptyEnum(enumType.name)
    }

    // First value must be zero in proto3
    guard let firstValue = enumType.values.first,
      firstValue.number == 0
    else {
      throw ValidationError.firstEnumValueNotZero(enumType.name)
    }

    var usedNames = Set<String>()
    var usedNumbers = Set<Int>()

    // Track if allow_alias is enabled
    let allowAlias = enumType.options.contains { option in
      option.name == "allow_alias" && option.value == .identifier("true")
    }

    for value in enumType.values {
      // Check name uniqueness
      if !usedNames.insert(value.name).inserted {
        throw ValidationError.duplicateEnumValue(value.name, value: value.number)
      }

      // Check number uniqueness unless allow_alias is true
      if !allowAlias && !usedNumbers.insert(value.number).inserted {
        throw ValidationError.duplicateEnumValue(value.name, value: value.number)
      }

      // Validate enum value options
      for option in value.options {
        try validateEnumValueOption(option)
      }
    }
  }

  private func validateService(_ service: ServiceNode) throws {
    var methodNames = Set<String>()

    for rpc in service.rpcs {
      // Check method name uniqueness
      if !methodNames.insert(rpc.name).inserted {
        throw ValidationError.duplicateMethodName(rpc.name)
      }

      // Validate input type
      try validateTypeReference(rpc.inputType, inMessage: nil)

      // Validate output type
      try validateTypeReference(rpc.outputType, inMessage: nil)

      // Validate RPC options
      for option in rpc.options {
        try validateRPCOption(option)
      }
    }
  }

  private func validateCustomOption(_ option: OptionNode) throws {
    // Custom option format must be (foo.bar.baz)
    let name = option.name.dropFirst().dropLast()  // Remove ( )
    let components = name.split(separator: ".")

    // Must have at least one component
    guard !components.isEmpty else {
      throw ValidationError.invalidOptionName(option.name)
    }

    // Each component must be valid identifier
    for component in components {
      guard let first = component.first,
        first.isLetter || first == "_",
        component.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" })
      else {
        throw ValidationError.invalidOptionName(option.name)
      }
    }

    // TODO: Validate option is actually declared
    // This would require having access to custom option declarations
  }

  private func validateEnumValueOption(_ option: OptionNode) throws {
    // Only few options are valid for enum values
    switch option.name {
    case "deprecated":
      guard case .identifier(let value) = option.value,
        value == "true" || value == "false"
      else {
        throw ValidationError.invalidOptionValue("deprecated must be a boolean")
      }

    default:
      if option.name.hasPrefix("(") {
        try validateCustomOption(option)
      } else {
        throw ValidationError.unknownOption(option.name)
      }
    }
  }

  private func validateRPCOption(_ option: OptionNode) throws {
    // Validate RPC-specific options
    switch option.name {
    case "deprecated":
      guard case .identifier(let value) = option.value,
        value == "true" || value == "false"
      else {
        throw ValidationError.invalidOptionValue("deprecated must be a boolean")
      }

    case "idempotency_level":
      guard case .identifier(let value) = option.value,
        ["IDEMPOTENCY_UNKNOWN", "NO_SIDE_EFFECTS", "IDEMPOTENT"].contains(value)
      else {
        throw ValidationError.invalidOptionValue(
          "idempotency_level must be IDEMPOTENCY_UNKNOWN, NO_SIDE_EFFECTS, or IDEMPOTENT"
        )
      }

    default:
      if option.name.hasPrefix("(") {
        try validateCustomOption(option)
      } else {
        throw ValidationError.unknownOption(option.name)
      }
    }
  }

  private func checkCyclicDependencies() throws {
    var visited = Set<String>()
    var stack = Set<String>()

    func dfs(_ type: String, path: [String]) throws {
      if stack.contains(type) {
        throw ValidationError.cyclicDependency(path + [type])
      }
      if visited.contains(type) {
        return
      }

      visited.insert(type)
      stack.insert(type)

      if let deps = dependencies[type] {
        for dep in deps {
          try dfs(dep, path: path + [type])
        }
      }

      stack.remove(type)
    }

    for type in definedTypes.keys {
      try dfs(type, path: [])
    }
  }

  private func validateMessage(_ message: MessageNode) throws {
    pushScope(message)
    defer { popScope() }

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

    // Validate nested enums
    for nestedEnum in message.enums {
      try validateEnum(nestedEnum)
    }

    // Validate message options
    for option in message.options {
      try validateMessageOption(option)
    }
  }

  private func validateFieldOption(_ option: OptionNode) throws {
    switch option.name {
    case "deprecated":
      guard case .identifier(let value) = option.value,
        value == "true" || value == "false"
      else {
        throw ValidationError.invalidOptionValue("deprecated must be a boolean")
      }

    case "packed":
      guard case .identifier(let value) = option.value,
        value == "true" || value == "false"
      else {
        throw ValidationError.invalidOptionValue("packed must be a boolean")
      }

    case "json_name":
      guard case .string = option.value else {
        throw ValidationError.invalidOptionValue("json_name must be a string")
      }

    case "ctype":
      guard case .identifier(let value) = option.value,
        ["STRING", "CORD", "STRING_PIECE"].contains(value.uppercased())
      else {
        throw ValidationError.invalidOptionValue("ctype must be STRING, CORD, or STRING_PIECE")
      }

    default:
      if option.name.hasPrefix("(") {
        try validateCustomOption(option)
      } else {
        throw ValidationError.unknownOption(option.name)
      }
    }
  }

  private func validateMessageOption(_ option: OptionNode) throws {
    switch option.name {
    case "message_set_wire_format":
      guard case .identifier(let value) = option.value,
        value == "true" || value == "false"
      else {
        throw ValidationError.invalidOptionValue("message_set_wire_format must be a boolean")
      }

    case "no_standard_descriptor_accessor":
      guard case .identifier(let value) = option.value,
        value == "true" || value == "false"
      else {
        throw ValidationError.invalidOptionValue(
          "no_standard_descriptor_accessor must be a boolean")
      }

    case "deprecated":
      guard case .identifier(let value) = option.value,
        value == "true" || value == "false"
      else {
        throw ValidationError.invalidOptionValue("deprecated must be a boolean")
      }

    case "map_entry":
      guard case .identifier(let value) = option.value,
        value == "true" || value == "false"
      else {
        throw ValidationError.invalidOptionValue("map_entry must be a boolean")
      }

    default:
      if option.name.hasPrefix("(") {
        try validateCustomOption(option)
      } else {
        throw ValidationError.unknownOption(option.name)
      }
    }
  }
}

extension Validator {
  // MARK: - Basic Structure Rules

  private func validateSyntaxVersion(_ syntax: String) throws {
    // In proto3, syntax must be exactly "proto3"
    guard syntax == "proto3" else {
      throw ValidationError.invalidSyntaxVersion(syntax)
    }
  }

  private func validatePackageSemantics(_ package: String) throws {
    let components = package.split(separator: ".")

    // Package name can't be empty
    guard !components.isEmpty else {
      throw ValidationError.invalidPackageName(package)
    }

    for component in components {
      // Each component must start with lowercase letter
      guard let first = component.first,
        first.isLowercase
      else {
        throw ValidationError.invalidPackageName(package)
      }

      // Can only contain lowercase letters, numbers and underscores
      guard component.allSatisfy({ $0.isLowercase || $0.isNumber || $0 == "_" }) else {
        throw ValidationError.invalidPackageName(package)
      }
    }
  }

  private func validateImportSemantics(_ importNode: ImportNode) throws {
    // Import path can't be empty
    guard !importNode.path.isEmpty else {
      throw ValidationError.invalidImport("Empty import path")
    }

    // Import path must be a string literal with .proto extension
    guard importNode.path.hasSuffix(".proto") else {
      throw ValidationError.invalidImport("Import path must end with .proto")
    }

    // Path cannot contain ../ (directory traversal)
    guard !importNode.path.contains("../") else {
      throw ValidationError.invalidImport("Import path cannot contain '../'")
    }

    // Path must be a valid file path
    guard
      importNode.path.allSatisfy({
        $0.isLetter || $0.isNumber || $0 == "_" || $0 == "/" || $0 == "." || $0 == "-"
      })
    else {
      throw ValidationError.invalidImport("Import path contains invalid characters")
    }

    // Public imports cannot be weak
    if importNode.modifier == .public {
      guard importNode.modifier != .weak else {
        throw ValidationError.invalidImport("Import cannot be both public and weak")
      }
    }
  }

  // MARK: - Name Rules

  private func validateMessageNameSemantics(_ name: String) throws {
    // Message name can't be empty
    guard !name.isEmpty else {
      throw ValidationError.invalidMessageName("Message name cannot be empty")
    }

    // Must start with uppercase letter
    guard let first = name.first,
      first.isUppercase
    else {
      throw ValidationError.invalidMessageName(
        "Message name '\(name)' must start with uppercase letter")
    }

    // Can contain only letters, numbers, and underscores
    guard name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
      throw ValidationError.invalidMessageName("Message name '\(name)' contains invalid characters")
    }

    // Cannot be a reserved word
    let reservedWords = [
      "syntax", "import", "weak", "public", "package", "option",
      "true", "false", "inf", "nan", "repeated", "optional", "required",
    ]
    guard !reservedWords.contains(name.lowercased()) else {
      throw ValidationError.invalidMessageName("Message name '\(name)' cannot be a reserved word")
    }
  }

  private func validateFieldNameSemantics(_ name: String) throws {
    // Field name can't be empty
    guard !name.isEmpty else {
      throw ValidationError.invalidFieldName("Field name cannot be empty")
    }

    // Must start with lowercase letter or underscore
    guard let first = name.first,
      first.isLowercase || first == "_"
    else {
      throw ValidationError.invalidFieldName(
        "Field name '\(name)' must start with lowercase letter or underscore")
    }

    // Can contain only letters, numbers, and underscores
    guard name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
      throw ValidationError.invalidFieldName("Field name '\(name)' contains invalid characters")
    }

    // Check against absolutely reserved keywords
    let reservedKeywords = [
      "syntax", "import", "package", "option", "service",
      "rpc", "returns", "reserved", "oneof", "repeated",
    ]
    guard !reservedKeywords.contains(name) else {
      throw ValidationError.invalidFieldName("Field name '\(name)' cannot be a reserved keyword")
    }
  }

  private func validateEnumNameSemantics(_ name: String) throws {
    // Enum name can't be empty
    guard !name.isEmpty else {
      throw ValidationError.invalidEnumName("Enum name cannot be empty")
    }

    // Must start with uppercase letter
    guard let first = name.first,
      first.isUppercase
    else {
      throw ValidationError.invalidEnumName("Enum name '\(name)' must start with uppercase letter")
    }

    // Can contain only letters, numbers, and underscores
    guard name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
      throw ValidationError.invalidEnumName("Enum name '\(name)' contains invalid characters")
    }

    // Cannot be a reserved word
    let reservedWords = [
      "syntax", "import", "weak", "public", "package", "option",
      "true", "false", "inf", "nan", "repeated", "optional", "required",
    ]
    guard !reservedWords.contains(name.lowercased()) else {
      throw ValidationError.invalidEnumName("Enum name '\(name)' cannot be a reserved word")
    }
  }

  private func validateEnumValueNameSemantics(_ name: String) throws {
    // Enum value name can't be empty
    guard !name.isEmpty else {
      throw ValidationError.invalidEnumValueName("Enum value name cannot be empty")
    }

    // Must start with uppercase letter or underscore
    guard let first = name.first,
      first.isUppercase || first == "_"
    else {
      throw ValidationError.invalidEnumValueName(
        "Enum value name '\(name)' must start with uppercase letter or underscore")
    }

    // Must be in UPPERCASE_WITH_UNDERSCORES format
    guard name.allSatisfy({ $0.isUppercase || $0.isNumber || $0 == "_" }) else {
      throw ValidationError.invalidEnumValueName(
        "Enum value name '\(name)' must be in UPPERCASE_WITH_UNDERSCORES format")
    }

    // Cannot be a reserved word
    let reservedWords = [
      "SYNTAX", "IMPORT", "WEAK", "PUBLIC", "PACKAGE", "OPTION",
      "TRUE", "FALSE", "INF", "NAN", "REPEATED", "OPTIONAL", "REQUIRED",
    ]
    guard !reservedWords.contains(name) else {
      throw ValidationError.invalidEnumValueName(
        "Enum value name '\(name)' cannot be a reserved word")
    }
  }

  private func validateServiceNameSemantics(_ name: String) throws {
    // Service name can't be empty
    guard !name.isEmpty else {
      throw ValidationError.invalidServiceName("Service name cannot be empty")
    }

    // Must start with uppercase letter
    guard let first = name.first,
      first.isUppercase
    else {
      throw ValidationError.invalidServiceName(
        "Service name '\(name)' must start with uppercase letter")
    }

    // Can contain only letters, numbers, and underscores
    guard name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
      throw ValidationError.invalidServiceName("Service name '\(name)' contains invalid characters")
    }

    // Cannot be a reserved word
    let reservedWords = [
      "syntax", "import", "weak", "public", "package", "option",
      "message", "enum", "oneof", "map", "repeated", "optional",
    ]
    guard !reservedWords.contains(name.lowercased()) else {
      throw ValidationError.invalidServiceName("Service name '\(name)' cannot be a reserved word")
    }

    // Conventionally should end with 'Service' but it's not a strict requirement
    // Could add as a warning in the future
  }

  private func validateMethodNameSemantics(_ name: String) throws {
    // Method name can't be empty
    guard !name.isEmpty else {
      throw ValidationError.invalidMethodName("Method name cannot be empty")
    }

    // Must start with letter
    // Note: protoc allows both upper and lower case for method names
    guard let first = name.first,
      first.isLetter
    else {
      throw ValidationError.invalidMethodName("Method name '\(name)' must start with a letter")
    }

    // Can contain only letters, numbers, and underscores
    guard name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
      throw ValidationError.invalidMethodName("Method name '\(name)' contains invalid characters")
    }

    // Cannot be a reserved word
    let reservedWords = [
      "syntax", "import", "weak", "public", "package", "option",
      "message", "enum", "service", "rpc", "returns", "stream",
    ]
    guard !reservedWords.contains(name.lowercased()) else {
      throw ValidationError.invalidMethodName("Method name '\(name)' cannot be a reserved word")
    }
  }

  // MARK: - Field Rules

  private func validateFieldNumberSemantics(_ number: Int, field: FieldNode) throws {
    // Field numbers must be positive
    guard number > 0 else {
      throw ValidationError.invalidFieldNumber(number, location: field.location)
    }

    // Field numbers must be less than 536,870,911 (2^29 - 1)
    guard number <= 536_870_911 else {
      throw ValidationError.invalidFieldNumber(number, location: field.location)
    }

    // Numbers in the range 19000-19999 are reserved for the protocol buffer implementation
    guard !(19000...19999).contains(number) else {
      throw ValidationError.invalidFieldNumber(number, location: field.location)
    }

    // Special numbers
    // 1-15 use 1 byte in encoding
    // 16-2047 use 2 bytes
    // Field numbers 1 through 15 should be used for frequently occurring message elements
    // Only repeated fields of primitive numeric types (types which use varint, 32-bit, or 64-bit wire types) can be packed

    // Note: While the above are best practices, they're not strict requirements,
    // so we don't throw errors for them. Could be added as warnings in the future.
  }

  private func validateFieldRules(_ field: FieldNode) throws {
    // Handle map fields
    if case .map = field.type {
      // Map fields cannot be repeated
      if field.isRepeated {
        throw ValidationError.repeatedMapField(field.name)
      }

      // Map fields cannot be optional
      if field.isOptional {
        throw ValidationError.optionalMapField(field.name)
      }
    }

    // Handle scalar fields
    if case .scalar(let scalarType) = field.type {
      // Check packed option for repeated fields
      if field.isRepeated {
        let hasPacked = field.options.contains { option in
          option.name == "packed" && option.value == .identifier("true")
        }

        // Only numeric types and enums can be packed
        let packableTypes: [TypeNode.ScalarType] = [
          .int32, .int64, .uint32, .uint64,
          .sint32, .sint64, .fixed32, .fixed64,
          .sfixed32, .sfixed64, .float, .double,
          .bool,  // bool is packable too
        ]

        if hasPacked && !packableTypes.contains(scalarType) {
          throw ValidationError.unpackableFieldType(field.name, scalarType)
        }
      }
    }

    // Handle oneof fields
    if field.oneof != nil {
      // Oneof fields cannot be repeated
      if field.isRepeated {
        throw ValidationError.repeatedOneof(field.name)
      }

      // Oneof fields cannot be optional
      if field.isOptional {
        throw ValidationError.optionalOneof(field.name)
      }
    }
  }

  private func validateMapFieldSemantics(_ field: FieldNode) throws {
    guard case .map(let keyType, let valueType) = field.type else {
      return  // Not a map field
    }

    // Validate key type
    // Map key types are restricted to:
    // integral types, bool, string
    let validKeyTypes: [TypeNode.ScalarType] = [
      .int32, .int64, .uint32, .uint64,
      .sint32, .sint64, .fixed32, .fixed64,
      .sfixed32, .sfixed64, .bool, .string,
    ]

    guard validKeyTypes.contains(keyType) else {
      throw ValidationError.invalidMapKeyType(String(describing: keyType))
    }

    // Validate value type
    switch valueType {
    case .map:
      // Map values cannot be another map
      throw ValidationError.invalidMapValueType("map")

    case .scalar:
      // All scalar types are valid for map values
      break

    case .named:
      // Message and enum types are valid for map values
      // Type existence will be checked during type resolution
      break
    }
  }

  private func validateOneofSemantics(_ oneof: OneofNode) throws {
    // Oneof name can't be empty
    guard !oneof.name.isEmpty else {
      throw ValidationError.emptyOneof(oneof.name)
    }

    // Must start with lowercase letter or underscore
    guard let first = oneof.name.first,
      first.isLowercase || first == "_"
    else {
      throw ValidationError.invalidFieldName(oneof.name)
    }

    // Can only contain letters, numbers and underscores
    guard oneof.name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
      throw ValidationError.invalidFieldName(oneof.name)
    }

    // Must have at least one field
    guard !oneof.fields.isEmpty else {
      throw ValidationError.emptyOneof(oneof.name)
    }

    // Track used names and numbers within this oneof
    var usedNames = Set<String>()
    var usedNumbers = Set<Int>()

    for field in oneof.fields {
      // Fields in oneof cannot be repeated
      if field.isRepeated {
        throw ValidationError.repeatedOneof(field.name)
      }

      // Fields in oneof cannot be optional
      if field.isOptional {
        throw ValidationError.optionalOneof(field.name)
      }

      // Check for duplicate field names within oneof
      if !usedNames.insert(field.name).inserted {
        throw ValidationError.duplicateFieldName(field.name, inType: oneof.name)
      }

      // Check for duplicate field numbers within oneof
      if !usedNumbers.insert(field.number).inserted {
        throw ValidationError.duplicateMessageFieldNumber(field.number, messageName: oneof.name)
      }

      // Validate field type
      switch field.type {
      case .map:
        // Map fields cannot be in oneof
        throw ValidationError.custom("Map fields are not allowed in oneof: \(field.name)")
      case .scalar:
        // All scalar types are allowed
        break
      case .named(let typeName):
        // Validate that the referenced type exists
        try validateTypeReference(typeName, inMessage: nil)
      }
    }
  }

  private func validateReservedFields(_ message: MessageNode) throws {
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

          // Check reserved ranges
          guard !(19000...19999).contains(number) else {
            throw ValidationError.invalidFieldNumber(number, location: reserved.location)
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

            // Check reserved ranges
            guard !(19000...19999).contains(num) else {
              throw ValidationError.invalidFieldNumber(num, location: reserved.location)
            }
          }

        case .name(let name):
          // Validate name format
          guard isValidFieldName(name) else {
            throw ValidationError.invalidFieldName(name)
          }

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

  // MARK: - Enum Rules

  private func validateEnumValueSemantics(_ enumType: EnumNode) throws {
    // Must have at least one value
    guard !enumType.values.isEmpty else {
      throw ValidationError.emptyEnum(enumType.name)
    }

    // First value must be zero in proto3
    guard let firstValue = enumType.values.first,
      firstValue.number == 0
    else {
      throw ValidationError.firstEnumValueNotZero(enumType.name)
    }

    var usedNames = Set<String>()
    var usedNumbers = Set<Int>()

    // Check if allow_alias is enabled via option
    let allowAlias = enumType.options.contains { option in
      option.name == "allow_alias" && option.value == .identifier("true")
    }

    for value in enumType.values {
      // Validate enum value name format
      guard let first = value.name.first,
        first.isUppercase || first == "_"
      else {
        throw ValidationError.invalidEnumValueName(
          "Enum value name '\(value.name)' must start with uppercase letter or underscore")
      }

      // Must be in UPPERCASE_WITH_UNDERSCORES format
      guard value.name.allSatisfy({ $0.isUppercase || $0.isNumber || $0 == "_" }) else {
        throw ValidationError.invalidEnumValueName(
          "Enum value name '\(value.name)' must be in UPPERCASE_WITH_UNDERSCORES format")
      }

      // Check for reserved keywords
      let reservedWords = [
        "SYNTAX", "IMPORT", "WEAK", "PUBLIC", "PACKAGE", "OPTION",
        "TRUE", "FALSE", "INF", "NAN", "REPEATED", "OPTIONAL", "REQUIRED",
      ]
      if reservedWords.contains(value.name) {
        throw ValidationError.invalidEnumValueName(
          "Enum value name '\(value.name)' cannot be a reserved word")
      }

      // Check for duplicate names (never allowed, even with allow_alias)
      if !usedNames.insert(value.name).inserted {
        throw ValidationError.duplicateEnumValue(value.name, value: value.number)
      }

      // Check for duplicate numbers (allowed only if allow_alias is true)
      if !allowAlias && !usedNumbers.insert(value.number).inserted {
        throw ValidationError.duplicateEnumValue(value.name, value: value.number)
      }

      // Validate value options
      for option in value.options {
        try validateEnumValueOption(option)
      }
    }

    // Additional proto3 specific validations
    for value in enumType.values {
      // In proto3, enum values must be non-negative
      if value.number < 0 {
        throw ValidationError.custom(
          "Enum value '\(value.name)' has negative number (\(value.number)). Proto3 only allows non-negative enum values"
        )
      }

      // Check for reserved range (19000-19999)
      if (19000...19999).contains(value.number) {
        throw ValidationError.custom(
          "Enum value '\(value.name)' uses number \(value.number) which is in the reserved range (19000-19999)"
        )
      }
    }
  }

  private func validateEnumValuesUniqueness(_ enumType: EnumNode) throws {
    var usedNames = Set<String>()
    var valueToNames: [Int: Set<String>] = [:]  // Track all names for each value number

    // Check if allow_alias is enabled
    let allowAlias = enumType.options.contains { option in
      option.name == "allow_alias" && option.value == .identifier("true")
    }

    for value in enumType.values {
      // Names must always be unique regardless of allow_alias
      if !usedNames.insert(value.name).inserted {
        throw ValidationError.custom(
          "Duplicate enum value name '\(value.name)' in enum '\(enumType.name)'")
      }

      // Track all names associated with each number
      if valueToNames[value.number] == nil {
        valueToNames[value.number] = []
      }
      valueToNames[value.number]?.insert(value.name)

      // If allow_alias is false, no number can have multiple names
      if !allowAlias && valueToNames[value.number]?.count ?? 0 > 1 {
        let aliasedNames = valueToNames[value.number]?.joined(separator: ", ") ?? ""
        throw ValidationError.custom(
          "Enum value number \(value.number) has multiple names (\(aliasedNames)) "
            + "but allow_alias is not set in enum '\(enumType.name)'")
      }
    }

    // Additional validation for allow_alias
    if allowAlias {
      // Find and validate all aliases
      for (number, names) in valueToNames where names.count > 1 {
        // In proto3, aliases can't use the number 0 (first enum value)
        if number == 0 {
          throw ValidationError.custom(
            "Enum value 0 cannot have aliases in proto3 (found values: \(names.joined(separator: ", ")))"
          )
        }

        // Log aliases if needed (could be useful for documentation)
        // print("Enum '\(enumType.name)' has aliases for value \(number): \(names.joined(separator: ", "))")
      }
    }

    // Validate sequential uniqueness within groups
    var lastNumber: Int?
    var currentGroup: Set<String> = []

    for value in enumType.values.sorted(by: { $0.number < $1.number }) {
      if let last = lastNumber, value.number != last {
        // New number group
        currentGroup.removeAll()
      }

      // Check if this name conflicts with others in the same number group
      if !currentGroup.insert(value.name).inserted {
        throw ValidationError.custom(
          "Duplicate enum value name '\(value.name)' for number \(value.number)")
      }

      lastNumber = value.number
    }

    // Additional proto3 specific validations
    let sortedValues = enumType.values.sorted(by: { $0.number < $1.number })
    if let firstValue = sortedValues.first {
      // Validate first value is 0
      if firstValue.number != 0 {
        throw ValidationError.firstEnumValueNotZero(enumType.name)
      }

      // In proto3, if allow_alias is true, all subsequent values with the same
      // number must be marked as aliases through options
      if allowAlias {
        for value in sortedValues where value.number != 0 {
          if valueToNames[value.number]?.count ?? 0 > 1 {
            // Check if this value has the appropriate alias option
            let hasAliasOption = value.options.contains { option in
              option.name == "alias" && option.value == .identifier("true")
            }
            if !hasAliasOption {
              throw ValidationError.custom(
                "Enum value '\(value.name)' is an alias but missing alias option")
            }
          }
        }
      }
    }
  }

  // MARK: - Service Rules

  private func validateMethodUniqueness(_ service: ServiceNode) throws {
    var methodNames = Set<String>()

    for rpc in service.rpcs {
      // Validate method name format
      guard let first = rpc.name.first,
        first.isUppercase
      else {
        throw ValidationError.invalidMethodName(
          "Method name '\(rpc.name)' must start with uppercase letter")
      }

      // Validate method name characters
      guard rpc.name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
        throw ValidationError.invalidMethodName(
          "Method name '\(rpc.name)' can only contain letters, numbers, and underscores")
      }

      // Check for reserved keywords
      let reservedWords = [
        "syntax", "import", "weak", "public", "package", "option",
        "message", "enum", "service", "rpc", "returns", "stream",
      ]
      if reservedWords.contains(rpc.name.lowercased()) {
        throw ValidationError.invalidMethodName(
          "Method name '\(rpc.name)' cannot be a reserved word")
      }

      // Check for duplicate method names
      if !methodNames.insert(rpc.name).inserted {
        throw ValidationError.duplicateMethodName(rpc.name)
      }

      // Validate input type exists and is a message
      try validateMethodType(rpc.inputType, isInput: true, methodName: rpc.name)

      // Validate output type exists and is a message
      try validateMethodType(rpc.outputType, isInput: false, methodName: rpc.name)

      // Validate streaming configuration
      if rpc.clientStreaming {
        try validateStreamingConfig(
          rpc.inputType,
          isInput: true,
          methodName: rpc.name
        )
      }

      if rpc.serverStreaming {
        try validateStreamingConfig(
          rpc.outputType,
          isInput: false,
          methodName: rpc.name
        )
      }
    }
  }

  private func validateMethodType(_ typeName: String, isInput: Bool, methodName: String) throws {
    // Handle fully qualified names (starting with dot)
    let typeToCheck = typeName.hasPrefix(".") ? String(typeName.dropFirst()) : typeName

    // Validate type exists
    try validateTypeReference(typeToCheck, inMessage: nil)

    // Ensure the type is a message (not an enum)
    if let type = definedTypes[typeToCheck] {
      guard type is MessageNode else {
        throw ValidationError.custom(
          "\(isInput ? "Input" : "Output") type '\(typeName)' in method '\(methodName)' must be a message"
        )
      }
    } else if let type = importedTypes[typeToCheck] {
      // For imported types, check if it's a message by looking up the imported definitions
      if let importedDefs = importedDefinitions[type],
        !importedDefs.contains(where: { $0 is MessageNode })
      {
        throw ValidationError.custom(
          "\(isInput ? "Input" : "Output") type '\(typeName)' in method '\(methodName)' must be a message"
        )
      }
    }
  }

  private func validateStreamingConfig(_ typeName: String, isInput: Bool, methodName: String) throws
  {
    // First validate that the type exists and is a message
    try validateMethodType(typeName, isInput: isInput, methodName: methodName)

    // Get the message type definition
    let messageType: MessageNode
    if let type = definedTypes[typeName] as? MessageNode {
      messageType = type
    } else if let importedType = importedTypes[typeName],
      let importedDefs = importedDefinitions[importedType],
      let type = importedDefs.first(where: { $0 is MessageNode }) as? MessageNode
    {
      messageType = type
    } else {
      throw ValidationError.custom("Could not resolve message type '\(typeName)'")
    }

    // Validate message size
    let totalFields = messageType.fields.count
    if totalFields > 100 {
      throw ValidationError.custom(
        "Streaming message '\(typeName)' in method '\(methodName)' has too many fields (\(totalFields)). "
          + "Recommended maximum is 100 fields for streaming messages."
      )
    }

    // Check for required performance-critical field types
    var hasLargeFields = false
    for field in messageType.fields {
      switch field.type {
      case .scalar(let scalarType):
        // Flag fields that could impact streaming performance
        switch scalarType {
        case .bytes, .string:
          if !field.isRepeated {
            hasLargeFields = true
          }
        default:
          break
        }
      case .map:
        hasLargeFields = true
      case .named:
        // Nested messages could be large
        hasLargeFields = true
      }
    }

    if hasLargeFields {
      // This is a warning condition - we don't throw, just indicate potential performance impact
      print(
        "Warning: Streaming message '\(typeName)' in method '\(methodName)' contains fields that may impact performance"
      )
    }

    // Validate streaming-specific options
    for option in messageType.options {
      switch option.name {
      case "optimize_for":
        guard case .identifier(let value) = option.value,
          value == "SPEED" || value == "CODE_SIZE" || value == "LITE_RUNTIME"
        else {
          throw ValidationError.custom(
            "Invalid optimize_for option value for streaming message '\(typeName)'"
          )
        }
      case "deprecated":
        if case .identifier("true") = option.value {
          print(
            "Warning: Using deprecated message type '\(typeName)' for streaming in '\(methodName)'")
        }
      default:
        break
      }
    }
  }

  private func validateStreamingRules(_ rpc: RPCNode) throws {
    // First validate that the types exist and are messages
    try validateMethodType(rpc.inputType, isInput: true, methodName: rpc.name)
    try validateMethodType(rpc.outputType, isInput: false, methodName: rpc.name)

    // Get the message type definitions
    let inputMessageType: MessageNode
    let outputMessageType: MessageNode

    // Resolve input message type
    if let type = definedTypes[rpc.inputType] as? MessageNode {
      inputMessageType = type
    } else if let importedType = importedTypes[rpc.inputType],
      let importedDefs = importedDefinitions[importedType],
      let type = importedDefs.first(where: { $0 is MessageNode }) as? MessageNode
    {
      inputMessageType = type
    } else {
      throw ValidationError.custom("Could not resolve input message type '\(rpc.inputType)'")
    }

    // Resolve output message type
    if let type = definedTypes[rpc.outputType] as? MessageNode {
      outputMessageType = type
    } else if let importedType = importedTypes[rpc.outputType],
      let importedDefs = importedDefinitions[importedType],
      let type = importedDefs.first(where: { $0 is MessageNode }) as? MessageNode
    {
      outputMessageType = type
    } else {
      throw ValidationError.custom("Could not resolve output message type '\(rpc.outputType)'")
    }

    // Validate streaming input message if client streaming is enabled
    if rpc.clientStreaming {
      try validateStreamingMessage(
        inputMessageType,
        isInput: true,
        methodName: rpc.name
      )
    }

    // Validate streaming output message if server streaming is enabled
    if rpc.serverStreaming {
      try validateStreamingMessage(
        outputMessageType,
        isInput: false,
        methodName: rpc.name
      )
    }

    // Validate bidirectional streaming specific rules
    if rpc.clientStreaming && rpc.serverStreaming {
      try validateBidirectionalStreaming(rpc, input: inputMessageType, output: outputMessageType)
    }
  }

  private func validateStreamingMessage(_ message: MessageNode, isInput: Bool, methodName: String)
    throws
  {
    // Validate message size
    let totalFields = message.fields.count
    if totalFields > 100 {
      throw ValidationError.custom(
        "Streaming message '\(message.name)' in method '\(methodName)' has too many fields (\(totalFields)). "
          + "Recommended maximum is 100 fields for streaming messages."
      )
    }

    // Check for required performance-critical field types
    var hasLargeFields = false
    var hasRequiredFields = false

    for field in message.fields {
      // Check for required fields (should be avoided in streaming messages)
      if !field.isOptional && !field.isRepeated {
        hasRequiredFields = true
      }

      switch field.type {
      case .scalar(let scalarType):
        // Flag fields that could impact streaming performance
        switch scalarType {
        case .bytes, .string:
          if !field.isRepeated {
            hasLargeFields = true
          }
        default:
          break
        }

      case .map:
        hasLargeFields = true

      case .named:
        // Nested messages could be large
        hasLargeFields = true
      }
    }

    if hasRequiredFields {
      print(
        "Warning: Streaming message '\(message.name)' in method '\(methodName)' contains required fields. "
          + "Consider making all fields optional for streaming messages."
      )
    }

    if hasLargeFields {
      print(
        "Warning: Streaming message '\(message.name)' in method '\(methodName)' contains fields "
          + "that may impact streaming performance"
      )
    }

    // Validate streaming-specific options
    for option in message.options {
      switch option.name {
      case "optimize_for":
        guard case .identifier(let value) = option.value,
          value == "SPEED" || value == "CODE_SIZE" || value == "LITE_RUNTIME"
        else {
          throw ValidationError.custom(
            "Invalid optimize_for option value for streaming message '\(message.name)'"
          )
        }

      case "deprecated":
        if case .identifier("true") = option.value {
          print(
            "Warning: Using deprecated message type '\(message.name)' for streaming in '\(methodName)'"
          )
        }

      case "message_set_wire_format":
        // Message-set wire format is not recommended for streaming
        if case .identifier("true") = option.value {
          print(
            "Warning: Message-set wire format is not recommended for streaming message '\(message.name)'"
          )
        }

      default:
        break
      }
    }
  }

  private func validateBidirectionalStreaming(
    _ rpc: RPCNode,
    input: MessageNode,
    output: MessageNode
  ) throws {
    // Validate correlation between input and output messages
    // Check for matching fields that could be used for message correlation
    var hasCorrelationField = false

    for inputField in input.fields {
      if let matchingOutputField = output.fields.first(where: { $0.name == inputField.name }) {
        // Check if the fields have matching types and could be used for correlation
        if inputField.type == matchingOutputField.type {
          hasCorrelationField = true
          break
        }
      }
    }

    if !hasCorrelationField {
      print(
        "Warning: Bidirectional streaming method '\(rpc.name)' lacks obvious correlation fields "
          + "between input '\(input.name)' and output '\(output.name)' messages"
      )
    }

    // Validate streaming options
    for option in rpc.options {
      switch option.name {
      case "idempotency_level":
        // For bidirectional streaming, idempotency is important
        guard case .identifier(let value) = option.value,
          ["IDEMPOTENCY_UNKNOWN", "NO_SIDE_EFFECTS", "IDEMPOTENT"].contains(value)
        else {
          throw ValidationError.custom(
            "Invalid idempotency_level for bidirectional streaming method '\(rpc.name)'"
          )
        }

      case "timeout":
        // Ensure timeout is specified for bidirectional streaming
        if case .string(let value) = option.value {
          guard value.hasSuffix("s") || value.hasSuffix("ms") else {
            throw ValidationError.custom(
              "Timeout value must include unit (s or ms) in method '\(rpc.name)'"
            )
          }
        }

      default:
        break
      }
    }
  }

  // MARK: - Extension Rules

  //  validateExtensionRules(_ message: MessageNode) // Proto3 extension restrictions

  private func validateExtensionRules(_ message: MessageNode) throws {
    // In proto3, extensions are only allowed in the following contexts:
    // 1. Custom options (extending google.protobuf.*)
    // 2. Must be within a defined extension range of the target message
    // 3. Cannot extend a non-custom message type

    // Get all extensions defined in the message
    let messageExtensions = message.fields.filter { field in
      // In proto3, extensions would be marked with special syntax/flags
      // For now, we'll assume any field marked as extension
      field.options.contains { option in
        option.name == "extension" && option.value == .identifier("true")
      }
    }

    for messageExtension in messageExtensions {
      // Validate extension target
      if case .named(let targetType) = messageExtension.type {
        // Check if target type is a valid extensible message
        guard isValidExtensionTarget(targetType) else {
          throw ValidationError.custom(
            "Message type '\(targetType)' cannot be extended in proto3. "
              + "Only custom options (google.protobuf.*) can be extended"
          )
        }

        // Validate extension field number is within allowed ranges
        try validateExtensionFieldNumber(
          messageExtension.number,
          targetType: targetType,
          location: messageExtension.location
        )

        // Validate extension field type
        try validateExtensionFieldType(messageExtension)

        // Validate extension options
        try validateExtensionOptions(messageExtension)
      } else {
        throw ValidationError.custom(
          "Extension field '\(messageExtension.name)' must extend a message type"
        )
      }
    }
  }

  private func isValidExtensionTarget(_ typeName: String) -> Bool {
    // In proto3, only custom options can be extended
    // These are typically in the google.protobuf.* namespace
    let validExtensionTargets = [
      "google.protobuf.FileOptions",
      "google.protobuf.MessageOptions",
      "google.protobuf.FieldOptions",
      "google.protobuf.EnumOptions",
      "google.protobuf.EnumValueOptions",
      "google.protobuf.ServiceOptions",
      "google.protobuf.MethodOptions",
    ]

    return validExtensionTargets.contains(typeName) || typeName.hasPrefix("google.protobuf.")
  }

  private func validateExtensionFieldNumber(
    _ number: Int,
    targetType: String,
    location: SourceLocation
  ) throws {
    // Extension field numbers must be in valid ranges
    // For custom options, typically these ranges are defined in descriptor.proto

    // Default extension ranges for common option types
    let extensionRanges: [String: [(Int, Int)]] = [
      "google.protobuf.FileOptions": [(1000, 1999)],
      "google.protobuf.MessageOptions": [(1000, 1999)],
      "google.protobuf.FieldOptions": [(1000, 1999)],
      "google.protobuf.EnumOptions": [(1000, 1999)],
      "google.protobuf.EnumValueOptions": [(1000, 1999)],
      "google.protobuf.ServiceOptions": [(1000, 1999)],
      "google.protobuf.MethodOptions": [(1000, 1999)],
    ]

    if let ranges = extensionRanges[targetType] {
      let isInValidRange = ranges.contains { range in
        (range.0...range.1).contains(number)
      }

      if !isInValidRange {
        throw ValidationError.custom(
          "Extension field number \(number) is not within valid extension ranges for '\(targetType)'"
        )
      }
    } else {
      // For custom types not in the predefined list,
      // we should look up their extension ranges in the type definition
      // This would require additional type resolution infrastructure
      throw ValidationError.custom(
        "Cannot validate extension field number for unknown target type '\(targetType)'"
      )
    }
  }

  private func validateExtensionFieldType(_ field: FieldNode) throws {
    // Validate field type restrictions for extensions
    switch field.type {
    case .map:
      throw ValidationError.custom(
        "Map fields cannot be used in extensions"
      )

    case .scalar:
      // All scalar types are allowed in extensions
      break

    case .named(let typeName):
      // Validate that the type exists
      try validateTypeReference(typeName, inMessage: nil)

      // In proto3, message types in extensions should be careful about default values
      if let type = definedTypes[typeName] {
        if type is MessageNode {
          // Message types in extensions should be handled carefully
          // Consider adding warnings or restrictions based on your needs
        }
      }
    }

    // Extensions cannot be required in proto3
    if !field.isOptional && !field.isRepeated {
      throw ValidationError.custom(
        "Extension field '\(field.name)' must be optional or repeated in proto3"
      )
    }
  }

  private func validateExtensionOptions(_ field: FieldNode) throws {
    for option in field.options {
      switch option.name {
      case "extension":
        // Already validated
        break

      case "deprecated":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.custom(
            "Option 'deprecated' for extension '\(field.name)' must be a boolean"
          )
        }

      case "packed":
        // packed option is only valid for repeated scalar fields
        if field.isRepeated {
          if case .scalar = field.type {
            guard case .identifier(let value) = option.value,
              value == "true" || value == "false"
            else {
              throw ValidationError.custom(
                "Option 'packed' for extension '\(field.name)' must be a boolean"
              )
            }
          } else {
            throw ValidationError.custom(
              "Option 'packed' can only be specified for repeated scalar fields"
            )
          }
        } else {
          throw ValidationError.custom(
            "Option 'packed' can only be specified for repeated fields"
          )
        }

      default:
        // Custom options on extensions should be validated
        if option.name.hasPrefix("(") {
          try validateCustomOption(option)
        } else {
          throw ValidationError.unknownOption(option.name)
        }
      }
    }
  }

  // MARK: - Options Rules

  private func validateFileOptions(_ options: [OptionNode]) throws {
    var seenOptions = Set<String>()  // Track options to prevent duplicates

    for option in options {
      // Check for duplicate options
      if !seenOptions.insert(option.name).inserted {
        throw ValidationError.duplicateOption(option.name)
      }

      switch option.name {
      case "java_package":
        guard case .string(let value) = option.value else {
          throw ValidationError.invalidOptionValue("java_package must be a string")
        }
        // Validate package name format
        try validateJavaPackageName(value)

      case "java_outer_classname":
        guard case .string(let value) = option.value else {
          throw ValidationError.invalidOptionValue("java_outer_classname must be a string")
        }
        // Validate Java class name format
        try validateJavaClassName(value)

      case "java_multiple_files":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("java_multiple_files must be a boolean")
        }

      case "java_generate_equals_and_hash":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue(
            "java_generate_equals_and_hash must be a boolean")
        }

      case "optimize_for":
        guard case .identifier(let value) = option.value else {
          throw ValidationError.invalidOptionValue("optimize_for must be an identifier")
        }
        // Validate optimization mode
        switch value.uppercased() {
        case "SPEED", "CODE_SIZE", "LITE_RUNTIME":
          break
        default:
          throw ValidationError.invalidOptionValue(
            "optimize_for must be SPEED, CODE_SIZE, or LITE_RUNTIME")
        }

      case "go_package":
        guard case .string(let value) = option.value else {
          throw ValidationError.invalidOptionValue("go_package must be a string")
        }
        // Validate Go package name format
        try validateGoPackageName(value)

      case "cc_generic_services",
        "java_generic_services",
        "py_generic_services":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("\(option.name) must be a boolean")
        }

      case "cc_enable_arenas":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("cc_enable_arenas must be a boolean")
        }

      case "objc_class_prefix":
        guard case .string(let value) = option.value else {
          throw ValidationError.invalidOptionValue("objc_class_prefix must be a string")
        }
        // Validate Objective-C class prefix
        try validateObjCClassPrefix(value)

      case "csharp_namespace":
        guard case .string(let value) = option.value else {
          throw ValidationError.invalidOptionValue("csharp_namespace must be a string")
        }
        // Validate C# namespace
        try validateCSharpNamespace(value)

      case "swift_prefix":
        guard case .string(let value) = option.value else {
          throw ValidationError.invalidOptionValue("swift_prefix must be a string")
        }
        // Validate Swift prefix
        try validateSwiftPrefix(value)

      case "php_class_prefix":
        guard case .string(let value) = option.value else {
          throw ValidationError.invalidOptionValue("php_class_prefix must be a string")
        }
        // Validate PHP class prefix
        try validatePHPClassPrefix(value)

      case "php_namespace":
        guard case .string(let value) = option.value else {
          throw ValidationError.invalidOptionValue("php_namespace must be a string")
        }
        // Validate PHP namespace
        try validatePHPNamespace(value)

      case "php_metadata_namespace":
        guard case .string(let value) = option.value else {
          throw ValidationError.invalidOptionValue("php_metadata_namespace must be a string")
        }
        // Validate PHP metadata namespace
        try validatePHPNamespace(value)

      case "ruby_package":
        guard case .string(let value) = option.value else {
          throw ValidationError.invalidOptionValue("ruby_package must be a string")
        }
        // Validate Ruby package name
        try validateRubyPackageName(value)

      default:
        if option.name.hasPrefix("(") {
          // Handle custom options
          try validateCustomOption(option)
        } else {
          throw ValidationError.unknownOption(option.name)
        }
      }
    }
  }

  // Helper methods for language-specific name validation

  private func validateJavaPackageName(_ name: String) throws {
    let components = name.split(separator: ".")
    guard !components.isEmpty else {
      throw ValidationError.invalidOptionValue("Java package name cannot be empty")
    }

    for component in components {
      guard component.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }),
        let first = component.first,
        first.isLetter || first == "_"
      else {
        throw ValidationError.invalidOptionValue(
          "Invalid Java package component: '\(component)'")
      }
    }
  }

  private func validateJavaClassName(_ name: String) throws {
    guard !name.isEmpty,
      let first = name.first,
      first.isUppercase,
      name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" })
    else {
      throw ValidationError.invalidOptionValue(
        "Invalid Java class name: '\(name)'")
    }
  }

  private func validateGoPackageName(_ name: String) throws {
    // Go package names can include "/" for import paths
    let components = name.split(separator: "/")
    guard !components.isEmpty else {
      throw ValidationError.invalidOptionValue("Go package name cannot be empty")
    }

    for component in components {
      guard !component.isEmpty,
        component.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" || $0 == "." }),
        let first = component.first,
        first.isLetter || first == "_"
      else {
        throw ValidationError.invalidOptionValue(
          "Invalid Go package component: '\(component)'")
      }
    }
  }

  private func validateObjCClassPrefix(_ prefix: String) throws {
    guard !prefix.isEmpty,
      prefix.count <= 3,  // Conventional limit
      prefix.allSatisfy({ $0.isUppercase })
    else {
      throw ValidationError.invalidOptionValue(
        "Objective-C class prefix must be 1-3 uppercase letters")
    }
  }

  private func validateCSharpNamespace(_ namespace: String) throws {
    let components = namespace.split(separator: ".")
    guard !components.isEmpty else {
      throw ValidationError.invalidOptionValue("C# namespace cannot be empty")
    }

    for component in components {
      guard !component.isEmpty,
        let first = component.first,
        first.isLetter || first == "_",
        component.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" })
      else {
        throw ValidationError.invalidOptionValue(
          "Invalid C# namespace component: '\(component)'")
      }
    }
  }

  private func validateSwiftPrefix(_ prefix: String) throws {
    guard !prefix.isEmpty,
      let first = prefix.first,
      first.isUppercase,
      prefix.allSatisfy({ $0.isLetter || $0.isNumber })
    else {
      throw ValidationError.invalidOptionValue(
        "Swift prefix must start with uppercase letter and contain only letters and numbers")
    }
  }

  private func validatePHPClassPrefix(_ prefix: String) throws {
    guard !prefix.isEmpty,
      let first = prefix.first,
      first.isUppercase,
      prefix.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" })
    else {
      throw ValidationError.invalidOptionValue(
        "PHP class prefix must start with uppercase letter and contain only letters, numbers, and underscores"
      )
    }
  }

  private func validatePHPNamespace(_ namespace: String) throws {
    let components = namespace.split(separator: "\\")
    guard !components.isEmpty else {
      throw ValidationError.invalidOptionValue("PHP namespace cannot be empty")
    }

    for component in components {
      guard !component.isEmpty,
        let first = component.first,
        first.isUppercase,
        component.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" })
      else {
        throw ValidationError.invalidOptionValue(
          "Invalid PHP namespace component: '\(component)'")
      }
    }
  }

  private func validateRubyPackageName(_ name: String) throws {
    let components = name.split(separator: "::")
    guard !components.isEmpty else {
      throw ValidationError.invalidOptionValue("Ruby package name cannot be empty")
    }

    for component in components {
      guard !component.isEmpty,
        let first = component.first,
        first.isUppercase,
        component.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" })
      else {
        throw ValidationError.invalidOptionValue(
          "Invalid Ruby package component: '\(component)'")
      }
    }
  }

  private func validateMessageOptions(_ options: [OptionNode]) throws {
    var messageOptions = Set<String>()  // Track for duplicates

    for option in options {
      // Check for duplicate options
      if !messageOptions.insert(option.name).inserted {
        throw ValidationError.duplicateOption(option.name)
      }

      switch option.name {
      case "message_set_wire_format":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue(
            "message_set_wire_format must be a boolean")
        }

        // In proto3, message_set_wire_format is discouraged
        if value == "true" {
          print("Warning: message_set_wire_format is not recommended in proto3")
        }

      case "no_standard_descriptor_accessor":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue(
            "no_standard_descriptor_accessor must be a boolean")
        }

      case "deprecated":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("deprecated must be a boolean")
        }

      case "map_entry":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("map_entry must be a boolean")
        }

        // map_entry should typically be generated automatically
        print(
          "Warning: map_entry option is typically generated automatically by the protocol buffer compiler"
        )

      case "optimize_for":
        guard case .identifier(let value) = option.value else {
          throw ValidationError.invalidOptionValue("optimize_for must be an identifier")
        }

        switch value.uppercased() {
        case "SPEED":
          // Default optimization mode
          break
        case "CODE_SIZE":
          // Generates minimal classes
          break
        case "LITE_RUNTIME":
          // Uses lite runtime library
          break
        default:
          throw ValidationError.invalidOptionValue(
            "optimize_for must be SPEED, CODE_SIZE, or LITE_RUNTIME")
        }

      case "preserve_unknown_fields":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("preserve_unknown_fields must be a boolean")
        }

        // In proto3, unknown fields are preserved by default
        if value == "false" {
          print("Warning: Setting preserve_unknown_fields to false is not recommended in proto3")
        }

      case "features":
        // Proto3 features option (introduced in newer versions)
        try validateMessageFeatures(option)

      default:
        if option.name.hasPrefix("(") {
          // Handle custom options
          try validateCustomMessageOption(option)
        } else {
          throw ValidationError.unknownOption(option.name)
        }
      }
    }

    // Validate option combinations
    try validateMessageOptionCombinations(options)
  }

  private func validateMessageFeatures(_ option: OptionNode) throws {
    // Validate features message fields if present
    guard case .map(let features) = option.value else {
      throw ValidationError.invalidOptionValue("features must be a message")
    }

    // Known feature flags
    for (key, value) in features {
      switch key {
      case "field_presence":
        guard case .identifier(let val) = value,
          ["EXPLICIT", "IMPLICIT", "LEGACY_REQUIRED"].contains(val.uppercased())
        else {
          throw ValidationError.invalidOptionValue(
            "field_presence must be EXPLICIT, IMPLICIT, or LEGACY_REQUIRED")
        }

      case "enum_type":
        guard case .identifier(let val) = value,
          ["OPEN", "CLOSED"].contains(val.uppercased())
        else {
          throw ValidationError.invalidOptionValue(
            "enum_type must be OPEN or CLOSED")
        }

      case "repeated_field_encoding":
        guard case .identifier(let val) = value,
          ["PACKED", "EXPANDED"].contains(val.uppercased())
        else {
          throw ValidationError.invalidOptionValue(
            "repeated_field_encoding must be PACKED or EXPANDED")
        }

      case "utf8_validation":
        guard case .identifier(let val) = value,
          ["VERIFY", "NONE"].contains(val.uppercased())
        else {
          throw ValidationError.invalidOptionValue(
            "utf8_validation must be VERIFY or NONE")
        }

      case "message_encoding":
        guard case .identifier(let val) = value,
          ["LENGTH_PREFIXED", "DELIMITED"].contains(val.uppercased())
        else {
          throw ValidationError.invalidOptionValue(
            "message_encoding must be LENGTH_PREFIXED or DELIMITED")
        }

      default:
        // Unknown feature flags might be added in future versions
        print("Warning: Unknown message feature flag: \(key)")
      }
    }
  }

  private func validateCustomMessageOption(_ option: OptionNode) throws {
    // Remove parentheses from custom option name
    let name = String(option.name.dropFirst().dropLast())

    // Validate custom option name format
    let components = name.split(separator: ".")
    guard !components.isEmpty else {
      throw ValidationError.invalidOptionName(option.name)
    }

    // Each component should be a valid identifier
    for component in components {
      guard component.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }),
        let first = component.first,
        first.isLetter || first == "_"
      else {
        throw ValidationError.invalidOptionName(option.name)
      }
    }

    // For now, just validate basic value types
    switch option.value {
    case .identifier(let value):
      guard value == "true" || value == "false" else {
        throw ValidationError.invalidOptionValue(
          "Boolean custom option value must be true or false")
      }
    case .string:
      break  // String values are valid
    case .number(let value):
      guard value >= Double(Int32.min) && value <= Double(Int32.max) else {
        throw ValidationError.invalidOptionValue("Number value out of range for custom option")
      }
    case .array(let values):
      // Validate each value in the array
      for value in values {
        try validateCustomOptionValue(value, optionName: name)
      }
    case .map(let entries):
      // Validate each key-value pair in the map
      for (key, value) in entries {
        // Key should be a valid identifier
        guard isValidIdentifier(key) else {
          throw ValidationError.invalidOptionValue("Invalid map key in custom option: \(key)")
        }
        // Validate the value
        try validateCustomOptionValue(value, optionName: name)
      }
    }

    // Verify the option is defined in a known extension
    if let extensionType = findExtensionType(name) {
      try validateOptionValueAgainstType(option.value, extensionType: extensionType)
    } else {
      // We might want to just warn here instead of throwing
      print("Warning: Custom option '\(name)' is not registered in known extensions")
    }
  }

  // Helper functions for custom option validation
  private func validateCustomOptionValue(_ value: OptionNode.Value, optionName: String) throws {
    switch value {
    case .identifier(let val):
      guard val == "true" || val == "false" else {
        throw ValidationError.invalidOptionValue(
          "Invalid boolean value in custom option '\(optionName)'"
        )
      }
    case .string:
      break  // String values are always valid
    case .number(let val):
      guard val >= Double(Int32.min) && val <= Double(Int32.max) else {
        throw ValidationError.invalidOptionValue(
          "Number out of range in custom option '\(optionName)'"
        )
      }
    case .array(let values):
      // Recursively validate array elements
      for val in values {
        try validateCustomOptionValue(val, optionName: optionName)
      }
    case .map(let entries):
      // Recursively validate map entries
      for (key, val) in entries {
        guard isValidIdentifier(key) else {
          throw ValidationError.invalidOptionValue(
            "Invalid map key '\(key)' in custom option '\(optionName)'"
          )
        }
        try validateCustomOptionValue(val, optionName: optionName)
      }
    }
  }

  private func isValidIdentifier(_ name: String) -> Bool {
    guard let first = name.first else { return false }
    return (first.isLetter || first == "_")
      && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
  }

  private func findExtensionType(_ name: String) -> TypeNode? {
    // This would look up the extension definition in the proto registry
    // For now, return nil or implement basic extension type lookup
    // Could be enhanced when extension registry is implemented
    return nil
  }

  private func validateOptionValueAgainstType(_ value: OptionNode.Value, extensionType: TypeNode)
    throws
  {
    // This would validate that the option value matches its declared type
    // For example:
    // - Check if boolean values are used for boolean options
    // - Verify number ranges for numeric options
    // - Validate enum values against their declared enum type
    // - etc.

    // Implementation would depend on how extension types are represented
    // For now, this is a placeholder for future implementation
  }

  private func validateMessageOptionCombinations(_ options: [OptionNode]) throws {
    let hasMessageSetWireFormat = options.contains { option in
      option.name == "message_set_wire_format" && option.value == .identifier("true")
    }

    let hasMapEntry = options.contains { option in
      option.name == "map_entry" && option.value == .identifier("true")
    }

    let hasNoStandardDescriptor = options.contains { option in
      option.name == "no_standard_descriptor_accessor" && option.value == .identifier("true")
    }

    let optimizeFor = options.first { option in
      option.name == "optimize_for"
    }?.value

    // message_set_wire_format and map_entry are mutually exclusive
    if hasMessageSetWireFormat && hasMapEntry {
      throw ValidationError.custom(
        "Cannot use both message_set_wire_format and map_entry options")
    }

    // Validate optimize_for compatibility
    if let optimizeFor = optimizeFor {
      guard case .identifier(let value) = optimizeFor else {
        throw ValidationError.invalidOptionValue("optimize_for must be an identifier")
      }

      switch value.uppercased() {
      case "LITE_RUNTIME":
        if hasMessageSetWireFormat {
          throw ValidationError.custom(
            "message_set_wire_format cannot be used with LITE_RUNTIME optimization")
        }
        if hasNoStandardDescriptor {
          throw ValidationError.custom(
            "no_standard_descriptor_accessor cannot be used with LITE_RUNTIME optimization")
        }
      case "CODE_SIZE":
        if hasMessageSetWireFormat {
          print("Warning: message_set_wire_format may impact code size optimization")
        }
      case "SPEED":
        // SPEED is compatible with all options
        break
      default:
        throw ValidationError.invalidOptionValue(
          "optimize_for must be one of: SPEED, CODE_SIZE, LITE_RUNTIME")
      }
    }

    // Validate custom options
    for option in options where option.name.hasPrefix("(") {
      // Custom options starting with ( are validated separately in validateCustomOption
      continue
    }

    // Check proto3 specific constraints
    if hasMessageSetWireFormat {
      print("Warning: message_set_wire_format is not recommended in proto3")
    }

    // Validate descriptor options
    if hasNoStandardDescriptor && hasMessageSetWireFormat {
      throw ValidationError.custom(
        "Cannot use both no_standard_descriptor_accessor and message_set_wire_format")
    }
  }

  private func validateFieldOptions(_ options: [OptionNode]) throws {
    var seenOptions = Set<String>()  // Track for duplicates

    for option in options {
      // Check for duplicate options
      if !seenOptions.insert(option.name).inserted {
        throw ValidationError.duplicateOption(option.name)
      }

      switch option.name {
      case "ctype":
        guard case .identifier(let value) = option.value else {
          throw ValidationError.invalidOptionValue("ctype must be an identifier")
        }
        switch value.uppercased() {
        case "STRING":
          break  // Default value
        case "CORD":
          // Validate CORD usage - typically for large strings
          print("Warning: CORD type should only be used for strings larger than 1MB")
        case "STRING_PIECE":
          // Validate STRING_PIECE usage
          print(
            "Warning: STRING_PIECE type should be used carefully with string-specific operations")
        default:
          throw ValidationError.invalidOptionValue("ctype must be STRING, CORD, or STRING_PIECE")
        }

      case "packed":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("packed must be a boolean")
        }
      // Note: Additional validation for packed fields should be done at the field level
      // since it's only valid for repeated numeric fields

      case "jstype":
        guard case .identifier(let value) = option.value else {
          throw ValidationError.invalidOptionValue("jstype must be an identifier")
        }
        switch value.uppercased() {
        case "JS_NORMAL":
          break  // Default value
        case "JS_STRING":
          // Used when the field should always be handled as a string in JavaScript
          break
        case "JS_NUMBER":
          // Used when the field should always be handled as a number in JavaScript
          break
        default:
          throw ValidationError.invalidOptionValue(
            "jstype must be JS_NORMAL, JS_STRING, or JS_NUMBER")
        }

      case "lazy":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("lazy must be a boolean")
        }
        // Lazy should be used carefully with message fields
        if value == "true" {
          print(
            "Warning: Lazy message parsing should be used carefully as it affects reflection capabilities"
          )
        }

      case "deprecated":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("deprecated must be a boolean")
        }
        // Could add warning for deprecated fields
        if value == "true" {
          print("Warning: Field marked as deprecated")
        }

      case "weak":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("weak must be a boolean")
        }
        // Weak references should be used carefully
        if value == "true" {
          print("Warning: Weak references should be used carefully to avoid memory leaks")
        }

      case "unverified_lazy":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("unverified_lazy must be a boolean")
        }
        // Warning about unverified lazy parsing
        if value == "true" {
          print("Warning: Unverified lazy parsing should only be used in trusted environments")
        }

      case "debug_redact":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("debug_redact must be a boolean")
        }

      case "retention":
        guard case .identifier(let value) = option.value else {
          throw ValidationError.invalidOptionValue("retention must be an identifier")
        }
        switch value.uppercased() {
        case "RETENTION_UNKNOWN", "RETENTION_RUNTIME", "RETENTION_SOURCE":
          break
        default:
          throw ValidationError.invalidOptionValue(
            "retention must be RETENTION_UNKNOWN, RETENTION_RUNTIME, or RETENTION_SOURCE")
        }

      case "targets":
        guard case .array(let values) = option.value else {
          throw ValidationError.invalidOptionValue("targets must be an array")
        }
        // Validate each target value
        for value in values {
          guard case .identifier(let target) = value else {
            throw ValidationError.invalidOptionValue("target must be an identifier")
          }
          switch target.uppercased() {
          case "TARGET_TYPE_UNKNOWN", "TARGET_TYPE_CPP", "TARGET_TYPE_JAVA",
            "TARGET_TYPE_CSHARP", "TARGET_TYPE_PYTHON", "TARGET_TYPE_PHP",
            "TARGET_TYPE_RUBY", "TARGET_TYPE_GO":
            break
          default:
            throw ValidationError.invalidOptionValue("Invalid target type: \(target)")
          }
        }

      case "json_name":
        guard case .string(let value) = option.value else {
          throw ValidationError.invalidOptionValue("json_name must be a string")
        }
        // Validate JSON name format
        try validateJsonName(value)

      default:
        if option.name.hasPrefix("(") {
          // Handle custom options
          try validateCustomFieldOption(option)
        } else {
          throw ValidationError.unknownOption(option.name)
        }
      }
    }

    // Validate option combinations and constraints
    try validateFieldOptionCombinations(options)
  }

  private func validateJsonName(_ name: String) throws {
    // JSON name can't be empty
    guard !name.isEmpty else {
      throw ValidationError.invalidOptionValue("json_name cannot be empty")
    }

    // JSON name should be a valid JSON property name
    // This is a basic validation; could be enhanced based on specific requirements
    guard name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }) else {
      throw ValidationError.invalidOptionValue("json_name contains invalid characters")
    }
  }

  private func validateCustomFieldOption(_ option: OptionNode) throws {
    // Similar to validateCustomMessageOption but specific to field options
    let name = String(option.name.dropFirst().dropLast())

    // Validate custom option name format
    let components = name.split(separator: ".")
    guard !components.isEmpty else {
      throw ValidationError.invalidOptionName(option.name)
    }

    // Each component should be a valid identifier
    for component in components {
      guard component.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }),
        let first = component.first,
        first.isLetter || first == "_"
      else {
        throw ValidationError.invalidOptionName(option.name)
      }
    }

    // Validate option value based on type
    try validateCustomOptionValue(option.value, optionName: name)
  }

  private func validateFieldOptionCombinations(_ options: [OptionNode]) throws {
    let hasLazy = options.contains { $0.name == "lazy" && $0.value == .identifier("true") }
    let hasUnverifiedLazy = options.contains {
      $0.name == "unverified_lazy" && $0.value == .identifier("true")
    }

    // Can't use both lazy and unverified_lazy
    if hasLazy && hasUnverifiedLazy {
      throw ValidationError.custom(
        "Cannot use both lazy and unverified_lazy options on the same field")
    }

    // Check for other incompatible combinations
    // For example:
    // - Packed with inappropriate field types
    // - Conflicting JavaScript type options
    // - etc.
  }

  private func validateEnumOptions(_ options: [OptionNode]) throws {
    var enumOptions = Set<String>()  // Track for duplicates

    for option in options {
      // Check for duplicate options
      if !enumOptions.insert(option.name).inserted {
        throw ValidationError.duplicateOption(option.name)
      }

      switch option.name {
      case "allow_alias":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("allow_alias must be a boolean")
        }

        // In proto3, if allow_alias is true, make sure it's actually needed
        if value == "true" {
          // This warning might be better placed in the enum validation itself
          // since we need to check actual enum values to determine if aliases exist
          print(
            "Warning: allow_alias is set but should only be used when actually defining aliases")
        }

      case "deprecated":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("deprecated must be a boolean")
        }

        if value == "true" {
          print("Warning: Enum marked as deprecated")
        }

      case "features":
        try validateEnumFeatures(option)

      case "json_format":
        guard case .identifier(let value) = option.value else {
          throw ValidationError.invalidOptionValue("json_format must be an identifier")
        }
        switch value.uppercased() {
        case "ALLOW_ALIAS_JSON", "ALLOW_UNKNOWN_JSON", "STRICT_JSON":
          break
        default:
          throw ValidationError.invalidOptionValue(
            "json_format must be ALLOW_ALIAS_JSON, ALLOW_UNKNOWN_JSON, or STRICT_JSON")
        }

      case "validate_utf8":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("validate_utf8 must be a boolean")
        }

      case "enum_visibility":
        guard case .identifier(let value) = option.value else {
          throw ValidationError.invalidOptionValue("enum_visibility must be an identifier")
        }
        switch value.uppercased() {
        case "VISIBLE", "HIDDEN":
          break
        default:
          throw ValidationError.invalidOptionValue("enum_visibility must be VISIBLE or HIDDEN")
        }

      default:
        if option.name.hasPrefix("(") {
          try validateCustomEnumOption(option)
        } else {
          throw ValidationError.unknownOption(option.name)
        }
      }
    }

    // Validate option combinations
    try validateEnumOptionCombinations(options)
  }

  private func validateEnumFeatures(_ option: OptionNode) throws {
    guard case .map(let features) = option.value else {
      throw ValidationError.invalidOptionValue("features must be a message")
    }

    for (key, value) in features {
      switch key {
      case "enum_type":
        guard case .identifier(let val) = value,
          ["OPEN", "CLOSED"].contains(val.uppercased())
        else {
          throw ValidationError.invalidOptionValue("enum_type must be OPEN or CLOSED")
        }

      case "legacy_closed":
        guard case .identifier(let val) = value,
          val == "true" || val == "false"
        else {
          throw ValidationError.invalidOptionValue("legacy_closed must be a boolean")
        }

      case "allow_alias":
        guard case .identifier(let val) = value,
          val == "true" || val == "false"
        else {
          throw ValidationError.invalidOptionValue("allow_alias feature must be a boolean")
        }

      case "deprecated":
        guard case .identifier(let val) = value,
          val == "true" || val == "false"
        else {
          throw ValidationError.invalidOptionValue("deprecated feature must be a boolean")
        }

      default:
        print("Warning: Unknown enum feature flag: \(key)")
      }
    }
  }

  private func validateCustomEnumOption(_ option: OptionNode) throws {
    let name = String(option.name.dropFirst().dropLast())

    // Validate custom option name format
    let components = name.split(separator: ".")
    guard !components.isEmpty else {
      throw ValidationError.invalidOptionName(option.name)
    }

    // Each component should be a valid identifier
    for component in components {
      guard component.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }),
        let first = component.first,
        first.isLetter || first == "_"
      else {
        throw ValidationError.invalidOptionName(option.name)
      }
    }

    // Validate option value
    switch option.value {
    case .identifier(let value):
      guard value == "true" || value == "false" else {
        throw ValidationError.invalidOptionValue(
          "Boolean custom option value must be true or false")
      }
    case .string:
      break  // String values are valid
    case .number(let value):
      guard value >= Double(Int32.min) && value <= Double(Int32.max) else {
        throw ValidationError.invalidOptionValue(
          "Number value out of range for custom option")
      }
    case .array(let values):
      for value in values {
        try validateCustomOptionValue(value, optionName: name)
      }
    case .map(let entries):
      for (key, value) in entries {
        guard isValidIdentifier(key) else {
          throw ValidationError.invalidOptionValue(
            "Invalid map key in custom option: \(key)")
        }
        try validateCustomOptionValue(value, optionName: name)
      }
    }
  }

  private func validateEnumOptionCombinations(_ options: [OptionNode]) throws {
    let hasAllowAlias = options.contains {
      $0.name == "allow_alias" && $0.value == .identifier("true")
    }

    let hasStrictJson = options.contains { option in
      option.name == "json_format" && option.value == .identifier("STRICT_JSON")
    }

    // If using STRICT_JSON, allow_alias should be false
    if hasStrictJson && hasAllowAlias {
      throw ValidationError.custom(
        "Cannot use STRICT_JSON with allow_alias=true as they have conflicting semantics")
    }

    // Check for deprecated and visibility conflicts
    let isDeprecated = options.contains {
      $0.name == "deprecated" && $0.value == .identifier("true")
    }

    let isHidden = options.contains { option in
      option.name == "enum_visibility" && option.value == .identifier("HIDDEN")
    }

    if isDeprecated && !isHidden {
      print("Warning: Deprecated enum should typically be hidden")
    }
  }

  private func validateEnumValueOptions(_ options: [OptionNode]) throws {
    var enumValueOptions = Set<String>()  // Track for duplicates

    for option in options {
      // Check for duplicate options
      if !enumValueOptions.insert(option.name).inserted {
        throw ValidationError.duplicateOption(option.name)
      }

      switch option.name {
      case "deprecated":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("deprecated must be a boolean")
        }

        if value == "true" {
          print("Warning: Enum value marked as deprecated")
        }

      case "features":
        try validateEnumValueFeatures(option)

      case "debug_redact":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("debug_redact must be a boolean")
        }

      case "retention":
        guard case .identifier(let value) = option.value else {
          throw ValidationError.invalidOptionValue("retention must be an identifier")
        }
        switch value.uppercased() {
        case "RETENTION_UNKNOWN", "RETENTION_RUNTIME", "RETENTION_SOURCE":
          break
        default:
          throw ValidationError.invalidOptionValue(
            "retention must be RETENTION_UNKNOWN, RETENTION_RUNTIME, or RETENTION_SOURCE")
        }

      case "enum_value_visibility":
        guard case .identifier(let value) = option.value else {
          throw ValidationError.invalidOptionValue("enum_value_visibility must be an identifier")
        }
        switch value.uppercased() {
        case "VISIBLE", "HIDDEN":
          break
        default:
          throw ValidationError.invalidOptionValue(
            "enum_value_visibility must be VISIBLE or HIDDEN")
        }

      case "alias":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("alias must be a boolean")
        }
      // Note: This option should only be used when the enum has allow_alias=true
      // The actual validation of this constraint is handled in validateEnumValuesUniqueness

      case "default":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("default must be a boolean")
        }
        if value == "true" {
          // Only one enum value in an enum can be marked as default
          // This should be validated at the enum level
          print("Warning: Enum value marked as default. Ensure only one value has this option")
        }

      default:
        if option.name.hasPrefix("(") {
          try validateCustomEnumValueOption(option)
        } else {
          throw ValidationError.unknownOption(option.name)
        }
      }
    }

    // Validate option combinations
    try validateEnumValueOptionCombinations(options)
  }

  private func validateEnumValueFeatures(_ option: OptionNode) throws {
    guard case .map(let features) = option.value else {
      throw ValidationError.invalidOptionValue("features must be a message")
    }

    for (key, value) in features {
      switch key {
      case "deprecated":
        guard case .identifier(let val) = value,
          val == "true" || val == "false"
        else {
          throw ValidationError.invalidOptionValue("deprecated feature must be a boolean")
        }

      case "visibility":
        guard case .identifier(let val) = value,
          ["VISIBLE", "HIDDEN"].contains(val.uppercased())
        else {
          throw ValidationError.invalidOptionValue("visibility must be VISIBLE or HIDDEN")
        }

      case "retention":
        guard case .identifier(let val) = value,
          ["RETENTION_UNKNOWN", "RETENTION_RUNTIME", "RETENTION_SOURCE"].contains(val.uppercased())
        else {
          throw ValidationError.invalidOptionValue(
            "retention must be RETENTION_UNKNOWN, RETENTION_RUNTIME, or RETENTION_SOURCE")
        }

      default:
        print("Warning: Unknown enum value feature flag: \(key)")
      }
    }
  }

  private func validateCustomEnumValueOption(_ option: OptionNode) throws {
    let name = String(option.name.dropFirst().dropLast())

    // Validate custom option name format
    let components = name.split(separator: ".")
    guard !components.isEmpty else {
      throw ValidationError.invalidOptionName(option.name)
    }

    // Each component should be a valid identifier
    for component in components {
      guard component.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }),
        let first = component.first,
        first.isLetter || first == "_"
      else {
        throw ValidationError.invalidOptionName(option.name)
      }
    }

    // Validate option value
    switch option.value {
    case .identifier(let value):
      guard value == "true" || value == "false" else {
        throw ValidationError.invalidOptionValue(
          "Boolean custom option value must be true or false")
      }
    case .string:
      break  // String values are valid
    case .number(let value):
      guard value >= Double(Int32.min) && value <= Double(Int32.max) else {
        throw ValidationError.invalidOptionValue(
          "Number value out of range for custom option")
      }
    case .array(let values):
      for value in values {
        try validateCustomOptionValue(value, optionName: name)
      }
    case .map(let entries):
      for (key, value) in entries {
        guard isValidIdentifier(key) else {
          throw ValidationError.invalidOptionValue(
            "Invalid map key in custom option: \(key)")
        }
        try validateCustomOptionValue(value, optionName: name)
      }
    }
  }

  private func validateEnumValueOptionCombinations(_ options: [OptionNode]) throws {
    let isDeprecated = options.contains {
      $0.name == "deprecated" && $0.value == .identifier("true")
    }

    let isHidden = options.contains { option in
      option.name == "enum_value_visibility" && option.value == .identifier("HIDDEN")
    }

    // Deprecated values should typically be hidden
    if isDeprecated && !isHidden {
      print("Warning: Deprecated enum value should typically be hidden")
    }

    let isDefault = options.contains {
      $0.name == "default" && $0.value == .identifier("true")
    }

    let isAlias = options.contains {
      $0.name == "alias" && $0.value == .identifier("true")
    }

    // Default value cannot be an alias
    if isDefault && isAlias {
      throw ValidationError.custom(
        "Enum value cannot be both default and alias")
    }

    // Default value should not be deprecated
    if isDefault && isDeprecated {
      throw ValidationError.custom(
        "Default enum value should not be deprecated")
    }
  }

  private func validateServiceOptions(_ options: [OptionNode]) throws {
    var serviceOptions = Set<String>()  // Track for duplicates

    for option in options {
      // Check for duplicate options
      if !serviceOptions.insert(option.name).inserted {
        throw ValidationError.duplicateOption(option.name)
      }

      switch option.name {
      case "deprecated":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("deprecated must be a boolean")
        }

        if value == "true" {
          print("Warning: Service marked as deprecated")
        }

      case "features":
        try validateServiceFeatures(option)

      case "default_host":
        guard case .string(let value) = option.value else {
          throw ValidationError.invalidOptionValue("default_host must be a string")
        }
        try validateHostName(value)

      case "default_timeout":
        guard case .string(let value) = option.value else {
          throw ValidationError.invalidOptionValue("default_timeout must be a string")
        }
        try validateTimeout(value)

      case "visibility":
        guard case .identifier(let value) = option.value else {
          throw ValidationError.invalidOptionValue("visibility must be an identifier")
        }
        switch value.uppercased() {
        case "VISIBLE", "HIDDEN", "INTERNAL", "PACKAGE":
          break
        default:
          throw ValidationError.invalidOptionValue(
            "visibility must be VISIBLE, HIDDEN, INTERNAL, or PACKAGE")
        }

      case "security_level":
        guard case .identifier(let value) = option.value else {
          throw ValidationError.invalidOptionValue("security_level must be an identifier")
        }
        switch value.uppercased() {
        case "NONE", "INTEGRITY", "PRIVACY":
          break
        default:
          throw ValidationError.invalidOptionValue(
            "security_level must be NONE, INTEGRITY, or PRIVACY")
        }

      case "security_policy":
        guard case .string(let value) = option.value else {
          throw ValidationError.invalidOptionValue("security_policy must be a string")
        }
        try validateSecurityPolicy(value)

      case "retry_policy":
        guard case .map(let policy) = option.value else {
          throw ValidationError.invalidOptionValue("retry_policy must be a message")
        }
        try validateRetryPolicy(policy)

      case "authentication":
        guard case .map(let auth) = option.value else {
          throw ValidationError.invalidOptionValue("authentication must be a message")
        }
        try validateAuthentication(auth)

      default:
        if option.name.hasPrefix("(") {
          try validateCustomServiceOption(option)
        } else {
          throw ValidationError.unknownOption(option.name)
        }
      }
    }

    // Validate option combinations
    try validateServiceOptionCombinations(options)
  }

  private func validateServiceFeatures(_ option: OptionNode) throws {
    guard case .map(let features) = option.value else {
      throw ValidationError.invalidOptionValue("features must be a message")
    }

    for (key, value) in features {
      switch key {
      case "deprecated":
        guard case .identifier(let val) = value,
          val == "true" || val == "false"
        else {
          throw ValidationError.invalidOptionValue("deprecated feature must be a boolean")
        }

      case "visibility":
        guard case .identifier(let val) = value,
          ["VISIBLE", "HIDDEN", "INTERNAL", "PACKAGE"].contains(val.uppercased())
        else {
          throw ValidationError.invalidOptionValue(
            "visibility must be VISIBLE, HIDDEN, INTERNAL, or PACKAGE")
        }

      case "enable_tracing":
        guard case .identifier(let val) = value,
          val == "true" || val == "false"
        else {
          throw ValidationError.invalidOptionValue("enable_tracing must be a boolean")
        }

      default:
        print("Warning: Unknown service feature flag: \(key)")
      }
    }
  }

  private func validateHostName(_ hostname: String) throws {
    // Basic hostname validation
    guard !hostname.isEmpty else {
      throw ValidationError.invalidOptionValue("default_host cannot be empty")
    }

    let components = hostname.split(separator: ".")
    guard components.count >= 2 else {
      throw ValidationError.invalidOptionValue("default_host must be a valid hostname")
    }

    for component in components {
      guard !component.isEmpty,
        component.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }),
        component.first != "-",
        component.last != "-"
      else {
        throw ValidationError.invalidOptionValue("Invalid hostname component: \(component)")
      }
    }
  }

  private func validateTimeout(_ timeout: String) throws {
    // Timeout must end with time unit (s, ms)
    guard timeout.hasSuffix("s") || timeout.hasSuffix("ms") else {
      throw ValidationError.invalidOptionValue("Timeout must include unit (s or ms)")
    }

    let valueStr =
      timeout.hasSuffix("ms")
      ? String(timeout.dropLast(2))
      : String(timeout.dropLast(1))

    guard let value = Double(valueStr),
      value > 0
    else {
      throw ValidationError.invalidOptionValue("Invalid timeout value")
    }

    // Optional: Add reasonable limits
    if timeout.hasSuffix("s") && value > 300 {  // 5 minutes
      print("Warning: Long timeout value (\(timeout)) might impact service reliability")
    }
  }

  private func validateSecurityPolicy(_ policy: String) throws {
    // Basic security policy validation
    guard !policy.isEmpty else {
      throw ValidationError.invalidOptionValue("security_policy cannot be empty")
    }

    // Add your specific security policy format validation here
    // For example: "v1.policy_name" format
    let components = policy.split(separator: ".")
    guard components.count >= 2,
      components[0].allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }),
      components[1].allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" })
    else {
      throw ValidationError.invalidOptionValue("Invalid security policy format")
    }
  }

  private func validateRetryPolicy(_ policy: [String: OptionNode.Value]) throws {
    // Validate required retry policy fields
    let requiredFields = ["initial_delay", "max_delay", "multiplier", "retryable_status_codes"]
    for field in requiredFields {
      guard policy[field] != nil else {
        throw ValidationError.invalidOptionValue("Missing required retry policy field: \(field)")
      }
    }

    // Validate field types and values
    for (key, value) in policy {
      switch key {
      case "initial_delay", "max_delay":
        guard case .string(let delay) = value else {
          throw ValidationError.invalidOptionValue("\(key) must be a string duration")
        }
        try validateTimeout(delay)

      case "multiplier":
        guard case .number(let mult) = value,
          mult > 1.0
        else {
          throw ValidationError.invalidOptionValue("multiplier must be greater than 1.0")
        }

      case "retryable_status_codes":
        guard case .array(let codes) = value else {
          throw ValidationError.invalidOptionValue("retryable_status_codes must be an array")
        }
        try validateStatusCodes(codes)

      case "max_attempts":
        guard case .number(let attempts) = value,
          attempts > 0,
          attempts <= 5
        else {  // Example limit
          throw ValidationError.invalidOptionValue("max_attempts must be between 1 and 5")
        }

      default:
        print("Warning: Unknown retry policy field: \(key)")
      }
    }
  }

  private func validateStatusCodes(_ codes: [OptionNode.Value]) throws {
    for code in codes {
      guard case .identifier(let status) = code else {
        throw ValidationError.invalidOptionValue("Status code must be an identifier")
      }

      // Validate against known status codes
      let validStatuses = [
        "CANCELLED", "UNKNOWN", "INVALID_ARGUMENT", "DEADLINE_EXCEEDED",
        "NOT_FOUND", "ALREADY_EXISTS", "PERMISSION_DENIED", "RESOURCE_EXHAUSTED",
        "FAILED_PRECONDITION", "ABORTED", "OUT_OF_RANGE", "UNIMPLEMENTED",
        "INTERNAL", "UNAVAILABLE", "DATA_LOSS", "UNAUTHENTICATED",
      ]

      guard validStatuses.contains(status.uppercased()) else {
        throw ValidationError.invalidOptionValue("Invalid status code: \(status)")
      }
    }
  }

  private func validateAuthentication(_ auth: [String: OptionNode.Value]) throws {
    // Validate authentication configuration
    guard let provider = auth["provider"] else {
      throw ValidationError.invalidOptionValue("Authentication must specify a provider")
    }

    guard case .string(let providerName) = provider else {
      throw ValidationError.invalidOptionValue("Authentication provider must be a string")
    }

    // Validate provider-specific configuration
    switch providerName.lowercased() {
    case "google_id_token":
      try validateGoogleIdTokenAuth(auth)
    case "google_compute_engine":
      try validateGceAuth(auth)
    case "oauth2":
      try validateOAuth2Auth(auth)
    default:
      throw ValidationError.invalidOptionValue(
        "Unsupported authentication provider: \(providerName)")
    }
  }

  private func validateGoogleIdTokenAuth(_ auth: [String: OptionNode.Value]) throws {
    guard let audience = auth["audience"],
      case .string = audience
    else {
      throw ValidationError.invalidOptionValue("Google ID token auth requires audience")
    }
  }

  private func validateGceAuth(_ auth: [String: OptionNode.Value]) throws {
    // GCE auth might not need additional configuration
    if let scopes = auth["scopes"] {
      guard case .array(let scopeList) = scopes else {
        throw ValidationError.invalidOptionValue("Scopes must be an array of strings")
      }
      for scope in scopeList {
        guard case .string = scope else {
          throw ValidationError.invalidOptionValue("Each scope must be a string")
        }
      }
    }
  }

  private func validateOAuth2Auth(_ auth: [String: OptionNode.Value]) throws {
    // Validate required OAuth2 fields
    let requiredFields = ["scopes"]
    for field in requiredFields {
      guard auth[field] != nil else {
        throw ValidationError.invalidOptionValue("Missing required OAuth2 field: \(field)")
      }
    }

    guard case .array(let scopes) = auth["scopes"] else {
      throw ValidationError.invalidOptionValue("OAuth2 scopes must be an array")
    }

    for scope in scopes {
      guard case .string = scope else {
        throw ValidationError.invalidOptionValue("Each OAuth2 scope must be a string")
      }
    }
  }

  private func validateCustomServiceOption(_ option: OptionNode) throws {
    let name = String(option.name.dropFirst().dropLast())

    // Validate custom option name format
    let components = name.split(separator: ".")
    guard !components.isEmpty else {
      throw ValidationError.invalidOptionName(option.name)
    }

    // Each component should be a valid identifier
    for component in components {
      guard component.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }),
        let first = component.first,
        first.isLetter || first == "_"
      else {
        throw ValidationError.invalidOptionName(option.name)
      }
    }

    // Validate option value
    try validateCustomOptionValue(option.value, optionName: name)
  }

  private func validateServiceOptionCombinations(_ options: [OptionNode]) throws {
    let isDeprecated = options.contains {
      $0.name == "deprecated" && $0.value == .identifier("true")
    }

    let visibility = options.first {
      $0.name == "visibility"
    }?.value

    // Deprecated services should typically be hidden
    if isDeprecated {
      if case .identifier(let vis) = visibility,
        vis.uppercased() != "HIDDEN"
      {
        print("Warning: Deprecated service should typically be hidden")
      }
    }

    // Check security-related option combinations
    let hasSecurityPolicy = options.contains { $0.name == "security_policy" }
    let hasSecurityLevel = options.contains { $0.name == "security_level" }
    let hasAuthentication = options.contains { $0.name == "authentication" }

    if hasSecurityPolicy && hasSecurityLevel {
      throw ValidationError.custom(
        "Cannot specify both security_policy and security_level")
    }

    if hasSecurityPolicy && !hasAuthentication {
      print("Warning: Security policy specified without authentication configuration")
    }
  }

  private func validateMethodOptions(_ options: [OptionNode]) throws {
    var methodOptions = Set<String>()  // Track for duplicates

    for option in options {
      // Check for duplicate options
      if !methodOptions.insert(option.name).inserted {
        throw ValidationError.duplicateOption(option.name)
      }

      switch option.name {
      case "deprecated":
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("deprecated must be a boolean")
        }

        if value == "true" {
          print("Warning: Method marked as deprecated")
        }

      case "idempotency_level":
        guard case .identifier(let value) = option.value else {
          throw ValidationError.invalidOptionValue("idempotency_level must be an identifier")
        }
        switch value.uppercased() {
        case "IDEMPOTENCY_UNKNOWN":
          // Default value, no special handling needed
          break
        case "NO_SIDE_EFFECTS":
          // Method is idempotent and has no side effects
          break
        case "IDEMPOTENT":
          // Method is idempotent but may have side effects
          break
        default:
          throw ValidationError.invalidOptionValue(
            "idempotency_level must be IDEMPOTENCY_UNKNOWN, NO_SIDE_EFFECTS, or IDEMPOTENT")
        }

      case "method_visibility":
        guard case .identifier(let value) = option.value else {
          throw ValidationError.invalidOptionValue("method_visibility must be an identifier")
        }
        switch value.uppercased() {
        case "VISIBLE", "HIDDEN", "INTERNAL", "PACKAGE":
          break
        default:
          throw ValidationError.invalidOptionValue(
            "method_visibility must be VISIBLE, HIDDEN, INTERNAL, or PACKAGE")
        }

      case "timeout":
        guard case .string(let value) = option.value else {
          throw ValidationError.invalidOptionValue("timeout must be a string")
        }
        try validateTimeout(value)

      case "retry_policy":
        guard case .map(let policy) = option.value else {
          throw ValidationError.invalidOptionValue("retry_policy must be a message")
        }
        try validateMethodRetryPolicy(policy)

      case "error_handling":
        guard case .map(let handling) = option.value else {
          throw ValidationError.invalidOptionValue("error_handling must be a message")
        }
        try validateErrorHandling(handling)

      case "authorization":
        guard case .map(let auth) = option.value else {
          throw ValidationError.invalidOptionValue("authorization must be a message")
        }
        try validateMethodAuthorization(auth)

      case "rate_limit":
        guard case .map(let limits) = option.value else {
          throw ValidationError.invalidOptionValue("rate_limit must be a message")
        }
        try validateRateLimit(limits)

      case "logging":
        guard case .map(let config) = option.value else {
          throw ValidationError.invalidOptionValue("logging must be a message")
        }
        try validateLoggingConfig(config)

      case "features":
        try validateMethodFeatures(option)

      default:
        if option.name.hasPrefix("(") {
          try validateCustomMethodOption(option)
        } else {
          throw ValidationError.unknownOption(option.name)
        }
      }
    }

    // Validate option combinations
    try validateMethodOptionCombinations(options)
  }

  private func validateMethodFeatures(_ option: OptionNode) throws {
    guard case .map(let features) = option.value else {
      throw ValidationError.invalidOptionValue("features must be a message")
    }

    for (key, value) in features {
      switch key {
      case "deprecated":
        guard case .identifier(let val) = value,
          val == "true" || val == "false"
        else {
          throw ValidationError.invalidOptionValue("deprecated feature must be a boolean")
        }

      case "visibility":
        guard case .identifier(let val) = value,
          ["VISIBLE", "HIDDEN", "INTERNAL", "PACKAGE"].contains(val.uppercased())
        else {
          throw ValidationError.invalidOptionValue(
            "visibility must be VISIBLE, HIDDEN, INTERNAL, or PACKAGE")
        }

      case "enable_tracing":
        guard case .identifier(let val) = value,
          val == "true" || val == "false"
        else {
          throw ValidationError.invalidOptionValue("enable_tracing must be a boolean")
        }

      default:
        print("Warning: Unknown method feature flag: \(key)")
      }
    }
  }

  private func validateMethodRetryPolicy(_ policy: [String: OptionNode.Value]) throws {
    // Validate required retry policy fields
    let requiredFields = ["max_attempts", "initial_backoff", "max_backoff", "backoff_multiplier"]
    for field in requiredFields {
      guard policy[field] != nil else {
        throw ValidationError.invalidOptionValue("Missing required retry policy field: \(field)")
      }
    }

    for (key, value) in policy {
      switch key {
      case "max_attempts":
        guard case .number(let attempts) = value,
          attempts > 0,
          attempts <= 5
        else {  // Example limit
          throw ValidationError.invalidOptionValue("max_attempts must be between 1 and 5")
        }

      case "initial_backoff", "max_backoff":
        guard case .string(let backoff) = value else {
          throw ValidationError.invalidOptionValue("\(key) must be a string duration")
        }
        try validateTimeout(backoff)

      case "backoff_multiplier":
        guard case .number(let mult) = value,
          mult >= 1.0
        else {
          throw ValidationError.invalidOptionValue("backoff_multiplier must be >= 1.0")
        }

      case "retryable_status_codes":
        guard case .array(let codes) = value else {
          throw ValidationError.invalidOptionValue("retryable_status_codes must be an array")
        }
        try validateStatusCodes(codes)

      default:
        print("Warning: Unknown retry policy field: \(key)")
      }
    }
  }

  private func validateErrorHandling(_ handling: [String: OptionNode.Value]) throws {
    for (key, value) in handling {
      switch key {
      case "retry_codes":
        guard case .array(let codes) = value else {
          throw ValidationError.invalidOptionValue("retry_codes must be an array")
        }
        try validateStatusCodes(codes)

      case "fallback_response":
        guard case .string = value else {
          throw ValidationError.invalidOptionValue("fallback_response must be a string")
        }

      case "error_mapping":
        guard case .map(let mapping) = value else {
          throw ValidationError.invalidOptionValue("error_mapping must be a message")
        }
        try validateErrorMapping(mapping)

      default:
        print("Warning: Unknown error handling field: \(key)")
      }
    }
  }

  private func validateErrorMapping(_ mapping: [String: OptionNode.Value]) throws {
    for (code, value) in mapping {
      guard Int(code) != nil else {
        throw ValidationError.invalidOptionValue("Error code must be a number: \(code)")
      }

      guard case .string = value else {
        throw ValidationError.invalidOptionValue("Error mapping value must be a string")
      }
    }
  }

  private func validateMethodAuthorization(_ auth: [String: OptionNode.Value]) throws {
    guard let roles = auth["roles"] else {
      throw ValidationError.invalidOptionValue("Authorization must specify roles")
    }

    guard case .array(let roleList) = roles else {
      throw ValidationError.invalidOptionValue("roles must be an array")
    }

    for role in roleList {
      guard case .string(let roleName) = role else {
        throw ValidationError.invalidOptionValue("Each role must be a string")
      }

      // Validate role name format
      guard !roleName.isEmpty,
        roleName.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." })
      else {
        throw ValidationError.invalidOptionValue("Invalid role name format: \(roleName)")
      }
    }
  }

  private func validateRateLimit(_ limits: [String: OptionNode.Value]) throws {
    for (key, value) in limits {
      switch key {
      case "qps":
        guard case .number(let qps) = value,
          qps > 0
        else {
          throw ValidationError.invalidOptionValue("QPS must be a positive number")
        }

      case "burst":
        guard case .number(let burst) = value,
          burst >= 0
        else {
          throw ValidationError.invalidOptionValue("Burst must be a non-negative number")
        }

      case "timeout":
        guard case .string(let timeout) = value else {
          throw ValidationError.invalidOptionValue("timeout must be a string duration")
        }
        try validateTimeout(timeout)

      default:
        print("Warning: Unknown rate limit field: \(key)")
      }
    }
  }

  private func validateLoggingConfig(_ config: [String: OptionNode.Value]) throws {
    for (key, value) in config {
      switch key {
      case "log_level":
        guard case .identifier(let level) = value,
          ["DEBUG", "INFO", "WARNING", "ERROR"].contains(level.uppercased())
        else {
          throw ValidationError.invalidOptionValue(
            "log_level must be DEBUG, INFO, WARNING, or ERROR")
        }

      case "sample_rate":
        guard case .number(let rate) = value,
          rate >= 0.0,
          rate <= 1.0
        else {
          throw ValidationError.invalidOptionValue("sample_rate must be between 0.0 and 1.0")
        }

      case "log_fields":
        guard case .array(let fields) = value else {
          throw ValidationError.invalidOptionValue("log_fields must be an array")
        }
        for field in fields {
          guard case .string = field else {
            throw ValidationError.invalidOptionValue("Each log field must be a string")
          }
        }

      default:
        print("Warning: Unknown logging config field: \(key)")
      }
    }
  }

  private func validateCustomMethodOption(_ option: OptionNode) throws {
    let name = String(option.name.dropFirst().dropLast())

    // Validate custom option name format
    let components = name.split(separator: ".")
    guard !components.isEmpty else {
      throw ValidationError.invalidOptionName(option.name)
    }

    // Each component should be a valid identifier
    for component in components {
      guard component.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }),
        let first = component.first,
        first.isLetter || first == "_"
      else {
        throw ValidationError.invalidOptionName(option.name)
      }
    }

    // Validate option value
    try validateCustomOptionValue(option.value, optionName: name)
  }

  private func validateMethodOptionCombinations(_ options: [OptionNode]) throws {
    let isDeprecated = options.contains {
      $0.name == "deprecated" && $0.value == .identifier("true")
    }

    let visibility = options.first {
      $0.name == "method_visibility"
    }?.value

    // Deprecated methods should typically be hidden
    if isDeprecated {
      if case .identifier(let vis) = visibility,
        vis.uppercased() != "HIDDEN"
      {
        print("Warning: Deprecated method should typically be hidden")
      }
    }

    // Check for conflicting timeout configurations
    let hasMethodTimeout = options.contains { $0.name == "timeout" }
    let hasRetryPolicy = options.contains { $0.name == "retry_policy" }

    if hasMethodTimeout && hasRetryPolicy {
      // Ensure retry policy timeout is not longer than method timeout
      // This would require parsing and comparing the timeout values
      print(
        "Warning: Method has both timeout and retry policy. Ensure retry policy timeout doesn't exceed method timeout"
      )
    }

    // Validate idempotency and retry policy combination
    if let idempotencyLevel = options.first(where: { $0.name == "idempotency_level" })?.value,
      case .identifier(let level) = idempotencyLevel,
      level.uppercased() == "NO_SIDE_EFFECTS"
    {

      // Methods with NO_SIDE_EFFECTS should typically have retry policies
      if !hasRetryPolicy {
        print("Warning: Method marked as NO_SIDE_EFFECTS should typically have a retry policy")
      }
    }
  }
}
