import Foundation

public class Reflection {
	private let descriptorPool: DescriptorPool

	public init(descriptorPool: DescriptorPool) {
		self.descriptorPool = descriptorPool
	}

	public func getMessageDescriptor(named name: String) -> Descriptor? {
		return descriptorPool.getDescriptor(named: name)
	}

	// Methods for dynamic message creation and manipulation
	public func createMessageInstance(descriptor: Descriptor) -> DynamicMessage {
		return DynamicMessage(descriptor: descriptor)
	}
}

public class DescriptorPool {
	private var descriptorsByName: [String: Descriptor] = [:]

	public func addDescriptor(_ descriptor: Descriptor) {
		descriptorsByName[descriptor.fullName] = descriptor
	}

	public func getDescriptor(named name: String) -> Descriptor? {
		return descriptorsByName[name]
	}
}

public class DynamicMessage {
	private let descriptor: Descriptor
	private var fieldValues: [Int: Any] = [:]

	public init(descriptor: Descriptor) {
		self.descriptor = descriptor
	}
	
	public func setField(number: Int, value: Any) throws {
		if descriptor.fields.contains(where: { $0.number == number }) {
			fieldValues[number] = value
		} else {
			throw DynamicMessageError.fieldNotFound
		}
	}


	public func getField(number: Int) -> Any? {
		return fieldValues[number]
	}

	public enum DynamicMessageError: Error {
		case fieldNotFound
	}
}

