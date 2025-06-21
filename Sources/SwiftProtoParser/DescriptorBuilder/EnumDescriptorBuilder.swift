import Foundation
import SwiftProtobuf

/// Builds SwiftProtobuf EnumDescriptorProto from AST EnumNode.
struct EnumDescriptorBuilder {
  
  /// Convert EnumNode to EnumDescriptorProto.
  static func build(from enumNode: EnumNode) throws -> Google_Protobuf_EnumDescriptorProto {
    var enumProto = Google_Protobuf_EnumDescriptorProto()
    
    // Set enum name
    enumProto.name = enumNode.name
    
    // Convert enum values
    for valueNode in enumNode.values {
      let valueProto = try buildEnumValue(from: valueNode)
      enumProto.value.append(valueProto)
    }
    
    // Validate that enum has a zero value (required in proto3)
    if !enumNode.hasZeroValue {
      throw DescriptorError.conversionFailed("Enum '\(enumNode.name)' must have a zero value in proto3")
    }
    
    // Convert enum options
    if !enumNode.options.isEmpty {
      enumProto.options = try buildEnumOptions(from: enumNode.options)
    }
    
    return enumProto
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
