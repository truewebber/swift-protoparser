import Foundation

public class ProtoFile {
	public var syntax: String?
	public var package: String?
	public var imports: [ImportStatement] = []
	public var topLevelDefinitions: [TopLevelDefinition] = []

	public init() {}
}

public class ImportStatement {
	public enum Modifier {
		case weak
		case publicImport
		case none
	}

	public var modifier: Modifier
	public var path: String

	public init(modifier: Modifier, path: String) {
		self.modifier = modifier
		self.path = path
	}
}

public enum TopLevelDefinition {
	case message(Message)
	case enumType(EnumType)
	case service(Service)
	case option(Option)
}

public class Message {
	public var name: String
	public var fields: [Field] = []
	public var nestedTypes: [Message] = []
	public var enums: [EnumType] = []
	public var oneofs: [Oneof] = []
	public var options: [Option] = []

	public init(name: String) {
		self.name = name
	}
}

public class Field {
	public enum Label {
		case optional
		case repeated
	}

	public var label: Label?
	public var type: FieldType
	public var name: String
	public var number: Int
	public var options: [Option] = []

	public init(label: Label?, type: FieldType, name: String, number: Int) {
		self.label = label
		self.type = type
		self.name = name
		self.number = number
	}
}

public enum FieldType {
	case basicType(String)
	case messageType(String)
	case enumType(String)
	case mapType(MapField)
}

public class MapField {
	public var keyType: String
	public var valueType: FieldType

	public init(keyType: String, valueType: FieldType) {
		self.keyType = keyType
		self.valueType = valueType
	}
}

public class EnumType {
	public var name: String
	public var values: [EnumValue] = []
	public var options: [Option] = []

	public init(name: String) {
		self.name = name
	}
}

public class EnumValue {
	public var name: String
	public var number: Int
	public var options: [Option] = []

	public init(name: String, number: Int) {
		self.name = name
		self.number = number
	}
}

public class Service {
	public var name: String
	public var methods: [Method] = []
	public var options: [Option] = []

	public init(name: String) {
		self.name = name
	}
}

public class Method {
	public var name: String
	public var inputType: String
	public var outputType: String
	public var options: [Option] = []

	public init(name: String, inputType: String, outputType: String) {
		self.name = name
		self.inputType = inputType
		self.outputType = outputType
	}
}

public class Option {
	public var name: String
	public var value: Any

	public init(name: String, value: Any) {
		self.name = name
		self.value = value
	}
}

public class Oneof {
	public var name: String
	public var fields: [Field] = []
	public var options: [Option] = []

	public init(name: String) {
		self.name = name
	}
}

