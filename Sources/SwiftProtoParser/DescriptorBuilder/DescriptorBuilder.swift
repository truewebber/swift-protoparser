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
      let messageProto = try MessageDescriptorBuilder.build(from: messageNode, packageName: ast.package)
      fileProto.messageType.append(messageProto)
    }
    
    // Convert enums
    for enumNode in ast.enums {
      let enumProto = try EnumDescriptorBuilder.build(from: enumNode)
      fileProto.enumType.append(enumProto)
    }
    
    // Convert services
    for serviceNode in ast.services {
      let serviceProto = try ServiceDescriptorBuilder.build(from: serviceNode, packageName: ast.package)
      fileProto.service.append(serviceProto)
    }
    
    // Convert file options
    if !ast.options.isEmpty {
      fileProto.options = try buildFileOptions(from: ast.options)
    }
    
    return fileProto
  }
  
  /// Build FileOptions from AST options.
  private static func buildFileOptions(from options: [OptionNode]) throws -> Google_Protobuf_FileOptions {
    var fileOptions = Google_Protobuf_FileOptions()
    
    for option in options {
      switch option.name {
      case "java_package":
        if case .string(let value) = option.value {
          fileOptions.javaPackage = value
        }
      case "java_outer_classname":
        if case .string(let value) = option.value {
          fileOptions.javaOuterClassname = value
        }
      case "java_multiple_files":
        if case .boolean(let value) = option.value {
          fileOptions.javaMultipleFiles = value
        }
      case "java_generate_equals_and_hash":
        if case .boolean(let value) = option.value {
          fileOptions.javaGenerateEqualsAndHash = value
        }
      case "java_string_check_utf8":
        if case .boolean(let value) = option.value {
          fileOptions.javaStringCheckUtf8 = value
        }
      case "optimize_for":
        if case .identifier(let value) = option.value {
          switch value {
          case "SPEED":
            fileOptions.optimizeFor = .speed
          case "CODE_SIZE":
            fileOptions.optimizeFor = .codeSize
          case "LITE_RUNTIME":
            fileOptions.optimizeFor = .liteRuntime
          default:
            fileOptions.optimizeFor = .speed
          }
        }
      case "go_package":
        if case .string(let value) = option.value {
          fileOptions.goPackage = value
        }
      case "cc_generic_services":
        if case .boolean(let value) = option.value {
          fileOptions.ccGenericServices = value
        }
      case "java_generic_services":
        if case .boolean(let value) = option.value {
          fileOptions.javaGenericServices = value
        }
      case "py_generic_services":
        if case .boolean(let value) = option.value {
          fileOptions.pyGenericServices = value
        }

      case "deprecated":
        if case .boolean(let value) = option.value {
          fileOptions.deprecated = value
        }
      case "cc_enable_arenas":
        if case .boolean(let value) = option.value {
          fileOptions.ccEnableArenas = value
        }
      case "objc_class_prefix":
        if case .string(let value) = option.value {
          fileOptions.objcClassPrefix = value
        }
      case "csharp_namespace":
        if case .string(let value) = option.value {
          fileOptions.csharpNamespace = value
        }
      case "swift_prefix":
        if case .string(let value) = option.value {
          fileOptions.swiftPrefix = value
        }
      case "php_class_prefix":
        if case .string(let value) = option.value {
          fileOptions.phpClassPrefix = value
        }
      case "php_namespace":
        if case .string(let value) = option.value {
          fileOptions.phpNamespace = value
        }
      case "php_metadata_namespace":
        if case .string(let value) = option.value {
          fileOptions.phpMetadataNamespace = value
        }
      case "ruby_package":
        if case .string(let value) = option.value {
          fileOptions.rubyPackage = value
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
        
        fileOptions.uninterpretedOption.append(uninterpretedOption)
      }
    }
    
    return fileOptions
  }
}
