import Foundation

/// Root AST node representing a complete .proto file
public struct ProtoAST {
    /// Protocol Buffer syntax version (proto3 only supported)
    public let syntax: ProtoVersion
    
    /// Package declaration
    public let package: String?
    
    /// Import statements
    public let imports: [String]
    
    /// Top-level options
    public let options: [OptionNode]
    
    /// Message definitions
    public let messages: [MessageNode]
    
    /// Enum definitions
    public let enums: [EnumNode]
    
    /// Service definitions
    public let services: [ServiceNode]
    
    public init(
        syntax: ProtoVersion,
        package: String? = nil,
        imports: [String] = [],
        options: [OptionNode] = [],
        messages: [MessageNode] = [],
        enums: [EnumNode] = [],
        services: [ServiceNode] = []
    ) {
        self.syntax = syntax
        self.package = package
        self.imports = imports
        self.options = options
        self.messages = messages
        self.enums = enums
        self.services = services
    }
}

// MARK: - Equatable
extension ProtoAST: Equatable {
    public static func == (lhs: ProtoAST, rhs: ProtoAST) -> Bool {
        return lhs.syntax == rhs.syntax &&
               lhs.package == rhs.package &&
               lhs.imports == rhs.imports &&
               lhs.options == rhs.options &&
               lhs.messages == rhs.messages &&
               lhs.enums == rhs.enums &&
               lhs.services == rhs.services
    }
}

// MARK: - CustomStringConvertible
extension ProtoAST: CustomStringConvertible {
    public var description: String {
        var components: [String] = []
        
        components.append("syntax = \"\(syntax)\";")
        
        if let package = package {
            components.append("package \(package);")
        }
        
        for importPath in imports {
            components.append("import \"\(importPath)\";")
        }
        
        for option in options {
            components.append(option.description)
        }
        
        for enumNode in enums {
            components.append(enumNode.description)
        }
        
        for message in messages {
            components.append(message.description)
        }
        
        for service in services {
            components.append(service.description)
        }
        
        return components.joined(separator: "\n\n")
    }
}
