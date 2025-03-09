import XCTest

@testable import SwiftProtoParser

/// Tests for Proto3 syntax validation rules.
final class SyntaxValidationTests: XCTestCase {
  // Test validator
  private var validator: ValidatorV2!

  override func setUp() {
    super.setUp()
    validator = ValidatorV2()
  }

  override func tearDown() {
    validator = nil
    super.tearDown()
  }

  // MARK: - Basic Syntax Tests

  func testValidSyntaxVersion() throws {
    // Create a file with valid proto3 syntax
    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      syntax: "proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: []
    )

    // This should not throw
    XCTAssertNoThrow(try validator.validate(file))
  }

  func testInvalidSyntaxVersion() throws {
    // Test with proto2 (invalid for our validator)
    let proto2File = FileNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      syntax: "proto2",
      package: "test",
      imports: [],
      options: [],
      definitions: []
    )

    // This should throw an invalidSyntaxVersion error
    XCTAssertThrowsError(try validator.validate(proto2File)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      switch validationError {
      case .invalidSyntaxVersion(let version):
        XCTAssertEqual(version, "proto2")
      default:
        XCTFail("Expected invalidSyntaxVersion error, got \(validationError)")
      }
    }

    // Test with empty syntax (invalid)
    let emptySyntaxFile = FileNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      syntax: "",
      package: "test",
      imports: [],
      options: [],
      definitions: []
    )

    XCTAssertThrowsError(try validator.validate(emptySyntaxFile)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      switch validationError {
      case .invalidSyntaxVersion(let version):
        XCTAssertEqual(version, "")
      default:
        XCTFail("Expected invalidSyntaxVersion error, got \(validationError)")
      }
    }

    // Test with incorrect case (Proto3 instead of proto3)
    let incorrectCaseFile = FileNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      syntax: "Proto3",
      package: "test",
      imports: [],
      options: [],
      definitions: []
    )

    XCTAssertThrowsError(try validator.validate(incorrectCaseFile)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      switch validationError {
      case .invalidSyntaxVersion(let version):
        XCTAssertEqual(version, "Proto3")
      default:
        XCTFail("Expected invalidSyntaxVersion error, got \(validationError)")
      }
    }

    // Test with whitespace (invalid)
    let whitespaceFile = FileNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      syntax: " proto3 ",
      package: "test",
      imports: [],
      options: [],
      definitions: []
    )

    XCTAssertThrowsError(try validator.validate(whitespaceFile)) { error in
      guard let validationError = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      switch validationError {
      case .invalidSyntaxVersion(let version):
        XCTAssertEqual(version, " proto3 ")
      default:
        XCTFail("Expected invalidSyntaxVersion error, got \(validationError)")
      }
    }
  }

  // Note: The following tests would require parser-level validation or modifications to the FileNode structure
  // to properly test syntax declaration position. Since we're working with the AST directly, we can't test
  // these aspects directly. They would be better tested in parser tests.

  // func testSyntaxMustBeFirstDeclaration() { ... }
  // func testSyntaxCannotBeRepeated() { ... }
}
