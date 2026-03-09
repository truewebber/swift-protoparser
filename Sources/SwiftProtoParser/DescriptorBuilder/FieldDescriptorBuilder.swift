import Foundation
import SwiftProtobuf

/// Builds SwiftProtobuf FieldDescriptorProto from AST FieldNode.
struct FieldDescriptorBuilder {

  /// Convert FieldNode to FieldDescriptorProto.
  static func build(
    from fieldNode: FieldNode,
    index: Int32,
    packageName: String? = nil,
    protoVersion: ProtoVersion = .proto2
  ) throws -> Google_Protobuf_FieldDescriptorProto {
    var fieldProto = Google_Protobuf_FieldDescriptorProto()

    // Set basic field properties
    fieldProto.name = fieldNode.name
    fieldProto.number = fieldNode.number

    // Convert field label
    switch fieldNode.label {
    case .optional:
      fieldProto.label = .optional
    case .singular:
      fieldProto.label = .optional  // Proto3 singular maps to LABEL_OPTIONAL in descriptor
    case .repeated:
      fieldProto.label = .repeated
    case .required:
      fieldProto.label = .required
    }

    // Convert field type
    try setFieldType(fieldProto: &fieldProto, fieldType: fieldNode.type, packageName: packageName)

    // Extract and handle the [default = ...] option separately from other field options
    let (defaultOption, remainingOptions) = partitionDefaultOption(from: fieldNode.options)
    if let defaultOption = defaultOption {
      if protoVersion == .proto3 {
        throw DescriptorError.conversionFailed("Explicit default values are not allowed in proto3.")
      }
      fieldProto.defaultValue = defaultValueString(from: defaultOption.value)
    }

    // Convert remaining field options (default is never forwarded to uninterpreted_option)
    if !remainingOptions.isEmpty {
      fieldProto.options = try buildFieldOptions(from: remainingOptions)
    }

    return fieldProto
  }

  /// Splits the options array into the `default` option (if present) and the rest.
  private static func partitionDefaultOption(
    from options: [OptionNode]
  ) -> (defaultOption: OptionNode?, remaining: [OptionNode]) {
    var defaultOption: OptionNode?
    var remaining: [OptionNode] = []
    for option in options {
      if option.name == "default" {
        defaultOption = option
      }
      else {
        remaining.append(option)
      }
    }
    return (defaultOption, remaining)
  }

  /// Converts an `OptionValue` to the exact `defaultValue` string format used by protoc.
  private static func defaultValueString(from value: OptionValue) -> String {
    switch value {
    case .string(let str):
      return str
    case .number(let num):
      if num.truncatingRemainder(dividingBy: 1) == 0 {
        return String(Int(num))
      }
      else {
        return String(num)
      }
    case .boolean(let bool):
      return bool ? "true" : "false"
    case .identifier(let id):
      return id
    }
  }

  /// Set field type in FieldDescriptorProto with proper type enum mapping.
  private static func setFieldType(
    fieldProto: inout Google_Protobuf_FieldDescriptorProto,
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
      // Maps are represented as repeated message with special structure
      fieldProto.type = .message
      let capitalizedName = fieldProto.name.prefix(1).uppercased() + fieldProto.name.dropFirst()
      fieldProto.typeName = "\(capitalizedName)Entry"
      fieldProto.label = .repeated
    }
  }

  /// Build fully qualified type name with package prefix.
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

  /// Build FieldOptions from AST options.
  private static func buildFieldOptions(from options: [OptionNode]) throws -> Google_Protobuf_FieldOptions {
    var fieldOptions = Google_Protobuf_FieldOptions()

    for option in options {
      switch option.name {
      case "deprecated":
        if case .boolean(let value) = option.value {
          fieldOptions.deprecated = value
        }
      case "packed":
        if case .boolean(let value) = option.value {
          fieldOptions.packed = value
        }
      case "lazy":
        if case .boolean(let value) = option.value {
          fieldOptions.lazy = value
        }
      case "weak":
        if case .boolean(let value) = option.value {
          fieldOptions.weak = value
        }
      case "jstype":
        if case .identifier(let value) = option.value {
          switch value {
          case "JS_NORMAL":
            fieldOptions.jstype = .jsNormal
          case "JS_STRING":
            fieldOptions.jstype = .jsString
          case "JS_NUMBER":
            fieldOptions.jstype = .jsNumber
          default:
            fieldOptions.jstype = .jsNormal
          }
        }
      case "ctype":
        if case .identifier(let value) = option.value {
          switch value {
          case "STRING":
            fieldOptions.ctype = .string
          case "CORD":
            fieldOptions.ctype = .cord
          case "STRING_PIECE":
            fieldOptions.ctype = .stringPiece
          default:
            fieldOptions.ctype = .string
          }
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

        fieldOptions.uninterpretedOption.append(uninterpretedOption)
      }
    }

    return fieldOptions
  }
}
