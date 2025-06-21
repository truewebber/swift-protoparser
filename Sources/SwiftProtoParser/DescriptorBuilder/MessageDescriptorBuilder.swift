import Foundation
import SwiftProtobuf

/// Builds SwiftProtobuf DescriptorProto from AST MessageNode.
struct MessageDescriptorBuilder {
  
  /// Convert MessageNode to DescriptorProto.
  static func build(from messageNode: MessageNode) throws -> Google_Protobuf_DescriptorProto {
    var messageProto = Google_Protobuf_DescriptorProto()
    
    // Set message name
    messageProto.name = messageNode.name
    
    // Convert fields
    for (index, fieldNode) in messageNode.fields.enumerated() {
      let fieldProto = try FieldDescriptorBuilder.build(from: fieldNode, index: Int32(index))
      messageProto.field.append(fieldProto)
    }
    
    // Convert nested messages
    for nestedMessage in messageNode.nestedMessages {
      let nestedProto = try build(from: nestedMessage)
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
    
    // Convert reserved numbers
    if !messageNode.reservedNumbers.isEmpty {
      // TODO: Implement reserved ranges conversion
    }
    
    // Convert reserved names
    if !messageNode.reservedNames.isEmpty {
      messageProto.reservedName.append(contentsOf: messageNode.reservedNames)
    }
    
    // Convert message options
    if !messageNode.options.isEmpty {
      // TODO: Implement message options conversion
    }
    
    return messageProto
  }
  
  /// Build OneofDescriptorProto from OneofNode.
  private static func buildOneof(from oneofNode: OneofNode) throws -> Google_Protobuf_OneofDescriptorProto {
    var oneofProto = Google_Protobuf_OneofDescriptorProto()
    
    oneofProto.name = oneofNode.name
    
    // Convert oneof options
    if !oneofNode.options.isEmpty {
      // TODO: Implement oneof options conversion
    }
    
    return oneofProto
  }
}
