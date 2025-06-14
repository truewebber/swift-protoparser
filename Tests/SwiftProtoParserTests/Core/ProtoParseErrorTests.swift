import XCTest
@testable import SwiftProtoParser

// MARK: - ProtoParseErrorTests

final class ProtoParseErrorTests: XCTestCase {
    
    // MARK: - File System Errors Tests
    
    func testFileNotFoundError() {
        let path = "/path/to/nonexistent.proto"
        let error = ProtoParseError.fileNotFound(path)
        
        XCTAssertEqual(error.errorDescription, "File not found: \(path)")
        XCTAssertEqual(error.failureReason, "The specified Protocol Buffers file could not be found.")
        XCTAssertEqual(error.recoverySuggestion, "Check that the file path is correct and the file exists.")
        XCTAssertEqual(error.description, "File not found: \(path)")
    }
    
    func testFileNotFoundConvenienceMethod() {
        let path = "/path/to/file.proto"
        let error = ProtoParseError.fileNotFound(at: path)
        
        if case .fileNotFound(let errorPath) = error {
            XCTAssertEqual(errorPath, path)
        } else {
            XCTFail("Expected fileNotFound error")
        }
    }
    
    func testIOError() {
        let underlyingError = NSError(domain: "test", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test IO error"])
        let error = ProtoParseError.ioError(underlying: underlyingError)
        
        XCTAssertEqual(error.errorDescription, "I/O error: Test IO error")
        XCTAssertEqual(error.failureReason, "An I/O operation failed while processing the file.")
        XCTAssertEqual(error.recoverySuggestion, "Ensure the file is readable and not corrupted.")
        XCTAssertEqual(error.description, "I/O error: Test IO error")
    }
    
    // MARK: - Dependency Resolution Errors Tests
    
    func testDependencyResolutionError() {
        let message = "Import not found"
        let importPath = "common/base.proto"
        let error = ProtoParseError.dependencyResolutionError(message: message, importPath: importPath)
        
        XCTAssertEqual(error.errorDescription, "Dependency resolution failed for '\(importPath)': \(message)")
        XCTAssertEqual(error.failureReason, "Failed to resolve imported dependencies.")
        XCTAssertEqual(error.recoverySuggestion, "Verify that all imported files are available in the import paths.")
    }
    
    func testDependencyResolutionConvenienceMethod() {
        let message = "File not accessible"
        let importPath = "shared/types.proto"
        let error = ProtoParseError.dependencyResolution(message, importPath: importPath)
        
        if case .dependencyResolutionError(let errorMessage, let errorImportPath) = error {
            XCTAssertEqual(errorMessage, message)
            XCTAssertEqual(errorImportPath, importPath)
        } else {
            XCTFail("Expected dependencyResolutionError")
        }
    }
    
    func testCircularDependencyError() {
        let chain = ["a.proto", "b.proto", "c.proto", "a.proto"]
        let error = ProtoParseError.circularDependency(chain)
        
        XCTAssertEqual(error.errorDescription, "Circular dependency detected: a.proto → b.proto → c.proto → a.proto")
        XCTAssertEqual(error.failureReason, "Import dependencies form a circular reference.")
        XCTAssertEqual(error.recoverySuggestion, "Remove circular imports by restructuring the dependency chain.")
    }
    
    // MARK: - Parsing Errors Tests
    
    func testLexicalError() {
        let message = "Unexpected character '@'"
        let file = "test.proto"
        let line = 10
        let column = 5
        let error = ProtoParseError.lexicalError(message: message, file: file, line: line, column: column)
        
        XCTAssertEqual(error.errorDescription, "Lexical error in \(file) at \(line):\(column): \(message)")
        XCTAssertEqual(error.failureReason, "Invalid token or character sequence encountered.")
        XCTAssertEqual(error.recoverySuggestion, "Check for invalid characters or malformed tokens in the file.")
    }
    
    func testLexicalConvenienceMethod() {
        let message = "Invalid token"
        let file = "example.proto"
        let line = 15
        let column = 20
        let error = ProtoParseError.lexical(message, in: file, at: line, column: column)
        
        if case .lexicalError(let errorMessage, let errorFile, let errorLine, let errorColumn) = error {
            XCTAssertEqual(errorMessage, message)
            XCTAssertEqual(errorFile, file)
            XCTAssertEqual(errorLine, line)
            XCTAssertEqual(errorColumn, column)
        } else {
            XCTFail("Expected lexicalError")
        }
    }
    
    func testSyntaxError() {
        let message = "Expected ';' after field declaration"
        let file = "service.proto"
        let line = 25
        let column = 15
        let error = ProtoParseError.syntaxError(message: message, file: file, line: line, column: column)
        
        XCTAssertEqual(error.errorDescription, "Syntax error in \(file) at \(line):\(column): \(message)")
        XCTAssertEqual(error.failureReason, "The file does not conform to Protocol Buffers syntax rules.")
        XCTAssertEqual(error.recoverySuggestion, "Verify the file follows valid Protocol Buffers 3 syntax.")
    }
    
    func testSyntaxConvenienceMethod() {
        let message = "Missing closing brace"
        let file = "message.proto"
        let line = 8
        let column = 1
        let error = ProtoParseError.syntax(message, in: file, at: line, column: column)
        
        if case .syntaxError(let errorMessage, let errorFile, let errorLine, let errorColumn) = error {
            XCTAssertEqual(errorMessage, message)
            XCTAssertEqual(errorFile, file)
            XCTAssertEqual(errorLine, line)
            XCTAssertEqual(errorColumn, column)
        } else {
            XCTFail("Expected syntaxError")
        }
    }
    
    func testSemanticError() {
        let message = "Duplicate field number 1"
        let context = "Message 'User'"
        let error = ProtoParseError.semanticError(message: message, context: context)
        
        XCTAssertEqual(error.errorDescription, "Semantic error in \(context): \(message)")
        XCTAssertEqual(error.failureReason, "The file contains semantically invalid constructs.")
        XCTAssertEqual(error.recoverySuggestion, "Review field types, message definitions, and naming conventions.")
    }
    
    func testSemanticConvenienceMethod() {
        let message = "Invalid field type"
        let context = "Service 'UserService'"
        let error = ProtoParseError.semantic(message, context: context)
        
        if case .semanticError(let errorMessage, let errorContext) = error {
            XCTAssertEqual(errorMessage, message)
            XCTAssertEqual(errorContext, context)
        } else {
            XCTFail("Expected semanticError")
        }
    }
    
    // MARK: - Internal Errors Tests
    
    func testInternalError() {
        let message = "Parser state corruption detected"
        let error = ProtoParseError.internalError(message: message)
        
        XCTAssertEqual(error.errorDescription, "Internal parser error: \(message)")
        XCTAssertEqual(error.failureReason, "An unexpected internal error occurred.")
        XCTAssertEqual(error.recoverySuggestion, "This may be a bug in SwiftProtoParser. Please report it.")
    }
    
    // MARK: - CustomStringConvertible Tests
    
    func testCustomStringConvertible() {
        let error = ProtoParseError.fileNotFound("test.proto")
        let stringDescription = String(describing: error)
        XCTAssertEqual(stringDescription, "File not found: test.proto")
    }
    
    // MARK: - Error Protocol Tests
    
    func testErrorProtocolConformance() {
        let error: Error = ProtoParseError.internalError(message: "test")
        XCTAssertTrue(error is ProtoParseError)
        
        // Test that it can be cast back
        if let protoError = error as? ProtoParseError {
            if case .internalError(let message) = protoError {
                XCTAssertEqual(message, "test")
            } else {
                XCTFail("Expected internalError case")
            }
        } else {
            XCTFail("Failed to cast Error back to ProtoParseError")
        }
    }
    
    // MARK: - LocalizedError Full Coverage Tests
    
    func testAllErrorTypesHaveDescriptions() {
        let errors: [ProtoParseError] = [
            .fileNotFound("test.proto"),
            .ioError(underlying: NSError(domain: "test", code: 1)),
            .dependencyResolutionError(message: "test", importPath: "test.proto"),
            .circularDependency(["a.proto", "b.proto"]),
            .lexicalError(message: "test", file: "test.proto", line: 1, column: 1),
            .syntaxError(message: "test", file: "test.proto", line: 1, column: 1),
            .semanticError(message: "test", context: "test"),
            .internalError(message: "test")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error description should not be nil for \(error)")
            XCTAssertNotNil(error.failureReason, "Failure reason should not be nil for \(error)")
            XCTAssertNotNil(error.recoverySuggestion, "Recovery suggestion should not be nil for \(error)")
            XCTAssertFalse(error.description.isEmpty, "Description should not be empty for \(error)")
        }
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptyStringsHandling() {
        let error = ProtoParseError.fileNotFound("")
        XCTAssertEqual(error.errorDescription, "File not found: ")
    }
    
    func testEmptyCircularDependencyChain() {
        let error = ProtoParseError.circularDependency([])
        XCTAssertEqual(error.errorDescription, "Circular dependency detected: ")
    }
    
    func testSingleItemCircularDependencyChain() {
        let error = ProtoParseError.circularDependency(["self.proto"])
        XCTAssertEqual(error.errorDescription, "Circular dependency detected: self.proto")
    }
}
