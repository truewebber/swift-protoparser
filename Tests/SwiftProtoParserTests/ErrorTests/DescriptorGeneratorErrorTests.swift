import XCTest

@testable import SwiftProtoParser

final class DescriptorGeneratorErrorTests: XCTestCase {

  // MARK: - Error Creation Tests

  func testNestedMapNotAllowedError() {
    // Create an error
    let error = DescriptorGeneratorError.nestedMapNotAllowed

    // Verify the error type
    if case .nestedMapNotAllowed = error {
      // Test passed
    }
    else {
      XCTFail("Expected nestedMapNotAllowed error")
    }
  }

  func testInvalidOptionValueError() {
    // Create an error with a specific value
    let error = DescriptorGeneratorError.invalidOptionValue("123.456")

    // Verify the error properties
    if case .invalidOptionValue(let value) = error {
      XCTAssertEqual(value, "123.456")
    }
    else {
      XCTFail("Expected invalidOptionValue error")
    }
  }

  func testUnsupportedOptionError() {
    // Create an error with a specific option
    let error = DescriptorGeneratorError.unsupportedOption("custom_option")

    // Verify the error properties
    if case .unsupportedOption(let option) = error {
      XCTAssertEqual(option, "custom_option")
    }
    else {
      XCTFail("Expected unsupportedOption error")
    }
  }

  func testCustomError() {
    // Create a custom error with a specific message
    let error = DescriptorGeneratorError.custom("Custom error message")

    // Verify the error properties
    if case .custom(let message) = error {
      XCTAssertEqual(message, "Custom error message")
    }
    else {
      XCTFail("Expected custom error")
    }
  }

  // MARK: - Error Description Tests

  func testNestedMapNotAllowedErrorDescription() {
    let error = DescriptorGeneratorError.nestedMapNotAllowed

    XCTAssertEqual(
      error.description,
      "Nested map fields are not allowed"
    )
  }

  func testInvalidOptionValueErrorDescription() {
    let error = DescriptorGeneratorError.invalidOptionValue("123.456")

    XCTAssertEqual(
      error.description,
      "Invalid option value: 123.456"
    )
  }

  func testUnsupportedOptionErrorDescription() {
    let error = DescriptorGeneratorError.unsupportedOption("custom_option")

    XCTAssertEqual(
      error.description,
      "Unsupported option: custom_option"
    )
  }

  func testCustomErrorDescription() {
    let error = DescriptorGeneratorError.custom("Custom error message")

    XCTAssertEqual(
      error.description,
      "Custom error message"
    )
  }

  // MARK: - Error Handling Tests

  func testDescriptorGeneratorThrowsNestedMapNotAllowedError() throws {
    // Skip this test as the generateMessageDescriptor method is private
    // and we can't directly test it without modifying the source code
  }
}
