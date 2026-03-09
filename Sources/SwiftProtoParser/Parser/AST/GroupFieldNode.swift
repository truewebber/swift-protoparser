import Foundation

// MARK: - GroupFieldNode

/// Represents a `group` field declaration inside a proto2 message.
///
/// Group fields are a legacy proto2 feature that combines a field declaration with
/// an inline nested message definition. They are not supported in proto3.
///
/// Example proto2 syntax:
/// ```
/// optional group SearchResult = 1 {
///   required string url = 2;
/// }
/// ```
///
/// Per the protobuf descriptor spec:
/// - The generated field name is the **lowercase** of `groupName` (e.g. `SearchResult` → `searchresult`).
/// - The synthetic nested `DescriptorProto` uses the **original** capitalisation of `groupName`.
/// - The field type is `TYPE_GROUP` (value 10).
/// - The `type_name` uses the original capitalisation for the fully-qualified name.
///
/// DescriptorBuilder responsibilities (SPP-5b) are not covered here; this node captures
/// the raw parse result only.
struct GroupFieldNode: Equatable {
  /// The field label (optional, required, or repeated).
  let label: FieldLabel

  /// The group name as written in the source (original capitalisation).
  ///
  /// Per protobuf spec the group name must begin with an uppercase letter.
  let groupName: String

  /// The field number assigned to this group field.
  let fieldNumber: Int32

  /// The inline message body containing the group's fields and nested declarations.
  ///
  /// The `body.name` equals `groupName` (original capitalisation).
  let body: MessageNode
}

// MARK: - CustomStringConvertible

extension GroupFieldNode: CustomStringConvertible {
  var description: String {
    var lines: [String] = []

    let labelStr = label.protoKeyword
    let prefix = labelStr.isEmpty ? "" : "\(labelStr) "
    lines.append("\(prefix)group \(groupName) = \(fieldNumber) {")

    for field in body.fields {
      lines.append("  \(field.description)")
    }

    lines.append("}")
    return lines.joined(separator: "\n")
  }
}
