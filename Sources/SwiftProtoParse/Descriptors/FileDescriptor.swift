import Foundation

public class FileDescriptor {
	public var name: String
	public var package: String?
	public var dependencies: [FileDescriptor] = []
	public var messageTypes: [Descriptor] = []
	public var enumTypes: [EnumDescriptor] = []
	public var serviceTypes: [ServiceDescriptor] = []

	public init(name: String) {
		self.name = name
	}
}
