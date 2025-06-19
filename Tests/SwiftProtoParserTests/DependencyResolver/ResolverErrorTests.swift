import XCTest
import Foundation
@testable import SwiftProtoParser

final class ResolverErrorTests: XCTestCase {
  
  // MARK: - File System Error Tests
  
  func testFileNotFoundError() {
    let error = ResolverError.fileNotFound("/path/to/missing.proto")
    
    XCTAssertEqual(error.errorDescription, "Proto file not found: /path/to/missing.proto")
    XCTAssertEqual(error.failureReason, "Check the file path and ensure the file exists")
    XCTAssertNil(error.recoverySuggestion)
  }
  
  func testDirectoryNotFoundError() {
    let error = ResolverError.directoryNotFound("/missing/directory")
    
    XCTAssertEqual(error.errorDescription, "Directory not found: /missing/directory")
    XCTAssertNil(error.failureReason)
    XCTAssertNil(error.recoverySuggestion)
  }
  
  func testIOError() {
    let error = ResolverError.ioError("/path/file.proto", underlying: "Permission denied")
    
    XCTAssertEqual(error.errorDescription, "IO error reading file '/path/file.proto': Permission denied")
    XCTAssertNil(error.failureReason)
    XCTAssertNil(error.recoverySuggestion)
  }
  
  // MARK: - Import Resolution Error Tests
  
  func testImportNotFoundError() {
    let searchPaths = ["/path1", "/path2", "/path3"]
    let error = ResolverError.importNotFound("common.proto", searchPaths: searchPaths)
    
    XCTAssertEqual(error.errorDescription, "Import 'common.proto' not found in search paths: /path1, /path2, /path3")
    XCTAssertEqual(error.failureReason, "Make sure the imported file exists and import paths are correctly configured")
    XCTAssertEqual(error.recoverySuggestion, "Add the directory containing the imported file to your import paths")
  }
  
  func testImportNotFoundErrorWithEmptySearchPaths() {
    let error = ResolverError.importNotFound("common.proto", searchPaths: [])
    
    XCTAssertEqual(error.errorDescription, "Import 'common.proto' not found in search paths: ")
    XCTAssertEqual(error.failureReason, "Make sure the imported file exists and import paths are correctly configured")
    XCTAssertEqual(error.recoverySuggestion, "Provide import paths using the importPaths parameter")
  }
  
  func testCircularDependencyError() {
    let cycle = ["file1.proto", "file2.proto", "file3.proto", "file1.proto"]
    let error = ResolverError.circularDependency(cycle)
    
    XCTAssertEqual(error.errorDescription, "Circular dependency detected: file1.proto → file2.proto → file3.proto → file1.proto")
    XCTAssertEqual(error.failureReason, "Proto files cannot import each other in a circular manner")
    XCTAssertEqual(error.recoverySuggestion, "Restructure your proto files to remove circular imports")
  }
  
  func testCircularDependencyErrorWithSingleFile() {
    let cycle = ["self.proto"]
    let error = ResolverError.circularDependency(cycle)
    
    XCTAssertEqual(error.errorDescription, "Circular dependency detected: self.proto")
    XCTAssertEqual(error.failureReason, "Proto files cannot import each other in a circular manner")
    XCTAssertEqual(error.recoverySuggestion, "Restructure your proto files to remove circular imports")
  }
  
  func testCircularDependencyErrorWithEmptyArray() {
    let cycle: [String] = []
    let error = ResolverError.circularDependency(cycle)
    
    XCTAssertEqual(error.errorDescription, "Circular dependency detected: ")
    XCTAssertEqual(error.failureReason, "Proto files cannot import each other in a circular manner")
    XCTAssertEqual(error.recoverySuggestion, "Restructure your proto files to remove circular imports")
  }
  
  func testInvalidImportPathError() {
    let error = ResolverError.invalidImportPath("../../../invalid/path")
    
    XCTAssertEqual(error.errorDescription, "Invalid import path format: ../../../invalid/path")
    XCTAssertNil(error.failureReason)
    XCTAssertNil(error.recoverySuggestion)
  }
  
  // MARK: - Validation Error Tests
  
  func testInvalidSyntaxError() {
    let error = ResolverError.invalidSyntax("/path/old.proto", expected: "proto3")
    
    XCTAssertEqual(error.errorDescription, "Invalid syntax in file '/path/old.proto'. Expected: proto3")
    XCTAssertNil(error.failureReason)
    XCTAssertNil(error.recoverySuggestion)
  }
  
  func testMissingSyntaxError() {
    let error = ResolverError.missingSyntax("/path/nosyntax.proto")
    
    XCTAssertEqual(error.errorDescription, "Missing syntax declaration in file: /path/nosyntax.proto")
    XCTAssertNil(error.failureReason)
    XCTAssertNil(error.recoverySuggestion)
  }
  
  func testDuplicateFileError() {
    let paths = ["/path1/file.proto", "/path2/file.proto", "/path3/file.proto"]
    let error = ResolverError.duplicateFile("file.proto", paths: paths)
    
    XCTAssertEqual(error.errorDescription, "Duplicate file 'file.proto' found at: /path1/file.proto, /path2/file.proto, /path3/file.proto")
    XCTAssertNil(error.failureReason)
    XCTAssertNil(error.recoverySuggestion)
  }
  
  func testDuplicateFileErrorWithSinglePath() {
    let paths = ["/path/file.proto"]
    let error = ResolverError.duplicateFile("file.proto", paths: paths)
    
    XCTAssertEqual(error.errorDescription, "Duplicate file 'file.proto' found at: /path/file.proto")
    XCTAssertNil(error.failureReason)
    XCTAssertNil(error.recoverySuggestion)
  }
  
  func testDuplicateFileErrorWithEmptyPaths() {
    let paths: [String] = []
    let error = ResolverError.duplicateFile("file.proto", paths: paths)
    
    XCTAssertEqual(error.errorDescription, "Duplicate file 'file.proto' found at: ")
    XCTAssertNil(error.failureReason)
    XCTAssertNil(error.recoverySuggestion)
  }
  
  // MARK: - Configuration Error Tests
  
  func testNoImportPathsError() {
    let error = ResolverError.noImportPaths("/path/main.proto")
    
    XCTAssertEqual(error.errorDescription, "File '/path/main.proto' has imports but no import paths provided")
    XCTAssertNil(error.failureReason)
    XCTAssertEqual(error.recoverySuggestion, "Provide import paths where dependent proto files can be found")
  }
  
  func testInvalidImportPathWithReasonError() {
    let error = ResolverError.invalidImportPathWithReason("/invalid/path", reason: "Directory does not exist")
    
    XCTAssertEqual(error.errorDescription, "Invalid import path '/invalid/path': Directory does not exist")
    XCTAssertNil(error.failureReason)
    XCTAssertNil(error.recoverySuggestion)
  }
  
  // MARK: - Equality Tests
  
  func testErrorEquality() {
    // Test same error types with same parameters
    let error1 = ResolverError.fileNotFound("/path/file.proto")
    let error2 = ResolverError.fileNotFound("/path/file.proto")
    XCTAssertEqual(error1, error2)
    
    // Test same error types with different parameters
    let error3 = ResolverError.fileNotFound("/different/path.proto")
    XCTAssertNotEqual(error1, error3)
    
    // Test different error types
    let error4 = ResolverError.directoryNotFound("/path/file.proto")
    XCTAssertNotEqual(error1, error4)
  }
  
  func testImportNotFoundEquality() {
    let paths1 = ["/path1", "/path2"]
    let paths2 = ["/path1", "/path2"]
    let paths3 = ["/path1", "/path3"]
    
    let error1 = ResolverError.importNotFound("file.proto", searchPaths: paths1)
    let error2 = ResolverError.importNotFound("file.proto", searchPaths: paths2)
    let error3 = ResolverError.importNotFound("file.proto", searchPaths: paths3)
    let error4 = ResolverError.importNotFound("other.proto", searchPaths: paths1)
    
    XCTAssertEqual(error1, error2)
    XCTAssertNotEqual(error1, error3)
    XCTAssertNotEqual(error1, error4)
  }
  
  func testCircularDependencyEquality() {
    let cycle1 = ["a.proto", "b.proto", "c.proto"]
    let cycle2 = ["a.proto", "b.proto", "c.proto"]
    let cycle3 = ["a.proto", "b.proto", "d.proto"]
    
    let error1 = ResolverError.circularDependency(cycle1)
    let error2 = ResolverError.circularDependency(cycle2)
    let error3 = ResolverError.circularDependency(cycle3)
    
    XCTAssertEqual(error1, error2)
    XCTAssertNotEqual(error1, error3)
  }
  
  func testIOErrorEquality() {
    let error1 = ResolverError.ioError("/path/file.proto", underlying: "Permission denied")
    let error2 = ResolverError.ioError("/path/file.proto", underlying: "Permission denied")
    let error3 = ResolverError.ioError("/path/file.proto", underlying: "File corrupted")
    let error4 = ResolverError.ioError("/other/file.proto", underlying: "Permission denied")
    
    XCTAssertEqual(error1, error2)
    XCTAssertNotEqual(error1, error3)
    XCTAssertNotEqual(error1, error4)
  }
  
  func testDuplicateFileEquality() {
    let paths1 = ["/path1/file.proto", "/path2/file.proto"]
    let paths2 = ["/path1/file.proto", "/path2/file.proto"]
    let paths3 = ["/path1/file.proto", "/path3/file.proto"]
    
    let error1 = ResolverError.duplicateFile("file.proto", paths: paths1)
    let error2 = ResolverError.duplicateFile("file.proto", paths: paths2)
    let error3 = ResolverError.duplicateFile("file.proto", paths: paths3)
    let error4 = ResolverError.duplicateFile("other.proto", paths: paths1)
    
    XCTAssertEqual(error1, error2)
    XCTAssertNotEqual(error1, error3)
    XCTAssertNotEqual(error1, error4)
  }
  
  func testInvalidSyntaxEquality() {
    let error1 = ResolverError.invalidSyntax("/path/file.proto", expected: "proto3")
    let error2 = ResolverError.invalidSyntax("/path/file.proto", expected: "proto3")
    let error3 = ResolverError.invalidSyntax("/path/file.proto", expected: "proto2")
    let error4 = ResolverError.invalidSyntax("/other/file.proto", expected: "proto3")
    
    XCTAssertEqual(error1, error2)
    XCTAssertNotEqual(error1, error3)
    XCTAssertNotEqual(error1, error4)
  }
  
  func testInvalidImportPathWithReasonEquality() {
    let error1 = ResolverError.invalidImportPathWithReason("/path", reason: "Does not exist")
    let error2 = ResolverError.invalidImportPathWithReason("/path", reason: "Does not exist")
    let error3 = ResolverError.invalidImportPathWithReason("/path", reason: "Permission denied")
    let error4 = ResolverError.invalidImportPathWithReason("/other", reason: "Does not exist")
    
    XCTAssertEqual(error1, error2)
    XCTAssertNotEqual(error1, error3)
    XCTAssertNotEqual(error1, error4)
  }
  
  func testSingleParameterErrorsEquality() {
    // Test errors with single string parameters
    XCTAssertEqual(
      ResolverError.fileNotFound("/path"),
      ResolverError.fileNotFound("/path")
    )
    XCTAssertNotEqual(
      ResolverError.fileNotFound("/path1"),
      ResolverError.fileNotFound("/path2")
    )
    
    XCTAssertEqual(
      ResolverError.directoryNotFound("/dir"),
      ResolverError.directoryNotFound("/dir")
    )
    XCTAssertNotEqual(
      ResolverError.directoryNotFound("/dir1"),
      ResolverError.directoryNotFound("/dir2")
    )
    
    XCTAssertEqual(
      ResolverError.invalidImportPath("/path"),
      ResolverError.invalidImportPath("/path")
    )
    XCTAssertNotEqual(
      ResolverError.invalidImportPath("/path1"),
      ResolverError.invalidImportPath("/path2")
    )
    
    XCTAssertEqual(
      ResolverError.missingSyntax("/file"),
      ResolverError.missingSyntax("/file")
    )
    XCTAssertNotEqual(
      ResolverError.missingSyntax("/file1"),
      ResolverError.missingSyntax("/file2")
    )
    
    XCTAssertEqual(
      ResolverError.noImportPaths("/file"),
      ResolverError.noImportPaths("/file")
    )
    XCTAssertNotEqual(
      ResolverError.noImportPaths("/file1"),
      ResolverError.noImportPaths("/file2")
    )
  }
  
  // MARK: - Error Protocol Conformance Tests
  
  func testErrorProtocolConformance() {
    let errors: [ResolverError] = [
      .fileNotFound("/path"),
      .directoryNotFound("/dir"),
      .ioError("/file", underlying: "reason"),
      .importNotFound("import", searchPaths: ["/path"]),
      .circularDependency(["a", "b"]),
      .invalidImportPath("/path"),
      .invalidSyntax("/file", expected: "proto3"),
      .missingSyntax("/file"),
      .duplicateFile("file", paths: ["/path1", "/path2"]),
      .noImportPaths("/file"),
      .invalidImportPathWithReason("/path", reason: "reason")
    ]
    
    for error in errors {
      // Test that errorDescription is not nil or empty
      XCTAssertNotNil(error.errorDescription)
      XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
      
      // Test that error can be converted to NSError
      let nsError = error as NSError
      XCTAssertNotNil(nsError.localizedDescription)
      
      // Test that error description contains meaningful content
      let description = error.errorDescription ?? ""
      XCTAssertFalse(description.isEmpty)
      XCTAssertTrue(description.count > 5) // Basic sanity check
    }
  }
  
  // MARK: - String Representation Tests
  
  func testErrorDescriptionContent() {
    // Test that error descriptions contain relevant information
    let fileError = ResolverError.fileNotFound("/path/to/file.proto")
    XCTAssertTrue(fileError.errorDescription?.contains("file.proto") ?? false)
    XCTAssertTrue(fileError.errorDescription?.contains("not found") ?? false)
    
    let importError = ResolverError.importNotFound("common.proto", searchPaths: ["/src", "/lib"])
    XCTAssertTrue(importError.errorDescription?.contains("common.proto") ?? false)
    XCTAssertTrue(importError.errorDescription?.contains("/src") ?? false)
    XCTAssertTrue(importError.errorDescription?.contains("/lib") ?? false)
    
    let circularError = ResolverError.circularDependency(["a.proto", "b.proto", "a.proto"])
    XCTAssertTrue(circularError.errorDescription?.contains("a.proto") ?? false)
    XCTAssertTrue(circularError.errorDescription?.contains("b.proto") ?? false)
    XCTAssertTrue(circularError.errorDescription?.contains("→") ?? false)
  }
  
  // MARK: - Edge Cases Tests
  
  func testEmptyStringParameters() {
    // Test behavior with empty string parameters
    let emptyPathError = ResolverError.fileNotFound("")
    XCTAssertEqual(emptyPathError.errorDescription, "Proto file not found: ")
    
    let emptyImportError = ResolverError.importNotFound("", searchPaths: [])
    XCTAssertEqual(emptyImportError.errorDescription, "Import '' not found in search paths: ")
    
    let emptyIOError = ResolverError.ioError("", underlying: "")
    XCTAssertEqual(emptyIOError.errorDescription, "IO error reading file '': ")
  }
  
  func testSpecialCharactersInPaths() {
    // Test with paths containing special characters
    let specialPath = "/path with spaces/file-name_2.proto"
    let error = ResolverError.fileNotFound(specialPath)
    XCTAssertTrue(error.errorDescription?.contains(specialPath) ?? false)
    
    let unicodePath = "/пуć/файл.proto"
    let unicodeError = ResolverError.directoryNotFound(unicodePath)
    XCTAssertTrue(unicodeError.errorDescription?.contains(unicodePath) ?? false)
  }
  
  func testLongErrorMessages() {
    // Test with very long paths and messages
    let longPath = String(repeating: "/very_long_directory_name", count: 10) + "/file.proto"
    let error = ResolverError.fileNotFound(longPath)
    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains(longPath) ?? false)
    
    let manyPaths = Array(repeating: "/import/path", count: 50).enumerated().map { "/import/path\($0.offset)" }
    let importError = ResolverError.importNotFound("file.proto", searchPaths: manyPaths)
    XCTAssertNotNil(importError.errorDescription)
  }
}
