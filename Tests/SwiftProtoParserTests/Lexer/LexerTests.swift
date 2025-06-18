import XCTest
@testable import SwiftProtoParser

// MARK: - Result Extensions for Testing

extension Result {
    /// Convenience property to check if the result is a success
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
    
    /// Convenience property to check if the result is a failure
    var isFailure: Bool {
        return !isSuccess
    }
}

// MARK: - LexerTests

final class LexerTests: XCTestCase {
    
    // MARK: - Basic Tokenization Tests
    
    func testEmptyInput() {
        let lexer = Lexer(input: "")
        let result = lexer.tokenize()
        
        XCTAssertTrue(result.isSuccess)
        if case .success(let tokens) = result {
            XCTAssertEqual(tokens.count, 1)
            XCTAssertEqual(tokens[0], .eof)
        }
    }
    
    func testWhitespaceTokenization() {
        let lexer = Lexer(input: " \t\r  ")
        let result = lexer.tokenize()
        
        XCTAssertTrue(result.isSuccess)
        if case .success(let tokens) = result {
            XCTAssertEqual(tokens.count, 6) // 5 whitespace + EOF
            for i in 0..<5 {
                XCTAssertTrue(tokens[i].hasType(.whitespace))
            }
            XCTAssertTrue(tokens[5].hasType(.eof))
        }
    }
    
    func testNewlineTokenization() {
        let lexer = Lexer(input: "\n\n")
        let result = lexer.tokenize()
        
        XCTAssertTrue(result.isSuccess)
        if case .success(let tokens) = result {
            XCTAssertEqual(tokens.count, 3) // 2 newlines + EOF
            XCTAssertTrue(tokens[0].hasType(.newline))
            XCTAssertTrue(tokens[1].hasType(.newline))
            XCTAssertTrue(tokens[2].hasType(.eof))
        }
    }
    
    // MARK: - Symbol Tokenization Tests
    
    func testSymbolTokenization() {
        let symbols = "{};[]()=<>,.-+"
        let lexer = Lexer(input: symbols)
        let result = lexer.tokenize()
        
        XCTAssertTrue(result.isSuccess)
        if case .success(let tokens) = result {
            XCTAssertEqual(tokens.count, symbols.count + 1) // symbols + EOF
            
            for (index, char) in symbols.enumerated() {
                XCTAssertTrue(tokens[index].hasType(.symbol(char)))
            }
            XCTAssertTrue(tokens.last?.hasType(.eof) == true)
        }
    }
    
    // MARK: - Keyword Tokenization Tests
    
    func testKeywordTokenization() {
        let input = "syntax package import message"
        let lexer = Lexer(input: input)
        let result = lexer.tokenize()
        
        XCTAssertTrue(result.isSuccess)
        if case .success(let tokens) = result {
            let nonWhitespaceTokens = tokens.filter { !$0.isIgnorable && !$0.hasType(.eof) }
            XCTAssertEqual(nonWhitespaceTokens.count, 4)
            
            XCTAssertTrue(nonWhitespaceTokens[0].hasType(.keyword(.syntax)))
            XCTAssertTrue(nonWhitespaceTokens[1].hasType(.keyword(.package)))
            XCTAssertTrue(nonWhitespaceTokens[2].hasType(.keyword(.import)))
            XCTAssertTrue(nonWhitespaceTokens[3].hasType(.keyword(.message)))
        }
    }
    
    func testAllKeywords() {
        let keywords = ["syntax", "package", "import", "option", "message", "enum", 
                       "service", "rpc", "repeated", "optional", "required", 
                       "returns", "stream", "reserved", "oneof", "map", "extend", 
                       "extensions", "group", "public", "weak"]
        
        for keyword in keywords {
            let lexer = Lexer(input: keyword)
            let result = lexer.tokenize()
            
            XCTAssertTrue(result.isSuccess, "Failed to tokenize keyword: \(keyword)")
            if case .success(let tokens) = result {
                let nonEofTokens = tokens.filter { $0 != .eof }
                XCTAssertEqual(nonEofTokens.count, 1)
                if case .keyword(let parsedKeyword) = nonEofTokens[0].type {
                    XCTAssertEqual(parsedKeyword.rawValue, keyword)
                } else {
                    XCTFail("Expected keyword token for: \(keyword)")
                }
            }
        }
    }
    
    // MARK: - Identifier Tokenization Tests
    
    func testIdentifierTokenization() {
        let input = "myMessage field_name _private test123"
        let lexer = Lexer(input: input)
        let result = lexer.tokenize()
        
        XCTAssertTrue(result.isSuccess)
        if case .success(let tokens) = result {
            let nonWhitespaceTokens = tokens.filter { !$0.isIgnorable && !($0 == .eof) }
            XCTAssertEqual(nonWhitespaceTokens.count, 4)
            
            XCTAssertEqual(nonWhitespaceTokens[0], .identifier("myMessage"))
            XCTAssertEqual(nonWhitespaceTokens[1], .identifier("field_name"))
            XCTAssertEqual(nonWhitespaceTokens[2], .identifier("_private"))
            XCTAssertEqual(nonWhitespaceTokens[3], .identifier("test123"))
        }
    }
    
    // MARK: - Boolean Literal Tests
    
    func testBooleanLiterals() {
        let lexer = Lexer(input: "true false")
        let result = lexer.tokenize()
        
        XCTAssertTrue(result.isSuccess)
        if case .success(let tokens) = result {
            let nonWhitespaceTokens = tokens.filter { !$0.isIgnorable && !($0 == .eof) }
            XCTAssertEqual(nonWhitespaceTokens.count, 2)
            
            XCTAssertEqual(nonWhitespaceTokens[0], .boolLiteral(true))
            XCTAssertEqual(nonWhitespaceTokens[1], .boolLiteral(false))
        }
    }
    
    // MARK: - Integer Literal Tests
    
    func testIntegerLiterals() {
        let testCases = [
            ("0", Int64(0)),
            ("42", Int64(42)),
            ("123456", Int64(123456)),
            ("9223372036854775807", Int64.max) // max int64
        ]
        
        for (input, expected) in testCases {
            let lexer = Lexer(input: input)
            let result = lexer.tokenize()
            
            XCTAssertTrue(result.isSuccess, "Failed to parse integer: \(input)")
            if case .success(let tokens) = result {
                let nonEofTokens = tokens.filter { $0 != .eof }
                XCTAssertEqual(nonEofTokens.count, 1)
                XCTAssertEqual(nonEofTokens[0], .integerLiteral(expected))
            }
        }
    }
    
    func testNegativeIntegerLiterals() {
        // Negative numbers should be parsed as separate symbol and number tokens
        let lexer = Lexer(input: "-17")
        let result = lexer.tokenize()
        
        XCTAssertTrue(result.isSuccess)
        if case .success(let tokens) = result {
            let nonEofTokens = tokens.filter { $0 != .eof }
            XCTAssertEqual(nonEofTokens.count, 2)
            XCTAssertEqual(nonEofTokens[0], .symbol("-"))
            XCTAssertEqual(nonEofTokens[1], .integerLiteral(17))
        }
    }
    
    func testFloatLiterals() {
        let testCases = [
            ("3.14", 3.14),
            ("0.0", 0.0),
            ("1.5e10", 1.5e10),
            ("2.5E-3", 2.5E-3)
        ]
        
        for (input, expected) in testCases {
            let lexer = Lexer(input: input)
            let result = lexer.tokenize()
            
            XCTAssertTrue(result.isSuccess, "Failed to parse float: \(input)")
            if case .success(let tokens) = result {
                let nonEofTokens = tokens.filter { $0 != .eof }
                XCTAssertEqual(nonEofTokens.count, 1)
                XCTAssertEqual(nonEofTokens[0], .floatLiteral(expected))
            }
        }
    }
    
    func testNegativeFloatLiterals() {
        // Negative floats should be parsed as separate symbol and number tokens
        let testCases = [
            ("-2.5", "-", 2.5),
            ("-1.2e+5", "-", 1.2e+5)
        ]
        
        for (input, expectedSymbol, expectedFloat) in testCases {
            let lexer = Lexer(input: input)
            let result = lexer.tokenize()
            
            XCTAssertTrue(result.isSuccess, "Failed to parse negative float: \(input)")
            if case .success(let tokens) = result {
                let nonEofTokens = tokens.filter { $0 != .eof }
                XCTAssertEqual(nonEofTokens.count, 2)
                XCTAssertEqual(nonEofTokens[0], .symbol(Character(expectedSymbol)))
                XCTAssertEqual(nonEofTokens[1], .floatLiteral(expectedFloat))
            }
        }
    }
    
    // MARK: - String Literal Tests
    
    func testStringLiterals() {
        let testCases = [
            ("\"hello\"", "hello"),
            ("'world'", "world"),
            ("\"hello world\"", "hello world"),
            ("\"\"", ""),
            ("''", "")
        ]
        
        for (input, expected) in testCases {
            let lexer = Lexer(input: input)
            let result = lexer.tokenize()
            
            XCTAssertTrue(result.isSuccess, "Failed to parse string: \(input)")
            if case .success(let tokens) = result {
                let nonEofTokens = tokens.filter { $0 != .eof }
                XCTAssertEqual(nonEofTokens.count, 1)
                XCTAssertEqual(nonEofTokens[0], .stringLiteral(expected))
            }
        }
    }
    
    func testStringLiteralsWithEscapes() {
        let testCases = [
            ("\"hello\\nworld\"", "hello\nworld"),
            ("\"tab\\there\"", "tab\there"),
            ("\"quote\\\"inside\"", "quote\"inside"),
            ("\"backslash\\\\\"", "backslash\\"),
            ("\"null\\0char\"", "null\0char")
        ]
        
        for (input, expected) in testCases {
            let lexer = Lexer(input: input)
            let result = lexer.tokenize()
            
            XCTAssertTrue(result.isSuccess, "Failed to parse escaped string: \(input)")
            if case .success(let tokens) = result {
                let nonEofTokens = tokens.filter { $0 != .eof }
                XCTAssertEqual(nonEofTokens.count, 1)
                XCTAssertEqual(nonEofTokens[0], .stringLiteral(expected))
            }
        }
    }
    
    // MARK: - Comment Tests
    
    func testSingleLineComments() {
        let input = "// This is a comment\n// Another comment"
        let lexer = Lexer(input: input)
        let result = lexer.tokenize()
        
        XCTAssertTrue(result.isSuccess)
        if case .success(let tokens) = result {
            let commentTokens = tokens.compactMap { token -> String? in
                if case .comment(let comment) = token.type {
                    return comment
                }
                return nil
            }
            
            XCTAssertEqual(commentTokens.count, 2)
            XCTAssertEqual(commentTokens[0], "// This is a comment")
            XCTAssertEqual(commentTokens[1], "// Another comment")
        }
    }
    
    func testMultiLineComments() {
        let input = "/* This is a\nmulti-line comment */"
        let lexer = Lexer(input: input)
        let result = lexer.tokenize()
        
        XCTAssertTrue(result.isSuccess)
        if case .success(let tokens) = result {
            let commentTokens = tokens.compactMap { token -> String? in
                if case .comment(let comment) = token.type {
                    return comment
                }
                return nil
            }
            
            XCTAssertEqual(commentTokens.count, 1)
            XCTAssertEqual(commentTokens[0], "/* This is a\nmulti-line comment */")
        }
    }
    
    // MARK: - Complex Proto3 Example Tests
    
    func testSimpleProto3File() {
        let input = """
        syntax = "proto3";
        
        package example;
        
        message Person {
            string name = 1;
            int32 age = 2;
            repeated string hobbies = 3;
        }
        """
        
        let lexer = Lexer(input: input, fileName: "person.proto")
        let result = lexer.tokenize()
        
        XCTAssertTrue(result.isSuccess)
        if case .success(let tokens) = result {
            let significantTokens = tokens.filter { !$0.isIgnorable && !($0 == .eof) }
            
            // Verify key tokens are present
            XCTAssertTrue(significantTokens.contains(.keyword(.syntax)))
            XCTAssertTrue(significantTokens.contains(.symbol("=")))
            XCTAssertTrue(significantTokens.contains(.stringLiteral("proto3")))
            XCTAssertTrue(significantTokens.contains(.keyword(.package)))
            XCTAssertTrue(significantTokens.contains(.identifier("example")))
            XCTAssertTrue(significantTokens.contains(.keyword(.message)))
            XCTAssertTrue(significantTokens.contains(.identifier("Person")))
            XCTAssertTrue(significantTokens.contains(.identifier("name")))
            XCTAssertTrue(significantTokens.contains(.integerLiteral(1)))
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidCharacterError() {
        let lexer = Lexer(input: "valid @#$invalid", fileName: "test.proto")
        let result = lexer.tokenize()
        
        XCTAssertTrue(result.isFailure)
        if case .failure(let error) = result {
            if case .invalidCharacter(let char, let line, let column) = error {
                XCTAssertEqual(char, "@")
                XCTAssertEqual(line, 1)
                XCTAssertEqual(column, 7)
            } else {
                XCTFail("Expected invalidCharacter error")
            }
        }
    }
    
    func testUnterminatedStringError() {
        let lexer = Lexer(input: "\"unterminated string", fileName: "test.proto")
        let result = lexer.tokenize()
        
        XCTAssertTrue(result.isFailure)
        if case .failure(let error) = result {
            if case .unterminatedString(let line, let column) = error {
                XCTAssertEqual(line, 1)
                XCTAssertEqual(column, 1)
            } else {
                XCTFail("Expected unterminatedString error")
            }
        }
    }
    
    func testUnterminatedMultiLineCommentError() {
        let lexer = Lexer(input: "/* unterminated comment", fileName: "test.proto")
        let result = lexer.tokenize()
        
        XCTAssertTrue(result.isFailure)
        if case .failure(let error) = result {
            if case .unterminatedComment(let line, let column) = error {
                XCTAssertEqual(line, 1)
                XCTAssertEqual(column, 1)
            } else {
                XCTFail("Expected unterminatedComment error")
            }
        }
    }
    
    func testInvalidEscapeSequenceError() {
        let lexer = Lexer(input: "\"invalid\\xescape\"", fileName: "test.proto")
        let result = lexer.tokenize()
        
        XCTAssertTrue(result.isFailure)
        if case .failure(let error) = result {
            if case .invalidEscapeSequence(let sequence, let line, let column) = error {
                XCTAssertEqual(sequence, "\\x")
                XCTAssertEqual(line, 1)
                XCTAssertEqual(column, 9) // Position after the 'x' character
            } else {
                XCTFail("Expected invalidEscapeSequence error")
            }
        }
    }
    
    func testInvalidIntegerLiteralError() {
        let lexer = Lexer(input: "999999999999999999999999999999", fileName: "test.proto")
        let result = lexer.tokenize()
        
        XCTAssertTrue(result.isFailure)
        if case .failure(let error) = result {
            if case .numberOutOfRange(let value, let line, let column) = error {
                XCTAssertEqual(value, "999999999999999999999999999999")
                XCTAssertEqual(line, 1)
                XCTAssertEqual(column, 1)
            } else {
                XCTFail("Expected numberOutOfRange error")
            }
        }
    }
    
    func testInvalidFloatLiteralError() {
        let lexer = Lexer(input: "3.14.15", fileName: "test.proto")
        let result = lexer.tokenize()
        
        XCTAssertTrue(result.isSuccess) // Should parse as 3.14 then . then 15
        if case .success(let tokens) = result {
            let significantTokens = tokens.filter { !$0.isIgnorable && !($0 == .eof) }
            XCTAssertEqual(significantTokens.count, 3)
            XCTAssertEqual(significantTokens[0], .floatLiteral(3.14))
            XCTAssertEqual(significantTokens[1], .symbol("."))
            XCTAssertEqual(significantTokens[2], .integerLiteral(15))
        }
    }
    
    // MARK: - Convenience Method Tests
    
    func testStaticTokenizeMethod() {
        let lexer = Lexer(input: "syntax = \"proto3\";")
        let result = lexer.tokenize()
        
        XCTAssertTrue(result.isSuccess)
        if case .success(let tokens) = result {
            let significantTokens = tokens.filter { !$0.isIgnorable && !($0 == .eof) }
            XCTAssertEqual(significantTokens.count, 4)
            XCTAssertEqual(significantTokens[0], .keyword(.syntax))
            XCTAssertEqual(significantTokens[1], .symbol("="))
            XCTAssertEqual(significantTokens[2], .stringLiteral("proto3"))
            XCTAssertEqual(significantTokens[3], .symbol(";"))
        }
    }
    
    func testPublicAPIIntegration() {
        let lexer = Lexer(input: "invalid @character", fileName: "test.proto")
        let result = lexer.tokenizeForPublicAPI()
        
        XCTAssertTrue(result.isFailure)
        if case .failure(let error) = result {
            if case .lexicalError(let message, let file, let line, let column) = error {
                XCTAssertTrue(message.contains("Invalid character"))
                XCTAssertEqual(file, "test.proto")
                XCTAssertEqual(line, 1)
                XCTAssertEqual(column, 9)
            } else {
                XCTFail("Expected lexicalError from public API")
            }
        }
    }
    
    func testStaticPublicAPIMethod() {
        let lexer = Lexer(input: "invalid @", fileName: "test.proto")
        let result = lexer.tokenizeForPublicAPI()
        
        XCTAssertTrue(result.isFailure)
        if case .failure(let error) = result {
            if case .lexicalError(let message, let file, let line, let column) = error {
                XCTAssertTrue(message.contains("Invalid character"))
                XCTAssertEqual(file, "test.proto")
                XCTAssertEqual(line, 1)
                XCTAssertEqual(column, 9)
            } else {
                XCTFail("Expected lexicalError from static public API method")
            }
        }
    }
    
    // MARK: - Position Tracking Tests
    
    func testLineAndColumnTracking() {
        // Test that position tracking works by introducing an error on line 2
        let inputWithError = """
        line1
        line2 @invalid
        line3
        """
        let errorLexer = Lexer(input: inputWithError, fileName: "test.proto")
        let result = errorLexer.tokenize()
        
        XCTAssertTrue(result.isFailure)
        if case .failure(let error) = result {
            if case .invalidCharacter(_, let line, let column) = error {
                XCTAssertEqual(line, 2)
                XCTAssertEqual(column, 7)
            } else {
                XCTFail("Expected invalidCharacter error with position info")
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testOnlySlashSymbol() {
        let lexer = Lexer(input: "/")
        let result = lexer.tokenize()
        
        XCTAssertTrue(result.isSuccess)
        if case .success(let tokens) = result {
            XCTAssertEqual(tokens.count, 2) // "/" symbol + EOF
            XCTAssertEqual(tokens[0], .symbol("/"))
            XCTAssertEqual(tokens[1], .eof)
        }
    }
    
    func testNumberFollowedByDot() {
        let lexer = Lexer(input: "42.")
        let result = lexer.tokenize()
        
        XCTAssertTrue(result.isSuccess)
        if case .success(let tokens) = result {
            let significantTokens = tokens.filter { !$0.isIgnorable && !($0 == .eof) }
            XCTAssertEqual(significantTokens.count, 2)
            XCTAssertEqual(significantTokens[0], .integerLiteral(42))
            XCTAssertEqual(significantTokens[1], .symbol("."))
        }
    }
    
    func testNegativeNumberHandling() {
        let lexer = Lexer(input: "- 42")
        let result = lexer.tokenize()
        
        XCTAssertTrue(result.isSuccess)
        if case .success(let tokens) = result {
            let significantTokens = tokens.filter { !$0.isIgnorable && !($0 == .eof) }
            XCTAssertEqual(significantTokens.count, 2)
            XCTAssertEqual(significantTokens[0], .symbol("-"))
            XCTAssertEqual(significantTokens[1], .integerLiteral(42))
        }
    }
}
