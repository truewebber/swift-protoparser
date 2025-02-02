import Foundation

/// Errors that can occur during validation
public enum ValidationError: Error, CustomStringConvertible {
  case cyclicDependency([String])
  case undefinedType(String, referencedIn: String)
  case duplicateEnumValue(String, inEnum: String)
  case invalidPackageReference(String)
  case invalidImportPath(String)
  case missingRequiredField(String, inMessage: String)
  case invalidMapKeyType(String, inField: String)
  case repeatedMapField(String)
  case invalidDefaultValue(String, forField: String)
  case firstEnumValueNotZero(String)  // String is enum name
  case emptyEnum(String)  // String is enum name
  case duplicateOption(String)
  case emptyOneof(String)  // oneof name
  case duplicateTypeName(String)  // type name
  case duplicateNestedTypeName(String)  // nested type name
  case duplicateFieldName(String, inType: String)  // field name and containing type
  case maxNestingDepthExceeded(Int)  // Int is current nesting depth
  case invalidFieldNumber(Int, location: SourceLocation)
  case invalidFieldName(String)
  case reservedFieldName(String)
  case invalidOptionValue(String)
  case invalidOptionName(String)
  case unknownOption(String)
  case custom(String)

  public var description: String {
    switch self {
    case .cyclicDependency(let path):
      return "Cyclic dependency detected: \(path.joined(separator: " -> "))"
    case .undefinedType(let type, let container):
      return "Undefined type '\(type)' referenced in '\(container)'"
    case .duplicateEnumValue(let value, let enumType):
      return "Duplicate enum value '\(value)' in enum '\(enumType)'"
    case .invalidPackageReference(let package):
      return "Invalid package reference: '\(package)'"
    case .invalidImportPath(let path):
      return "Invalid import path: '\(path)'"
    case .missingRequiredField(let field, let message):
      return "Missing required field '\(field)' in message '\(message)'"
    case .invalidMapKeyType(let type, let field):
      return "Invalid map key type '\(type)' in field '\(field)'"
    case .repeatedMapField(let field):
      return "Map field '\(field)' cannot be repeated"
    case .invalidDefaultValue(let value, let field):
      return "Invalid default value '\(value)' for field '\(field)'"
    case .firstEnumValueNotZero(let name):
      return "First enum value in '\(name)' must be zero in proto3"
    case .emptyEnum(let name):
      return "Enum '\(name)' must have at least one value"
    case .duplicateOption(let name):
      return "Duplicate option '\(name)'"
    case .emptyOneof(let name):
      return "Empty oneof '\(name)'"
    case .duplicateTypeName(let name):
      return "Duplicate type name: '\(name)'"
    case .duplicateNestedTypeName(let name):
      return "Duplicate nested type name: '\(name)'"
    case .duplicateFieldName(let field, let type):
      return "Duplicate field name '\(field)' in '\(type)'"
    case .maxNestingDepthExceeded(let depth):
      return "Maximum message nesting depth exceeded (depth: \(depth))"
    case .invalidFieldNumber(let num, let loc):
      return "Invalid field number \(num) at \(loc.line):\(loc.column)"
    case .invalidFieldName(let name):
      return "Invalid field name \(name)"
    case .reservedFieldName(let name):
      return "Field is reserved \(name)"
    case .invalidOptionValue(let message):
      return "Invalid option value: \(message)"
    case .invalidOptionName(let name):
      return "Invalid option name: \(name)"
    case .unknownOption(let name):
      return "Unknown option: \(name)"
    case .custom(let message):
      return message
    }
  }
}

/// Validates proto3 files for correctness
public final class Validator {
  /// Types defined in the current scope
  private var definedTypes: [String: DefinitionNode] = [:]

  /// Dependencies between types
  private var dependencies: [String: Set<String>] = [:]

  /// The current package being validated
  private var currentPackage: String?

  /// Track imported types
  private var importedTypes: [String: String] = [:]

  /// Initialize a new validator
  public init() {}

  // MARK: - Main Validation

  /// Validates a proto file according to proto3 rules
  /// - Parameter file: The file node to validate
  /// - Throws: ValidationError if validation fails
  public func validate(_ file: FileNode) throws {
    // Reset state
    definedTypes.removeAll()
    dependencies.removeAll()
    currentPackage = file.package

    // First pass: collect all defined types
    try collectDefinedTypes(file)

    // Second pass: validate types and collect dependencies
    try validateFile(file)

    // Third pass: check for cyclic dependencies
    try checkCyclicDependencies()
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
        .invalidMapKeyType(String(describing: type), inField: field)
    }
  }

  private func validateFieldRules(_ field: FieldNode) throws {
    // Map fields can't be repeated
    if field.isRepeated {
      if case .map = field.type {
        throw ValidationError.repeatedMapField(field.name)
      }
    }
  }

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

  // MARK: - File Validation

  private func validateFile(_ file: FileNode) throws {
    // Validate syntax version
    if file.syntax != "proto3" {
      throw ValidationError.custom("Invalid syntax version: \(file.syntax), expected 'proto3'")
    }

    // Validate package name
    if let package = file.package {
      try validatePackageName(package)
    }

    // Validate imports
    for imp in file.imports {
      try validateImport(imp)
    }

    // Validate top-level options
    for option in file.options {
      try validateOption(option)
    }

    // Validate messages
    for message in file.messages {
      try validateMessage(message)
    }

    // Validate enums
    for enumType in file.enums {
      try validateEnum(enumType)
    }

    // Validate services
    for service in file.services {
      try validateService(service)
    }
  }

  // MARK: - Message Validation

  private func validateMessage(_ message: MessageNode) throws {
    let fullName = message.fullName(inPackage: currentPackage)
    var fieldNumbers = Set<Int>()
    var fieldNames = Set<String>()

    // Validate fields
    for field in message.fields {
      try validateField(field, in: message)

      // Check for duplicate field numbers
      if !fieldNumbers.insert(field.number).inserted {
        throw ValidationError.custom(
          "Duplicate field number \(field.number) in message '\(fullName)'")
      }

      // Check for duplicate field names
      if !fieldNames.insert(field.name).inserted {
        throw ValidationError.duplicateFieldName(field.name, inType: fullName)
      }

      // Collect dependencies
      if case .named(let typeName) = field.type {
        addDependency(from: fullName, to: resolveTypeName(typeName))
      }
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
        throw ValidationError.invalidMapKeyType(String(describing: keyType), inField: field.name)
      }
      if field.isRepeated {
        throw ValidationError.repeatedMapField(field.name)
      }
    }

    // Validate options
    for option in field.options {
      try validateFieldOption(option, for: field)
    }
  }

  // MARK: - Enum Validation

  private func validateEnum(_ enumType: EnumNode) throws {
    let fullName = enumType.fullName(inPackage: currentPackage)
    var valueNames = Set<String>()
    var valueNumbers = Set<Int>()

    // Proto3 requires first enum value to be zero
    guard let firstValue = enumType.values.first, firstValue.number == 0 else {
      throw ValidationError.custom("First enum value in '\(fullName)' must be zero in proto3")
    }

    for value in enumType.values {
      // Check for duplicate names
      if !valueNames.insert(value.name).inserted {
        throw ValidationError.duplicateEnumValue(value.name, inEnum: fullName)
      }

      // Check for duplicate numbers (unless allow_alias is enabled)
      if !enumType.allowAlias && !valueNumbers.insert(value.number).inserted {
        throw ValidationError.custom(
          "Duplicate enum value number \(value.number) in enum '\(fullName)' (consider using allow_alias)"
        )
      }

      // Validate options
      for option in value.options {
        try validateEnumValueOption(option)
      }
    }
  }

  // MARK: - Service Validation

  private func validateService(_ service: ServiceNode) throws {
    var methodNames = Set<String>()

    for rpc in service.rpcs {
      // Check for duplicate method names
      if !methodNames.insert(rpc.name).inserted {
        throw ValidationError.custom(
          "Duplicate RPC method name '\(rpc.name)' in service '\(service.name)'")
      }

      // Validate input and output types exist
      let inputType = resolveTypeName(rpc.inputType)
      let outputType = resolveTypeName(rpc.outputType)

      if definedTypes[inputType] == nil {
        throw ValidationError.undefinedType(inputType, referencedIn: service.name)
      }
      if definedTypes[outputType] == nil {
        throw ValidationError.undefinedType(outputType, referencedIn: service.name)
      }

      // Validate options
      for option in rpc.options {
        try validateRPCOption(option)
      }
    }
  }

  // MARK: - Helper Methods

  private func validatePackageName(_ package: String) throws {
    let components = package.split(separator: ".")
    for component in components {
      if !component.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
        throw ValidationError.invalidPackageReference(package)
      }
    }
  }

  private func validateImport(_ importNode: ImportNode) throws {
    // Validate import path format
    if importNode.path.isEmpty || importNode.path.contains("..") {
      throw ValidationError.invalidImportPath(importNode.path)
    }
  }

  private func validateOption(_ option: OptionNode) throws {
    // Add specific option validation rules here
  }

  private func validateFieldOption(_ option: OptionNode, for field: FieldNode) throws {
    // Add field-specific option validation rules here
  }

  private func validateEnumValueOption(_ option: OptionNode) throws {
    // Add enum value-specific option validation rules here
  }

  private func validateRPCOption(_ option: OptionNode) throws {
    // Add RPC-specific option validation rules here
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

  private func addDependency(from source: String, to target: String) {
    var deps = dependencies[source] ?? Set()
    deps.insert(target)
    dependencies[source] = deps
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

  private func isValidFieldName(_ name: String) -> Bool {
    guard let first = name.first else { return false }
    return (first.isLowercase || first == "_")
      && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
  }

  private func validateFieldOptions(_ options: [OptionNode]) throws {
    for option in options {
      switch option.name {
      case "deprecated":
        // deprecated must be boolean
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("deprecated must be a boolean")
        }

      case "packed":
        // packed can be only used with repeated scalar fields
        guard case .identifier(let value) = option.value,
          value == "true" || value == "false"
        else {
          throw ValidationError.invalidOptionValue("packed must be a boolean")
        }

      case "json_name":
        // json_name must be string
        guard case .string = option.value else {
          throw ValidationError.invalidOptionValue("json_name must be a string")
        }

      default:
        // Handle custom options (ones in parentheses)
        if option.name.hasPrefix("(") {
          // Validate custom option format - must be (package.option_name) or (option_name)
          let name = String(option.name.dropFirst().dropLast())
          let components = name.split(separator: ".")
          guard !components.isEmpty else {
            throw ValidationError.invalidOptionName(option.name)
          }
          // Custom option validation would go here
        } else {
          throw ValidationError.unknownOption(option.name)
        }
      }
    }
  }

  private func validateTypeReference(_ typeName: String, inMessage message: MessageNode) throws {
    // Handle fully qualified names (starting with dot)
    let typeToCheck = typeName.hasPrefix(".") ? String(typeName.dropFirst()) : typeName

    // If type contains dots, we need to validate each component
    let components = typeToCheck.split(separator: ".")

    if components.count > 1 {
      // For nested type references like "Outer.Inner.VeryInner"
      // First try to find from root scope
      var currentScope = try resolveСurrentScope(
        currentScope: String(components[0]),
        typeName: typeName,
        messageName: message.name
      )

      // Then validate each nested component
      for component in components.dropFirst() {
        currentScope = "\(currentScope).\(component)"
        guard definedTypes[String(currentScope)] != nil else {
          throw ValidationError.undefinedType(typeName, referencedIn: message.name)
        }
      }
      return
    }

    // For non-nested types, search in this order:
    // 1. Current message scope and its parents
    // 2. Current package scope
    // 3. Root package scope
    // 4. Imported files

    // 1. Check message scope hierarchy
    var currentMessage: MessageNode? = message
    while currentMessage != nil {
      if currentMessage?.findNestedType(typeToCheck) != nil {
        return
      }
      currentMessage = currentMessage?.parent as? MessageNode
    }

    // 2. Check current package scope
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

    // Type not found in any scope
    throw ValidationError.undefinedType(typeName, referencedIn: message.name)
  }

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
