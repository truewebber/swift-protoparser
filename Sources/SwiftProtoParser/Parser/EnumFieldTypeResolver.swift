import Foundation

/// A scope-aware registry of enum names that enforces protobuf scoping rules.
///
/// This registry tracks the fully-qualified paths to all enums in the AST and
/// provides methods to check if a type name is an enum within a given scope,
/// following the official protobuf name resolution order.
struct ScopedEnumRegistry {

  // MARK: - Properties

  /// Set of fully-qualified enum names.
  /// Examples:
  /// - "Status" - top-level enum
  /// - "MessageA.Status" - nested in MessageA
  /// - "Outer.Inner.Status" - nested in Outer.Inner
  private let qualifiedNames: Set<String>

  // MARK: - Initialization

  /// Creates a registry with the given qualified enum names.
  ///
  /// - Parameter qualifiedNames: Set of fully-qualified enum paths.
  init(qualifiedNames: Set<String>) {
    self.qualifiedNames = qualifiedNames
  }

  // MARK: - Public Methods

  /// Checks if a simple type name is an enum visible from the given scope.
  ///
  /// This method follows protobuf name resolution order:
  /// 1. Current message scope
  /// 2. Parent scopes (walking up the hierarchy)
  /// 3. Top-level (package) scope
  ///
  /// - Parameters:
  ///   - name: Simple type name to check (e.g., "Status")
  ///   - scope: Current scope as array of message names (e.g., ["Outer", "Inner"])
  /// - Returns: `true` if the name is an enum visible from this scope
  func isEnum(_ name: String, inScope scope: [String]) -> Bool {
    // Step 1: Check current message scope
    if !scope.isEmpty {
      let currentScope = scope.joined(separator: ".")
      let qualifiedName = "\(currentScope).\(name)"
      if qualifiedNames.contains(qualifiedName) {
        return true
      }
    }

    // Step 2: Walk up parent scopes
    for i in (0..<scope.count).reversed() {
      let parentScope = scope[0..<i].joined(separator: ".")
      let qualifiedName = parentScope.isEmpty ? name : "\(parentScope).\(name)"
      if qualifiedNames.contains(qualifiedName) {
        return true
      }
    }

    // Step 3: Check top-level (package) scope
    if qualifiedNames.contains(name) {
      return true
    }

    return false
  }

  /// Checks if a fully-qualified type name is an enum.
  ///
  /// This is used for resolving qualified type references like "MessageA.Status".
  ///
  /// - Parameter qualifiedName: Fully-qualified type name (e.g., "MessageA.Status")
  /// - Returns: `true` if this qualified name is an enum
  func isQualifiedEnum(_ qualifiedName: String) -> Bool {
    return qualifiedNames.contains(qualifiedName)
  }
}

/// Resolves field types to correctly identify enum types vs message types.
///
/// The parser initially marks all non-scalar, non-qualified types as `.message()`.
/// This resolver scans the AST, builds a scope-aware enum registry, and corrects
/// field types to `.enumType()` where appropriate, following protobuf scoping rules.
///
/// Note: This resolver enforces protobuf scoping rules. Cross-message unqualified
/// references to nested enums are NOT resolved (matching protoc behavior).
struct EnumFieldTypeResolver {

  // MARK: - Properties

  /// Scope-aware registry of all enum names in the AST.
  private let enumRegistry: ScopedEnumRegistry

  /// Original AST to resolve.
  private let ast: ProtoAST

  // MARK: - Initialization

  /// Creates a resolver and builds the enum registry from the AST.
  ///
  /// - Parameter ast: The parsed AST to analyze.
  init(ast: ProtoAST) {
    self.ast = ast
    self.enumRegistry = Self.buildEnumRegistry(from: ast)
  }

  // MARK: - Public Methods

  /// Resolves field types throughout the AST, converting `.message()` to `.enumType()` where appropriate.
  ///
  /// This also processes extend declarations to resolve enum types in custom options.
  ///
  /// - Returns: A new AST with corrected field types.
  func resolveFieldTypes() -> ProtoAST {
    // Resolve field types in all messages (starting with empty scope)
    let resolvedMessages = ast.messages.map { resolveMessage($0, scope: []) }

    // Resolve field types in extend declarations (top-level scope)
    let resolvedExtends = ast.extends.map { resolveExtend($0) }

    // Return new AST with resolved messages and extends
    return ProtoAST(
      syntax: ast.syntax,
      package: ast.package,
      imports: ast.imports,
      options: ast.options,
      messages: resolvedMessages,
      enums: ast.enums,
      services: ast.services,
      extends: resolvedExtends
    )
  }

  // MARK: - Private Methods

  /// Builds a scope-aware registry of all enum names in the AST.
  ///
  /// This method builds fully-qualified paths for all enums:
  /// - Top-level enums: stored as simple name (e.g., "Status")
  /// - Nested enums: stored with full path (e.g., "MessageA.Status", "Outer.Inner.Status")
  ///
  /// - Parameter ast: The AST to scan.
  /// - Returns: A scope-aware enum registry.
  private static func buildEnumRegistry(from ast: ProtoAST) -> ScopedEnumRegistry {
    var qualifiedNames = Set<String>()

    // Add top-level enums (stored as simple names)
    for enumNode in ast.enums {
      qualifiedNames.insert(enumNode.name)
    }

    // Add nested enums from messages (stored with full qualified paths)
    for message in ast.messages {
      collectNestedEnums(from: message, scope: [], into: &qualifiedNames)
    }

    return ScopedEnumRegistry(qualifiedNames: qualifiedNames)
  }

  /// Recursively collects nested enum names from a message with scope tracking.
  ///
  /// This method builds qualified names for nested enums by tracking the message
  /// hierarchy. For example, an enum "Status" nested in "Outer.Inner" is stored
  /// as "Outer.Inner.Status".
  ///
  /// - Parameters:
  ///   - message: The message to scan.
  ///   - scope: Current scope (array of parent message names).
  ///   - qualifiedNames: The set of qualified names to populate.
  private static func collectNestedEnums(
    from message: MessageNode,
    scope: [String],
    into qualifiedNames: inout Set<String>
  ) {
    // Build current message's scope
    let currentScope = scope + [message.name]

    // Add this message's nested enums with full qualified path
    for enumNode in message.nestedEnums {
      let qualifiedName = (currentScope + [enumNode.name]).joined(separator: ".")
      qualifiedNames.insert(qualifiedName)
    }

    // Recursively process nested messages
    for nestedMessage in message.nestedMessages {
      collectNestedEnums(from: nestedMessage, scope: currentScope, into: &qualifiedNames)
    }
  }

  /// Resolves field types in a message (and its nested messages).
  ///
  /// - Parameters:
  ///   - message: The message to resolve.
  ///   - scope: Current scope as array of parent message names (e.g., ["Outer", "Inner"]).
  /// - Returns: A new message with resolved field types.
  private func resolveMessage(_ message: MessageNode, scope: [String]) -> MessageNode {
    // Build current message's scope
    let currentScope = scope + [message.name]

    // Resolve fields with current scope
    let resolvedFields = message.fields.map { resolveField($0, scope: currentScope) }

    // Resolve oneof groups with current scope
    let resolvedOneofGroups = message.oneofGroups.map { resolveOneof($0, scope: currentScope) }

    // Recursively resolve nested messages
    let resolvedNestedMessages = message.nestedMessages.map { nestedMessage in
      resolveMessage(nestedMessage, scope: currentScope)
    }

    // Return new message with resolved fields
    return MessageNode(
      name: message.name,
      fields: resolvedFields,
      nestedMessages: resolvedNestedMessages,
      nestedEnums: message.nestedEnums,
      oneofGroups: resolvedOneofGroups,
      options: message.options,
      reservedNumbers: message.reservedNumbers,
      reservedNames: message.reservedNames
    )
  }

  /// Resolves the type of a single field.
  ///
  /// - Parameters:
  ///   - field: The field to resolve.
  ///   - scope: Current scope as array of message names.
  /// - Returns: A new field with resolved type.
  private func resolveField(_ field: FieldNode, scope: [String]) -> FieldNode {
    let resolvedType = resolveFieldType(field.type, scope: scope)

    return FieldNode(
      name: field.name,
      type: resolvedType,
      number: field.number,
      label: field.label,
      options: field.options
    )
  }

  /// Resolves field types in a oneof group.
  ///
  /// - Parameters:
  ///   - oneof: The oneof group to resolve.
  ///   - scope: Current scope as array of message names.
  /// - Returns: A new oneof group with resolved field types.
  private func resolveOneof(_ oneof: OneofNode, scope: [String]) -> OneofNode {
    let resolvedFields = oneof.fields.map { resolveField($0, scope: scope) }

    return OneofNode(
      name: oneof.name,
      fields: resolvedFields,
      options: oneof.options
    )
  }

  /// Resolves field types in an extend declaration.
  ///
  /// Extend declarations are always at top-level scope in proto3 (for custom options).
  /// Services are not processed - RPC methods can only use message types, not enums.
  ///
  /// - Parameter extend: The extend declaration to resolve.
  /// - Returns: A new extend declaration with resolved field types.
  private func resolveExtend(_ extend: ExtendNode) -> ExtendNode {
    // Extend fields are at top-level scope (empty scope array)
    let resolvedFields = extend.fields.map { resolveField($0, scope: []) }

    return ExtendNode(
      extendedType: extend.extendedType,
      fields: resolvedFields,
      options: extend.options,
      position: extend.position
    )
  }

  /// Resolves a field type, converting `.message()` to `.enumType()` if the type is an enum.
  ///
  /// This method enforces protobuf scoping rules:
  /// - Checks if unqualified name is an enum visible from the current scope
  /// - Resolves qualified enum references to `.enumType()`
  /// - Recursively resolves map value types
  ///
  /// - Parameters:
  ///   - fieldType: The field type to resolve.
  ///   - scope: Current scope as array of message names.
  /// - Returns: The resolved field type.
  private func resolveFieldType(_ fieldType: FieldType, scope: [String]) -> FieldType {
    switch fieldType {
    case .message(let typeName):
      // Check if this is actually an enum visible from current scope
      if enumRegistry.isEnum(typeName, inScope: scope) {
        return .enumType(typeName)
      }
      return fieldType

    case .qualifiedType(let typeName):
      // Check if this qualified type is an enum (e.g., "MessageA.Status")
      // This is critical - DescriptorBuilder needs to know enum vs message
      if enumRegistry.isQualifiedEnum(typeName) {
        return .enumType(typeName)
      }
      return fieldType

    case .map(let keyType, let valueType):
      // Recursively resolve map value type (key is always scalar)
      let resolvedValueType = resolveFieldType(valueType, scope: scope)
      return .map(key: keyType, value: resolvedValueType)

    default:
      // Scalar types, enumType - leave unchanged
      return fieldType
    }
  }
}
