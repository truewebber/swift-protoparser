import XCTest
@testable import SwiftProtoParse

final class UtilitiesTests: XCTestCase {
	func testErrorCollectorAddsError() {
		let errorCollector = SimpleErrorCollector()
		errorCollector.addError(line: 1, column: 5, message: "Unexpected token")
		XCTAssertEqual(errorCollector.errors.count, 1)
		XCTAssertEqual(errorCollector.errors.first, "Error at 1:5: Unexpected token")
	}
}
