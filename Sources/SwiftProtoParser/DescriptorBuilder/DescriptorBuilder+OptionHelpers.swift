import Foundation
import SwiftProtobuf

extension DescriptorBuilder {

  /// Converts an `OptionNode` into a fully populated `Google_Protobuf_UninterpretedOption`.
  ///
  /// **Name parts** are built according to the proto spec:
  ///
  ///   `(pkg.ext_name).sub.field` →
  ///     ```
  ///     name: [
  ///       NamePart("pkg.ext_name", isExtension: true),
  ///       NamePart("sub",          isExtension: false),
  ///       NamePart("field",        isExtension: false),
  ///     ]
  ///     ```
  ///
  /// **Value mapping** follows protobuf descriptor conventions:
  ///   - `.string`         → `stringValue`
  ///   - `.number(v >= 0, integer)` → `positiveIntValue`
  ///   - `.number(v < 0, integer)`  → `negativeIntValue`
  ///   - `.number(v, float)`        → `doubleValue`
  ///   - `.boolean`        → `identifierValue` ("true" / "false")
  ///   - `.identifier`     → `identifierValue`
  ///   - `.messageLiteral` → `aggregateValue`
  static func buildUninterpretedOption(from option: OptionNode) -> Google_Protobuf_UninterpretedOption {
    var uninterp = Google_Protobuf_UninterpretedOption()

    // Build name parts array
    var extensionPart = Google_Protobuf_UninterpretedOption.NamePart()
    extensionPart.namePart = option.name
    extensionPart.isExtension = option.isCustom
    var nameParts: [Google_Protobuf_UninterpretedOption.NamePart] = [extensionPart]

    for segment in option.subFieldPath {
      var part = Google_Protobuf_UninterpretedOption.NamePart()
      part.namePart = segment
      part.isExtension = false
      nameParts.append(part)
    }
    uninterp.name = nameParts

    // Build value
    switch option.value {
    case .string(let v):
      uninterp.stringValue = Data(v.utf8)

    case .boolean(let v):
      uninterp.identifierValue = v ? "true" : "false"

    case .identifier(let v):
      uninterp.identifierValue = v

    case .messageLiteral(let v):
      uninterp.aggregateValue = v

    case .number(let v):
      if v < 0 {
        if v.truncatingRemainder(dividingBy: 1) == 0 {
          uninterp.negativeIntValue = Int64(v)
        }
        else {
          uninterp.doubleValue = v
        }
      }
      else if v.truncatingRemainder(dividingBy: 1) == 0 {
        uninterp.positiveIntValue = UInt64(v)
      }
      else {
        uninterp.doubleValue = v
      }
    }

    return uninterp
  }
}
