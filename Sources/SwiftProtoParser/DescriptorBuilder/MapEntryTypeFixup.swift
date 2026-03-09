import SwiftProtobuf

/// Post-processing pass that fully qualifies map-entry `typeName` references.
///
/// During initial descriptor building, a map field's `typeName` is set to the bare
/// entry message name without a leading dot (e.g. `"FieldsEntry"`).  This avoids
/// triggering the unresolved-type validator, which skips names without a leading dot.
///
/// After validation, this pass walks every field and, for any field whose `typeName`
/// lacks a leading dot (i.e. a synthetic map-entry reference), replaces it with the
/// fully-qualified form using the containing message's FQN.
///
/// Example:
///   `FieldsEntry`  →  `.google.protobuf.Struct.FieldsEntry`
struct MapEntryTypeFixup {

  /// Applies the fixup pass and returns a corrected `FileDescriptorSet`.
  static func process(_ set: Google_Protobuf_FileDescriptorSet) -> Google_Protobuf_FileDescriptorSet {
    var result = set
    result.file = set.file.map { fixFile($0) }
    return result
  }

  // MARK: - Private

  private static func fixFile(
    _ file: Google_Protobuf_FileDescriptorProto
  ) -> Google_Protobuf_FileDescriptorProto {
    var f = file
    let packagePrefix = file.package.isEmpty ? "" : ".\(file.package)"
    f.messageType = f.messageType.map { fixMessage($0, parentFQN: packagePrefix) }
    return f
  }

  private static func fixMessage(
    _ msg: Google_Protobuf_DescriptorProto,
    parentFQN: String
  ) -> Google_Protobuf_DescriptorProto {
    let msgFQN = "\(parentFQN).\(msg.name)"
    var m = msg
    m.field = m.field.map { fixField($0, containingFQN: msgFQN) }
    m.nestedType = m.nestedType.map { fixMessage($0, parentFQN: msgFQN) }
    return m
  }

  /// Fully qualifies a map-entry type reference.
  ///
  /// A field is treated as a map-entry reference when it is a message-type field
  /// whose `typeName` is non-empty and does **not** start with `.`.  All ordinary
  /// cross-file or cross-package references are already fully qualified with a
  /// leading dot at build time; only synthetic map-entry names are left bare.
  private static func fixField(
    _ field: Google_Protobuf_FieldDescriptorProto,
    containingFQN: String
  ) -> Google_Protobuf_FieldDescriptorProto {
    guard field.type == .message,
      !field.typeName.isEmpty,
      !field.typeName.hasPrefix(".")
    else {
      return field
    }
    var f = field
    f.typeName = "\(containingFQN).\(f.typeName)"
    return f
  }
}
