import SwiftProtobuf

/// Post-processes a fully assembled `FileDescriptorSet` to correct field types for
/// cross-file enum references.
///
/// During initial descriptor building each file is processed independently.  At that
/// point the builder cannot tell whether a qualified type name (e.g.
/// `.nested.common.BaseStatus`) resolves to a message or an enum defined in another
/// file, so it conservatively emits `type = .message` for every complex type reference.
///
/// Once all files are assembled into a `FileDescriptorSet` the full type universe is
/// available.  This pass:
///   1. Builds a registry of every fully-qualified enum type name from all files.
///   2. Walks every field in every message (including nested messages, oneof fields,
///      and synthetic map-entry messages) and corrects `type` from `.message` to
///      `.enum` wherever the `typeName` matches a registered enum.
struct EnumTypePostProcessor {

  /// Applies the post-processing pass and returns a corrected `FileDescriptorSet`.
  static func process(_ set: Google_Protobuf_FileDescriptorSet) -> Google_Protobuf_FileDescriptorSet {
    let enumRegistry = buildEnumRegistry(from: set)
    var result = set
    result.file = set.file.map { processFile($0, enumRegistry: enumRegistry) }
    return result
  }

  // MARK: - Registry building

  /// Collects every fully-qualified enum name (e.g. `.nested.common.BaseStatus`)
  /// from all files in the set.
  private static func buildEnumRegistry(from set: Google_Protobuf_FileDescriptorSet) -> Set<String> {
    var registry = Set<String>()
    for file in set.file {
      let packagePrefix = file.package.isEmpty ? "" : ".\(file.package)"
      collectTopLevelEnums(from: file.enumType, prefix: packagePrefix, into: &registry)
      for message in file.messageType {
        collectMessageEnums(from: message, prefix: "\(packagePrefix).\(message.name)", into: &registry)
      }
    }
    return registry
  }

  private static func collectTopLevelEnums(
    from enums: [Google_Protobuf_EnumDescriptorProto],
    prefix: String,
    into registry: inout Set<String>
  ) {
    for enumProto in enums {
      registry.insert("\(prefix).\(enumProto.name)")
    }
  }

  private static func collectMessageEnums(
    from message: Google_Protobuf_DescriptorProto,
    prefix: String,
    into registry: inout Set<String>
  ) {
    collectTopLevelEnums(from: message.enumType, prefix: prefix, into: &registry)
    for nested in message.nestedType where !nested.options.mapEntry {
      collectMessageEnums(from: nested, prefix: "\(prefix).\(nested.name)", into: &registry)
    }
  }

  // MARK: - Correction pass

  private static func processFile(
    _ file: Google_Protobuf_FileDescriptorProto,
    enumRegistry: Set<String>
  ) -> Google_Protobuf_FileDescriptorProto {
    var result = file
    result.messageType = file.messageType.map { processMessage($0, enumRegistry: enumRegistry) }
    return result
  }

  private static func processMessage(
    _ message: Google_Protobuf_DescriptorProto,
    enumRegistry: Set<String>
  ) -> Google_Protobuf_DescriptorProto {
    var result = message
    result.field = message.field.map { correctFieldType($0, enumRegistry: enumRegistry) }
    result.nestedType = message.nestedType.map { processMessage($0, enumRegistry: enumRegistry) }
    return result
  }

  /// Corrects a single field's type from `.message` to `.enum` when the `typeName`
  /// resolves to a known enum in the registry.
  private static func correctFieldType(
    _ field: Google_Protobuf_FieldDescriptorProto,
    enumRegistry: Set<String>
  ) -> Google_Protobuf_FieldDescriptorProto {
    guard field.type == .message, !field.typeName.isEmpty else { return field }
    let fullyQualified = field.typeName.hasPrefix(".") ? field.typeName : ".\(field.typeName)"
    guard enumRegistry.contains(fullyQualified) else { return field }
    var corrected = field
    corrected.type = .enum
    return corrected
  }
}
