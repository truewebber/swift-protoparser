import XCTest
@testable import SwiftProtoParser

// MARK: - LexerErrorTests

final class LexerErrorTests: XCTestCase {
    
    // MARK: - Error Case Creation Tests
    
    func testInvalidCharacterError() {
        let error = LexerError.invalidCharacter("@", line: 5, column: 10)
        
        if case .invalidCharacter(let char, let line, let column) = error {
            XCTAssertEqual(char, "@")
            XCTAssertEqual(line, 5)
            XCTAssertEqual(column, 10)
        } else {
            XCTFail("Expected invalidCharacter error")
        }
    }
    
    func testUnterminatedStringError() {
        let error = LexerError.unterminatedString(line: 3, column: 7)
        
        if case .unterminatedString(let line, let column) = error {
            XCTAssertEqual(line, 3)
            XCTAssertEqual(column, 7)
        } else {
            XCTFail("Expected unterminatedString error")
        }
    }
    
    func testInvalidEscapeSequenceError() {
        let error = LexerError.invalidEscapeSequence("\\z", line: 1, column: 15)
        
        if case .invalidEscapeSequence(let sequence, let line, let column) = error {
            XCTAssertEqual(sequence, "\\z")
            XCTAssertEqual(line, 1)
            XCTAssertEqual(column, 15)
        } else {
            XCTFail("Expected invalidEscapeSequence error")
        }
    }
    
    func testNumberLiteralErrors() {
        let intError = LexerError.invalidIntegerLiteral("123abc", line: 2, column: 5)
        let floatError = LexerError.invalidFloatLiteral("3.14.15", line: 4, column: 8)
        let rangeError = LexerError.numberOutOfRange("999999999999999999999", line: 6, column: 12)
        
        if case .invalidIntegerLiteral(let value, let line, let column) = intError {
            XCTAssertEqual(value, "123abc")
            XCTAssertEqual(line, 2)
            XCTAssertEqual(column, 5)
        } else {
            XCTFail("Expected invalidIntegerLiteral error")
        }
        
        if case .invalidFloatLiteral(let value, let line, let column) = floatError {
            XCTAssertEqual(value, "3.14.15")
            XCTAssertEqual(line, 4)
            XCTAssertEqual(column, 8)
        } else {
            XCTFail("Expected invalidFloatLiteral error")
        }
        
        if case .numberOutOfRange(let value, let line, let column) = rangeError {
            XCTAssertEqual(value, "999999999999999999999")
            XCTAssertEqual(line, 6)
            XCTAssertEqual(column, 12)
        } else {
            XCTFail("Expected numberOutOfRange error")
        }
    }
    
    func testCommentAndInputErrors() {
        let commentError = LexerError.unterminatedComment(line: 10, column: 1)
        let eofError = LexerError.unexpectedEndOfInput(line: 20, column: 5)
        let utf8Error = LexerError.invalidUTF8(line: 15, column: 3)
        
        if case .unterminatedComment(let line, let column) = commentError {
            XCTAssertEqual(line, 10)
            XCTAssertEqual(column, 1)
        } else {
            XCTFail("Expected unterminatedComment error")
        }
        
        if case .unexpectedEndOfInput(let line, let column) = eofError {
            XCTAssertEqual(line, 20)
            XCTAssertEqual(column, 5)
        } else {
            XCTFail("Expected unexpectedEndOfInput error")
        }
        
        if case .invalidUTF8(let line, let column) = utf8Error {
            XCTAssertEqual(line, 15)
            XCTAssertEqual(column, 3)
        } else {
            XCTFail("Expected invalidUTF8 error")
        }
    }
    
    // MARK: - Description Tests
    
    func testErrorDescriptions() {
        XCTAssertEqual(
            LexerError.invalidCharacter("@", line: 5, column: 10).description,
            "Invalid character '@' at 5:10"
        )
        
        XCTAssertEqual(
            LexerError.unterminatedString(line: 3, column: 7).description,
            "Unterminated string literal at 3:7"
        )
        
        XCTAssertEqual(
            LexerError.invalidEscapeSequence("\\z", line: 1, column: 15).description,
            "Invalid escape sequence '\\z' at 1:15"
        )
        
        XCTAssertEqual(
            LexerError.invalidIntegerLiteral("123abc", line: 2, column: 5).description,
            "Invalid integer literal '123abc' at 2:5"
        )
        
        XCTAssertEqual(
            LexerError.invalidFloatLiteral("3.14.15", line: 4, column: 8).description,
            "Invalid float literal '3.14.15' at 4:8"
        )
        
        XCTAssertEqual(
            LexerError.numberOutOfRange("999999999999999999999", line: 6, column: 12).description,
            "Number '999999999999999999999' out of range at 6:12"
        )
        
        XCTAssertEqual(
            LexerError.unterminatedComment(line: 10, column: 1).description,
            "Unterminated comment at 10:1"
        )
        
        XCTAssertEqual(
            LexerError.unexpectedEndOfInput(line: 20, column: 5).description,
            "Unexpected end of input at 20:5"
        )
        
        XCTAssertEqual(
            LexerError.invalidUTF8(line: 15, column: 3).description,
            "Invalid UTF-8 sequence at 15:3"
        )
    }
    
    // MARK: - ProtoParseError Conversion Tests
    
    func testToProtoParseErrorConversion() {
        let fileName = "test.proto"
        
        // Test invalid character conversion
        let invalidCharError = LexerError.invalidCharacter("@", line: 5, column: 10)
        let protoError1 = invalidCharError.toProtoParseError(file: fileName)
        
        if case .lexicalError(let message, let file, let line, let column) = protoError1 {
            XCTAssertEqual(message, "Invalid character '@'")
            XCTAssertEqual(file, fileName)
            XCTAssertEqual(line, 5)
            XCTAssertEqual(column, 10)
        } else {
            XCTFail("Expected lexicalError")
        }
        
        // Test unterminated string conversion
        let stringError = LexerError.unterminatedString(line: 3, column: 7)
        let protoError2 = stringError.toProtoParseError(file: fileName)
        
        if case .lexicalError(let message, let file, let line, let column) = protoError2 {
            XCTAssertEqual(message, "Unterminated string literal")
            XCTAssertEqual(file, fileName)
            XCTAssertEqual(line, 3)
            XCTAssertEqual(column, 7)
        } else {
            XCTFail("Expected lexicalError")
        }
        
        // Test escape sequence conversion
        let escapeError = LexerError.invalidEscapeSequence("\\z", line: 1, column: 15)
        let protoError3 = escapeError.toProtoParseError(file: fileName)
        
        if case .lexicalError(let message, let file, let line, let column) = protoError3 {
            XCTAssertEqual(message, "Invalid escape sequence '\\z'")
            XCTAssertEqual(file, fileName)
            XCTAssertEqual(line, 1)
            XCTAssertEqual(column, 15)
        } else {
            XCTFail("Expected lexicalError")
        }
    }
    
    func testAllErrorTypesConvertToProtoParseError() {
        let fileName = "example.proto"
        let errors: [LexerError] = [
            .invalidCharacter("@", line: 1, column: 1),
            .unterminatedString(line: 2, column: 2),
            .invalidEscapeSequence("\\z", line: 3, column: 3),
            .invalidIntegerLiteral("123abc", line: 4, column: 4),
            .invalidFloatLiteral("3.14.15", line: 5, column: 5),
            .numberOutOfRange("999999999999999999999", line: 6, column: 6),
            .unterminatedComment(line: 7, column: 7),
            .unexpectedEndOfInput(line: 8, column: 8),
            .invalidUTF8(line: 9, column: 9)
        ]
        
        for error in errors {
            let protoError = error.toProtoParseError(file: fileName)
            
            // Ensure all errors convert to lexicalError
            if case .lexicalError(let message, let file, let line, let column) = protoError {
                XCTAssertEqual(file, fileName)
                XCTAssertEqual(line, error.line)
                XCTAssertEqual(column, error.column)
                XCTAssertFalse(message.isEmpty)
            } else {
                XCTFail("Expected lexicalError for \(error)")
            }
        }
    }
    
    // MARK: - Position Information Tests
    
    func testPositionProperties() {
        let errors: [(LexerError, Int, Int)] = [
            (.invalidCharacter("@", line: 1, column: 5), 1, 5),
            (.unterminatedString(line: 10, column: 20), 10, 20),
            (.invalidEscapeSequence("\\z", line: 3, column: 15), 3, 15),
            (.invalidIntegerLiteral("123abc", line: 7, column: 8), 7, 8),
            (.invalidFloatLiteral("3.14.15", line: 2, column: 12), 2, 12),
            (.numberOutOfRange("999999999999999999999", line: 4, column: 6), 4, 6),
            (.unterminatedComment(line: 9, column: 1), 9, 1),
            (.unexpectedEndOfInput(line: 15, column: 30), 15, 30),
            (.invalidUTF8(line: 6, column: 18), 6, 18)
        ]
        
        for (error, expectedLine, expectedColumn) in errors {
            XCTAssertEqual(error.line, expectedLine, "Incorrect line for \(error)")
            XCTAssertEqual(error.column, expectedColumn, "Incorrect column for \(error)")
            
            let position = error.position
            XCTAssertEqual(position.line, expectedLine, "Incorrect position.line for \(error)")
            XCTAssertEqual(position.column, expectedColumn, "Incorrect position.column for \(error)")
        }
    }
    
    // MARK: - Convenience Constructor Tests
    
    func testConvenienceConstructors() {
        // Test invalidCharacter convenience constructor
        let charError = LexerError.invalidCharacter("@", at: 5, column: 10)
        XCTAssertEqual(charError.line, 5)
        XCTAssertEqual(charError.column, 10)
        
        // Test unterminatedString convenience constructor
        let stringError = LexerError.unterminatedString(at: 3, column: 7)
        XCTAssertEqual(stringError.line, 3)
        XCTAssertEqual(stringError.column, 7)
        
        // Test invalidEscapeSequence convenience constructor
        let escapeError = LexerError.invalidEscapeSequence("\\z", at: 1, column: 15)
        XCTAssertEqual(escapeError.line, 1)
        XCTAssertEqual(escapeError.column, 15)
        
        // Test invalidIntegerLiteral convenience constructor
        let intError = LexerError.invalidIntegerLiteral("123abc", at: 2, column: 5)
        XCTAssertEqual(intError.line, 2)
        XCTAssertEqual(intError.column, 5)
        
        // Test invalidFloatLiteral convenience constructor
        let floatError = LexerError.invalidFloatLiteral("3.14.15", at: 4, column: 8)
        XCTAssertEqual(floatError.line, 4)
        XCTAssertEqual(floatError.column, 8)
        
        // Test numberOutOfRange convenience constructor
        let rangeError = LexerError.numberOutOfRange("999999999999999999999", at: 6, column: 12)
        XCTAssertEqual(rangeError.line, 6)
        XCTAssertEqual(rangeError.column, 12)
        
        // Test unterminatedComment convenience constructor
        let commentError = LexerError.unterminatedComment(at: 10, column: 1)
        XCTAssertEqual(commentError.line, 10)
        XCTAssertEqual(commentError.column, 1)
        
        // Test unexpectedEndOfInput convenience constructor
        let eofError = LexerError.unexpectedEndOfInput(at: 20, column: 5)
        XCTAssertEqual(eofError.line, 20)
        XCTAssertEqual(eofError.column, 5)
        
        // Test invalidUTF8 convenience constructor
        let utf8Error = LexerError.invalidUTF8(at: 15, column: 3)
        XCTAssertEqual(utf8Error.line, 15)
        XCTAssertEqual(utf8Error.column, 3)
    }
    
    // MARK: - Error Protocol Conformance Tests
    
    func testErrorProtocolConformance() {
        let error: Error = LexerError.invalidCharacter("@", line: 5, column: 10)
        XCTAssertTrue(error is LexerError)
        
        // Test that it can be cast back
        if let lexerError = error as? LexerError {
            XCTAssertEqual(lexerError.line, 5)
            XCTAssertEqual(lexerError.column, 10)
        } else {
            XCTFail("Should be able to cast Error back to LexerError")
        }
    }
    
    // MARK: - CustomStringConvertible Tests
    
    func testCustomStringConvertible() {
        let error = LexerError.invalidCharacter("@", line: 5, column: 10)
        let description = String(describing: error)
        XCTAssertEqual(description, "Invalid character '@' at 5:10")
    }
}
