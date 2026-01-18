import Foundation

/// Resolves field types to correctly identify enum types vs message types.
///
/// The parser initially marks all non-scalar, non-qualified types as `.message()`.
/// This resolver scans the AST, builds an enum registry, and corrects field types
/// to `.enumType()` where appropriate.
struct EnumFieldTypeResolver {

  // MARK: - Properties

  /// Registry of all enum names in the AST (both top-level and nested).
  private let enumRegistry: Set<String>

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
  /// - Returns: A new AST with corrected field types.
  func resolveFieldTypes() -> ProtoAST {
    // Resolve field types in all messages
    let resolvedMessages = ast.messages.map { resolveMessage($0, parentContext: nil) }

    // Return new AST with resolved messages
    return ProtoAST(
      syntax: ast.syntax,
      package: ast.package,
      imports: ast.imports,
      options: ast.options,
      messages: resolvedMessages,
      enums: ast.enums,
      services: ast.services,
      extends: ast.extends
    )
  }

  // MARK: - Private Methods

  /// Builds a registry of all enum names in the AST.
  ///
  /// - Parameter ast: The AST to scan.
  /// - Returns: A set of enum names (includes both top-level and nested enums).
  private static func buildEnumRegistry(from ast: ProtoAST) -> Set<String> {
    var registry = Set<String>()

    // Add top-level enums
    for enumNode in ast.enums {
      registry.insert(enumNode.name)
    }

    // Add nested enums from messages
    for message in ast.messages {
      collectNestedEnums(from: message, into: &registry)
    }

    return registry
  }

  /// Recursively collects nested enum names from a message.
  ///
  /// - Parameters:
  ///   - message: The message to scan.
  ///   - registry: The registry to populate.
  private static func collectNestedEnums(from message: MessageNode, into registry: inout Set<String>) {
    // Add this message's nested enums
    for enumNode in message.nestedEnums {
      registry.insert(enumNode.name)
    }

    // Recursively process nested messages
    for nestedMessage in message.nestedMessages {
      collectNestedEnums(from: nestedMessage, into: &registry)
    }
  }

  /// Resolves field types in a message (and its nested messages).
  ///
  /// - Parameters:
  ///   - message: The message to resolve.
  ///   - parentContext: Optional parent message name for scoping (currently unused, reserved for future scoping improvements).
  /// - Returns: A new message with resolved field types.
  private func resolveMessage(_ message: MessageNode, parentContext: String?) -> MessageNode {
    // Resolve fields
    let resolvedFields = message.fields.map { resolveField($0) }

    // Resolve oneof groups
    let resolvedOneofGroups = message.oneofGroups.map { resolveOneof($0) }

    // Recursively resolve nested messages
    let resolvedNestedMessages = message.nestedMessages.map { nestedMessage in
      resolveMessage(nestedMessage, parentContext: message.name)
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
  /// - Parameter field: The field to resolve.
  /// - Returns: A new field with resolved type.
  private func resolveField(_ field: FieldNode) -> FieldNode {
    let resolvedType = resolveFieldType(field.type)

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
  /// - Parameter oneof: The oneof group to resolve.
  /// - Returns: A new oneof group with resolved field types.
  private func resolveOneof(_ oneof: OneofNode) -> OneofNode {
    let resolvedFields = oneof.fields.map { resolveField($0) }

    return OneofNode(
      name: oneof.name,
      fields: resolvedFields,
      options: oneof.options
    )
  }

  /// Resolves a field type, converting `.message()` to `.enumType()` if the type is an enum.
  ///
  /// - Parameter fieldType: The field type to resolve.
  /// - Returns: The resolved field type.
  private func resolveFieldType(_ fieldType: FieldType) -> FieldType {
    switch fieldType {
    case .message(let typeName):
      // Check if this is actually an enum
      if enumRegistry.contains(typeName) {
        return .enumType(typeName)
      }
      return fieldType

    case .map(let keyType, let valueType):
      // Recursively resolve map value type (key is always scalar)
      let resolvedValueType = resolveFieldType(valueType)
      return .map(key: keyType, value: resolvedValueType)

    default:
      // Scalar types, qualifiedType, enumType - leave unchanged
      return fieldType
    }
  }
}
