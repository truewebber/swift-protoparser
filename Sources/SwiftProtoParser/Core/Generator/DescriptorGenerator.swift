import Foundation
import SwiftProtobuf

/// Generates Swift Protobuf descriptors from AST nodes
public final class DescriptorGenerator {
  /// Current package being processed
  private var currentPackage: String?

  /// Map of fully qualified names to descriptors
  private var descriptorMap: [String: Any] = [:]

  /// File options being collected
  private var fileOptions: [String: Any] = [:]

  /// Initialize a new descriptor generator
  public init() {}

  /// Generates a file descriptor from a FileNode
  /// - Parameter file: The file node to convert
  /// - Returns: A FileDescriptorProto representing the file
  /// - Throws: DescriptorGeneratorError if generation fails
  public func generateFileDescriptor(_ file: FileNode) throws -> Google_Protobuf_FileDescriptorProto
  {
    // Reset state
    descriptorMap.removeAll()
    fileOptions.removeAll()
    currentPackage = file.package

    var fileDescriptor = Google_Protobuf_FileDescriptorProto()

    // Set basic file properties
    fileDescriptor.syntax = file.syntax
    fileDescriptor.package = file.package ?? ""

    // Process imports
    fileDescriptor.dependency = file.importedFiles
    fileDescriptor.publicDependency = file.publicImports.compactMap {
      guard let index = file.importedFiles.firstIndex(of: $0) else { return nil }
      return Int32(index)
    }
    fileDescriptor.weakDependency = file.weakImports.compactMap {
      guard let index = file.importedFiles.firstIndex(of: $0) else { return nil }
      return Int32(index)
    }

    // Process options
    try processFileOptions(file.options, into: &fileDescriptor)

    // Process all messages
    for message in file.messages {
      let descriptor = try generateMessageDescriptor(message)
      fileDescriptor.messageType.append(descriptor)
    }

    // Process all enums
    for enumType in file.enums {
      let descriptor = try generateEnumDescriptor(enumType)
      fileDescriptor.enumType.append(descriptor)
    }

    // Process all services
    for service in file.services {
      let descriptor = try generateServiceDescriptor(service)
      fileDescriptor.service.append(descriptor)
    }

    return fileDescriptor
  }

  // MARK: - Message Generation

  private func generateMessageDescriptor(_ message: MessageNode) throws
    -> Google_Protobuf_DescriptorProto
  {
    var descriptor = Google_Protobuf_DescriptorProto()

    descriptor.name = message.name

    // Process fields
    for field in message.fields {
      let fieldDescriptor = try generateFieldDescriptor(field)
      descriptor.field.append(fieldDescriptor)
    }

    // Process nested types
    for nestedMessage in message.messages {
      let nestedDescriptor = try generateMessageDescriptor(nestedMessage)
      descriptor.nestedType.append(nestedDescriptor)
    }

    // Process nested enums
    for nestedEnum in message.enums {
      let enumDescriptor = try generateEnumDescriptor(nestedEnum)
      descriptor.enumType.append(enumDescriptor)
    }

    // Process oneofs
    for oneof in message.oneofs {
      let oneofDescriptor = try generateOneofDescriptor(oneof)
      descriptor.oneofDecl.append(oneofDescriptor)
    }

    // Process options
    try processMessageOptions(message.options, into: &descriptor)

    // Process reserved ranges and names
    for reserved in message.reserved {
      for range in reserved.ranges {
        switch range {
        case .single(let number):
          var descriptorRange = Google_Protobuf_DescriptorProto.ReservedRange()
          descriptorRange.start = Int32(number)
          descriptorRange.end = Int32(number + 1)
          descriptor.reservedRange.append(descriptorRange)

        case .range(let start, let end):
          var descriptorRange = Google_Protobuf_DescriptorProto.ReservedRange()
          descriptorRange.start = Int32(start)
          descriptorRange.end = Int32(end + 1)
          descriptor.reservedRange.append(descriptorRange)

        case .name(let name):
          descriptor.reservedName.append(name)
        }
      }
    }

    return descriptor
  }

  // MARK: - Field Generation

  private func generateFieldDescriptor(_ field: FieldNode) throws
    -> Google_Protobuf_FieldDescriptorProto
  {
    var descriptor = Google_Protobuf_FieldDescriptorProto()

    descriptor.name = field.name
    descriptor.number = Int32(field.number)
    descriptor.jsonName = field.jsonName ?? field.name

    if field.isRepeated {
      descriptor.label = .repeated
    } else if field.isOptional {
      descriptor.label = .optional
    } else {
      descriptor.proto3Optional = field.isOptional
    }

    switch field.type {
    case .scalar(let scalarType):
      descriptor.type = try mapScalarType(scalarType)

    case .map(let keyType, let valueType):
      descriptor = try generateMapFieldDescriptor(field.name, keyType, valueType, field.number)

    case .named(let typeName):
      descriptor.type = .message
      descriptor.typeName = resolveTypeName(typeName)
    }

    // Process field options
    try processFieldOptions(field.options, into: &descriptor)

    return descriptor
  }

  // MARK: - Enum Generation

  private func generateEnumDescriptor(_ enumType: EnumNode) throws
    -> Google_Protobuf_EnumDescriptorProto
  {
    var descriptor = Google_Protobuf_EnumDescriptorProto()

    descriptor.name = enumType.name

    // Process values
    for value in enumType.values {
      var valueDescriptor = Google_Protobuf_EnumValueDescriptorProto()
      valueDescriptor.name = value.name
      valueDescriptor.number = Int32(value.number)

      // Process enum value options
      try processEnumValueOptions(value.options, into: &valueDescriptor)

      descriptor.value.append(valueDescriptor)
    }

    // Process enum options
    try processEnumOptions(enumType.options, into: &descriptor)

    return descriptor
  }

  // MARK: - Service Generation

  private func generateServiceDescriptor(_ service: ServiceNode) throws
    -> Google_Protobuf_ServiceDescriptorProto
  {
    var descriptor = Google_Protobuf_ServiceDescriptorProto()

    descriptor.name = service.name

    // Process RPCs
    for rpc in service.rpcs {
      var methodDescriptor = Google_Protobuf_MethodDescriptorProto()

      methodDescriptor.name = rpc.name
      methodDescriptor.inputType = resolveTypeName(rpc.inputType)
      methodDescriptor.outputType = resolveTypeName(rpc.outputType)
      methodDescriptor.clientStreaming = rpc.clientStreaming
      methodDescriptor.serverStreaming = rpc.serverStreaming

      // Process RPC options
      try processMethodOptions(rpc.options, into: &methodDescriptor)

      descriptor.method.append(methodDescriptor)
    }

    // Process service options
    try processServiceOptions(service.options, into: &descriptor)

    return descriptor
  }

  // MARK: - Helper Methods

  private func generateOneofDescriptor(_ oneof: OneofNode) throws
    -> Google_Protobuf_OneofDescriptorProto
  {
    var descriptor = Google_Protobuf_OneofDescriptorProto()

    descriptor.name = oneof.name

    // Process oneof options
    try processOneofOptions(oneof.options, into: &descriptor)

    return descriptor
  }

  private func generateMapFieldDescriptor(
    _ name: String,
    _ keyType: TypeNode.ScalarType,
    _ valueType: TypeNode,
    _ number: Int
  ) throws -> Google_Protobuf_FieldDescriptorProto {
    var descriptor = Google_Protobuf_FieldDescriptorProto()

    descriptor.name = name
    descriptor.number = Int32(number)
    descriptor.label = .repeated
    descriptor.type = .message

    // Generate the map entry message type
    var mapEntry = Google_Protobuf_DescriptorProto()
    mapEntry.name = uppercaseFirst(name) + "Entry"
    mapEntry.options = Google_Protobuf_MessageOptions()
    mapEntry.options.mapEntry = true

    // Add key field
    var keyField = Google_Protobuf_FieldDescriptorProto()
    keyField.name = "key"
    keyField.number = 1
    keyField.label = .optional
    keyField.type = try mapScalarType(keyType)
    mapEntry.field.append(keyField)

    // Add value field
    var valueField = Google_Protobuf_FieldDescriptorProto()
    valueField.name = "value"
    valueField.number = 2
    valueField.label = .optional

    switch valueType {
    case .scalar(let scalarType):
      valueField.type = try mapScalarType(scalarType)
    case .named(let typeName):
      valueField.type = .message
      valueField.typeName = resolveTypeName(typeName)
    case .map:
      throw DescriptorGeneratorError.nestedMapNotAllowed
    }

    mapEntry.field.append(valueField)

    return descriptor
  }

  private func mapScalarType(_ type: TypeNode.ScalarType) throws
    -> Google_Protobuf_FieldDescriptorProto.TypeEnum
  {
    switch type {
    case .double: return .double
    case .float: return .float
    case .int32: return .int32
    case .int64: return .int64
    case .uint32: return .uint32
    case .uint64: return .uint64
    case .sint32: return .sint32
    case .sint64: return .sint64
    case .fixed32: return .fixed32
    case .fixed64: return .fixed64
    case .sfixed32: return .sfixed32
    case .sfixed64: return .sfixed64
    case .bool: return .bool
    case .string: return .string
    case .bytes: return .bytes
    }
  }

  private func resolveTypeName(_ name: String) -> String {
    if name.hasPrefix(".") {
      return name
    }
    if let package = currentPackage, !package.isEmpty {
      return ".\(package).\(name)"
    }
    return ".\(name)"
  }

  private func uppercaseFirst(_ str: String) -> String {
    guard let first = str.first else { return str }
    return first.uppercased() + str.dropFirst()
  }
}

// MARK: - Option Processing

extension DescriptorGenerator {
  private func processFileOptions(
    _ options: [OptionNode],
    into descriptor: inout Google_Protobuf_FileDescriptorProto
  ) throws {
    var fileOptions = Google_Protobuf_FileOptions()

    for option in options {
      switch option.name {
      case "java_package":
        guard case .string(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("java_package must be a string")
        }
        fileOptions.javaPackage = value

      case "java_outer_classname":
        guard case .string(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("java_outer_classname must be a string")
        }
        fileOptions.javaOuterClassname = value

      case "java_multiple_files":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("java_multiple_files must be a boolean")
        }
        fileOptions.javaMultipleFiles = value == "true"

      case "java_generate_equals_and_hash":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue(
            "java_generate_equals_and_hash must be a boolean")
        }
        fileOptions.javaGenerateEqualsAndHash = value == "true"

      case "optimize_for":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("optimize_for must be an identifier")
        }
        switch value.uppercased() {
        case "SPEED":
          fileOptions.optimizeFor = .speed
        case "CODE_SIZE":
          fileOptions.optimizeFor = .codeSize
        case "LITE_RUNTIME":
          fileOptions.optimizeFor = .liteRuntime
        default:
          throw DescriptorGeneratorError.invalidOptionValue("Invalid optimize_for value: \(value)")
        }

      case "go_package":
        guard case .string(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("go_package must be a string")
        }
        fileOptions.goPackage = value

      case "cc_generic_services":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("cc_generic_services must be a boolean")
        }
        fileOptions.ccGenericServices = value == "true"

      case "java_generic_services":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue(
            "java_generic_services must be a boolean")
        }
        fileOptions.javaGenericServices = value == "true"

      case "py_generic_services":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("py_generic_services must be a boolean")
        }
        fileOptions.pyGenericServices = value == "true"

      case "deprecated":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("deprecated must be a boolean")
        }
        fileOptions.deprecated = value == "true"

      case "cc_enable_arenas":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("cc_enable_arenas must be a boolean")
        }
        fileOptions.ccEnableArenas = value == "true"

      case "objc_class_prefix":
        guard case .string(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("objc_class_prefix must be a string")
        }
        fileOptions.objcClassPrefix = value

      case "csharp_namespace":
        guard case .string(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("csharp_namespace must be a string")
        }
        fileOptions.csharpNamespace = value

      case "swift_prefix":
        guard case .string(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("swift_prefix must be a string")
        }
        fileOptions.swiftPrefix = value

      case "php_class_prefix":
        guard case .string(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("php_class_prefix must be a string")
        }
        fileOptions.phpClassPrefix = value

      case "php_namespace":
        guard case .string(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("php_namespace must be a string")
        }
        fileOptions.phpNamespace = value

      default:
        if option.name.hasPrefix("(") {
          try processCustomOption(option, into: &fileOptions)
        } else {
          throw DescriptorGeneratorError.unsupportedOption(option.name)
        }
      }
    }

    descriptor.options = fileOptions
  }

  private func processMessageOptions(
    _ options: [OptionNode],
    into descriptor: inout Google_Protobuf_DescriptorProto
  ) throws {
    var messageOptions = Google_Protobuf_MessageOptions()

    for option in options {
      switch option.name {
      case "message_set_wire_format":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue(
            "message_set_wire_format must be a boolean")
        }
        messageOptions.messageSetWireFormat = value == "true"

      case "no_standard_descriptor_accessor":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue(
            "no_standard_descriptor_accessor must be a boolean")
        }
        messageOptions.noStandardDescriptorAccessor = value == "true"

      case "deprecated":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("deprecated must be a boolean")
        }
        messageOptions.deprecated = value == "true"

      case "map_entry":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("map_entry must be a boolean")
        }
        messageOptions.mapEntry = value == "true"

      default:
        if option.name.hasPrefix("(") {
          try processCustomOption(option, into: &messageOptions)
        } else {
          throw DescriptorGeneratorError.unsupportedOption(option.name)
        }
      }
    }

    descriptor.options = messageOptions
  }

  private func processFieldOptions(
    _ options: [OptionNode],
    into descriptor: inout Google_Protobuf_FieldDescriptorProto
  ) throws {
    var fieldOptions = Google_Protobuf_FieldOptions()

    for option in options {
      switch option.name {
      case "ctype":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("ctype must be an identifier")
        }
        switch value.uppercased() {
        case "STRING":
          fieldOptions.ctype = .string
        case "CORD":
          fieldOptions.ctype = .cord
        case "STRING_PIECE":
          fieldOptions.ctype = .stringPiece
        default:
          throw DescriptorGeneratorError.invalidOptionValue("Invalid ctype value: \(value)")
        }

      case "packed":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("packed must be a boolean")
        }
        fieldOptions.packed = value == "true"

      case "jstype":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("jstype must be an identifier")
        }
        switch value.uppercased() {
        case "JS_NORMAL":
          fieldOptions.jstype = .jsNormal
        case "JS_STRING":
          fieldOptions.jstype = .jsString
        case "JS_NUMBER":
          fieldOptions.jstype = .jsNumber
        default:
          throw DescriptorGeneratorError.invalidOptionValue("Invalid jstype value: \(value)")
        }

      case "lazy":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("lazy must be a boolean")
        }
        fieldOptions.lazy = value == "true"

      case "deprecated":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("deprecated must be a boolean")
        }
        fieldOptions.deprecated = value == "true"

      case "weak":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("weak must be a boolean")
        }
        fieldOptions.weak = value == "true"

      default:
        if option.name.hasPrefix("(") {
          try processCustomOption(option, into: &fieldOptions)
        } else {
          throw DescriptorGeneratorError.unsupportedOption(option.name)
        }
      }
    }

    descriptor.options = fieldOptions
  }

  private func processEnumOptions(
    _ options: [OptionNode],
    into descriptor: inout Google_Protobuf_EnumDescriptorProto
  ) throws {
    var enumOptions = Google_Protobuf_EnumOptions()

    for option in options {
      switch option.name {
      case "allow_alias":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("allow_alias must be a boolean")
        }
        enumOptions.allowAlias = value == "true"

      case "deprecated":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("deprecated must be a boolean")
        }
        enumOptions.deprecated = value == "true"

      default:
        if option.name.hasPrefix("(") {
          try processCustomOption(option, into: &enumOptions)
        } else {
          throw DescriptorGeneratorError.unsupportedOption(option.name)
        }
      }
    }

    descriptor.options = enumOptions
  }

  private func processEnumValueOptions(
    _ options: [OptionNode],
    into descriptor: inout Google_Protobuf_EnumValueDescriptorProto
  ) throws {
    var enumValueOptions = Google_Protobuf_EnumValueOptions()

    for option in options {
      switch option.name {
      case "deprecated":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("deprecated must be a boolean")
        }
        enumValueOptions.deprecated = value == "true"

      default:
        if option.name.hasPrefix("(") {
          try processCustomOption(option, into: &enumValueOptions)
        } else {
          throw DescriptorGeneratorError.unsupportedOption(option.name)
        }
      }
    }

    descriptor.options = enumValueOptions
  }

  private func processServiceOptions(
    _ options: [OptionNode],
    into descriptor: inout Google_Protobuf_ServiceDescriptorProto
  ) throws {
    var serviceOptions = Google_Protobuf_ServiceOptions()

    for option in options {
      switch option.name {
      case "deprecated":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("deprecated must be a boolean")
        }
        serviceOptions.deprecated = value == "true"

      default:
        if option.name.hasPrefix("(") {
          try processCustomOption(option, into: &serviceOptions)
        } else {
          throw DescriptorGeneratorError.unsupportedOption(option.name)
        }
      }
    }

    descriptor.options = serviceOptions
  }

  private func processMethodOptions(
    _ options: [OptionNode],
    into descriptor: inout Google_Protobuf_MethodDescriptorProto
  ) throws {
    var methodOptions = Google_Protobuf_MethodOptions()

    for option in options {
      switch option.name {
      case "deprecated":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue("deprecated must be a boolean")
        }
        methodOptions.deprecated = value == "true"

      case "idempotency_level":
        guard case .identifier(let value) = option.value else {
          throw DescriptorGeneratorError.invalidOptionValue(
            "idempotency_level must be an identifier")
        }
        switch value.uppercased() {
        case "IDEMPOTENCY_UNKNOWN":
          methodOptions.idempotencyLevel = .idempotencyUnknown
        case "NO_SIDE_EFFECTS":
          methodOptions.idempotencyLevel = .noSideEffects
        case "IDEMPOTENT":
          methodOptions.idempotencyLevel = .idempotent
        default:
          throw DescriptorGeneratorError.invalidOptionValue(
            "Invalid idempotency_level value: \(value)")
        }

      default:
        if option.name.hasPrefix("(") {
          try processCustomOption(option, into: &methodOptions)
        } else {
          throw DescriptorGeneratorError.unsupportedOption(option.name)
        }
      }
    }

    descriptor.options = methodOptions
  }

  private func processOneofOptions(
    _ options: [OptionNode],
    into descriptor: inout Google_Protobuf_OneofDescriptorProto
  ) throws {
    var oneofOptions = Google_Protobuf_OneofOptions()

    for option in options {
      if option.name.hasPrefix("(") {
        try processCustomOption(option, into: &oneofOptions)
      } else {
        throw DescriptorGeneratorError.unsupportedOption(option.name)
      }
    }

    descriptor.options = oneofOptions
  }

  private func processCustomOption<T: Message>(
    _ option: OptionNode,
    into options: inout T
  ) throws {
    // Custom options processing would go here
    // This requires additional work to handle extension fields
    throw DescriptorGeneratorError.unsupportedOption("Custom options are not yet supported")
  }
}

// MARK: - Errors

/// Errors that can occur during descriptor generation
public enum DescriptorGeneratorError: Error, CustomStringConvertible {
  case nestedMapNotAllowed
  case invalidOptionValue(String)
  case unsupportedOption(String)
  case custom(String)

  public var description: String {
    switch self {
    case .nestedMapNotAllowed:
      return "Nested map fields are not allowed"
    case .invalidOptionValue(let value):
      return "Invalid option value: \(value)"
    case .unsupportedOption(let option):
      return "Unsupported option: \(option)"
    case .custom(let message):
      return message
    }
  }
}
