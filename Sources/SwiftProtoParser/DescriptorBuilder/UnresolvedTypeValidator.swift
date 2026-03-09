import SwiftProtobuf

/// Validates and resolves all complex type references in a fully-assembled
/// `FileDescriptorSet` using protobuf scope-walking rules (C++ scoping).
///
/// After per-file descriptor building each field of type `.message` or `.enum`
/// has a `typeName` of the form `.<package>.<Name>`. If that type does not exist
/// in the global registry (all types from all files in the set), the original
/// source reference was unresolvable with the current file's package prefix.
///
/// This validator applies the standard protobuf name-resolution algorithm:
/// for a name `Foo` written in package `a.b.c`, the compiler tries:
///
///   `.a.b.c.Foo` → `.a.b.Foo` → `.a.Foo` → `.Foo`
///
/// If a candidate is found in the registry the field's `typeName` (and `type`
/// for enum/message distinction) is rewritten to the correct fully-qualified
/// name. If no candidate is found, a `.semanticError` is returned — matching
/// the behaviour of `protoc`, which rejects such files.
///
/// This pass runs **before** `EnumTypePostProcessor` so that enum-vs-message
/// correction operates on already-correct type names.
struct UnresolvedTypeValidator {

  // MARK: - Private types

  private enum TypeKind {
    case message
    case enumType
  }

  // MARK: - Public API

  /// Validates all type references in `set` and returns a corrected set or
  /// a semantic error if any reference cannot be resolved.
  static func validate(
    _ set: Google_Protobuf_FileDescriptorSet
  ) -> Result<Google_Protobuf_FileDescriptorSet, ProtoParseError> {
    let registry = buildTypeRegistry(from: set)
    var validatedFiles: [Google_Protobuf_FileDescriptorProto] = []

    for file in set.file {
      switch validateFile(file, typeRegistry: registry) {
      case .success(let validated):
        validatedFiles.append(validated)
      case .failure(let error):
        return .failure(error)
      }
    }

    var result = set
    result.file = validatedFiles
    return .success(result)
  }

  // MARK: - Registry building

  /// Collects every fully-qualified type name from all files in the set.
  ///
  /// Maps each FQN (e.g. `.nested.common.BaseItem`) to its kind.
  private static func buildTypeRegistry(
    from set: Google_Protobuf_FileDescriptorSet
  ) -> [String: TypeKind] {
    var registry: [String: TypeKind] = [:]
    for file in set.file {
      let pkgPrefix = file.package.isEmpty ? "" : ".\(file.package)"
      for message in file.messageType {
        let fqn = "\(pkgPrefix).\(message.name)"
        collectMessageTypes(from: message, fqn: fqn, into: &registry)
      }
      for enumProto in file.enumType {
        registry["\(pkgPrefix).\(enumProto.name)"] = .enumType
      }
    }
    return registry
  }

  private static func collectMessageTypes(
    from message: Google_Protobuf_DescriptorProto,
    fqn: String,
    into registry: inout [String: TypeKind]
  ) {
    registry[fqn] = .message
    for nested in message.nestedType where !nested.options.mapEntry {
      collectMessageTypes(from: nested, fqn: "\(fqn).\(nested.name)", into: &registry)
    }
    for enumProto in message.enumType {
      registry["\(fqn).\(enumProto.name)"] = .enumType
    }
  }

  // MARK: - File validation

  private static func validateFile(
    _ file: Google_Protobuf_FileDescriptorProto,
    typeRegistry: [String: TypeKind]
  ) -> Result<Google_Protobuf_FileDescriptorProto, ProtoParseError> {
    var result = file

    var validatedMessages: [Google_Protobuf_DescriptorProto] = []
    for message in file.messageType {
      switch validateMessage(
        message,
        filePackage: file.package,
        fileName: file.name,
        parentFQN: "",
        typeRegistry: typeRegistry
      ) {
      case .success(let validated): validatedMessages.append(validated)
      case .failure(let error): return .failure(error)
      }
    }
    result.messageType = validatedMessages

    var validatedServices: [Google_Protobuf_ServiceDescriptorProto] = []
    for service in file.service {
      switch validateService(
        service,
        filePackage: file.package,
        fileName: file.name,
        typeRegistry: typeRegistry
      ) {
      case .success(let validated): validatedServices.append(validated)
      case .failure(let error): return .failure(error)
      }
    }
    result.service = validatedServices

    return .success(result)
  }

  // MARK: - Message validation

  private static func validateMessage(
    _ message: Google_Protobuf_DescriptorProto,
    filePackage: String,
    fileName: String,
    parentFQN: String,
    typeRegistry: [String: TypeKind]
  ) -> Result<Google_Protobuf_DescriptorProto, ProtoParseError> {
    // Compute this message's fully-qualified name so fields can use it as
    // the innermost scope when walking up the package hierarchy.
    let messageFQN: String
    if parentFQN.isEmpty {
      messageFQN =
        filePackage.isEmpty ? ".\(message.name)" : ".\(filePackage).\(message.name)"
    }
    else {
      messageFQN = "\(parentFQN).\(message.name)"
    }

    var result = message

    var validatedFields: [Google_Protobuf_FieldDescriptorProto] = []
    for field in message.field {
      switch validateField(
        field,
        filePackage: filePackage,
        fileName: fileName,
        messageFQN: messageFQN,
        typeRegistry: typeRegistry
      ) {
      case .success(let validated): validatedFields.append(validated)
      case .failure(let error): return .failure(error)
      }
    }
    result.field = validatedFields

    var validatedNested: [Google_Protobuf_DescriptorProto] = []
    for nested in message.nestedType {
      switch validateMessage(
        nested,
        filePackage: filePackage,
        fileName: fileName,
        parentFQN: messageFQN,
        typeRegistry: typeRegistry
      ) {
      case .success(let validated): validatedNested.append(validated)
      case .failure(let error): return .failure(error)
      }
    }
    result.nestedType = validatedNested

    return .success(result)
  }

  // MARK: - Field validation

  private static func validateField(
    _ field: Google_Protobuf_FieldDescriptorProto,
    filePackage: String,
    fileName: String,
    messageFQN: String,
    typeRegistry: [String: TypeKind]
  ) -> Result<Google_Protobuf_FieldDescriptorProto, ProtoParseError> {
    // Only validate FQN type names (leading dot). Primitives have empty
    // typeName; synthetic map-entry references have no leading dot.
    guard !field.typeName.isEmpty, field.typeName.hasPrefix(".") else {
      return .success(field)
    }

    if let kind = typeRegistry[field.typeName] {
      // Type exists — ensure the kind flag is also correct while we're here
      var corrected = field
      corrected.type = kind == .enumType ? .enum : .message
      return .success(corrected)
    }

    // Type not found — apply scope-based resolution starting from the
    // innermost scope (the containing message) up to the root.
    let sourceName = recoverSourceName(from: field.typeName, filePackage: filePackage)
    let candidates = scopeCandidates(
      for: sourceName,
      inPackage: filePackage,
      messageFQN: messageFQN
    )

    for candidate in candidates {
      if let kind = typeRegistry[candidate] {
        var corrected = field
        corrected.typeName = candidate
        corrected.type = kind == .enumType ? .enum : .message
        return .success(corrected)
      }
    }

    return .failure(
      .semanticError(
        message:
          "undefined type '\(field.typeName)'; searched scopes: \(candidates.joined(separator: ", "))",
        context: "\(fileName): \(messageFQN).\(field.name)"
      )
    )
  }

  // MARK: - Service validation

  private static func validateService(
    _ service: Google_Protobuf_ServiceDescriptorProto,
    filePackage: String,
    fileName: String,
    typeRegistry: [String: TypeKind]
  ) -> Result<Google_Protobuf_ServiceDescriptorProto, ProtoParseError> {
    var result = service
    var validatedMethods: [Google_Protobuf_MethodDescriptorProto] = []

    for method in service.method {
      switch validateMethod(
        method,
        filePackage: filePackage,
        fileName: fileName,
        serviceName: service.name,
        typeRegistry: typeRegistry
      ) {
      case .success(let validated): validatedMethods.append(validated)
      case .failure(let error): return .failure(error)
      }
    }
    result.method = validatedMethods
    return .success(result)
  }

  private static func validateMethod(
    _ method: Google_Protobuf_MethodDescriptorProto,
    filePackage: String,
    fileName: String,
    serviceName: String,
    typeRegistry: [String: TypeKind]
  ) -> Result<Google_Protobuf_MethodDescriptorProto, ProtoParseError> {
    var result = method

    if !method.inputType.isEmpty, method.inputType.hasPrefix(".") {
      switch resolveTypeName(
        method.inputType,
        filePackage: filePackage,
        context: "\(fileName): \(serviceName).\(method.name) (input)",
        typeRegistry: typeRegistry
      ) {
      case .success(let resolved): result.inputType = resolved
      case .failure(let error): return .failure(error)
      }
    }

    if !method.outputType.isEmpty, method.outputType.hasPrefix(".") {
      switch resolveTypeName(
        method.outputType,
        filePackage: filePackage,
        context: "\(fileName): \(serviceName).\(method.name) (output)",
        typeRegistry: typeRegistry
      ) {
      case .success(let resolved): result.outputType = resolved
      case .failure(let error): return .failure(error)
      }
    }

    return .success(result)
  }

  // MARK: - Core resolution helpers

  /// Resolves a fully-qualified type name, applying scope-walking if needed.
  ///
  /// Used for service input/output types (no containing message scope).
  private static func resolveTypeName(
    _ typeName: String,
    filePackage: String,
    context: String,
    typeRegistry: [String: TypeKind]
  ) -> Result<String, ProtoParseError> {
    if typeRegistry[typeName] != nil { return .success(typeName) }

    let sourceName = recoverSourceName(from: typeName, filePackage: filePackage)
    let candidates = scopeCandidates(for: sourceName, inPackage: filePackage, messageFQN: "")

    for candidate in candidates where typeRegistry[candidate] != nil {
      return .success(candidate)
    }

    return .failure(
      .semanticError(
        message:
          "undefined type '\(typeName)'; searched scopes: \(candidates.joined(separator: ", "))",
        context: context
      )
    )
  }

  // MARK: - Scope-walking helpers

  /// Strips the file's package prefix from `typeName` to recover the name as
  /// it was written in the source.
  ///
  /// - `typeName = ".nested.v1.BaseItem"`, `filePackage = "nested.v1"`
  ///   → `"BaseItem"` (was an unqualified source reference)
  /// - `typeName = ".nested.common.BaseItem"`, `filePackage = "nested.v1"`
  ///   → `"nested.common.BaseItem"` (was a qualified source reference)
  private static func recoverSourceName(from typeName: String, filePackage: String) -> String {
    guard !filePackage.isEmpty else {
      return String(typeName.dropFirst())  // drop leading dot
    }
    let pkgPrefix = ".\(filePackage)."
    if typeName.hasPrefix(pkgPrefix) {
      return String(typeName.dropFirst(pkgPrefix.count))
    }
    return String(typeName.dropFirst())  // qualified: strip only the leading dot
  }

  /// Generates scope-walking candidates for `sourceName` in descending order
  /// from the innermost scope to the root, following protobuf C++ scoping rules.
  ///
  /// Walks up through every enclosing message scope before descending through
  /// the package hierarchy — matching the behaviour of `protoc`.
  ///
  /// Example: `sourceName = "Foo"`, `messageFQN = ".a.b.Outer.Inner"`, `package = "a.b"` →
  ///   `.a.b.Outer.Inner.Foo`  (innermost: containing message)
  ///   `.a.b.Outer.Foo`        (parent message scope)
  ///   `.a.b.Foo`              (file package)
  ///   `.a.Foo`
  ///   `.Foo`                  (root)
  private static func scopeCandidates(
    for sourceName: String,
    inPackage package: String,
    messageFQN: String = ""
  ) -> [String] {
    var candidates: [String] = []
    var seen: Set<String> = []

    // 1. Walk up through every enclosing message scope, stopping at the
    //    package boundary.  This covers both the innermost scope and every
    //    intermediate parent-message scope that standard C++ scoping checks.
    if !messageFQN.isEmpty {
      let packageDepth = package.isEmpty ? 0 : package.split(separator: ".").count
      var messageComponents = messageFQN.dropFirst().split(separator: ".").map(String.init)
      while messageComponents.count > packageDepth {
        let candidate = ".\(messageComponents.joined(separator: ".")).\(sourceName)"
        if seen.insert(candidate).inserted {
          candidates.append(candidate)
        }
        messageComponents.removeLast()
      }
    }

    // 2. Package hierarchy (full package down to root)
    var pkgComponents = package.isEmpty ? [] : package.split(separator: ".").map(String.init)
    while !pkgComponents.isEmpty {
      let candidate = ".\(pkgComponents.joined(separator: ".")).\(sourceName)"
      if seen.insert(candidate).inserted {
        candidates.append(candidate)
      }
      pkgComponents.removeLast()
    }

    // 3. Root scope
    let rootCandidate = ".\(sourceName)"
    if seen.insert(rootCandidate).inserted {
      candidates.append(rootCandidate)
    }

    return candidates
  }
}
