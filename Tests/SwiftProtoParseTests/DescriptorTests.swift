import XCTest
@testable import SwiftProtoParse

final class DescriptorTests: XCTestCase {
	func testDescriptorInitialization() {
		let descriptor = Descriptor(name: "TestMessage", fullName: "package.TestMessage")
		XCTAssertEqual(descriptor.name, "TestMessage")
		XCTAssertEqual(descriptor.fullName, "package.TestMessage")
		XCTAssertTrue(descriptor.fields.isEmpty)
	}

	func testFieldDescriptorInitialization() {
		let fieldDescriptor = FieldDescriptor(
			name: "id",
			number: 1,
			type: .int32,
			label: .optional
		)
		XCTAssertEqual(fieldDescriptor.name, "id")
		XCTAssertEqual(fieldDescriptor.number, 1)
		XCTAssertEqual(fieldDescriptor.type, .int32)
		XCTAssertEqual(fieldDescriptor.label, .optional)
	}
}
