import Foundation

/// Base protocol for all AST nodes.
public protocol ASTNode {
	var startLine: Int { get }
	var startColumn: Int { get }
}

/// Represents the entire .proto file.
public struct ProtoFile: ASTNode {
	public let syntax: Syntax?
	public let imports: [ImportStatement]
	public let package: PackageStatement?
	public let options: [ASTOption]
	public let definitions: [TopLevelDefinition]
	public let startLine: Int
	public let startColumn: Int
}

/// Represents the syntax declaration.
public struct Syntax: ASTNode {
	public let version: String
	public let startLine: Int
	public let startColumn: Int
}

/// Represents an import statement.
public struct ImportStatement: ASTNode {
	public enum Modifier {
		case none
		case publicImport
		case weak
	}
	public let modifier: Modifier
	public let path: String
	public let startLine: Int
	public let startColumn: Int
}

/// Represents the package declaration.
public struct PackageStatement: ASTNode {
	public let name: String
	public let startLine: Int
	public let startColumn: Int
}

/// Represents an option statement.
public struct ASTOption: ASTNode {
	public let name: String
	public let value: ASTOptionValue
	public let startLine: Int
	public let startColumn: Int
}

///// Represents the value of an option.
public enum ASTOptionValue {
	case string(String)
	case number(String)
	case boolean(Bool)
	case aggregate([ASTOption])
}

// Update any references from ASTOption to ASTOption

/// Represents top-level definitions.
public enum TopLevelDefinition: ASTNode {
	case message(MessageDeclaration)
	case enumType(EnumDeclaration)
	case service(ServiceDeclaration)
	// ... other types
	
	public var startLine: Int {
		switch self {
		case .message(let message):
			return message.startLine
		case .enumType(let enumType):
			return enumType.startLine
		case .service(let service):
			return service.startLine
		}
	}
	
	public var startColumn: Int {
		switch self {
		case .message(let message):
			return message.startColumn
		case .enumType(let enumType):
			return enumType.startColumn
		case .service(let service):
			return service.startColumn
		}
	}
}

/// Represents a message declaration.
public struct MessageDeclaration: ASTNode {
	public let name: String
	public let body: [MessageElement]
	public let startLine: Int
	public let startColumn: Int
}

/// Represents elements within a message.
public enum MessageElement {
	case field(FieldDeclaration)
	case enumType(EnumDeclaration)
	case message(MessageDeclaration)
	case oneof(OneofDeclaration)
	case option(ASTOption)
	case reserved(ReservedStatement)
	// ... other elements
}

/// Represents a field declaration.
public struct FieldDeclaration: ASTNode {
	public let label: FieldLabel
	public let type: String
	public let name: String
	public let number: Int
	public let options: [ASTOption]
	public let startLine: Int
	public let startColumn: Int
}

/// Represents the label of a field (optional, repeated).
public enum FieldLabel {
	case optional
	case repeated
}

/// Represents an enum declaration.
public struct EnumDeclaration: ASTNode {
	public let name: String
	public let body: [EnumElement]
	public let startLine: Int
	public let startColumn: Int
}

/// Represents elements within an enum.
public enum EnumElement {
	case value(EnumValue)
	case option(ASTOption)
	case reserved(ReservedStatement)
}

/// Represents an enum value.
public struct EnumValue: ASTNode {
	public let name: String
	public let number: Int
	public let options: [ASTOption]
	public let startLine: Int
	public let startColumn: Int
}

/// Represents a service declaration.
public struct ServiceDeclaration: ASTNode {
	public let name: String
	public let body: [ServiceElement]
	public let startLine: Int
	public let startColumn: Int
}

/// Represents elements within a service.
public enum ServiceElement {
	case rpc(RPCMethod)
	case option(ASTOption)
}

/// Represents an RPC method.
public struct RPCMethod: ASTNode {
	public let name: String
	public let inputType: String
	public let outputType: String
	public let isClientStreaming: Bool
	public let isServerStreaming: Bool
	public let options: [ASTOption]
	public let startLine: Int
	public let startColumn: Int
}

/// Represents a oneof declaration.
public struct OneofDeclaration: ASTNode {
	public let name: String
	public let fields: [FieldDeclaration]
	public let startLine: Int
	public let startColumn: Int
}

/// Represents a reserved statement.
public struct ReservedStatement: ASTNode {
	public let numbers: [ReservedRange]
	public let names: [String]
	public let startLine: Int
	public let startColumn: Int
}

/// Represents a reserved range.
public struct ReservedRange {
	public let start: Int
	public let end: Int?
}

