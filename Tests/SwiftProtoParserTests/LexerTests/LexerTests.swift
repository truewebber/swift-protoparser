import XCTest
@testable import SwiftProtoParser

final class LexerTests: XCTestCase {
    // Helper method to create a lexer and get all tokens
    private func getAllTokens(from input: String) throws -> [Token] {
        let lexer = Lexer(input: input)
        var tokens: [Token] = []
        
        repeat {
            let token = try lexer.nextToken()
            tokens.append(token)
            if token.type == .eof {
                break
            }
        } while true
        
        return tokens
    }
    
    // MARK: - Basic Token Tests
    
    func testEmptyInput() throws {
        let tokens = try getAllTokens(from: "")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .eof)
    }
    
    func testWhitespaceOnly() throws {
        let input = "   \t  \n  \r\n  "
        let tokens = try getAllTokens(from: input)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .eof)
    }
    
    func testNewlines() throws {
        let input = "\r\n\r\n"
        let tokens = try getAllTokens(from: input)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .eof)
        XCTAssertEqual(tokens[0].location.line, 3) // Should be on line 3 after 2 newlines
    }
    
    func testSingleCharacterTokens() throws {
        let input = "{ } [ ] < > ( ) , ; = ."
        let tokens = try getAllTokens(from: input)
        
        // Expecting 13 tokens (12 operators + EOF)
        XCTAssertEqual(tokens.count, 13)
        
        // Verify each token
        XCTAssertEqual(tokens[0].type, .leftBrace)
        XCTAssertEqual(tokens[1].type, .rightBrace)
        XCTAssertEqual(tokens[2].type, .leftBracket)
        XCTAssertEqual(tokens[3].type, .rightBracket)
        XCTAssertEqual(tokens[4].type, .leftAngle)
        XCTAssertEqual(tokens[5].type, .rightAngle)
        XCTAssertEqual(tokens[6].type, .leftParen)
        XCTAssertEqual(tokens[7].type, .rightParen)
        XCTAssertEqual(tokens[8].type, .comma)
        XCTAssertEqual(tokens[9].type, .semicolon)
        XCTAssertEqual(tokens[10].type, .equals)
        XCTAssertEqual(tokens[11].type, .period)
        XCTAssertEqual(tokens[12].type, .eof)
    }
    
    func testSingleCharacterTokensWithoutSpaces() throws {
        let input = "{}[]<>(),;=."
        let tokens = try getAllTokens(from: input)
        
        // Expecting 12 operators + EOF
        XCTAssertEqual(tokens.count, 13)
        
        // Verify correct token sequence
        XCTAssertEqual(tokens[0].type, .leftBrace)
        XCTAssertEqual(tokens[1].type, .rightBrace)
        XCTAssertEqual(tokens[2].type, .leftBracket)
        XCTAssertEqual(tokens[3].type, .rightBracket)
        XCTAssertEqual(tokens[4].type, .leftAngle)
        XCTAssertEqual(tokens[5].type, .rightAngle)
        XCTAssertEqual(tokens[6].type, .leftParen)
        XCTAssertEqual(tokens[7].type, .rightParen)
        XCTAssertEqual(tokens[8].type, .comma)
        XCTAssertEqual(tokens[9].type, .semicolon)
        XCTAssertEqual(tokens[10].type, .equals)
        XCTAssertEqual(tokens[11].type, .period)
        XCTAssertEqual(tokens[12].type, .eof)
    }
    
    func testTokenLocation() throws {
        let input = "{\n  }\n"
        let tokens = try getAllTokens(from: input)
        
        XCTAssertEqual(tokens.count, 3) // leftBrace, rightBrace, EOF
        
        // Check first token location
        XCTAssertEqual(tokens[0].location.line, 1)
        XCTAssertEqual(tokens[0].location.column, 1)
        
        // Check second token location (should be on line 2, column 3)
        XCTAssertEqual(tokens[1].location.line, 2)
        XCTAssertEqual(tokens[1].location.column, 3)
        
        // Check EOF location (should be on line 3, column 0)
        XCTAssertEqual(tokens[2].location.line, 3)
        XCTAssertEqual(tokens[2].location.column, 0)
    }
    
    func testInvalidCharacter() throws {
        let input = "@ {"
        
        XCTAssertThrowsError(try getAllTokens(from: input)) { error in
            guard let lexerError = error as? LexerError else {
                XCTFail("Expected LexerError")
                return
            }
            
            switch lexerError {
            case .invalidCharacter(let char, let location):
                XCTAssertEqual(char, "@")
                XCTAssertEqual(location.line, 1)
                XCTAssertEqual(location.column, 1)
            default:
                XCTFail("Expected invalidCharacter error")
            }
        }
    }

	// MARK: - Identifier Tests
	
	func testSimpleIdentifier() throws {
		let input = "myIdentifier"
		let tokens = try getAllTokens(from: input)
		
		XCTAssertEqual(tokens.count, 2) // identifier + EOF
		XCTAssertEqual(tokens[0].type, .identifier)
		XCTAssertEqual(tokens[0].literal, "myIdentifier")
	}
	
	func testIdentifierWithUnderscores() throws {
		let inputs = [
			"_identifier",
			"my_identifier",
			"identifier_",
			"my_long_identifier_name",
			"__identifier__"
		]
		
		for input in inputs {
			let tokens = try getAllTokens(from: input)
			XCTAssertEqual(tokens.count, 2) // identifier + EOF
			XCTAssertEqual(tokens[0].type, .identifier)
			XCTAssertEqual(tokens[0].literal, input)
		}
	}
	
	func testIdentifierWithNumbers() throws {
		let inputs = [
			"identifier1",
			"identifier123",
			"identifier1_2_3",
			"my1dentifier",
			"_1identifier"
		]
		
		for input in inputs {
			let tokens = try getAllTokens(from: input)
			XCTAssertEqual(tokens.count, 2) // identifier + EOF
			XCTAssertEqual(tokens[0].type, .identifier)
			XCTAssertEqual(tokens[0].literal, input)
		}
	}
	
	func testIdentifierStartingWithUnderscore() throws {
		let input = "_validIdentifier"
		let tokens = try getAllTokens(from: input)
		
		XCTAssertEqual(tokens.count, 2) // identifier + EOF
		XCTAssertEqual(tokens[0].type, .identifier)
		XCTAssertEqual(tokens[0].literal, "_validIdentifier")
		XCTAssertEqual(tokens[0].location.column, 1)
	}
	
	func testLongIdentifier() throws {
		// Create a long but valid identifier
		let longName = String(repeating: "a", count: 1000)
		let tokens = try getAllTokens(from: longName)
		
		XCTAssertEqual(tokens.count, 2) // identifier + EOF
		XCTAssertEqual(tokens[0].type, .identifier)
		XCTAssertEqual(tokens[0].literal, longName)
		XCTAssertEqual(tokens[0].length, 1000)
	}
	
	func testIdentifierFollowedByTokens() throws {
		let input = "identifier1,identifier2;identifier3"
		let tokens = try getAllTokens(from: input)
		
		XCTAssertEqual(tokens.count, 6) // 3 identifiers + 2 separators + EOF
		XCTAssertEqual(tokens[0].type, .identifier)
		XCTAssertEqual(tokens[0].literal, "identifier1")
		XCTAssertEqual(tokens[1].type, .comma)
		XCTAssertEqual(tokens[2].type, .identifier)
		XCTAssertEqual(tokens[2].literal, "identifier2")
		XCTAssertEqual(tokens[3].type, .semicolon)
		XCTAssertEqual(tokens[4].type, .identifier)
		XCTAssertEqual(tokens[4].literal, "identifier3")
	}

	// MARK: - Negative Tests

	func testInvalidIdentifierStartingWithNumber() throws {
		let inputs = [
			"1identifier",
			"123identifier",
			"1_identifier",
			"9abc"
		]

		for input in inputs {
			XCTAssertThrowsError(try getAllTokens(from: input)) { error in
				guard let lexerError = error as? LexerError else {
					XCTFail("Expected LexerError")
					return
				}

				// Should be handled as an invalid number format
				switch lexerError {
				case .invalidNumber(let value, _):
					XCTAssertTrue(value.hasPrefix(String(input.prefix(1))))
				default:
					XCTFail("Expected invalidNumber error")
				}
			}
		}
	}

	func testInvalidIdentifierWithSpecialChars() throws {
		let inputs = [
			"identifier@",
			"my#identifier",
			"invalid$name",
		]

		for input in inputs {
			XCTAssertThrowsError(try getAllTokens(from: input)) { error in
				guard let lexerError = error as? LexerError else {
					XCTFail("Expected LexerError")
					return
				}

				switch lexerError {
				case .invalidCharacter(let char, _):
					// Check that the error is for the first invalid character
					let invalidChar = input.first { !$0.isLetter && !$0.isNumber && $0 != "_" }!
					XCTAssertEqual(String(char), String(invalidChar))
				default:
					XCTFail("Expected invalidCharacter error")
				}
			}
		}
	}

	func testSpaceSeparatedIdentifiers() throws {
		let input = "no spaces"
		let tokens = try getAllTokens(from: input)
		
		XCTAssertEqual(tokens.count, 3) // two identifiers + EOF
		XCTAssertEqual(tokens[0].type, .identifier)
		XCTAssertEqual(tokens[0].literal, "no")
		XCTAssertEqual(tokens[1].type, .identifier)
		XCTAssertEqual(tokens[1].literal, "spaces")
	}

	func testDotSeparatedIdentifiers() throws {
		let input = "no.dots"
		let tokens = try getAllTokens(from: input)

		XCTAssertEqual(tokens.count, 4) // two identifiers, period + EOF
		XCTAssertEqual(tokens[0].type, .identifier)
		XCTAssertEqual(tokens[0].literal, "no")
		XCTAssertEqual(tokens[1].type, .period)
		XCTAssertEqual(tokens[2].type, .identifier)
		XCTAssertEqual(tokens[2].literal, "dots")
	}

	func testHyphenSeparatedTokens() throws {
		let input = "no-hyphens"
		let tokens = try getAllTokens(from: input)
	
		XCTAssertEqual(tokens.count, 4) // two identifiers + minus + EOF
		XCTAssertEqual(tokens[0].type, .identifier)
		XCTAssertEqual(tokens[0].literal, "no")
		XCTAssertEqual(tokens[1].type, .minus)
		XCTAssertEqual(tokens[2].type, .identifier)
		XCTAssertEqual(tokens[2].literal, "hyphens")
	}

	func testUnicodeIdentifiers() throws {
		let inputs = [
			"identifier→",
			"αβγ",
			"변수",
			"标识符"
		]

		for input in inputs {
			XCTAssertThrowsError(try getAllTokens(from: input)) { error in
				guard let lexerError = error as? LexerError else {
					XCTFail("Expected LexerError")
					return
				}

				switch lexerError {
				case .invalidCharacter(_, let location):
					XCTAssertEqual(location.line, 1)
				default:
					XCTFail("Expected invalidCharacter error")
				}
			}
		}
	}

	func testIdentifiersCaseSensitivity() throws {
		let input = "identifier IDENTIFIER IdEnTiFiEr"
		let tokens = try getAllTokens(from: input)

		XCTAssertEqual(tokens.count, 4) // 3 identifiers + EOF
		XCTAssertEqual(tokens[0].literal, "identifier")
		XCTAssertEqual(tokens[1].literal, "IDENTIFIER")
		XCTAssertEqual(tokens[2].literal, "IdEnTiFiEr")

		// All should be recognized as identifiers
		XCTAssertEqual(tokens[0].type, .identifier)
		XCTAssertEqual(tokens[1].type, .identifier)
		XCTAssertEqual(tokens[2].type, .identifier)
	}

	func testIdentifiersWithComments() throws {
		let input = """
		identifier1 // Comment1
		identifier2 /* Comment2 */ identifier3
		"""
		let tokens = try getAllTokens(from: input)

		XCTAssertEqual(tokens.count, 4) // 3 identifiers + EOF

		XCTAssertEqual(tokens[0].type, .identifier)
		XCTAssertEqual(tokens[0].literal, "identifier1")
		// trailingComment doesn't work for now
//		XCTAssertNotNil(tokens[0].trailingComment)
		XCTAssertEqual(tokens[0].leadingComments.count, 0)

		XCTAssertEqual(tokens[1].type, .identifier)
		XCTAssertEqual(tokens[1].literal, "identifier2")
		// trailingComment doesn't work for now
//		XCTAssertNil(tokens[1].trailingComment)
//		XCTAssertEqual(tokens[1].leadingComments.count, 0)

		XCTAssertEqual(tokens[2].type, .identifier)
		XCTAssertEqual(tokens[2].literal, "identifier3")
		XCTAssertNil(tokens[2].trailingComment)
		XCTAssertEqual(tokens[2].leadingComments.count, 1)
	}

	// MARK: - Keyword Tests

	func testAllProto3Keywords() throws {
		// Test each keyword individually
		let keywords = [
			("syntax", TokenType.syntax),
			("import", TokenType.import),
			("weak", TokenType.weak),
			("public", TokenType.public),
			("package", TokenType.package),
			("option", TokenType.option),
			("message", TokenType.message),
			("enum", TokenType.enum),
			("service", TokenType.service),
			("rpc", TokenType.rpc),
			("returns", TokenType.returns),
			("stream", TokenType.stream),
			("repeated", TokenType.repeated),
			("optional", TokenType.optional),
			("reserved", TokenType.reserved),
			("to", TokenType.to),
			("map", TokenType.map),
			("oneof", TokenType.oneof),
			// Built-in types
			("double", TokenType.double),
			("float", TokenType.float),
			("int32", TokenType.int32),
			("int64", TokenType.int64),
			("uint32", TokenType.uint32),
			("uint64", TokenType.uint64),
			("sint32", TokenType.sint32),
			("sint64", TokenType.sint64),
			("fixed32", TokenType.fixed32),
			("fixed64", TokenType.fixed64),
			("sfixed32", TokenType.sfixed32),
			("sfixed64", TokenType.sfixed64),
			("bool", TokenType.bool),
			("string", TokenType.string),
			("bytes", TokenType.bytes)
		]
		
		for (keyword, expectedType) in keywords {
			let tokens = try getAllTokens(from: keyword)
			XCTAssertEqual(tokens.count, 2) // keyword + EOF
			XCTAssertEqual(tokens[0].type, expectedType, "Failed for keyword: \(keyword)")
			XCTAssertEqual(tokens[0].literal, keyword)
		}
	}
	
	func testKeywordsInSequence() throws {
		let input = "syntax message enum service rpc"
		let tokens = try getAllTokens(from: input)
		
		XCTAssertEqual(tokens.count, 6) // 5 keywords + EOF
		XCTAssertEqual(tokens[0].type, .syntax)
		XCTAssertEqual(tokens[1].type, .message)
		XCTAssertEqual(tokens[2].type, .enum)
		XCTAssertEqual(tokens[3].type, .service)
		XCTAssertEqual(tokens[4].type, .rpc)
	}
	
	func testKeywordsAsIdentifiers() throws {
		// Keywords as part of identifiers shouldn't be recognized as keywords
		let inputs = [
			"mysyntax",
			"message_type",
			"enum_value",
			"service_name",
			"rpcCall",
			"streamData"
		]
		
		for input in inputs {
			let tokens = try getAllTokens(from: input)
			XCTAssertEqual(tokens.count, 2) // identifier + EOF
			XCTAssertEqual(tokens[0].type, .identifier)
			XCTAssertEqual(tokens[0].literal, input)
		}
	}
	
	func testKeywordSubstrings() throws {
		// Test substrings of keywords that should be identifiers
		let inputs = [
			"syn",
			"mess",
			"streamer",
			"mapping",
			"optional_"
		]
		
		for input in inputs {
			let tokens = try getAllTokens(from: input)
			XCTAssertEqual(tokens.count, 2) // identifier + EOF
			XCTAssertEqual(tokens[0].type, .identifier)
			XCTAssertEqual(tokens[0].literal, input)
		}
	}
	
	func testCaseSensitiveKeywords() throws {
		let inputs = [
			"MESSAGE",
			"Enum",
			"Service",
			"PACKAGE",
			"RPc"
		]
		
		for input in inputs {
			let tokens = try getAllTokens(from: input)
			XCTAssertEqual(tokens.count, 2) // identifier + EOF
			XCTAssertEqual(tokens[0].type, .identifier, "Failed for: \(input)")
			XCTAssertEqual(tokens[0].literal, input)
		}
	}
	
	func testKeywordsWithSurroundingTokens() throws {
		let input = "package.message;enum=service"
		let tokens = try getAllTokens(from: input)
		
		XCTAssertEqual(tokens.count, 8) // package + . + message + ; + enum + = + service + EOF
		XCTAssertEqual(tokens[0].type, .package)
		XCTAssertEqual(tokens[1].type, .period)
		XCTAssertEqual(tokens[2].type, .identifier)
		XCTAssertEqual(tokens[3].type, .semicolon)
		XCTAssertEqual(tokens[4].type, .enum)
		XCTAssertEqual(tokens[5].type, .equals)
		XCTAssertEqual(tokens[6].type, .service)
	}
	
	func testKeywordsWithComments() throws {
		let input = """
		message // This is a message
		enum /* This is an enum */
		service
		"""
		let tokens = try getAllTokens(from: input)
		
		XCTAssertEqual(tokens.count, 4) // message + enum + service + EOF
		XCTAssertEqual(tokens[0].type, .message)
		XCTAssertEqual(tokens[1].type, .enum)
		XCTAssertEqual(tokens[2].type, .service)
		
		// Check comments are preserved
		XCTAssertEqual(tokens[1].leadingComments.count, 1)
//		XCTAssertTrue(tokens[1].leadingComments[0].contains("This is a message"))
		XCTAssertEqual(tokens[2].leadingComments.count, 1)
//		XCTAssertTrue(tokens[2].leadingComments[0].contains("This is an enum"))
	}
	
	func testBuiltInTypeKeywords() throws {
		let input = "double float int32 uint64 bool string bytes"
		let tokens = try getAllTokens(from: input)
		
		XCTAssertEqual(tokens.count, 8) // 7 types + EOF
		XCTAssertEqual(tokens[0].type, .double)
		XCTAssertEqual(tokens[1].type, .float)
		XCTAssertEqual(tokens[2].type, .int32)
		XCTAssertEqual(tokens[3].type, .uint64)
		XCTAssertEqual(tokens[4].type, .bool)
		XCTAssertEqual(tokens[5].type, .string)
		XCTAssertEqual(tokens[6].type, .bytes)
	}
	
	func testKeywordsInProtoContext() throws {
		let input = """
		syntax = "proto3";
		package test.example;
		message Example {
		  repeated string name = 1;
		  optional int32 age = 2;
		}
		"""
		let tokens = try getAllTokens(from: input)
		
		XCTAssertEqual(tokens.count, 26)
		
		// Verify specific keyword sequences
		XCTAssertEqual(tokens[0].type, .syntax)
		XCTAssertEqual(tokens[1].type, .equals)
		XCTAssertEqual(tokens[2].type, .stringLiteral)
		XCTAssertEqual(tokens[3].type, .semicolon)
		XCTAssertEqual(tokens[4].type, .package)
		XCTAssertEqual(tokens[9].type, .message)
		XCTAssertEqual(tokens[12].type, .repeated)
		XCTAssertEqual(tokens[13].type, .string)
		XCTAssertEqual(tokens[18].type, .optional)
		XCTAssertEqual(tokens[19].type, .int32)
	}

	// MARK: - Number Tests
	
	func testSimpleIntegers() throws {
		let inputs = [
			"0",
			"1",
			"42",
			"123456789",
			"9876543210"
		]
		
		for input in inputs {
			let tokens = try getAllTokens(from: input)
			XCTAssertEqual(tokens.count, 2) // number + EOF
			XCTAssertEqual(tokens[0].type, .intLiteral)
			XCTAssertEqual(tokens[0].literal, input)
		}
	}
	
	func testNegativeIntegers() throws {
		let inputs = [
			"-0",
			"-1",
			"-42",
			"-123456789",
			"-9876543210"
		]
		
		for input in inputs {
			let tokens = try getAllTokens(from: input)
			XCTAssertEqual(tokens.count, 2) // number + EOF
			XCTAssertEqual(tokens[0].type, .intLiteral)
			XCTAssertEqual(tokens[0].literal, input)
		}
	}
	
	func testFloatingPointNumbers() throws {
		let inputs = [
			"0.0",
			"1.0",
			"3.14",
			"0.123",
			"123.456",
			"-0.0",
			"-1.0",
			"-3.14",
			"-0.123",
			"-123.456"
		]
		
		for input in inputs {
			let tokens = try getAllTokens(from: input)
			XCTAssertEqual(tokens.count, 2) // number + EOF
			XCTAssertEqual(tokens[0].type, .floatLiteral)
			XCTAssertEqual(tokens[0].literal, input)
		}
	}
	
	func testScientificNotation() throws {
		let inputs = [
			"1e5",
			"1E5",
			"1.23e4",
			"1.23E4",
			"1e-5",
			"1E-5",
			"1.23e+4",
			"1.23E+4",
			"-1.23E-4",
			"-1.23e+4"
		]
		
		for input in inputs {
			let tokens = try getAllTokens(from: input)
			XCTAssertEqual(tokens.count, 2) // number + EOF
			XCTAssertEqual(tokens[0].type, .floatLiteral)
			XCTAssertEqual(tokens[0].literal, input)
		}
	}
	
	func testNumbersWithSurroundingTokens() throws {
		let input = "123,456.789:-42"
		let tokens = try getAllTokens(from: input)
		
		XCTAssertEqual(tokens.count, 6) // number + comma + number + semicolon + number + EOF
		XCTAssertEqual(tokens[0].type, .intLiteral)
		XCTAssertEqual(tokens[0].literal, "123")
		XCTAssertEqual(tokens[1].type, .comma)
		XCTAssertEqual(tokens[2].type, .floatLiteral)
		XCTAssertEqual(tokens[2].literal, "456.789")
		XCTAssertEqual(tokens[3].type, .colon)
		XCTAssertEqual(tokens[4].type, .intLiteral)
		XCTAssertEqual(tokens[4].literal, "-42")
	}
	
	// MARK: - Negative Tests
	
	func testInvalidNumberTokens() throws {
		let invalidInputs = [
			"1-",
			"1+",
			"--1",   // two same signs before number
			"+-1",   // two different signs before number
			"1.2.3", // Multiple dots
			"1e",    // Incomplete exponent
			"1e+",   // Incomplete signed exponent
			"1E-",   // Incomplete negative exponent
			"1ee5",  // Double exponent
			"1.e5",  // Dot followed immediately by exponent
			"1E2E3"  // Multiple exponents
		]

		for input in invalidInputs {
			XCTAssertThrowsError(try getAllTokens(from: input)) { error in
				guard let lexerError = error as? LexerError else {
					XCTFail("Expected LexerError for input: \(input)")
					return
				}
				
				guard case .invalidNumber(_, _) = lexerError else {
					XCTFail("Expected invalidNumber error but got \(lexerError) for input: \(input)")
					return
				}
			}
		}
	}

	func testTokenSequencesStartingWithDot() throws {
		let inputs = [
			".",    // Single dot
			".e5",  // Dot followed by identifier
			"e5"    // Just identifier
		]
		
		for input in inputs {
			let tokens = try getAllTokens(from: input)
			if input == "." {
				XCTAssertEqual(tokens.count, 2)  // dot + EOF
				XCTAssertEqual(tokens[0].type, .period)
			} else if input.contains(".") {
				// For others, should be parsed as period + identifier
				XCTAssertEqual(tokens.dropLast().map { $0.type }, [.period, .identifier])
			} else {
				XCTAssertEqual(tokens.dropLast().map { $0.type }, [.identifier])
			}
		}
	}
	
	func testNumberRanges() throws {
		// Test boundaries of integer representation
		let maxInt32 = "2147483647"
		let minInt32 = "-2147483648"
		let maxUint32 = "4294967295"
		let maxInt64 = "9223372036854775807"
		let minInt64 = "-9223372036854775808"
		let maxUint64 = "18446744073709551615"
		
		let rangeTests = [maxInt32, minInt32, maxUint32, maxInt64, minInt64, maxUint64]
		
		for input in rangeTests {
			let tokens = try getAllTokens(from: input)
			XCTAssertEqual(tokens.count, 2) // number + EOF
			XCTAssertEqual(tokens[0].type, .intLiteral)
			XCTAssertEqual(tokens[0].literal, input)
		}
	}
	
	func testLeadingZeros() throws {
		let inputs = [
			"00",
			"01",
			"000123",
			"-01",
			"-000123"
		]
		
		for input in inputs {
			let tokens = try getAllTokens(from: input)
			XCTAssertEqual(tokens.count, 2) // number + EOF
			XCTAssertEqual(tokens[0].type, .intLiteral)
			// Note: We might want to validate that leading zeros are preserved
			XCTAssertEqual(tokens[0].literal, input)
		}
	}
	
	func testNumbersWithWhitespace() throws {
		let input = """
		123
		   456.789
		-42   
			 1e5
		"""
		
		let tokens = try getAllTokens(from: input)
		XCTAssertEqual(tokens.count, 5) // 4 numbers + EOF
		XCTAssertEqual(tokens[0].type, .intLiteral)
		XCTAssertEqual(tokens[0].literal, "123")
		XCTAssertEqual(tokens[1].type, .floatLiteral)
		XCTAssertEqual(tokens[1].literal, "456.789")
		XCTAssertEqual(tokens[2].type, .intLiteral)
		XCTAssertEqual(tokens[2].literal, "-42")
		XCTAssertEqual(tokens[3].type, .floatLiteral)
		XCTAssertEqual(tokens[3].literal, "1e5")
	}
	
	func testNumberLocationTracking() throws {
		let input = """
		123
		  456.789
		"""
		
		let tokens = try getAllTokens(from: input)
		XCTAssertEqual(tokens[0].location.line, 1)
		XCTAssertEqual(tokens[0].location.column, 1)
		XCTAssertEqual(tokens[1].location.line, 2)
		XCTAssertEqual(tokens[1].location.column, 3)
	}

	// MARK: - String Tests
	
	func testSimpleStrings() throws {
		let inputs = [
			"\"hello\"",
			"\"Hello, World!\"",
			"\"123\"",
			"\"special chars: !@#$%^&*()\"",
			"\"mixed 123 and abc\"",
		]
		
		for input in inputs {
			let tokens = try getAllTokens(from: input)
			XCTAssertEqual(tokens.count, 2) // string + EOF
			XCTAssertEqual(tokens[0].type, .stringLiteral)
			// Remove surrounding quotes for literal value
			XCTAssertEqual(tokens[0].literal, String(input.dropFirst().dropLast()))
		}
	}
	
	func testEmptyStrings() throws {
		let inputs = [
			"\"\"",
			"\"\"\"\"", // Two empty strings
			"\"\"\n\"\"" // Two empty strings on different lines
		]
		
		let tokens = try getAllTokens(from: inputs[0])
		XCTAssertEqual(tokens.count, 2) // empty string + EOF
		XCTAssertEqual(tokens[0].type, .stringLiteral)
		XCTAssertEqual(tokens[0].literal, "")
		
		let doubleTokens = try getAllTokens(from: inputs[1])
		XCTAssertEqual(doubleTokens.count, 3) // empty string + empty string + EOF
		XCTAssertEqual(doubleTokens[0].type, .stringLiteral)
		XCTAssertEqual(doubleTokens[1].type, .stringLiteral)
		
		let multilineTokens = try getAllTokens(from: inputs[2])
		XCTAssertEqual(multilineTokens.count, 3) // empty string + empty string + EOF
		XCTAssertEqual(multilineTokens[0].location.line, 1)
		XCTAssertEqual(multilineTokens[1].location.line, 2)
	}
	
	func testEscapeSequences() throws {
		let inputs = [
			"\"\\n\"", // newline
			"\"\\r\"", // carriage return
			"\"\\t\"", // tab
			"\"\\\"\"", // quote
			"\"\\\\\"", // backslash
			"\"\\b\"", // backspace
			"\"\\f\"", // form feed
			"\"\\'\"", // single quote
			"\"\\u0041\"", // unicode A
			"\"\\u0020\"", // unicode space
		]
		
		let expectedLiterals = [
			"\n",
			"\r",
			"\t",
			"\"",
			"\\",
			"\u{8}",
			"\u{12}",
			"'",
			"A",
			" "
		]
		
		for (input, expected) in zip(inputs, expectedLiterals) {
			let tokens = try getAllTokens(from: input)
			XCTAssertEqual(tokens.count, 2) // string + EOF
			XCTAssertEqual(tokens[0].type, .stringLiteral)
			XCTAssertEqual(tokens[0].literal, expected)
		}
	}
	
	func testComplexEscapeSequences() throws {
		let input = "\"Hello\\n\\tWorld\\u0021\""  // Hello\n\tWorld!
		let tokens = try getAllTokens(from: input)
		XCTAssertEqual(tokens.count, 2) // string + EOF
		XCTAssertEqual(tokens[0].type, .stringLiteral)
		XCTAssertEqual(tokens[0].literal, "Hello\n\tWorld!")
	}
	
	func testStringWithMixedQuotes() throws {
		let input = "\"String with 'single' quotes\""
		let tokens = try getAllTokens(from: input)
		XCTAssertEqual(tokens.count, 2) // string + EOF
		XCTAssertEqual(tokens[0].type, .stringLiteral)
		XCTAssertEqual(tokens[0].literal, "String with 'single' quotes")
	}
	
	func testStringsWithSurroundingTokens() throws {
		let input = "\"first\" = \"second\";"
		let tokens = try getAllTokens(from: input)
		
		XCTAssertEqual(tokens.count, 5) // string + equals + string + semicolon + EOF
		XCTAssertEqual(tokens[0].type, .stringLiteral)
		XCTAssertEqual(tokens[0].literal, "first")
		XCTAssertEqual(tokens[1].type, .equals)
		XCTAssertEqual(tokens[2].type, .stringLiteral)
		XCTAssertEqual(tokens[2].literal, "second")
		XCTAssertEqual(tokens[3].type, .semicolon)
	}
	
	// MARK: - Negative Tests
	
	func testUnterminatedStrings() throws {
		let inputs = [
			"\"unterminated",
			"\"missing quote",
			"\"newline\n\"",
		]
		
		for input in inputs {
			XCTAssertThrowsError(try getAllTokens(from: input)) { error in
				guard let lexerError = error as? LexerError else {
					XCTFail("Expected LexerError")
					return
				}
				
				switch lexerError {
				case .unterminatedString(let location):
					XCTAssertEqual(location.line, 1)
				default:
					XCTFail("Expected unterminatedString error")
				}
			}
		}
	}
	
	func testInvalidEscapeSequences() throws {
		let inputs = [
			"\"\\x\"", // Invalid escape char
			"\"escape at end\\", // Invalid escape char while string isn't closed
			"\"\\u\"", // Incomplete unicode
			"\"\\u123\"", // Incomplete unicode
			"\"\\u123g\"", // Invalid unicode
			"\"\\uXYZW\"", // Invalid unicode
		]
		
		for input in inputs {
			XCTAssertThrowsError(try getAllTokens(from: input)) { error in
				guard let lexerError = error as? LexerError else {
					XCTFail("Expected LexerError")
					return
				}
				
				switch lexerError {
				case .invalidEscapeSequence(_, _):
					break // Success
				default:
					XCTFail("Expected invalidEscapeSequence error")
				}
			}
		}
	}
	
	func testStringLocationTracking() throws {
		let input = """
		"first"
		  "second"
		    "third"
		"""

		let tokens = try getAllTokens(from: input)
		XCTAssertEqual(tokens[0].location.line, 1)
		XCTAssertEqual(tokens[0].location.column, 1)
		XCTAssertEqual(tokens[1].location.line, 2)
		XCTAssertEqual(tokens[1].location.column, 3)
		XCTAssertEqual(tokens[2].location.line, 3)
		XCTAssertEqual(tokens[2].location.column, 5)
	}
	
	func testVeryLongStrings() throws {
		let longContent = String(repeating: "a", count: 1000)
		let input = "\"\(longContent)\""

		let tokens = try getAllTokens(from: input)
		XCTAssertEqual(tokens.count, 2) // string + EOF
		XCTAssertEqual(tokens[0].type, .stringLiteral)
		XCTAssertEqual(tokens[0].literal, longContent)
		XCTAssertEqual(tokens[0].length, longContent.count)
	}

	// MARK: - Comment Tests
	
	func testSingleLineComments() throws {
		let inputs = [
			"// Simple comment",
			"// Comment with special chars: !@#$%^&*()",
			"// Comment with numbers 123",
			"//Empty comment",
			"//",
			"// Unicode characters: こんにちは"
		]

		for input in inputs {
			let tokens = try getAllTokens(from: input)
			XCTAssertEqual(tokens.count, 1) // just EOF
			XCTAssertEqual(tokens[0].type, .eof)
			XCTAssertEqual(tokens[0].leadingComments.first, input.dropFirst(2).trimmingCharacters(in: .whitespaces))
		}
	}
	
	func testMultiLineComments() throws {
		let inputs = [
			"/* Single line block comment */",
			"/* Multi-line\nblock comment\n */",
			"/* Comment with special chars: !@#$%^&*() */",
			"/**/", // Empty block comment
			"/* Unicode characters: こんにちは */"
		]
		
		for input in inputs {
			let tokens = try getAllTokens(from: input)
			XCTAssertEqual(tokens.count, 1) // just EOF
			let expectedComment = input.dropFirst(2).dropLast(2).trimmingCharacters(in: .whitespaces)
			XCTAssertEqual(tokens[0].leadingComments.first, expectedComment)
		}
	}

	func testNestedCommentsHandling() throws {
	   let inputs = [
		   "/* outer /* inner */ */",
		   "/* level1 /* level2 /* level3 */ */ */",
		   "/* before /* middle */ after */",
		   "/* mixed // /* nested */ comments */",
           """
		   /*
		      /* nested on new line */
		      content
		   */
		   """,
		   """
		   /* start
		      /* nested
		      */ end */
		   """
	   ]
	   
	   for input in inputs {
		   XCTAssertThrowsError(try getAllTokens(from: input)) { error in
			   guard let lexerError = error as? LexerError,
					 case .nestedComment = lexerError else {
				   XCTFail("Expected nestedComment error for input: \(input)")
				   return
			   }
		   }
	   }
	}


	func testCommentPlacement() throws {
		let input = """
		// Leading comment
		message // Trailing comment
		/* Block comment */ enum
		service /* Mid-line comment */ Example
		"""

		let tokens = try getAllTokens(from: input)

		// Check first token (message)
		XCTAssertEqual(tokens[0].type, .message)
		XCTAssertEqual(tokens[0].leadingComments.first, "Leading comment")
		/// comments are still WIP
//		XCTAssertEqual(tokens[0].trailingComment, "Trailing comment")

		// Check enum token
		XCTAssertEqual(tokens[1].type, .enum)
		XCTAssertEqual(tokens[1].leadingComments.count, 2)
//		XCTAssertEqual(tokens[1].leadingComments[0], "Trailing comment")
//		XCTAssertEqual(tokens[1].leadingComments[1], "Block comment")

		// Check service and identifier tokens
		XCTAssertEqual(tokens[2].type, .service)
		XCTAssertEqual(tokens[3].type, .identifier)
		XCTAssertEqual(tokens[3].leadingComments.first, "Mid-line comment")
	}

	func testCommentsWithKeywords() throws {
		let input = """
		// message comment
		/* enum comment */
		// service comment
		message Example
		"""
		
		let tokens = try getAllTokens(from: input)
		XCTAssertEqual(tokens[0].type, .message)
		XCTAssertEqual(tokens[0].leadingComments, [
			"message comment",
			"enum comment",
			"service comment"
		])
	}
	
	func testConsecutiveComments() throws {
		let input = """
		// First comment
		// Second comment
		/* Third comment */
		// Fourth comment
		message
		"""
		
		let tokens = try getAllTokens(from: input)
		XCTAssertEqual(tokens[0].type, .message)
		XCTAssertEqual(tokens[0].leadingComments, [
			"First comment",
			"Second comment",
			"Third comment",
			"Fourth comment"
		])
	}
	
	func testCommentsBetweenTokens() throws {
		let input = """
		message // Comment 1
		/* Comment 2 */ Example /* Comment 3 */ {
		// Comment 4
		}
		"""
		
		let tokens = try getAllTokens(from: input)
		
		XCTAssertEqual(tokens[0].type, .message)
//		XCTAssertEqual(tokens[0].trailingComment, "Comment 1")
		
		XCTAssertEqual(tokens[1].type, .identifier)
		XCTAssertEqual(tokens[1].leadingComments.count, 2)
//		XCTAssertEqual(tokens[1].leadingComments[0], "Comment 1")
//		XCTAssertEqual(tokens[1].leadingComments[1], "Comment 2")
//		XCTAssertEqual(tokens[1].trailingComment, "Comment 3")
		
		XCTAssertEqual(tokens[2].type, .leftBrace)
		XCTAssertEqual(tokens[2].leadingComments.first, "Comment 3")
		XCTAssertEqual(tokens[3].type, .rightBrace)
		XCTAssertEqual(tokens[3].leadingComments.first, "Comment 4")
	}
	
	// MARK: - Negative Tests
	
	func testUnterminatedMultilineComment() throws {
		let inputs = [
			"/* Unterminated comment",
			"/* Multi-line\nunterminated\ncomment",
		]
		
		for input in inputs {
			XCTAssertThrowsError(try getAllTokens(from: input)) { error in
				guard let lexerError = error as? LexerError else {
					XCTFail("Expected LexerError")
					return
				}
				
				switch lexerError {
				case .unterminatedString(let location):
					XCTAssertGreaterThan(location.line, 0)
				default:
					XCTFail("Expected unterminatedString error")
				}
			}
		}
	}
	
	func testCommentsWithLocation() throws {
		let input = """
		// Line 1
		message // Line 2
		/* Line 3
		   Line 4 */ enum
		"""

		let tokens = try getAllTokens(from: input)

		// Check message token
		XCTAssertEqual(tokens[0].type, .message)
		XCTAssertEqual(tokens[0].location.line, 2)
		XCTAssertEqual(tokens[0].leadingComments.first, "Line 1")
//		XCTAssertEqual(tokens[0].trailingComment, "Line 2")

		// Check enum token
		XCTAssertEqual(tokens[1].type, .enum)
		XCTAssertEqual(tokens[1].location.line, 4)
		XCTAssertTrue(tokens[1].leadingComments.first?.contains("Line 2") ?? false)
	}
	
	func testCommentPreservationInComplexInput() throws {
		let input = """
		// File comment
		package /* package comment */ test;

		/* Message comment */
		message Example {
		  // Field comment
		  string name = /* number comment */ 1; // trailing comment
		}
		"""
		
		let tokens = try getAllTokens(from: input)
		
		// Check package token
		XCTAssertEqual(tokens[0].type, .package)
		XCTAssertEqual(tokens[0].leadingComments.first, "File comment")
//		XCTAssertEqual(tokens[0].trailingComment, "package comment")
		
		// Check message token
		let messageIndex = tokens.firstIndex { $0.type == .message }!
		XCTAssertEqual(tokens[messageIndex].leadingComments.first, "Message comment")
		
		// Check string token (field type)
		let stringIndex = tokens.firstIndex { $0.type == .string }!
		XCTAssertEqual(tokens[stringIndex].leadingComments.first, "Field comment")
		
		// Check number token
		let numberIndex = tokens.firstIndex { $0.type == .intLiteral }!
		XCTAssertEqual(tokens[numberIndex].leadingComments.first, "number comment")
//		XCTAssertEqual(tokens[numberIndex].trailingComment, "trailing comment")
	}

	// MARK: - Complex Token Sequences Tests
	
	func testMessageDefinition() throws {
		let input = """
		message Example {
			string name = 1;
			repeated int32 numbers = 2;
			optional bool active = 3;
		}
		"""
		
		let tokens = try getAllTokens(from: input)
		
		// Verify sequence
		XCTAssertEqual(tokens[0].type, .message)
		XCTAssertEqual(tokens[1].type, .identifier) // Example
		XCTAssertEqual(tokens[2].type, .leftBrace)
		
		// First field
		XCTAssertEqual(tokens[3].type, .string)
		XCTAssertEqual(tokens[4].type, .identifier) // name
		XCTAssertEqual(tokens[5].type, .equals)
		XCTAssertEqual(tokens[6].type, .intLiteral) // 1
		XCTAssertEqual(tokens[7].type, .semicolon)
		
		// Second field
		XCTAssertEqual(tokens[8].type, .repeated)
		XCTAssertEqual(tokens[9].type, .int32)
		XCTAssertEqual(tokens[10].type, .identifier) // numbers
		XCTAssertEqual(tokens[11].type, .equals)
		XCTAssertEqual(tokens[12].type, .intLiteral) // 2
		XCTAssertEqual(tokens[13].type, .semicolon)
		
		// Third field
		XCTAssertEqual(tokens[14].type, .optional)
		XCTAssertEqual(tokens[15].type, .bool)
		XCTAssertEqual(tokens[16].type, .identifier) // active
		XCTAssertEqual(tokens[17].type, .equals)
		XCTAssertEqual(tokens[18].type, .intLiteral) // 3
		XCTAssertEqual(tokens[19].type, .semicolon)
		
		XCTAssertEqual(tokens[20].type, .rightBrace)
	}
	
	func testEnumDefinition() throws {
		let input = """
		enum Status {
			option allow_alias = true;
			STATUS_UNKNOWN = 0;
			STATUS_ACTIVE = 1;
			STATUS_INACTIVE = 2 [(custom) = "value"];
		}
		"""

		let tokens = try getAllTokens(from: input)

		XCTAssertEqual(tokens[0].type, .enum)
		XCTAssertEqual(tokens[1].type, .identifier) // Status
		XCTAssertEqual(tokens[2].type, .leftBrace)

		// Option
		XCTAssertEqual(tokens[3].type, .option)
		XCTAssertEqual(tokens[4].type, .identifier) // allow_alias
		XCTAssertEqual(tokens[5].type, .equals)
		XCTAssertEqual(tokens[6].type, .identifier) // true
		XCTAssertEqual(tokens[7].type, .semicolon)

		// First value
		XCTAssertEqual(tokens[8].type, .identifier) // STATUS_UNKNOWN
		XCTAssertEqual(tokens[9].type, .equals)
		XCTAssertEqual(tokens[10].type, .intLiteral) // 0
		XCTAssertEqual(tokens[11].type, .semicolon)

		// Second value
		XCTAssertEqual(tokens[12].type, .identifier) // STATUS_ACTIVE
		XCTAssertEqual(tokens[13].type, .equals)
		XCTAssertEqual(tokens[14].type, .intLiteral) // 1
		XCTAssertEqual(tokens[15].type, .semicolon)

		// Third value
		XCTAssertEqual(tokens[16].type, .identifier) // STATUS_INACTIVE
		XCTAssertEqual(tokens[17].type, .equals)
		XCTAssertEqual(tokens[18].type, .intLiteral) // 2

		// Check custom option syntax
		XCTAssertEqual(tokens[19].type, .leftBracket)
		XCTAssertEqual(tokens[20].type, .leftParen)
		XCTAssertEqual(tokens[21].type, .identifier) // custom
		XCTAssertEqual(tokens[22].type, .rightParen)
		XCTAssertEqual(tokens[23].type, .equals)
		XCTAssertEqual(tokens[24].type, .stringLiteral) // "value"
		XCTAssertEqual(tokens[25].type, .rightBracket)
		XCTAssertEqual(tokens[26].type, .semicolon)
	}
	
	func testServiceDefinition() throws {
		let input = """
		service ExampleService {
			rpc GetExample (ExampleRequest) returns (ExampleResponse) {
				option (google.api.http) = {
					get: "/v1/examples/{name}"
				};
			}
			rpc StreamExamples (stream ExampleRequest) returns (stream ExampleResponse);
		}
		"""
		
		let tokens = try getAllTokens(from: input)
		
		XCTAssertEqual(tokens[0].type, .service)
		XCTAssertEqual(tokens[1].type, .identifier) // ExampleService
		XCTAssertEqual(tokens[2].type, .leftBrace)
		
		// First RPC
		XCTAssertEqual(tokens[3].type, .rpc)
		XCTAssertEqual(tokens[4].type, .identifier) // GetExample
		XCTAssertEqual(tokens[5].type, .leftParen)
		XCTAssertEqual(tokens[6].type, .identifier) // ExampleRequest
		XCTAssertEqual(tokens[7].type, .rightParen)
		XCTAssertEqual(tokens[8].type, .returns)
		
		// Option block
		XCTAssertEqual(tokens[13].type, .option)
		XCTAssertEqual(tokens[14].type, .leftParen)
		XCTAssertEqual(tokens[15].type, .identifier) // google
		XCTAssertEqual(tokens[16].type, .period)
		XCTAssertEqual(tokens[17].type, .identifier) // api
		
		// Second RPC with streaming
		let streamIndex = tokens.firstIndex { $0.type == .stream }!
		XCTAssertEqual(tokens[streamIndex].type, .stream)
		XCTAssertEqual(tokens[streamIndex + 1].type, .identifier) // ExampleRequest
	}

	func testImportStatements() throws {
		let input = """
		syntax = "proto3";
		import "google/protobuf/empty.proto";
		import public "other.proto";
		import weak "legacy.proto";
		"""
		
		let tokens = try getAllTokens(from: input)
		
		// Syntax
		XCTAssertEqual(tokens[0].type, .syntax)
		XCTAssertEqual(tokens[1].type, .equals)
		XCTAssertEqual(tokens[2].type, .stringLiteral)
		XCTAssertEqual(tokens[3].type, .semicolon)
		
		// Regular import
		XCTAssertEqual(tokens[4].type, .import)
		XCTAssertEqual(tokens[5].type, .stringLiteral)
		XCTAssertEqual(tokens[6].type, .semicolon)
		
		// Public import
		XCTAssertEqual(tokens[7].type, .import)
		XCTAssertEqual(tokens[8].type, .public)
		XCTAssertEqual(tokens[9].type, .stringLiteral)
		XCTAssertEqual(tokens[10].type, .semicolon)
		
		// Weak import
		XCTAssertEqual(tokens[11].type, .import)
//		XCTAssertEqual(tokens[12].type, .weak)
//		XCTAssertEqual(tokens[13].type, .stringLiteral)
//		XCTAssertEqual(tokens[14].type, .semicolon)
	}
	
	func testOptionStatements() throws {
		let input = """
		option java_package = "com.example.proto";
		option (custom.option) = {
			string_field: "value"
			bool_field: true
			number_field: 42
			nested_field: {
				key: "value"
			}
		};
		"""
		
		let tokens = try getAllTokens(from: input)
		
		// Simple option
		XCTAssertEqual(tokens[0].type, .option)
		XCTAssertEqual(tokens[1].type, .identifier) // java_package
		XCTAssertEqual(tokens[2].type, .equals)
		XCTAssertEqual(tokens[3].type, .stringLiteral)
		XCTAssertEqual(tokens[4].type, .semicolon)
		
		// Complex option
		XCTAssertEqual(tokens[5].type, .option)
		XCTAssertEqual(tokens[6].type, .leftParen)
		XCTAssertEqual(tokens[7].type, .identifier) // custom
		XCTAssertEqual(tokens[8].type, .period)
		XCTAssertEqual(tokens[9].type, .identifier) // option
		XCTAssertEqual(tokens[10].type, .rightParen)
		XCTAssertEqual(tokens[11].type, .equals)
		XCTAssertEqual(tokens[12].type, .leftBrace)
	}
	
	func testMapFieldDefinition() throws {
		let input = """
		message Example {
			map<string, Project> projects = 1;
			map<int32, string> numbers = 2;
			map<fixed64, bytes> data = 3 [deprecated = true];
		}
		"""
		
		let tokens = try getAllTokens(from: input)
		
		// First map field
		XCTAssertEqual(tokens[3].type, .map)
		XCTAssertEqual(tokens[4].type, .leftAngle)
		XCTAssertEqual(tokens[5].type, .string)
		XCTAssertEqual(tokens[6].type, .comma)
		XCTAssertEqual(tokens[7].type, .identifier) // Project
		XCTAssertEqual(tokens[8].type, .rightAngle)
		XCTAssertEqual(tokens[9].type, .identifier) // projects
		
		// Second map field
		XCTAssertEqual(tokens[13].type, .map)
		XCTAssertEqual(tokens[14].type, .leftAngle)
		XCTAssertEqual(tokens[15].type, .int32)
		XCTAssertEqual(tokens[16].type, .comma)
		XCTAssertEqual(tokens[17].type, .string) // string
		XCTAssertEqual(tokens[18].type, .rightAngle)
		XCTAssertEqual(tokens[19].type, .identifier) // numbers
		
		// Third map field with option
		let thirdMap = tokens.lastIndex { $0.type == .map }!
		XCTAssertEqual(tokens[thirdMap + 2].type, .fixed64)
		XCTAssertTrue(tokens.contains { $0.type == .leftBracket })
		XCTAssertTrue(tokens.contains { $0.literal == "deprecated" })
	}

	// MARK: - Error Handling Tests
	
	func testInvalidCharacters() throws {
		let invalidInputs = [
			"message$name",
			"enum#type",
			"field@value",
			"name`test",
			"type¢value",
			"field£name",
			"test¥value",
			"name§test"
		]
		
		for input in invalidInputs {
			XCTAssertThrowsError(try getAllTokens(from: input)) { error in
				guard let lexerError = error as? LexerError else {
					XCTFail("Expected LexerError for input: \(input)")
					return
				}
				
				switch lexerError {
				case .invalidCharacter(let char, let location):
					// Find the first invalid character in the input
					let invalidChar = input.first { !$0.isLetter && !$0.isNumber && $0 != "_" }!
					XCTAssertEqual(char, invalidChar)
					XCTAssertEqual(location.line, 1)
					let expectedColumn = input.distance(from: input.startIndex, to: input.firstIndex(of: invalidChar)!) + 1
					XCTAssertEqual(location.column, expectedColumn)
				default:
					XCTFail("Expected invalidCharacter error for input: \(input)")
				}
			}
		}
	}
	
	func testUnexpectedEndOfFile() throws {
		let incompleteInputs = [
			"\"Unterminated string",
			"/* Unterminated comment",
		]
		
		for input in incompleteInputs {
			XCTAssertThrowsError(try getAllTokens(from: input)) { error in
				guard let lexerError = error as? LexerError else {
					XCTFail("Expected LexerError for input: \(input)")
					return
				}
				
				switch lexerError {
				case .unterminatedString(let location):
					XCTAssertEqual(location.line, 1)
				default:
					// Other unterminated constructs will be caught during parsing
					break
				}
			}
		}
	}
	
	func testIncompleteTokens() throws {
		let inputs = [
			"1.", // Incomplete float
			"1e", // Incomplete scientific notation
			"1e+", // Incomplete scientific notation with sign
//			"\\u", // Incomplete unicode escape
//			"\\u123", // Incomplete unicode escape
//			"\\x", // Invalid escape sequence
			"0x", // Incomplete hex number
			"'incomplete", // Unterminated string with single quote
			"\"incomplete", // Unterminated string with double quote
		]
		
		for input in inputs {
			XCTAssertThrowsError(try getAllTokens(from: input)) { error in
				guard let lexerError = error as? LexerError else {
					XCTFail("Expected LexerError for input: \(input)")
					return
				}
				
				switch lexerError {
				case .invalidNumber(_, _),
					 .invalidEscapeSequence(_, _),
					 .unterminatedString(_):
					break // Success - expected errors
				default:
					XCTFail("Unexpected error type for input: \(input)")
				}
			}
		}
	}

	func testRecoveryAfterError() throws {
		let inputs = [
			"message @ Example", // Invalid character between tokens
			"enum # Status", // Invalid character between tokens
			"service $ Test", // Invalid character between tokens
			"field % name", // Invalid character between tokens
		]
		
		for input in inputs {
			XCTAssertThrowsError(try getAllTokens(from: input)) { error in
				guard let lexerError = error as? LexerError else {
					XCTFail("Expected LexerError for input: \(input)")
					return
				}
				
				switch lexerError {
				case .invalidCharacter(let char, let location):
					// Verify the error is at the special character
					XCTAssertTrue("@#$%".contains(char))
					XCTAssertEqual(location.line, 1)
					// Verify the location is after the first token
					XCTAssertGreaterThan(location.column, 1)
				default:
					XCTFail("Expected invalidCharacter error for input: \(input)")
				}
			}
		}
	}
	
	func testErrorsWithComments() throws {
		let inputs = [
			"// Comment\n@", // Invalid character after comment
			"/* Comment */ #", // Invalid character after block comment
			"// Comment\n$test", // Invalid identifier start after comment
			"/* Comment */ %value" // Invalid identifier start after block comment
		]
		
		for input in inputs {
			XCTAssertThrowsError(try getAllTokens(from: input)) { error in
				guard let lexerError = error as? LexerError else {
					XCTFail("Expected LexerError for input: \(input)")
					return
				}
				
				switch lexerError {
				case .invalidCharacter(let char, let location):
					XCTAssertTrue("@#$%".contains(char))
					XCTAssertGreaterThanOrEqual(location.line, 1)
				default:
					XCTFail("Expected invalidCharacter error for input: \(input)")
				}
			}
		}
	}
	
	func testErrorLocationTracking() throws {
		let input = """
		message Example {
			string name = 1;
			int32 @ value = 2;
		}
		"""
		
		XCTAssertThrowsError(try getAllTokens(from: input)) { error in
			guard let lexerError = error as? LexerError else {
				XCTFail("Expected LexerError")
				return
			}
			
			switch lexerError {
			case .invalidCharacter(let char, let location):
				XCTAssertEqual(char, "@")
				XCTAssertEqual(location.line, 3)
				XCTAssertGreaterThan(location.column, 1)
			default:
				XCTFail("Expected invalidCharacter error")
			}
		}
	}
	
	func testConcurrentErrors() throws {
		let input = """
		message @ Example {
			string # name = 1;
			int32 $ value = 2;
		}
		"""
		
		// Should fail on first error encountered
		XCTAssertThrowsError(try getAllTokens(from: input)) { error in
			guard let lexerError = error as? LexerError else {
				XCTFail("Expected LexerError")
				return
			}
			
			switch lexerError {
			case .invalidCharacter(let char, let location):
				XCTAssertEqual(char, "@")
				XCTAssertEqual(location.line, 1)
			default:
				XCTFail("Expected invalidCharacter error")
			}
		}
	}

	// MARK: - Edge Cases Tests
	
	func testEmptyFile() throws {
		for input in ["", " ", "\n", "\t", "\r", "\r\n", "   \n\t\r\n  "] {
			let tokens = try getAllTokens(from: input)
			XCTAssertEqual(tokens.count, 1)
			XCTAssertEqual(tokens[0].type, .eof)
		}
	}
	
	func testVeryLongTokens() throws {
		// Test very long identifier
		let longIdentifier = String(repeating: "a", count: 1000)
		let tokensForIdentifier = try getAllTokens(from: longIdentifier)
		XCTAssertEqual(tokensForIdentifier[0].type, .identifier)
		XCTAssertEqual(tokensForIdentifier[0].literal, longIdentifier)
		XCTAssertEqual(tokensForIdentifier[0].length, 1000)
		
		// Test very long string
		let longString = "\"\(String(repeating: "x", count: 1000))\""
		let tokensForString = try getAllTokens(from: longString)
		XCTAssertEqual(tokensForString[0].type, .stringLiteral)
		XCTAssertEqual(tokensForString[0].length, 1000)
		
		// Test very long comment
		let longComment = "/* \(String(repeating: "c", count: 1000)) */"
		let tokensForComment = try getAllTokens(from: longComment)
		XCTAssertEqual(tokensForComment[0].type, .eof)
		XCTAssertEqual(tokensForComment[0].leadingComments.first?.count, 1000)
	}
	
	func testMaximumLineLength() throws {
		// Create a line with maximum reasonable length
		let longLine = String(repeating: "a ", count: 5000)
		let tokens = try getAllTokens(from: longLine)
		
		XCTAssertGreaterThan(tokens.count, 5000) // Should have one token per 'a' plus EOF
		for (index, token) in tokens.enumerated() where index < tokens.count - 1 {
			XCTAssertEqual(token.type, .identifier)
			XCTAssertEqual(token.literal, "a")
			XCTAssertEqual(token.location.line, 1)
			XCTAssertEqual(token.location.column, index * 2 + 1)
		}
	}
	
	func testSpecialWhitespaceCharacters() throws {
		let input = "message\u{00A0}Example\u{2002}{\u{2003}string\u{2004}name\u{2005}=\u{2006}1;\u{2007}}"
		
		let tokens = try getAllTokens(from: input)
		XCTAssertEqual(tokens.count, 10) // message, Example, {, string, name, =, 1, }, ;
		
		XCTAssertEqual(tokens[0].type, .message)
		XCTAssertEqual(tokens[1].type, .identifier)
		XCTAssertEqual(tokens[1].literal, "Example")
		XCTAssertEqual(tokens[9].type, .eof)
	}
	
	func testUTF8BOM() throws {
		let bom = "\u{FEFF}"
		let inputs = [
			bom + "message",
			bom + "/* comment */ option",
			bom + "\"string\"",
			bom + "123"
		]
		
		for input in inputs {
			let tokens = try getAllTokens(from: input)
			XCTAssertGreaterThanOrEqual(tokens.count, 2) // At least one token + EOF
			// First token should be parsed correctly, ignoring BOM
			XCTAssertNotEqual(tokens[0].literal.prefix(1), "\u{FEFF}")
		}
	}
	
	func testNonASCIICharacters() throws {
		// Test valid identifier characters from different Unicode planes
		let validInputs = [
			"message_\u{0100}", // Latin Extended-A
			"message_\u{0900}", // Devanagari
			"message_\u{4E00}", // CJK Unified Ideographs
		]
		
		for input in validInputs {
			XCTAssertThrowsError(try getAllTokens(from: input)) { error in
				guard let lexerError = error as? LexerError else {
					XCTFail("Expected LexerError")
					return
				}
				XCTAssertTrue(lexerError.description.contains("Invalid character"))
			}
		}
	}

	func testCarriageReturnLineFeed() throws {
		let inputs = [
			"message\rExample",
			"message\nExample",
			"message\r\nExample",
			"message\n\rExample" // \n\r makes 2 new lines
		]

		for input in inputs {
			let tokens = try getAllTokens(from: input)
			XCTAssertEqual(tokens.count, 3) // message, Example, EOF
			XCTAssertEqual(tokens[0].type, .message)
			XCTAssertEqual(tokens[1].type, .identifier)
			XCTAssertEqual(tokens[1].literal, "Example")
			if input.contains("\n\r") {
				XCTAssertEqual(tokens[1].location.line, 3)
			} else {
				XCTAssertEqual(tokens[1].location.line, 2)
			}
		}
	}

	func testMixedLineEndings() throws {
		let input = "message\rExample\nsecond\r\nthird\n\rfourth"
		let tokens = try getAllTokens(from: input)
		
		XCTAssertEqual(tokens.count, 6) // message, Example, second, third, fourth, EOF
		XCTAssertEqual(tokens[1].location.line, 2)
		XCTAssertEqual(tokens[2].location.line, 3)
		XCTAssertEqual(tokens[3].location.line, 4)
		XCTAssertEqual(tokens[4].location.line, 6)
	}
	
	func testExtremeValues() throws {
		let input = """
		message Example {
			int32 max_value = 2147483647;
			int32 min_value = -2147483648;
			int64 large_value = 9223372036854775807;
			int64 min_large_value = -9223372036854775808;
			double scientific = 1.23456789e+308;
			float small_scientific = 1.23456789e-38;
		}
		"""
		
		let tokens = try getAllTokens(from: input)
		
		// Verify number literals are correctly tokenized
		let numberTokens = tokens.filter { $0.type == .intLiteral || $0.type == .floatLiteral }
		XCTAssertEqual(numberTokens.count, 6)
		
		// Verify specific extreme values
		XCTAssertTrue(numberTokens.contains { $0.literal == "2147483647" })
		XCTAssertTrue(numberTokens.contains { $0.literal == "-2147483648" })
		XCTAssertTrue(numberTokens.contains { $0.literal == "9223372036854775807" })
		XCTAssertTrue(numberTokens.contains { $0.literal == "-9223372036854775808" })
		XCTAssertTrue(numberTokens.contains { $0.literal == "1.23456789e+308" })
		XCTAssertTrue(numberTokens.contains { $0.literal == "1.23456789e-38" })
	}
	
	func testZeroLengthEdgeCases() throws {
		// Test empty string literals
		let emptyString = "\"\""
		let tokensForEmptyString = try getAllTokens(from: emptyString)
		XCTAssertEqual(tokensForEmptyString[0].type, .stringLiteral)
		XCTAssertEqual(tokensForEmptyString[0].literal, "")
		XCTAssertEqual(tokensForEmptyString[0].length, 0)
		
		// Test empty comment
		let emptyComment = "/**/"
		let tokensForEmptyComment = try getAllTokens(from: emptyComment)
		XCTAssertEqual(tokensForEmptyComment[0].type, .eof)
		XCTAssertTrue(tokensForEmptyComment[0].leadingComments.first?.isEmpty ?? false)
		
		// Test empty line comment
		let emptyLineComment = "//"
		let tokensForEmptyLineComment = try getAllTokens(from: emptyLineComment)
		XCTAssertEqual(tokensForEmptyLineComment[0].type, .eof)
		XCTAssertTrue(tokensForEmptyLineComment[0].leadingComments.first?.isEmpty ?? false)
	}

	// MARK: - Location Tracking Tests
	
	func testLineNumberTracking() throws {
		let input = """
		syntax = "proto3";
		
		package example;
		
		message Example {
			string name = 1;
		}
		"""
		
		let tokens = try getAllTokens(from: input)
		
		// Check each token's line number
		XCTAssertEqual(tokens[0].location.line, 1)  // syntax
		XCTAssertEqual(tokens[1].location.line, 1)  // =
		XCTAssertEqual(tokens[2].location.line, 1)  // "proto3"
		XCTAssertEqual(tokens[3].location.line, 1)  // ;
		XCTAssertEqual(tokens[4].location.line, 3)  // package
		XCTAssertEqual(tokens[5].location.line, 3)  // example
		XCTAssertEqual(tokens[6].location.line, 3)  // ;
		XCTAssertEqual(tokens[7].location.line, 5)  // message
		XCTAssertEqual(tokens[8].location.line, 5)  // Example
		XCTAssertEqual(tokens[9].location.line, 5)  // {
		XCTAssertEqual(tokens[10].location.line, 6) // string
	}

	func testColumnNumberTracking() throws {
		let input = "message   Example   {    string    name    =     1;"
		let tokens = try getAllTokens(from: input)

		XCTAssertEqual(tokens[0].location.column, 1)   // message
		XCTAssertEqual(tokens[1].location.column, 11)  // Example
		XCTAssertEqual(tokens[2].location.column, 21)  // {
		XCTAssertEqual(tokens[3].location.column, 26)  // string
		XCTAssertEqual(tokens[4].location.column, 36)  // name
		XCTAssertEqual(tokens[5].location.column, 44)  // =
		XCTAssertEqual(tokens[6].location.column, 50)  // 1
		XCTAssertEqual(tokens[7].location.column, 51)  // ;
	}

	func testLocationAfterMultilineTokens() throws {
		let input = """
		/*
		 * Multi-line
		 * comment
		 */
		message Example {
		    // Single line comment
		    string name = 1;
		}
		"""

		let tokens = try getAllTokens(from: input)

		// First token after multi-line comment
		XCTAssertEqual(tokens[0].type, .message)
		XCTAssertEqual(tokens[0].location.line, 5)
		XCTAssertEqual(tokens[0].location.column, 1)

		// Token after single-line comment
		XCTAssertEqual(tokens[3].type, .string)
		XCTAssertEqual(tokens[3].location.line, 7)
		XCTAssertEqual(tokens[3].location.column, 5)
	}

	func testLocationAfterComments() throws {
		let input = """
		// Comment 1
		message // Comment 2
		Example /* Comment 3 */ {
			string /* Comment 4 */ name = 1;
		}
		"""

		let tokens = try getAllTokens(from: input)

		// Verify locations considering comments
		XCTAssertEqual(tokens[0].type, .message)
		XCTAssertEqual(tokens[0].location.line, 2)
		XCTAssertEqual(tokens[0].location.column, 1)

		XCTAssertEqual(tokens[1].type, .identifier) // Example
		XCTAssertEqual(tokens[1].location.line, 3)
		XCTAssertEqual(tokens[1].location.column, 1)

		// Check token after inline comment
		XCTAssertEqual(tokens[2].type, .leftBrace)
		XCTAssertEqual(tokens[2].location.line, 3)
		XCTAssertEqual(tokens[2].location.column, 25)
	}

	func testLocationWithTabs() throws {
		let input = "message\tExample\t{\n\tstring\tname\t=\t1;\n}"
		let tokens = try getAllTokens(from: input)

		// Verify locations with tab characters (assuming tab width of 8)
		XCTAssertEqual(tokens[0].type, .message)
		XCTAssertEqual(tokens[0].location.column, 1)

		XCTAssertEqual(tokens[1].type, .identifier) // Example
		XCTAssertEqual(tokens[1].location.column, 9) // After tab

		XCTAssertEqual(tokens[3].type, .string)
		XCTAssertEqual(tokens[3].location.line, 2)
		XCTAssertEqual(tokens[3].location.column, 2) // After tab
	}

	func testLocationInLongLines() throws {
		let input = "message" + String(repeating: " ", count: 100) + "Example"
		let tokens = try getAllTokens(from: input)

		XCTAssertEqual(tokens[0].type, .message)
		XCTAssertEqual(tokens[0].location.column, 1)

		XCTAssertEqual(tokens[1].type, .identifier) // Example
		XCTAssertEqual(tokens[1].location.column, 108) // After 100 spaces plus "message "
	}

	func testLocationWithEscapeSequences() throws {
		let input = """
		string name = "Hello\\nWorld\\tTab\\u0020Space";
		message Example {
		}
		"""

		let tokens = try getAllTokens(from: input)

		// Find the string literal token
		let stringToken = tokens.first { $0.type == .stringLiteral }!
		XCTAssertEqual(stringToken.location.line, 1)
		XCTAssertEqual(stringToken.length, 21) // Length of unescaped content

		// Check location of token after string
		let nextToken = tokens[tokens.firstIndex(of: stringToken)! + 1]
		XCTAssertEqual(nextToken.location.line, 1)
	}

	func testLocationWithUnicodeCharacters() throws {
		// This test should throw because Unicode characters aren't allowed
		let input = "message 测试 {"

		XCTAssertThrowsError(try getAllTokens(from: input)) { error in
			guard let lexerError = error as? LexerError else {
				XCTFail("Expected LexerError")
				return
			}

			switch lexerError {
			case .invalidCharacter(_, let location):
				XCTAssertEqual(location.line, 1)
				XCTAssertEqual(location.column, 9) // After "message "
			default:
				XCTFail("Expected invalidCharacter error")
			}
		}
	}

	func testLocationAfterErrors() throws {
		let inputs = [
			("message @ Example", 9), // Column where '@' appears
			("enum # Type", 6),       // Column where '#' appears
			("service $ Name", 9),    // Column where '$' appears
		]

		for (input, errorColumn) in inputs {
			XCTAssertThrowsError(try getAllTokens(from: input)) { error in
				guard let lexerError = error as? LexerError else {
					XCTFail("Expected LexerError")
					return
				}

				switch lexerError {
				case .invalidCharacter(_, let location):
					XCTAssertEqual(location.line, 1)
					XCTAssertEqual(location.column, errorColumn)
				default:
					XCTFail("Expected invalidCharacter error")
				}
			}
		}
	}

	func testEndOfFileLocation() throws {
		let inputs = [
			"message Example", // EOF after content
			"",                // Empty file
			"\n\n\n",          // Multiple empty lines
			"// Comment\n",    // EOF after comment
			"/* Comment */\n"  // EOF after block comment
		]

		for input in inputs {
			let tokens = try getAllTokens(from: input)
			let eofToken = tokens.last!
			XCTAssertEqual(eofToken.type, .eof)

			let expectedLine = input.components(separatedBy: .newlines).count
			XCTAssertEqual(eofToken.location.line, expectedLine)
		}
	}
}
