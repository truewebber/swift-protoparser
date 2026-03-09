import XCTest

@testable import SwiftProtoParser

// MARK: - RequiredFieldLabelTests

/// Tests for AC-3 of SPP-2: `required` field label in proto2 / proto3.
///
/// AC-3: `required int32 foo = 1;` in a proto2 message produces a field descriptor
///       with `label == LABEL_REQUIRED` (value 2).
///       The same construct in a proto3 file produces error
///       "Required fields are not allowed in proto3."
final class RequiredFieldLabelTests: XCTestCase {

  // MARK: - FieldLabel enum tests

  func test_fieldLabel_required_exists() {
    XCTAssertEqual(FieldLabel.required.rawValue, "required")
  }

  func test_fieldLabel_required_isRequired() {
    XCTAssertTrue(FieldLabel.required.isRequired)
  }

  func test_fieldLabel_required_protoKeyword() {
    XCTAssertEqual(FieldLabel.required.protoKeyword, "required")
  }

  func test_fieldLabel_required_doesNotAllowMultipleValues() {
    XCTAssertFalse(FieldLabel.required.allowsMultipleValues)
  }

  func test_fieldLabel_nonRequired_isNotRequired() {
    XCTAssertFalse(FieldLabel.optional.isRequired)
    XCTAssertFalse(FieldLabel.repeated.isRequired)
    XCTAssertFalse(FieldLabel.singular.isRequired)
  }

  // MARK: - AC-3: proto2 required field → LABEL_REQUIRED

  func test_parse_requiredFieldInProto2_succeeds() {
    let proto = """
      syntax = "proto2";
      message Foo {
        required int32 id = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)

    switch result {
    case .success:
      break
    case .failure(let error):
      XCTFail("Expected success for required field in proto2, got: \(error)")
    }
  }

  func test_parse_requiredFieldInProto2_astLabelIsRequired() {
    let proto = """
      syntax = "proto2";
      message Foo {
        required int32 id = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)

    guard case .success(let ast) = result else {
      XCTFail("Expected success")
      return
    }
    XCTAssertEqual(
      ast.messages[0].fields[0].label,
      .required,
      "required field in proto2 must produce .required label"
    )
  }

  func test_parse_requiredFieldInNoSyntax_succeeds() {
    let proto = """
      message Foo {
        required int32 id = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)

    switch result {
    case .success(let ast):
      XCTAssertEqual(
        ast.messages[0].fields[0].label,
        .required,
        "required field in no-syntax (proto2) must produce .required label"
      )
    case .failure(let error):
      XCTFail("Expected success for required field in no-syntax file, got: \(error)")
    }
  }

  func test_parse_requiredFieldInProto2_descriptorLabelIsRequired() throws {
    let proto = """
      syntax = "proto2";
      message Foo {
        required int32 id = 1;
      }
      """

    guard case .success(let tokens) = Lexer(input: proto).tokenize(),
      case .success(let ast) = Parser(tokens: tokens).parse()
    else {
      XCTFail("Expected successful parse")
      return
    }

    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    let field = descriptor.messageType[0].field[0]
    XCTAssertEqual(field.label, .required, "required proto2 field must produce LABEL_REQUIRED in descriptor")
  }

  func test_parse_multipleRequiredFieldsInProto2() throws {
    let proto = """
      syntax = "proto2";
      message Person {
        required string name = 1;
        required int32 id = 2;
        optional string email = 3;
        repeated string phones = 4;
      }
      """

    guard case .success(let tokens) = Lexer(input: proto).tokenize(),
      case .success(let ast) = Parser(tokens: tokens).parse()
    else {
      XCTFail("Expected successful parse")
      return
    }

    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    let fields = descriptor.messageType[0].field

    XCTAssertEqual(fields[0].label, .required, "name must be LABEL_REQUIRED")
    XCTAssertEqual(fields[1].label, .required, "id must be LABEL_REQUIRED")
    XCTAssertEqual(fields[2].label, .optional, "email must be LABEL_OPTIONAL")
    XCTAssertEqual(fields[3].label, .repeated, "phones must be LABEL_REPEATED")
  }

  // MARK: - AC-3: proto3 required field → exact error

  func test_parse_requiredFieldInProto3_producesError() {
    let proto = """
      syntax = "proto3";
      message Foo {
        required int32 id = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)

    switch result {
    case .success:
      XCTFail("required in proto3 must produce an error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("Required fields are not allowed in proto3."),
        "Error must contain exact protoc text. Got: \(error.description)"
      )
    }
  }

  func test_parse_requiredFieldInProto3_exactErrorText() {
    let proto = """
      syntax = "proto3";
      message Bar {
        required string name = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)

    guard case .failure(let error) = result else {
      XCTFail("Expected failure")
      return
    }
    XCTAssertTrue(
      error.description.contains("Required fields are not allowed in proto3."),
      "Must contain exact error: 'Required fields are not allowed in proto3.' Got: \(error.description)"
    )
  }

  // MARK: - required in extend block

  func test_parse_requiredInExtendBlock_proto2_succeeds() {
    let proto = """
      syntax = "proto2";
      message Foo {}
      extend Foo {
        required int32 bar = 100;
      }
      """

    let result = SwiftProtoParser.parseProtoString(proto)

    switch result {
    case .success(let ast):
      XCTAssertEqual(
        ast.extends[0].fields[0].label,
        .required,
        "required in extend block in proto2 must produce .required label"
      )
    case .failure(let error):
      XCTFail("Expected success for required in extend proto2, got: \(error)")
    }
  }

  // MARK: - Proto3 regression

  func test_parse_optionalRepeatedInProto3_stillWork() throws {
    let proto = """
      syntax = "proto3";
      message Foo {
        string name = 1;
        repeated int32 ids = 2;
        optional bool flag = 3;
      }
      """

    guard case .success(let tokens) = Lexer(input: proto).tokenize(),
      case .success(let ast) = Parser(tokens: tokens).parse()
    else {
      XCTFail("Expected successful parse")
      return
    }

    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    let fields = descriptor.messageType[0].field

    XCTAssertEqual(fields[0].label, .optional, "singular field → LABEL_OPTIONAL")
    XCTAssertEqual(fields[1].label, .repeated, "repeated field → LABEL_REPEATED")
    XCTAssertEqual(fields[2].label, .optional, "optional field → LABEL_OPTIONAL")
  }
}
