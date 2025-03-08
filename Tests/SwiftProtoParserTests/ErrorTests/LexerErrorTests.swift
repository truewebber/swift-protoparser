import XCTest
@testable import SwiftProtoParser

final class LexerErrorTests: XCTestCase {
    
    // MARK: - Error Creation Tests
    
    func testInvalidCharacterError() {
        // Create an error with a specific character and location
        let location = SourceLocation(line: 10, column: 15)
        let error = LexerError.invalidCharacter("@", location: location)
        
        // Verify the error properties
        if case .invalidCharacter(let char, let loc) = error {
            XCTAssertEqual(char, "@")
            XCTAssertEqual(loc.line, 10)
            XCTAssertEqual(loc.column, 15)
        } else {
            XCTFail("Expected invalidCharacter error")
        }
    }
    
    func testUnterminatedStringError() {
        // Create an error with a specific location
        let location = SourceLocation(line: 5, column: 20)
        let error = LexerError.unterminatedString(location: location)
        
        // Verify the error properties
        if case .unterminatedString(let loc) = error {
            XCTAssertEqual(loc.line, 5)
            XCTAssertEqual(loc.column, 20)
        } else {
            XCTFail("Expected unterminatedString error")
        }
    }
    
    func testInvalidEscapeSequenceError() {
        // Create an error with a specific escape sequence and location
        let location = SourceLocation(line: 7, column: 25)
        let error = LexerError.invalidEscapeSequence("\\z", location: location)
        
        // Verify the error properties
        if case .invalidEscapeSequence(let seq, let loc) = error {
            XCTAssertEqual(seq, "\\z")
            XCTAssertEqual(loc.line, 7)
            XCTAssertEqual(loc.column, 25)
        } else {
            XCTFail("Expected invalidEscapeSequence error")
        }
    }
    
    func testInvalidNumberError() {
        // Create an error with a specific number and location
        let location = SourceLocation(line: 12, column: 8)
        let error = LexerError.invalidNumber("12a34", location: location)
        
        // Verify the error properties
        if case .invalidNumber(let num, let loc) = error {
            XCTAssertEqual(num, "12a34")
            XCTAssertEqual(loc.line, 12)
            XCTAssertEqual(loc.column, 8)
        } else {
            XCTFail("Expected invalidNumber error")
        }
    }
    
    func testNestedCommentError() {
        // Create an error with a specific location
        let location = SourceLocation(line: 15, column: 10)
        let error = LexerError.nestedComment(location: location)
        
        // Verify the error properties
        if case .nestedComment(let loc) = error {
            XCTAssertEqual(loc.line, 15)
            XCTAssertEqual(loc.column, 10)
        } else {
            XCTFail("Expected nestedComment error")
        }
    }
    
    // MARK: - Error Description Tests
    
    func testInvalidCharacterErrorDescription() {
        let location = SourceLocation(line: 10, column: 15)
        let error = LexerError.invalidCharacter("@", location: location)
        
        XCTAssertEqual(
            error.description,
            "Invalid character '@' at 10:15"
        )
    }
    
    func testUnterminatedStringErrorDescription() {
        let location = SourceLocation(line: 5, column: 20)
        let error = LexerError.unterminatedString(location: location)
        
        XCTAssertEqual(
            error.description,
            "Unterminated string literal at 5:20"
        )
    }
    
    func testInvalidEscapeSequenceErrorDescription() {
        let location = SourceLocation(line: 7, column: 25)
        let error = LexerError.invalidEscapeSequence("\\z", location: location)
        
        XCTAssertEqual(
            error.description,
            "Invalid escape sequence '\\z' at 7:25"
        )
    }
    
    func testInvalidNumberErrorDescription() {
        let location = SourceLocation(line: 12, column: 8)
        let error = LexerError.invalidNumber("12a34", location: location)
        
        XCTAssertEqual(
            error.description,
            "Invalid number format '12a34' at 12:8"
        )
    }
    
    func testNestedCommentErrorDescription() {
        let location = SourceLocation(line: 15, column: 10)
        let error = LexerError.nestedComment(location: location)
        
        XCTAssertEqual(
            error.description,
            "Encountered not allowed nested comments at 15:10"
        )
    }
    
    // MARK: - Error Handling Tests
    
    func testLexerThrowsInvalidCharacterError() throws {
        // Create a lexer with an invalid character
        let input = "message Test { field@ string name = 1; }"
        let lexer = Lexer(input: input)
        
        // Collect all tokens and expect an error
        XCTAssertThrowsError(try lexer.collectAllTokens()) { error in
            guard let lexerError = error as? LexerError else {
                XCTFail("Expected LexerError but got \(error)")
                return
            }
            
            if case .invalidCharacter(let char, _) = lexerError {
                XCTAssertEqual(char, "@")
            } else {
                XCTFail("Expected invalidCharacter error but got \(lexerError)")
            }
        }
    }
    
    func testLexerThrowsUnterminatedStringError() throws {
        // Create a lexer with an unterminated string
        let input = "message Test { string name = \"unterminated; }"
        let lexer = Lexer(input: input)
        
        // Collect all tokens and expect an error
        XCTAssertThrowsError(try lexer.collectAllTokens()) { error in
            guard let lexerError = error as? LexerError else {
                XCTFail("Expected LexerError but got \(error)")
                return
            }
            
            if case .unterminatedString(_) = lexerError {
                // Test passed
            } else {
                XCTFail("Expected unterminatedString error but got \(lexerError)")
            }
        }
    }
    
    func testLexerThrowsInvalidEscapeSequenceError() throws {
        // Create a lexer with an invalid escape sequence
        let input = "message Test { string name = \"invalid\\zescape\"; }"
        let lexer = Lexer(input: input)
        
        // Collect all tokens and expect an error
        XCTAssertThrowsError(try lexer.collectAllTokens()) { error in
            guard let lexerError = error as? LexerError else {
                XCTFail("Expected LexerError but got \(error)")
                return
            }
            
            if case .invalidEscapeSequence(let seq, _) = lexerError {
                XCTAssertEqual(seq, "z")
            } else {
                XCTFail("Expected invalidEscapeSequence error but got \(lexerError)")
            }
        }
    }
    
    func testLexerThrowsInvalidNumberError() throws {
        // Create a lexer with an invalid number
        let input = "message Test { int32 field = 12a34; }"
        let lexer = Lexer(input: input)
        
        // Collect all tokens and expect an error
        XCTAssertThrowsError(try lexer.collectAllTokens()) { error in
            guard let lexerError = error as? LexerError else {
                XCTFail("Expected LexerError but got \(error)")
                return
            }
            
            if case .invalidNumber(let num, _) = lexerError {
                XCTAssertEqual(num, "12")
            } else {
                XCTFail("Expected invalidNumber error but got \(lexerError)")
            }
        }
    }
    
    func testLexerThrowsNestedCommentError() throws {
        // Create a lexer with nested comments
        let input = "/* Outer comment /* Nested comment */ */"
        let lexer = Lexer(input: input)
        
        // Collect all tokens and expect an error
        XCTAssertThrowsError(try lexer.collectAllTokens()) { error in
            guard let lexerError = error as? LexerError else {
                XCTFail("Expected LexerError but got \(error)")
                return
            }
            
            if case .nestedComment(_) = lexerError {
                // Test passed
            } else {
                XCTFail("Expected nestedComment error but got \(lexerError)")
            }
        }
    }
}

// Helper extension to collect all tokens from a lexer
extension Lexer {
    func collectAllTokens() throws -> [Token] {
        var tokens: [Token] = []
        var token = try nextToken()
        
        while token.type != .eof {
            tokens.append(token)
            token = try nextToken()
        }
        
        tokens.append(token) // Add EOF token
        return tokens
    }
} 