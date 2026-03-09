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

    // Convert reserved numbers → EnumReservedRange (end is inclusive, unlike DescriptorProto.ReservedRange)
    if !enumNode.reservedNumbers.isEmpty {
      enumProto.reservedRange = buildEnumReservedRanges(from: enumNode.reservedNumbers)
    }

    // Convert reserved names
    if !enumNode.reservedNames.isEmpty {
      enumProto.reservedName.append(contentsOf: enumNode.reservedNames)
    }

    return enumProto
  }

  /// Groups sorted reserved numbers into `EnumReservedRange` entries.
  ///
  /// Consecutive numbers (e.g. [4, 5, 6]) are merged into a single range.
  /// `EnumReservedRange.end` is **inclusive** (unlike `DescriptorProto.ReservedRange` where end is exclusive).
  private static func buildEnumReservedRanges(
    from reservedNumbers: [Int32]
  ) -> [Google_Protobuf_EnumDescriptorProto.EnumReservedRange] {
    var ranges: [Google_Protobuf_EnumDescriptorProto.EnumReservedRange] = []
    let sorted = reservedNumbers.sorted()
    var rangeStart: Int32?
    var rangeEnd: Int32?

    for number in sorted {
      if let end = rangeEnd, number == end + 1 {
        rangeEnd = number
      }
      else {
        if let start = rangeStart, let end = rangeEnd {
          var r = Google_Protobuf_EnumDescriptorProto.EnumReservedRange()
          r.start = start
          r.end = end
          ranges.append(r)
        }
        rangeStart = number
        rangeEnd = number
      }
    }

    if let start = rangeStart, let end = rangeEnd {
      var r = Google_Protobuf_EnumDescriptorProto.EnumReservedRange()
      r.start = start
      r.end = end
      ranges.append(r)
    }

    return ranges
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
