import Foundation

/// Represents a FileDescriptor containing all definitions in a .proto file.
public struct FileDescriptor {
	public let syntax: String
	public let package: String?
	public let dependencies: [String]
	public let messages: [DescriptorProto]
	public let enums: [EnumDescriptorProto]
	public let services: [ServiceDescriptorProto]
	public let options: [Option]
}

/// Represents a message type descriptor.
public struct DescriptorProto {
	public let name: String
	public let fields: [FieldDescriptorProto]
	public let nestedTypes: [DescriptorProto]
	public let enumTypes: [EnumDescriptorProto]
	public let oneofs: [OneofDescriptorProto]
	public let options: [Option]
}

/// Represents a field in a message.
public struct FieldDescriptorProto {
	public enum Label {
		case optional
		case repeated
	}
	public let name: String
	public let number: Int32
	public let label: Label
	public let type: FieldType
	public let typeName: String?
	public let options: [Option]
}

/// Represents field types.
public enum FieldType: Equatable {
	case int32
	case int64
	case uint32
	case uint64
	case sint32
	case sint64
	case fixed32
	case fixed64
	case sfixed32
	case sfixed64
	case float
	case double
	case bool
	case string
	case bytes
	case message(String)
	case enumeration(String)
}

/// Represents an enum type descriptor.
public struct EnumDescriptorProto {
	public let name: String
	public let values: [EnumValueDescriptorProto]
	public let options: [Option]
}

/// Represents a value within an enum.
public struct EnumValueDescriptorProto {
	public let name: String
	public let number: Int32
	public let options: [Option]
}

/// Represents a service descriptor.
public struct ServiceDescriptorProto {
	public let name: String
	public let methods: [MethodDescriptorProto]
	public let options: [Option]
}

/// Represents a method within a service.
public struct MethodDescriptorProto {
	public let name: String
	public let inputType: String
	public let outputType: String
	public let clientStreaming: Bool
	public let serverStreaming: Bool
	public let options: [Option]
}

/// Represents a oneof descriptor.
public struct OneofDescriptorProto {
	public let name: String
	public let fields: [FieldDescriptorProto]
	public let options: [Option]
}

/// Represents an option used in descriptors.
public struct Option {
	public let name: String
	public let value: OptionValue
}

/// Represents the value of an option in descriptors.
public enum OptionValue {
	case string(String)
	case number(String)
	case boolean(Bool)
	case aggregate([Option]) // Uses [Option]
}
