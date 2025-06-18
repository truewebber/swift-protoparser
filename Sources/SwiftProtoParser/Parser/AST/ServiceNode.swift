import Foundation

/// Represents a protobuf service definition
public struct ServiceNode: Equatable {
    /// The service name
    public let name: String
    
    /// The RPC methods in this service
    public let methods: [RPCMethodNode]
    
    /// Service-specific options
    public let options: [OptionNode]
    
    public init(
        name: String,
        methods: [RPCMethodNode] = [],
        options: [OptionNode] = []
    ) {
        self.name = name
        self.methods = methods
        self.options = options
    }
    
    /// Returns the RPC method with the given name, if it exists
    public func method(named name: String) -> RPCMethodNode? {
        return methods.first { $0.name == name }
    }
    
    /// Returns all method names used in this service
    public var usedMethodNames: Set<String> {
        return Set(methods.map { $0.name })
    }
}

/// Represents an RPC method within a protobuf service
public struct RPCMethodNode: Equatable {
    /// The method name
    public let name: String
    
    /// The input (request) message type
    public let inputType: String
    
    /// The output (response) message type
    public let outputType: String
    
    /// Whether the input is streamed
    public let inputStreaming: Bool
    
    /// Whether the output is streamed
    public let outputStreaming: Bool
    
    /// Method-specific options
    public let options: [OptionNode]
    
    public init(
        name: String,
        inputType: String,
        outputType: String,
        inputStreaming: Bool = false,
        outputStreaming: Bool = false,
        options: [OptionNode] = []
    ) {
        self.name = name
        self.inputType = inputType
        self.outputType = outputType
        self.inputStreaming = inputStreaming
        self.outputStreaming = outputStreaming
        self.options = options
    }
    
    /// Returns the streaming type of this RPC method
    public var streamingType: RPCStreamingType {
        switch (inputStreaming, outputStreaming) {
        case (false, false):
            return .unary
        case (false, true):
            return .serverStreaming
        case (true, false):
            return .clientStreaming
        case (true, true):
            return .bidirectionalStreaming
        }
    }
}

/// Represents the streaming type of an RPC method
public enum RPCStreamingType: String, CaseIterable {
    case unary = "unary"
    case serverStreaming = "server_streaming"
    case clientStreaming = "client_streaming"
    case bidirectionalStreaming = "bidirectional_streaming"
    
    /// Returns a human-readable description of the streaming type
    public var description: String {
        switch self {
        case .unary:
            return "Unary"
        case .serverStreaming:
            return "Server Streaming"
        case .clientStreaming:
            return "Client Streaming"
        case .bidirectionalStreaming:
            return "Bidirectional Streaming"
        }
    }
}

// MARK: - CustomStringConvertible
extension ServiceNode: CustomStringConvertible {
    public var description: String {
        var lines: [String] = []
        
        lines.append("service \(name) {")
        
        // Add options
        for option in options {
            lines.append("  \(option.description)")
        }
        
        // Add methods
        for method in methods {
            let methodLines = method.description.split(separator: "\n")
            for line in methodLines {
                lines.append("  \(line)")
            }
        }
        
        lines.append("}")
        
        return lines.joined(separator: "\n")
    }
}

// MARK: - CustomStringConvertible
extension RPCMethodNode: CustomStringConvertible {
    public var description: String {
        var components: [String] = []
        
        components.append("rpc \(name)(")
        
        if inputStreaming {
            components.append("stream ")
        }
        components.append("\(inputType)) returns (")
        
        if outputStreaming {
            components.append("stream ")
        }
        components.append("\(outputType))")
        
        if options.isEmpty {
            components.append(";")
        } else {
            components.append(" {")
            var lines = [components.joined(separator: "")]
            
            for option in options {
                lines.append("  \(option.description)")
            }
            
            lines.append("}")
            return lines.joined(separator: "\n")
        }
        
        return components.joined(separator: "")
    }
}
