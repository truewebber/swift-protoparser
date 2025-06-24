import XCTest

@testable import SwiftProtoParser

class DescriptorErrorTests: XCTestCase {

  func testConversionFailedError() {
    let error = DescriptorError.conversionFailed(reason: "test reason")
    XCTAssertEqual(error.errorDescription, "Descriptor conversion failed: test reason")
  }

  func testMissingRequiredFieldError() {
    let error = DescriptorError.missingRequiredField(field: "name", in: "MessageNode")
    XCTAssertEqual(error.errorDescription, "Missing required field 'name' in MessageNode")
  }

  func testInvalidFieldTypeError() {
    let error = DescriptorError.invalidFieldType(type: "unknown", context: "FieldNode")
    XCTAssertEqual(error.errorDescription, "Invalid field type 'unknown' in FieldNode")
  }

  func testDuplicateElementError() {
    let error = DescriptorError.duplicateElement(name: "TestMessage", type: "message")
    XCTAssertEqual(error.errorDescription, "Duplicate message 'TestMessage' found during conversion")
  }

  func testUnsupportedFeatureError() {
    let error = DescriptorError.unsupportedFeature(feature: "groups", context: "proto3")
    XCTAssertEqual(error.errorDescription, "Unsupported feature 'groups' in proto3")
  }

  func testInternalError() {
    let error = DescriptorError.internalError(message: "unexpected state")
    XCTAssertEqual(error.errorDescription, "Internal descriptor builder error: unexpected state")
  }

  // MARK: - Convenience Methods Tests

  func testConversionFailedConvenience() {
    let error = DescriptorError.conversionFailed("test")
    XCTAssertEqual(error, .conversionFailed(reason: "test"))
  }

  func testMissingFieldConvenience() {
    let error = DescriptorError.missingField("field", in: "context")
    XCTAssertEqual(error, .missingRequiredField(field: "field", in: "context"))
  }

  func testInvalidTypeConvenience() {
    let error = DescriptorError.invalidType("type", in: "context")
    XCTAssertEqual(error, .invalidFieldType(type: "type", context: "context"))
  }

  func testDuplicateConvenience() {
    let error = DescriptorError.duplicate("name", type: "type")
    XCTAssertEqual(error, .duplicateElement(name: "name", type: "type"))
  }

  func testUnsupportedConvenience() {
    let error = DescriptorError.unsupported("feature", in: "context")
    XCTAssertEqual(error, .unsupportedFeature(feature: "feature", context: "context"))
  }

  func testInternalErrorConvenience() {
    let error = DescriptorError.internalError("message")
    XCTAssertEqual(error, .internalError(message: "message"))
  }

  // MARK: - Equatable Tests

  func testErrorEquality() {
    let error1 = DescriptorError.conversionFailed(reason: "test")
    let error2 = DescriptorError.conversionFailed(reason: "test")
    let error3 = DescriptorError.conversionFailed(reason: "different")

    XCTAssertEqual(error1, error2)
    XCTAssertNotEqual(error1, error3)
  }

  func testErrorTypeEquality() {
    let conversionError = DescriptorError.conversionFailed(reason: "test")
    let missingFieldError = DescriptorError.missingRequiredField(field: "test", in: "context")

    XCTAssertNotEqual(conversionError, missingFieldError)
  }

  // MARK: - LocalizedError Protocol Tests

  func testLocalizedErrorProtocol() {
    let error = DescriptorError.conversionFailed(reason: "test reason")
    XCTAssertNotNil(error.errorDescription)
    XCTAssertEqual(error.localizedDescription, error.errorDescription!)
  }

  func testAllErrorsHaveDescriptions() {
    let errors: [DescriptorError] = [
      .conversionFailed(reason: "test"),
      .missingRequiredField(field: "field", in: "context"),
      .invalidFieldType(type: "type", context: "context"),
      .duplicateElement(name: "name", type: "type"),
      .unsupportedFeature(feature: "feature", context: "context"),
      .internalError(message: "message"),
    ]

    for error in errors {
      XCTAssertNotNil(error.errorDescription)
      XCTAssertFalse(error.errorDescription!.isEmpty)
    }
  }
}
