import Foundation
import SwiftProtobuf

/// Builds SwiftProtobuf FieldDescriptorProto from AST FieldNode.
struct FieldDescriptorBuilder {
  
  /// Convert FieldNode to FieldDescriptorProto.
  static func build(from fieldNode: FieldNode, index: Int32) throws -> Google_Protobuf_FieldDescriptorProto {
    var fieldProto = Google_Protobuf_FieldDescriptorProto()
    
    // Set basic field properties
    fieldProto.name = fieldNode.name
    fieldProto.number = fieldNode.number
    
    // Convert field label
    switch fieldNode.label {
    case .optional:
      fieldProto.label = .optional
    case .singular:
      fieldProto.label = .optional  // Proto3 singular is optional
    case .repeated:
      fieldProto.label = .repeated
    }
    
    // Convert field type - simplified for now
    try setFieldType(fieldProto: &fieldProto, fieldType: fieldNode.type)
    
    // Note: Proto3 doesn't support default values (except for enums)
    // Default values are handled by the runtime
    
    // Convert field options - simplified for now
    if !fieldNode.options.isEmpty {
      // TODO: Implement field options conversion
    }
    
    return fieldProto
  }
  
  /// Set field type in FieldDescriptorProto - simplified implementation.
  private static func setFieldType(fieldProto: inout Google_Protobuf_FieldDescriptorProto, fieldType: FieldType) throws {
    // For now, just set the type name as string
    // TODO: Map FieldType cases to proper Google_Protobuf_FieldDescriptorProto.TypeEnum values
    fieldProto.typeName = fieldType.protoTypeName
  }
}
