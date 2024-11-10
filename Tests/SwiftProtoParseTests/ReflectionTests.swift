import XCTest
@testable import SwiftProtoParse

final class ReflectionTests: XCTestCase {
	func testReflectionRetrievesDescriptor() {
		let descriptorPool = DescriptorPool()
		let messageDescriptor = Descriptor(name: "TestMessage", fullName: "TestMessage")
		descriptorPool.addDescriptor(messageDescriptor)

		let reflection = Reflection(descriptorPool: descriptorPool)
		let retrievedDescriptor = reflection.getMessageDescriptor(named: "TestMessage")

		XCTAssertNotNil(retrievedDescriptor)
		XCTAssertEqual(retrievedDescriptor?.name, "TestMessage")
	}

	func testDynamicMessageSetAndGetField() throws {
		let fieldDescriptor = FieldDescriptor(
			name: "id",
			number: 1,
			type: .int32,
			label: .optional
		)
		let messageDescriptor = Descriptor(name: "TestMessage", fullName: "TestMessage")
		messageDescriptor.fields.append(fieldDescriptor)

		let dynamicMessage = DynamicMessage(descriptor: messageDescriptor)
		try dynamicMessage.setField(number: 1, value: 123)

		if let value = dynamicMessage.getField(number: 1) as? Int {
			XCTAssertEqual(value, 123)
		} else {
			XCTFail("Expected to retrieve Int value")
		}
	}
}
