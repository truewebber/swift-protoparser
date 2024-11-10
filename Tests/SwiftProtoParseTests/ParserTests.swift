import XCTest
@testable import SwiftProtoParse

final class ParserTests: XCTestCase {
	func testParserParsesSimpleMessage() {
		let input = """
		syntax = "proto3";
		message Person {
			string name = 1;
			int32 id = 2;
		}
		"""
		let lexer = Lexer(input: input)
		let errorCollector = SimpleErrorCollector()
		let parser = Parser(lexer: lexer, errorCollector: errorCollector)

		do {
			let protoFile = try parser.parseProto()
			XCTAssertEqual(protoFile.topLevelDefinitions.count, 1)
			if case let .message(personMessage) = protoFile.topLevelDefinitions.first {
				XCTAssertEqual(personMessage.name, "Person")
				XCTAssertEqual(personMessage.fields.count, 2)
				XCTAssertEqual(personMessage.fields[0].name, "name")
				XCTAssertEqual(personMessage.fields[1].name, "id")
			} else {
				XCTFail("Expected a message definition")
			}
		} catch {
			XCTFail("Parser threw an error: \(error)")
		}

		XCTAssertTrue(errorCollector.errors.isEmpty)
	}
}
