import Foundation

/// Represents an RPC method in a service.
public struct RPCNode: Node {
  /// Source location of this RPC.
  public let location: SourceLocation

  /// Comments that appear before this RPC.
  public let leadingComments: [String]

  /// Comment that appears after the RPC definition.
  public let trailingComment: String?

  /// Name of the RPC method.
  public let name: String

  /// Input message type.
  public let inputType: String

  /// Output message type.
  public let outputType: String

  /// Whether the input is a stream.
  public let clientStreaming: Bool

  /// Whether the output is a stream.
  public let serverStreaming: Bool

  /// Options applied to this RPC.
  public let options: [OptionNode]

  public init(
    location: SourceLocation,
    leadingComments: [String] = [],
    trailingComment: String? = nil,
    name: String,
    inputType: String,
    outputType: String,
    clientStreaming: Bool = false,
    serverStreaming: Bool = false,
    options: [OptionNode] = []
  ) {
    self.location = location
    self.leadingComments = leadingComments
    self.trailingComment = trailingComment
    self.name = name
    self.inputType = inputType
    self.outputType = outputType
    self.clientStreaming = clientStreaming
    self.serverStreaming = serverStreaming
    self.options = options
  }
}

/// Represents a service definition in a proto file.
public final class ServiceNode: DefinitionNode {
  /// Source location of this service.
  public let location: SourceLocation

  /// Comments that appear before this service.
  public let leadingComments: [String]

  /// Comment that appears after the service name.
  public let trailingComment: String?

  /// Name of the service.
  public let name: String

  /// RPC methods defined in this service.
  public private(set) var rpcs: [RPCNode]

  /// Options applied to this service.
  public private(set) var options: [OptionNode]

  public init(
    location: SourceLocation,
    leadingComments: [String] = [],
    trailingComment: String? = nil,
    name: String,
    rpcs: [RPCNode] = [],
    options: [OptionNode] = []
  ) {
    self.location = location
    self.leadingComments = leadingComments
    self.trailingComment = trailingComment
    self.name = name
    self.rpcs = rpcs
    self.options = options
  }
}

// MARK: - RPC Management

extension ServiceNode {
  /// Gets all RPC method names in this service.
  public var methodNames: Set<String> {
    return Set(rpcs.map { $0.name })
  }

  /// Gets all message types referenced by RPCs in this service.
  public var messageReferences: Set<String> {
    var references = Set<String>()
    for rpc in rpcs {
      references.insert(rpc.inputType)
      references.insert(rpc.outputType)
    }
    return references
  }

  /// Finds an RPC by name.
  /// - Parameter name: The name to look for.
  /// - Returns: The RPC if found.
  public func findRPC(named name: String) -> RPCNode? {
    return rpcs.first { $0.name == name }
  }

  /// Returns streaming RPCs.
  /// - Returns: Array of RPCs that use streaming.
  public func streamingRPCs() -> [RPCNode] {
    return rpcs.filter { $0.clientStreaming || $0.serverStreaming }
  }
}

// MARK: - Validation

extension ServiceNode {
  /// Validates the service according to proto3 rules.
  /// - Throws: ParserError if validation fails.
  public func validate() throws {
    // Validate service name
    guard isValidServiceName(name) else {
      throw ParserError.invalidServiceName(name)
    }

    // Validate that there is at least one RPC
    guard !rpcs.isEmpty else {
      throw ParserError.emptyService(name)
    }

    // Validate RPC methods
    var seenNames = Set<String>()

    for rpc in rpcs {
      // Validate RPC name format
      guard isValidRPCName(rpc.name) else {
        throw ParserError.invalidRPCName(rpc.name)
      }

      // Check for duplicate names
      guard !seenNames.contains(rpc.name) else {
        throw ParserError.duplicateRPCName(rpc.name)
      }
      seenNames.insert(rpc.name)

      // Validate message type references
      guard isValidMessageType(rpc.inputType) else {
        throw ParserError.invalidMessageType(rpc.inputType)
      }
      guard isValidMessageType(rpc.outputType) else {
        throw ParserError.invalidMessageType(rpc.outputType)
      }

      // Validate RPC options
      for option in rpc.options {
        try validateRPCOption(option)
      }
    }

    // Validate service options
    for option in options {
      try validateServiceOption(option)
    }
  }

  private func validateRPCOption(_ option: OptionNode) throws {
    // Add RPC-specific option validation here
    // For example, validate timeout values, retry policy, etc.
    switch option.name {
    case "timeout":
      if case .string(let value) = option.value {
        guard value.hasSuffix("s") || value.hasSuffix("ms") else {
          throw ParserError.invalidRPCOption(option.name, "timeout must include unit (s or ms)")
        }
        let numberPart = String(value.dropLast(value.hasSuffix("ms") ? 2 : 1))
        guard Double(numberPart) != nil else {
          throw ParserError.invalidRPCOption(option.name, "invalid timeout value")
        }
      }
    default:
      break  // Other options are allowed without specific validation
    }
  }

  private func validateServiceOption(_ option: OptionNode) throws {
    // Add service-specific option validation here
    switch option.name {
    case "deprecated":
      switch option.value {
      case .identifier(let value) where value == "true" || value == "false":
        break  // Valid boolean value
      default:
        throw ParserError.invalidServiceOption(option.name, "must be a boolean")
      }
    default:
      break  // Other options are allowed without specific validation
    }
  }
}

// MARK: - Additional Error Types

extension ParserError {
  static func emptyService(_ name: String) -> ParserError {
    return .custom("Service '\(name)' must have at least one RPC method")
  }

  static func duplicateRPCName(_ name: String) -> ParserError {
    return .custom("Duplicate RPC method name: '\(name)'")
  }

  static func invalidMessageType(_ type: String) -> ParserError {
    return .custom("Invalid message type reference: '\(type)'")
  }

  static func invalidRPCOption(_ option: String, _ reason: String) -> ParserError {
    return .custom("Invalid RPC option '\(option)': \(reason)")
  }

  static func invalidServiceOption(_ option: String, _ reason: String) -> ParserError {
    return .custom("Invalid service option '\(option)': \(reason)")
  }
}

// MARK: - Helper Functions

private func isValidServiceName(_ name: String) -> Bool {
  guard let first = name.first else { return false }
  return first.isUppercase && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
}

private func isValidRPCName(_ name: String) -> Bool {
  guard let first = name.first else { return false }
  return first.isUppercase && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
}

private func isValidMessageType(_ type: String) -> Bool {
  let components = type.split(separator: ".")
  guard !components.isEmpty else { return false }
  return components.allSatisfy { component in
    guard let first = component.first else { return false }
    return first.isUppercase && component.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
  }
}
