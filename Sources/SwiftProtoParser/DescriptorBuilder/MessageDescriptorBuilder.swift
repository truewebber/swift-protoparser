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

    // Generate synthetic map entry messages for map fields
    let mapEntryMessages = try generateMapEntryMessages(from: messageNode.fields, packageName: packageName)
    messageProto.nestedType.append(contentsOf: mapEntryMessages)

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

  // MARK: - Map Entry Message Generation

  /// Generate synthetic entry messages for map fields.
  ///
  /// According to the Protocol Buffers specification, map fields are syntactic sugar
  /// for a repeated nested message. This method generates those synthetic entry messages.
  ///
  /// For example, `map<string, int32> counts = 1;` generates:
  /// ```
  /// message CountsEntry {
  ///   option map_entry = true;
  ///   string key = 1;
  ///   int32 value = 2;
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - fields: Array of field nodes to scan for map types
  ///   - packageName: Optional package name for type resolution
  /// - Returns: Array of generated entry message descriptors
  private static func generateMapEntryMessages(
    from fields: [FieldNode],
    packageName: String?
  ) throws -> [Google_Protobuf_DescriptorProto] {
    var entryMessages: [Google_Protobuf_DescriptorProto] = []

    for field in fields {
      // Only process map fields
      guard case .map(let keyType, let valueType) = field.type else {
        continue
      }

      // Generate entry message name: capitalize first letter + "Entry"
      let entryName = field.name.prefix(1).uppercased() + field.name.dropFirst() + "Entry"

      var entryMessage = Google_Protobuf_DescriptorProto()
      entryMessage.name = entryName

      // Set map_entry option to true
      var messageOptions = Google_Protobuf_MessageOptions()
      messageOptions.mapEntry = true
      entryMessage.options = messageOptions

      // Create key field (field number 1)
      var keyField = Google_Protobuf_FieldDescriptorProto()
      keyField.name = "key"
      keyField.number = 1
      keyField.label = .optional
      try setFieldTypeAndName(&keyField, fieldType: keyType, packageName: packageName)

      // Create value field (field number 2)
      var valueField = Google_Protobuf_FieldDescriptorProto()
      valueField.name = "value"
      valueField.number = 2
      valueField.label = .optional
      try setFieldTypeAndName(&valueField, fieldType: valueType, packageName: packageName)

      // Add fields to entry message
      entryMessage.field = [keyField, valueField]

      entryMessages.append(entryMessage)
    }

    return entryMessages
  }

  /// Set field type and type name in a FieldDescriptorProto based on FieldType.
  ///
  /// - Parameters:
  ///   - fieldProto: Field descriptor to modify
  ///   - fieldType: AST field type
  ///   - packageName: Optional package name for type resolution
  private static func setFieldTypeAndName(
    _ fieldProto: inout Google_Protobuf_FieldDescriptorProto,
    fieldType: FieldType,
    packageName: String?
  ) throws {
    switch fieldType {
    // Scalar types
    case .double:
      fieldProto.type = .double
    case .float:
      fieldProto.type = .float
    case .int32:
      fieldProto.type = .int32
    case .int64:
      fieldProto.type = .int64
    case .uint32:
      fieldProto.type = .uint32
    case .uint64:
      fieldProto.type = .uint64
    case .sint32:
      fieldProto.type = .sint32
    case .sint64:
      fieldProto.type = .sint64
    case .fixed32:
      fieldProto.type = .fixed32
    case .fixed64:
      fieldProto.type = .fixed64
    case .sfixed32:
      fieldProto.type = .sfixed32
    case .sfixed64:
      fieldProto.type = .sfixed64
    case .bool:
      fieldProto.type = .bool
    case .string:
      fieldProto.type = .string
    case .bytes:
      fieldProto.type = .bytes

    // Complex types
    case .message(let typeName):
      fieldProto.type = .message
      fieldProto.typeName = buildFullyQualifiedTypeName(typeName, packageName: packageName)

    case .enumType(let typeName):
      fieldProto.type = .enum
      fieldProto.typeName = buildFullyQualifiedTypeName(typeName, packageName: packageName)

    case .qualifiedType(let qualifiedName):
      // For qualified types like google.protobuf.Timestamp, assume it's a message type
      fieldProto.type = .message
      // Qualified names are already fully qualified, just add leading dot if missing
      fieldProto.typeName = qualifiedName.hasPrefix(".") ? qualifiedName : ".\(qualifiedName)"

    case .map(_, _):
      // Maps should not appear as key or value types in map entries
      // This is invalid in proto3
      throw DescriptorError.invalidMapType("Map cannot be used as key or value type in another map")
    }
  }

  /// Build fully qualified type name with package prefix.
  ///
  /// - Parameters:
  ///   - typeName: Type name to qualify
  ///   - packageName: Optional package name
  /// - Returns: Fully qualified type name with leading dot
  private static func buildFullyQualifiedTypeName(_ typeName: String, packageName: String?) -> String {
    // If already starts with dot, it's already fully qualified
    if typeName.hasPrefix(".") {
      return typeName
    }

    // Build fully qualified name
    if let package = packageName, !package.isEmpty {
      return ".\(package).\(typeName)"
    }
    else {
      return ".\(typeName)"
    }
  }
}
