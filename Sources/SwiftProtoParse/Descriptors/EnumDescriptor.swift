import Foundation

public class EnumDescriptor {
	public var name: String
	public var fullName: String
	public var values: [EnumValueDescriptor] = []

	public init(name: String, fullName: String) {
		self.name = name
		self.fullName = fullName
	}
}

public class EnumValueDescriptor {
	public var name: String
	public var number: Int

	public init(name: String, number: Int) {
		self.name = name
		self.number = number
	}
}
