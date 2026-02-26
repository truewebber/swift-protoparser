import Foundation
import SwiftProtobuf

/// Builds SwiftProtobuf ServiceDescriptorProto from AST ServiceNode.
struct ServiceDescriptorBuilder {

  /// Convert ServiceNode to ServiceDescriptorProto.
  static func build(from serviceNode: ServiceNode, packageName: String? = nil) throws
    -> Google_Protobuf_ServiceDescriptorProto
  {
    var serviceProto = Google_Protobuf_ServiceDescriptorProto()

    // Set service name
    serviceProto.name = serviceNode.name

    // Convert RPC methods
    for methodNode in serviceNode.methods {
      let methodProto = try buildMethod(from: methodNode, packageName: packageName)
      serviceProto.method.append(methodProto)
    }

    // Convert service options
    if !serviceNode.options.isEmpty {
      serviceProto.options = try buildServiceOptions(from: serviceNode.options)
    }

    return serviceProto
  }

  /// Build MethodDescriptorProto from RPCMethodNode.
  private static func buildMethod(from methodNode: RPCMethodNode, packageName: String?) throws
    -> Google_Protobuf_MethodDescriptorProto
  {
    var methodProto = Google_Protobuf_MethodDescriptorProto()

    methodProto.name = methodNode.name
    methodProto.inputType = buildFullyQualifiedTypeName(methodNode.inputType, packageName: packageName)
    methodProto.outputType = buildFullyQualifiedTypeName(methodNode.outputType, packageName: packageName)

    // Set streaming flags
    methodProto.clientStreaming = methodNode.inputStreaming
    methodProto.serverStreaming = methodNode.outputStreaming

    // Convert method options
    if !methodNode.options.isEmpty {
      methodProto.options = try buildMethodOptions(from: methodNode.options)
    }

    return methodProto
  }

  /// Build fully qualified type name with package prefix.
  ///
  /// A type name that already contains dots (e.g. `google.protobuf.Empty`) references
  /// a type in a foreign package. In that case only a leading dot is prepended — the
  /// current file's package must not be inserted. A plain name without dots is a local
  /// type and gets the file package prepended as usual.
  private static func buildFullyQualifiedTypeName(_ typeName: String, packageName: String?) -> String {
    // Already fully qualified — return as-is
    if typeName.hasPrefix(".") {
      return typeName
    }

    // Cross-package reference: type name contains dots, so it already carries its own
    // package path. Only add the leading dot.
    if typeName.contains(".") {
      return ".\(typeName)"
    }

    // Local type: prepend the current file's package
    if let package = packageName, !package.isEmpty {
      return ".\(package).\(typeName)"
    }

    return ".\(typeName)"
  }

  /// Build ServiceOptions from AST options.
  private static func buildServiceOptions(from options: [OptionNode]) throws -> Google_Protobuf_ServiceOptions {
    var serviceOptions = Google_Protobuf_ServiceOptions()

    for option in options {
      switch option.name {
      case "deprecated":
        if case .boolean(let value) = option.value {
          serviceOptions.deprecated = value
        }
      default:
        // Custom options - add to uninterpreted_option
        // This is a simplified implementation
        break
      }
    }

    return serviceOptions
  }

  /// Build MethodOptions from AST options.
  private static func buildMethodOptions(from options: [OptionNode]) throws -> Google_Protobuf_MethodOptions {
    var methodOptions = Google_Protobuf_MethodOptions()

    for option in options {
      switch option.name {
      case "deprecated":
        if case .boolean(let value) = option.value {
          methodOptions.deprecated = value
        }
      case "idempotency_level":
        if case .identifier(let value) = option.value {
          switch value {
          case "NO_SIDE_EFFECTS":
            methodOptions.idempotencyLevel = .noSideEffects
          case "IDEMPOTENT":
            methodOptions.idempotencyLevel = .idempotent
          default:
            methodOptions.idempotencyLevel = .idempotencyUnknown
          }
        }
      default:
        // Custom options - add to uninterpreted_option
        // This is a simplified implementation
        break
      }
    }

    return methodOptions
  }
}
