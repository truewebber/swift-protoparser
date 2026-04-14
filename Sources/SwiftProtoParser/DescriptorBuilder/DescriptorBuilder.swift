import Foundation
import SwiftProtobuf

/// Main descriptor builder that converts ProtoAST to swift-protobuf FileDescriptorProto.
struct DescriptorBuilder {

  /// Convert ProtoAST to FileDescriptorProto.
  static func buildFileDescriptor(from ast: ProtoAST, fileName: String) throws
    -> Google_Protobuf_FileDescriptorProto
  {
    var fileProto = Google_Protobuf_FileDescriptorProto()

    // Set file name
    fileProto.name = fileName

    // Set syntax per protoc behaviour:
    // proto3 → "proto3"; proto2 / no-syntax → field is left unset (protoc omits the field).
    let syntaxValue = ast.syntax.descriptorSyntaxValue
    if !syntaxValue.isEmpty {
      fileProto.syntax = syntaxValue
    }

    // Set package
    if let package = ast.package {
      fileProto.package = package
    }

    // Set imports: populate dependency, publicDependency, and weakDependency.
    for (index, importNode) in ast.imports.enumerated() {
      fileProto.dependency.append(importNode.path)
      switch importNode.modifier {
      case .public:
        fileProto.publicDependency.append(Int32(index))
      case .weak:
        fileProto.weakDependency.append(Int32(index))
      case .none:
        break
      }
    }

    // Convert messages
    for messageNode in ast.messages {
      let messageProto = try MessageDescriptorBuilder.build(
        from: messageNode,
        packageName: ast.package,
        protoVersion: ast.syntax
      )
      fileProto.messageType.append(messageProto)
    }

    // Convert enums
    for enumNode in ast.enums {
      let enumProto = try EnumDescriptorBuilder.build(from: enumNode, protoVersion: ast.syntax)
      fileProto.enumType.append(enumProto)
    }

    // Convert services
    for serviceNode in ast.services {
      let serviceProto = try ServiceDescriptorBuilder.build(from: serviceNode, packageName: ast.package)
      fileProto.service.append(serviceProto)
    }

    // Convert top-level extend blocks → FileDescriptorProto.extension
    for extendNode in ast.extends {
      let extendee = buildFullyQualifiedExtendee(extendNode.extendedType, packageName: ast.package)
      for fieldNode in extendNode.fields {
        var fieldProto = try FieldDescriptorBuilder.build(
          from: fieldNode,
          index: 0,
          packageName: ast.package,
          protoVersion: ast.syntax
        )
        fieldProto.extendee = extendee
        fileProto.extension.append(fieldProto)
      }
    }

    // Convert file options
    if !ast.options.isEmpty {
      fileProto.options = try buildFileOptions(from: ast.options)
    }

    return fileProto
  }

  /// Returns the extendee name as a fully-qualified absolute reference (with leading `.`).
  ///
  /// - Already-absolute names (starting with `.`): returned unchanged.
  /// - Qualified names (containing `.`): a leading `.` is prepended to mark them as global.
  /// - Simple names (no dots): the current package is prepended so that `Base` in package
  ///   `my.pkg` becomes `.my.pkg.Base`, matching protoc's name resolution behaviour.
  private static func buildFullyQualifiedExtendee(_ name: String, packageName: String?) -> String {
    if name.hasPrefix(".") {
      return name
    }
    if name.contains(".") {
      return ".\(name)"
    }
    if let pkg = packageName, !pkg.isEmpty {
      return ".\(pkg).\(name)"
    }
    return ".\(name)"
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
        fileOptions.uninterpretedOption.append(buildUninterpretedOption(from: option))
      }
    }

    return fileOptions
  }
}
