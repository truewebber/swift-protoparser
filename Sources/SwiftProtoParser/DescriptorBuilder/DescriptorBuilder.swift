import Foundation
import SwiftProtobuf

/// Main descriptor builder that converts ProtoAST to swift-protobuf FileDescriptorProto.
public struct DescriptorBuilder {
  
  /// Convert ProtoAST to FileDescriptorProto.
  public static func buildFileDescriptor(from ast: ProtoAST, fileName: String) throws -> Google_Protobuf_FileDescriptorProto {
    var fileProto = Google_Protobuf_FileDescriptorProto()
    
    // Set file name
    fileProto.name = fileName
    
    // Set syntax
    fileProto.syntax = ast.syntax.rawValue
    
    // Set package
    if let package = ast.package {
      fileProto.package = package
    }
    
    // Set imports
    fileProto.dependency.append(contentsOf: ast.imports)
    
    // Convert messages
    for messageNode in ast.messages {
      let messageProto = try MessageDescriptorBuilder.build(from: messageNode)
      fileProto.messageType.append(messageProto)
    }
    
    // Convert enums
    for enumNode in ast.enums {
      let enumProto = try EnumDescriptorBuilder.build(from: enumNode)
      fileProto.enumType.append(enumProto)
    }
    
    // Convert services
    for serviceNode in ast.services {
      let serviceProto = try ServiceDescriptorBuilder.build(from: serviceNode)
      fileProto.service.append(serviceProto)
    }
    
    // Convert file options
    if !ast.options.isEmpty {
      // TODO: Implement file options conversion
    }
    
    return fileProto
  }
}
