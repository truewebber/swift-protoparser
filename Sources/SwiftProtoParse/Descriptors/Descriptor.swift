import Foundation

public class Descriptor {
	public var name: String
	public var fullName: String
	public var fields: [FieldDescriptor] = []
	public var nestedTypes: [Descriptor] = []
	public var enumTypes: [EnumDescriptor] = []

	public init(name: String, fullName: String) {
		self.name = name
		self.fullName = fullName
	}
}
