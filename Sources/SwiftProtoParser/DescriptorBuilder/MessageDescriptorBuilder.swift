import Foundation
import SwiftProtobuf

/// Builds SwiftProtobuf DescriptorProto from AST MessageNode.
struct MessageDescriptorBuilder {

  /// Convert MessageNode to DescriptorProto.
  static func build(from messageNode: MessageNode, packageName: String? = nil) throws -> Google_Protobuf_DescriptorProto
  {
    var messageProto = Google_Protobuf_DescriptorProto()

    // Set message name
    messageProto.name = messageNode.name

    // Convert fields
    for (index, fieldNode) in messageNode.fields.enumerated() {
      let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: Int32(index), packageName: packageName)
      messageProto.field.append(fieldProto)
    }

    // Convert nested messages
    for nestedMessage in messageNode.nestedMessages {
      let nestedProto = try build(from: nestedMessage, packageName: packageName)
      messageProto.nestedType.append(nestedProto)
    }

    // Convert nested enums
    for nestedEnum in messageNode.nestedEnums {
      let enumProto = try EnumDescriptorBuilder.build(from: nestedEnum)
      messageProto.enumType.append(enumProto)
    }

    // Convert oneof groups
    for oneofGroup in messageNode.oneofGroups {
      let oneofProto = try buildOneof(from: oneofGroup)
      messageProto.oneofDecl.append(oneofProto)
    }

    // Convert reserved numbers to reserved ranges
    if !messageNode.reservedNumbers.isEmpty {
      messageProto.reservedRange = try buildReservedRanges(from: messageNode.reservedNumbers)
    }

    // Convert reserved names
    if !messageNode.reservedNames.isEmpty {
      messageProto.reservedName.append(contentsOf: messageNode.reservedNames)
    }

    // Convert message options
    if !messageNode.options.isEmpty {
      messageProto.options = try buildMessageOptions(from: messageNode.options)
    }

    return messageProto
  }

  /// Build OneofDescriptorProto from OneofNode.
  private static func buildOneof(from oneofNode: OneofNode) throws -> Google_Protobuf_OneofDescriptorProto {
    var oneofProto = Google_Protobuf_OneofDescriptorProto()

    oneofProto.name = oneofNode.name

    // Convert oneof options
    if !oneofNode.options.isEmpty {
      oneofProto.options = try buildOneofOptions(from: oneofNode.options)
    }

    return oneofProto
  }

  /// Build reserved ranges from reserved numbers.
  private static func buildReservedRanges(from reservedNumbers: [Int32]) throws -> [Google_Protobuf_DescriptorProto
    .ReservedRange]
  {
    var ranges: [Google_Protobuf_DescriptorProto.ReservedRange] = []

    // Sort numbers to create ranges
    let sortedNumbers = reservedNumbers.sorted()

    var rangeStart: Int32?
    var rangeEnd: Int32?

    for number in sortedNumbers {
      if let start = rangeStart, let end = rangeEnd {
        if number == end + 1 {
          // Extend current range
          rangeEnd = number
        }
        else {
          // Close current range and start new one
          var range = Google_Protobuf_DescriptorProto.ReservedRange()
          range.start = start
          range.end = end + 1  // end is exclusive in protobuf
          ranges.append(range)

          rangeStart = number
          rangeEnd = number
        }
      }
      else {
        // Start first range
        rangeStart = number
        rangeEnd = number
      }
    }

    // Close last range
    if let start = rangeStart, let end = rangeEnd {
      var range = Google_Protobuf_DescriptorProto.ReservedRange()
      range.start = start
      range.end = end + 1  // end is exclusive in protobuf
      ranges.append(range)
    }

    return ranges
  }

  /// Build MessageOptions from AST options.
  private static func buildMessageOptions(from options: [OptionNode]) throws -> Google_Protobuf_MessageOptions {
    var messageOptions = Google_Protobuf_MessageOptions()

    for option in options {
      switch option.name {
      case "deprecated":
        if case .boolean(let value) = option.value {
          messageOptions.deprecated = value
        }
      case "map_entry":
        if case .boolean(let value) = option.value {
          messageOptions.mapEntry = value
        }
      case "message_set_wire_format":
        if case .boolean(let value) = option.value {
          messageOptions.messageSetWireFormat = value
        }
      case "no_standard_descriptor_accessor":
        if case .boolean(let value) = option.value {
          messageOptions.noStandardDescriptorAccessor = value
        }
      default:
        // Custom options - add to uninterpreted_option
        var uninterpretedOption = Google_Protobuf_UninterpretedOption()
        var namePart = Google_Protobuf_UninterpretedOption.NamePart()
        namePart.namePart = option.name
        namePart.isExtension = option.isCustom
        uninterpretedOption.name = [namePart]

        // Set value based on option value type
        switch option.value {
        case .string(let value):
          uninterpretedOption.stringValue = Data(value.utf8)
        case .number(let value):
          uninterpretedOption.positiveIntValue = UInt64(value)
        case .boolean(let value):
          uninterpretedOption.identifierValue = value ? "true" : "false"
        case .identifier(let value):
          uninterpretedOption.identifierValue = value
        }

        messageOptions.uninterpretedOption.append(uninterpretedOption)
      }
    }

    return messageOptions
  }

  /// Build OneofOptions from AST options.
  private static func buildOneofOptions(from options: [OptionNode]) throws -> Google_Protobuf_OneofOptions {
    var oneofOptions = Google_Protobuf_OneofOptions()

    for option in options {
      switch option.name {
      default:
        // Custom options - add to uninterpreted_option
        var uninterpretedOption = Google_Protobuf_UninterpretedOption()
        var namePart = Google_Protobuf_UninterpretedOption.NamePart()
        namePart.namePart = option.name
        namePart.isExtension = option.isCustom
        uninterpretedOption.name = [namePart]

        // Set value based on option value type
        switch option.value {
        case .string(let value):
          uninterpretedOption.stringValue = Data(value.utf8)
        case .number(let value):
          uninterpretedOption.positiveIntValue = UInt64(value)
        case .boolean(let value):
          uninterpretedOption.identifierValue = value ? "true" : "false"
        case .identifier(let value):
          uninterpretedOption.identifierValue = value
        }

        oneofOptions.uninterpretedOption.append(uninterpretedOption)
      }
    }

    return oneofOptions
  }
}
