import Foundation
import SwiftProtobuf

/// Builds SwiftProtobuf EnumDescriptorProto from AST EnumNode.
struct EnumDescriptorBuilder {

  /// Convert EnumNode to EnumDescriptorProto.
  static func build(
    from enumNode: EnumNode,
    protoVersion: ProtoVersion = .proto3
  ) throws -> Google_Protobuf_EnumDescriptorProto {
    var enumProto = Google_Protobuf_EnumDescriptorProto()

    // Set enum name
    enumProto.name = enumNode.name

    // Convert enum values
    for valueNode in enumNode.values {
      let valueProto = try buildEnumValue(from: valueNode)
      enumProto.value.append(valueProto)
    }

    // Zero value is required only in proto3
    if protoVersion == .proto3 && !enumNode.hasZeroValue {
      throw DescriptorError.conversionFailed("Enum '\(enumNode.name)' must have a zero value in proto3")
    }

    // Convert enum options
    if !enumNode.options.isEmpty {
      enumProto.options = try buildEnumOptions(from: enumNode.options)
    }

    // Convert reserved ranges → EnumReservedRange (end is inclusive)
    if !enumNode.reservedRanges.isEmpty {
      enumProto.reservedRange = buildEnumReservedRanges(from: enumNode.reservedRanges)
    }

    // Convert reserved names
    if !enumNode.reservedNames.isEmpty {
      enumProto.reservedName.append(contentsOf: enumNode.reservedNames)
    }

    return enumProto
  }

  /// Converts AST `ReservedNumberRange` values into `EnumReservedRange` descriptors.
  ///
  /// `EnumReservedRange.end` is **inclusive**.
  /// For the `max` sentinel, the inclusive end is `Int32.max` (2_147_483_647),
  /// which matches protoc's output for `reserved N to max;` inside an enum.
  private static func buildEnumReservedRanges(
    from reservedRanges: [ReservedNumberRange]
  ) -> [Google_Protobuf_EnumDescriptorProto.EnumReservedRange] {
    reservedRanges.map { r in
      var range = Google_Protobuf_EnumDescriptorProto.EnumReservedRange()
      range.start = r.start
      range.end = r.endIsMax ? Int32.max : r.end
      return range
    }
  }

  /// Build EnumValueDescriptorProto from EnumValueNode.
  private static func buildEnumValue(from valueNode: EnumValueNode) throws -> Google_Protobuf_EnumValueDescriptorProto {
    var valueProto = Google_Protobuf_EnumValueDescriptorProto()

    valueProto.name = valueNode.name
    valueProto.number = valueNode.number

    // Convert value options
    if !valueNode.options.isEmpty {
      valueProto.options = try buildEnumValueOptions(from: valueNode.options)
    }

    return valueProto
  }

  /// Build EnumOptions from AST options.
  private static func buildEnumOptions(from options: [OptionNode]) throws -> Google_Protobuf_EnumOptions {
    var enumOptions = Google_Protobuf_EnumOptions()

    for option in options {
      switch option.name {
      case "allow_alias":
        if case .boolean(let value) = option.value {
          enumOptions.allowAlias = value
        }
      case "deprecated":
        if case .boolean(let value) = option.value {
          enumOptions.deprecated = value
        }
      default:
        // Custom options - add to uninterpreted_option
        // This is a simplified implementation
        break
      }
    }

    return enumOptions
  }

  /// Build EnumValueOptions from AST options.
  private static func buildEnumValueOptions(from options: [OptionNode]) throws -> Google_Protobuf_EnumValueOptions {
    var valueOptions = Google_Protobuf_EnumValueOptions()

    for option in options {
      switch option.name {
      case "deprecated":
        if case .boolean(let value) = option.value {
          valueOptions.deprecated = value
        }
      default:
        // Custom options - add to uninterpreted_option
        // This is a simplified implementation
        break
      }
    }

    return valueOptions
  }
}
