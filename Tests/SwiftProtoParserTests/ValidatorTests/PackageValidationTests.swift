import XCTest

@testable import SwiftProtoParser

/// Tests for Proto3 package validation rules
final class PackageValidationTests: XCTestCase {
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

  // MARK: - Package Name Format Tests

  func testValidPackageNames() throws {
    // Test valid package name formats
    let validPackages = [
      "test",
      "com.example.test",
      "com.example.test.subpackage",
      "a.b.c.d.e.f.g",
      "package_with_underscore",
      "package123.with456.numbers789",
      "a",  // Single letter
      "a.b",  // Short package
      "a_1.b_2.c_3",  // Mix of letters, numbers, and underscores
    ]

    for packageName in validPackages {
      let file = FileNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        syntax: "proto3",
        package: packageName,
        imports: [],
        options: [],
        definitions: []
      )

      // This should not throw
      XCTAssertNoThrow(
        try validator.validate(file), "Package name '\(packageName)' should be valid")
    }
  }

  func testInvalidPackageNames() throws {
    // Test invalid package name formats
    let invalidPackages = [
      "Test",  // Uppercase first letter
      "com.Example.test",  // Uppercase in the middle
      "com.example.Test",  // Uppercase in the last segment
      "com.example.",  // Trailing dot
      ".com.example",  // Leading dot
      "com..example",  // Double dot
      "com.example..test",  // Double dot in the middle
      "com.example test",  // Space
      "com.example-test",  // Hyphen
      "com.example+test",  // Plus sign
      "com.example*test",  // Asterisk
      "com.example/test",  // Slash
      "com.example\\test",  // Backslash
      "com.example@test",  // At sign
      "com.example#test",  // Hash
      "com.example$test",  // Dollar sign
      "com.example%test",  // Percent
      "com.example^test",  // Caret
      "com.example&test",  // Ampersand
      "com.example(test",  // Opening parenthesis
      "com.example)test",  // Closing parenthesis
      "com.example=test",  // Equals sign
      "com.example!test",  // Exclamation mark
      "com.example?test",  // Question mark
      "com.example:test",  // Colon
      "com.example;test",  // Semicolon
      "com.example,test",  // Comma
      "1test",  // Starting with a number
      "1.test",  // Segment starting with a number
      "test.1",  // Segment that is just a number
      "_test",  // Starting with underscore
      "test._subpackage",  // Segment starting with underscore
      "com.example._test",  // Segment starting with underscore
    ]

    for packageName in invalidPackages {
      let file = FileNode(
        location: SourceLocation(line: 1, column: 1),
        leadingComments: [],
        syntax: "proto3",
        package: packageName,
        imports: [],
        options: [],
        definitions: []
      )

      // This should throw an invalidPackageName error
      XCTAssertThrowsError(
        try validator.validate(file), "Package name '\(packageName)' should be invalid"
      ) { error in
        guard let validationError = error as? ValidationError else {
          XCTFail("Expected ValidationError for package '\(packageName)'")
          return
        }

        switch validationError {
        case .invalidPackageName(let name):
          XCTAssertEqual(name, packageName)
        default:
          XCTFail("Expected invalidPackageName error for '\(packageName)', got \(validationError)")
        }
      }
    }
  }

  func testPackageNameLength() throws {
    // Test very long package name (should be valid, but might have implementation limits)
    let longSegment = String(repeating: "a", count: 100)
    let longPackageName = "\(longSegment).\(longSegment).\(longSegment)"

    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      syntax: "proto3",
      package: longPackageName,
      imports: [],
      options: [],
      definitions: []
    )

    // This should not throw, as Proto3 doesn't specify a maximum package name length
    // However, implementations might have practical limits
    XCTAssertNoThrow(try validator.validate(file), "Long package name should be valid")
  }

  func testNoPackage() throws {
    // Test with no package (should be valid)
    let file = FileNode(
      location: SourceLocation(line: 1, column: 1),
      leadingComments: [],
      syntax: "proto3",
      package: nil,
      imports: [],
      options: [],
      definitions: []
    )

    // This should not throw
    XCTAssertNoThrow(try validator.validate(file), "Nil package should be valid")
  }

  // Note: The following tests would require parser-level validation or modifications to the FileNode structure
  // to properly test package declaration position. Since we're working with the AST directly, we can't test
  // these aspects directly. They would be better tested in parser tests.

  // func testPackageDeclarationPosition() { ... }
  // func testDuplicatePackageDeclaration() { ... }
}
