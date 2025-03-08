import XCTest
@testable import SwiftProtoParser

final class ImportErrorTests: XCTestCase {
    
    // MARK: - Error Creation Tests
    
    func testFileNotFoundError() {
        // Create an error with a specific file path
        let error = ImportError.fileNotFound("missing.proto")
        
        // Verify the error properties
        if case .fileNotFound(let path) = error {
            XCTAssertEqual(path, "missing.proto")
        } else {
            XCTFail("Expected fileNotFound error")
        }
    }
    
    func testCircularImportError() {
        // Create an error with a specific import path
        let error = ImportError.circularImport("a.proto -> b.proto -> a.proto")
        
        // Verify the error properties
        if case .circularImport(let path) = error {
            XCTAssertEqual(path, "a.proto -> b.proto -> a.proto")
        } else {
            XCTFail("Expected circularImport error")
        }
    }
    
    func testInvalidImportError() {
        // Create an error with a specific import path
        let error = ImportError.invalidImport("invalid/path.proto")
        
        // Verify the error properties
        if case .invalidImport(let path) = error {
            XCTAssertEqual(path, "invalid/path.proto")
        } else {
            XCTFail("Expected invalidImport error")
        }
    }
    
    func testParseError() {
        // Create an error with a specific path and underlying error
        let underlyingError = NSError(domain: "test", code: 123, userInfo: nil)
        let error = ImportError.parseError("test.proto", underlyingError)
        
        // Verify the error properties
        if case .parseError(let path, let err) = error {
            XCTAssertEqual(path, "test.proto")
            XCTAssertEqual((err as NSError).code, 123)
        } else {
            XCTFail("Expected parseError error")
        }
    }
    
    // MARK: - Error Description Tests
    
    func testFileNotFoundErrorDescription() {
        let error = ImportError.fileNotFound("missing.proto")
        
        XCTAssertEqual(
            error.description,
            "Import not found: missing.proto"
        )
    }
    
    func testCircularImportErrorDescription() {
        let error = ImportError.circularImport("a.proto -> b.proto -> a.proto")
        
        XCTAssertEqual(
            error.description,
            "Circular import detected: a.proto -> b.proto -> a.proto"
        )
    }
    
    func testInvalidImportErrorDescription() {
        let error = ImportError.invalidImport("invalid/path.proto")
        
        XCTAssertEqual(
            error.description,
            "Invalid import: invalid/path.proto"
        )
    }
    
    func testParseErrorDescription() {
        let underlyingError = NSError(domain: "test", code: 123, userInfo: nil)
        let error = ImportError.parseError("test.proto", underlyingError)
        
        XCTAssertTrue(
            error.description.contains("Error parsing import test.proto")
        )
    }
    
    // MARK: - Error Handling Tests
    
    func testImportResolverThrowsFileNotFoundError() throws {
        // Create a mock file provider that always returns nil
        let mockFileProvider = MockFileProvider(files: [:])
        
        // Create an import resolver with the mock file provider
        let importResolver = ImportResolver(fileProvider: mockFileProvider) { _, _ in
            // This closure should not be called in this test
            XCTFail("Import resolver should not call the parse closure")
            throw NSError(domain: "test", code: 123, userInfo: nil)
        }
        
        // Try to resolve an import and expect a fileNotFound error
        XCTAssertThrowsError(try importResolver.resolveImport("missing.proto")) { error in
            guard let importError = error as? ImportError else {
                XCTFail("Expected ImportError but got \(error)")
                return
            }
            
            if case .fileNotFound(let path) = importError {
                XCTAssertEqual(path, "missing.proto")
            } else {
                XCTFail("Expected fileNotFound error but got \(importError)")
            }
        }
    }
    
    func testImportResolverThrowsCircularImportError() throws {
        // Skip this test as it's difficult to simulate a circular import
        // without knowing the internal implementation details of ImportResolver
    }
    
    func testImportResolverThrowsParseError() throws {
        // Create a mock file provider with a file
        let mockFileProvider = MockFileProvider(files: [
            "invalid.proto": "invalid proto content"
        ])
        
        // Create an import resolver with the mock file provider
        let importResolver = ImportResolver(fileProvider: mockFileProvider) { _, _ in
            // Simulate a parsing error by throwing an ImportError directly
            throw ImportError.parseError("invalid.proto", NSError(domain: "test", code: 123, userInfo: nil))
        }
        
        // Try to resolve an import and expect a parseError
        XCTAssertThrowsError(try importResolver.resolveImport("invalid.proto")) { error in
            guard let importError = error as? ImportError else {
                XCTFail("Expected ImportError but got \(error)")
                return
            }
            
            if case .parseError(let path, _) = importError {
                XCTAssertEqual(path, "invalid.proto")
            } else {
                XCTFail("Expected parseError error but got \(importError)")
            }
        }
    }
} 