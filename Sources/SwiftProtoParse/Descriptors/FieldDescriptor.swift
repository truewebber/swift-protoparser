import Foundation

public class FieldDescriptor {
	public enum Label {
		case optional
		case repeated
	}

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
		case bool
		case string
		case bytes
		case float
		case double
		case message(String)
		case enumeration(String)
	}

	public var name: String
	public var number: Int
	public var label: Label?
	public var type: FieldType

	public init(name: String, number: Int, type: FieldType, label: Label? = nil) {
		self.name = name
		self.number = number
		self.type = type
		self.label = label
	}
}

public class MapFieldDescriptor {
	public var keyType: FieldDescriptor.FieldType
	public var valueType: FieldDescriptor.FieldType

	public init(keyType: FieldDescriptor.FieldType, valueType: FieldDescriptor.FieldType) {
		self.keyType = keyType
		self.valueType = valueType
	}
}

