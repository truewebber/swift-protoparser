import XCTest
@testable import SwiftProtoParse

final class LexerTests: XCTestCase {
	func testLexerWithSimpleInput() {
		let input = "syntax = \"proto3\";"
		let lexer = Lexer(input: input)

		var tokens: [Token] = []
		var token = lexer.nextToken()
		while token != .endOfFile {
			tokens.append(token)
			token = lexer.nextToken()
		}

		let expectedTokens: [Token] = [
			.keyword("syntax"),
			.symbol("="),
			.stringLiteral("proto3"),
			.symbol(";")
		]

		XCTAssertEqual(tokens, expectedTokens)
	}

	func testLexerWithComplexInput() {
		let input = """
		// Comment
		message Person {
			string name = 1;
			int32 id = 2;
		}
		"""
		let lexer = Lexer(input: input)

		var tokens: [Token] = []
		var token = lexer.nextToken()
		while token != .endOfFile {
			tokens.append(token)
			token = lexer.nextToken()
		}

		// Build the expected tokens array
		let expectedTokens: [Token] = [
			.keyword("message"),
			.identifier("Person"),
			.symbol("{"),
			.identifier("string"),
			.identifier("name"),
			.symbol("="),
			.numericLiteral("1"),
			.symbol(";"),
			.identifier("int32"),
			.identifier("id"),
			.symbol("="),
			.numericLiteral("2"),
			.symbol(";"),
			.symbol("}")
		]

		XCTAssertEqual(tokens, expectedTokens)
	}
}

