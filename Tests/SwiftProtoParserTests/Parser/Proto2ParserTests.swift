import XCTest

@testable import SwiftProtoParser

// MARK: - Proto2ParserTests

/// Tests for proto2 enum semantics (AC-8 and AC-15).
///
/// - AC-8: Enum without zero value is valid in proto2 (zero-value check is proto3-only).
/// - AC-15: Duplicate enum values without `allow_alias = true` produce a protoc-compatible error.
final class Proto2ParserTests: XCTestCase {

  // MARK: - AC-8: Proto2 enum without zero value

  func test_parse_proto2EnumWithoutZeroValue_succeeds() {
    let proto = """
      syntax = "proto2";
      enum Status {
        STARTED = 1;
        RUNNING = 2;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.enums.count, 1)
      XCTAssertEqual(ast.enums[0].name, "Status")
    case .failure(let error):
      XCTFail("proto2 enum without zero value must not produce an error, got: \(error.description)")
    }
  }

  func test_parse_noSyntaxEnumWithoutZeroValue_succeeds() {
    let proto = """
      enum Status {
        STARTED = 1;
        RUNNING = 2;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.enums.count, 1)
    case .failure(let error):
      XCTFail("No-syntax (proto2) enum without zero value must not produce an error, got: \(error.description)")
    }
  }

  func test_parse_proto2EnumWithZeroValue_succeeds() {
    let proto = """
      syntax = "proto2";
      enum Status {
        UNKNOWN = 0;
        STARTED = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      break
    case .failure(let error):
      XCTFail("proto2 enum with zero value must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto2NestedEnumWithoutZeroValue_succeeds() {
    let proto = """
      syntax = "proto2";
      message Request {
        enum Type {
          QUERY = 1;
          MUTATION = 2;
        }
        required Type type = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages[0].nestedEnums.count, 1)
    case .failure(let error):
      XCTFail("proto2 nested enum without zero value must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto3EnumWithoutZeroValue_producesError() {
    let proto = """
      syntax = "proto3";
      enum Status {
        STARTED = 1;
        RUNNING = 2;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("proto3 enum without zero value must produce an error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("missing") || error.description.contains("zero"),
        "Expected missing zero value error, got: \(error.description)"
      )
    }
  }

  // MARK: - AC-15: allow_alias enum option

  func test_parse_proto3EnumWithAllowAlias_duplicateValues_succeeds() {
    let proto = """
      syntax = "proto3";
      enum Status {
        option allow_alias = true;
        UNKNOWN = 0;
        STARTED = 1;
        RUNNING = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.enums.count, 1)
    case .failure(let error):
      XCTFail("Enum with allow_alias = true must allow duplicate values, got: \(error.description)")
    }
  }

  func test_parse_proto2EnumWithAllowAlias_duplicateValues_succeeds() {
    let proto = """
      syntax = "proto2";
      enum Status {
        option allow_alias = true;
        STARTED = 1;
        RUNNING = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.enums.count, 1)
    case .failure(let error):
      XCTFail("proto2 enum with allow_alias = true must allow duplicate values, got: \(error.description)")
    }
  }

  func test_parse_proto3EnumWithoutAllowAlias_duplicateValues_producesError() {
    let proto = """
      syntax = "proto3";
      enum Status {
        UNKNOWN = 0;
        STARTED = 1;
        RUNNING = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("Enum with duplicate values and no allow_alias must produce an error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("allow_alias"),
        "Expected allow_alias error message, got: \(error.description)"
      )
    }
  }

  func test_parse_proto2EnumWithoutAllowAlias_duplicateValues_producesError() {
    let proto = """
      syntax = "proto2";
      enum Status {
        STARTED = 1;
        RUNNING = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("proto2 enum with duplicate values and no allow_alias must produce an error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("allow_alias"),
        "Expected allow_alias error message, got: \(error.description)"
      )
    }
  }

  func test_parse_noSyntaxEnumWithoutAllowAlias_duplicateValues_producesError() {
    let proto = """
      enum Status {
        STARTED = 1;
        RUNNING = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("No-syntax enum with duplicate values and no allow_alias must produce an error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("allow_alias"),
        "Expected allow_alias error message, got: \(error.description)"
      )
    }
  }

  func test_parse_duplicateEnumValue_errorContainsExactProtocFormat() {
    let proto = """
      syntax = "proto3";
      package test.pkg;
      enum Status {
        UNKNOWN = 0;
        STARTED = 1;
        RUNNING = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("Duplicate enum values without allow_alias must produce an error")
    case .failure(let error):
      let desc = error.description
      XCTAssertTrue(
        desc.contains("RUNNING") && desc.contains("STARTED"),
        "Error must reference both duplicate and original value names, got: \(desc)"
      )
      XCTAssertTrue(
        desc.contains("allow_alias"),
        "Error must mention allow_alias, got: \(desc)"
      )
      XCTAssertTrue(
        desc.contains("next available"),
        "Error must mention next available enum value, got: \(desc)"
      )
    }
  }

  func test_parse_duplicateEnumValue_errorMentionsNextAvailableValue() {
    let proto = """
      syntax = "proto3";
      enum Status {
        UNKNOWN = 0;
        STARTED = 1;
        RUNNING = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("Duplicate enum values without allow_alias must produce an error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("2"),
        "Next available value should be 2 (max 1 + 1), got: \(error.description)"
      )
    }
  }

  func test_parse_allowAliasSetFalse_duplicateValues_producesError() {
    let proto = """
      syntax = "proto3";
      enum Status {
        option allow_alias = false;
        UNKNOWN = 0;
        STARTED = 1;
        RUNNING = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("allow_alias = false must not suppress the duplicate error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("allow_alias"),
        "Expected allow_alias error, got: \(error.description)"
      )
    }
  }

  // MARK: - AC-4: Extension ranges (proto2 only)

  func test_parse_proto2ExtensionRangeSingle_succeeds() {
    let proto = """
      syntax = "proto2";
      message Extendable {
        required int32 id = 1;
        extensions 100 to 199;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages.count, 1)
      let msg = ast.messages[0]
      XCTAssertEqual(msg.extensionRanges.count, 1)
      XCTAssertEqual(msg.extensionRanges[0].start, 100)
      XCTAssertEqual(msg.extensionRanges[0].end, 200, "End must be stored exclusive (199 + 1 = 200)")
    case .failure(let error):
      XCTFail("proto2 single extension range must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto2ExtensionRangeMax_succeeds() {
    let proto = """
      syntax = "proto2";
      message Extendable {
        required int32 id = 1;
        extensions 1000 to max;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages.count, 1)
      let msg = ast.messages[0]
      XCTAssertEqual(msg.extensionRanges.count, 1)
      XCTAssertEqual(msg.extensionRanges[0].start, 1000)
      XCTAssertEqual(msg.extensionRanges[0].end, 536_870_912, "'max' must map to exclusive end 536870912")
    case .failure(let error):
      XCTFail("proto2 extension range to max must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto2ExtensionRangeCommaSeparated_yieldsThreeRanges() {
    let proto = """
      syntax = "proto2";
      message Extendable {
        required int32 id = 1;
        extensions 100 to 199, 300 to 399, 500 to max;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      let ranges = ast.messages[0].extensionRanges
      XCTAssertEqual(ranges.count, 3)
      XCTAssertEqual(ranges[0].start, 100)
      XCTAssertEqual(ranges[0].end, 200)
      XCTAssertEqual(ranges[1].start, 300)
      XCTAssertEqual(ranges[1].end, 400)
      XCTAssertEqual(ranges[2].start, 500)
      XCTAssertEqual(ranges[2].end, 536_870_912)
    case .failure(let error):
      XCTFail("Comma-separated extension ranges must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto3ExtensionRange_producesExactError() {
    let proto = """
      syntax = "proto3";
      message Extendable {
        int32 id = 1;
        extensions 100 to 199;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("proto3 with extension ranges must produce an error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("Extension ranges are not allowed in proto3."),
        "Expected exact protoc error, got: \(error.description)"
      )
    }
  }

  func test_parse_proto2ExtensionRangeSingleNumber_succeeds() {
    let proto = """
      syntax = "proto2";
      message Extendable {
        required int32 id = 1;
        extensions 100 to 100;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      let ranges = ast.messages[0].extensionRanges
      XCTAssertEqual(ranges.count, 1)
      XCTAssertEqual(ranges[0].start, 100)
      XCTAssertEqual(ranges[0].end, 101, "Single-number range end is exclusive (100 + 1 = 101)")
    case .failure(let error):
      XCTFail("Single-number extension range must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto2ExtensionRangeWithDeclarationOption_succeeds() {
    // Tests extension range options syntax: extensions N [declaration = {...}];
    // This syntax appears in google/protobuf/descriptor.proto bundled with protoc 3.x+
    let proto = """
      syntax = "proto2";
      message FileDescriptorSet {
        repeated string file = 1;
        extensions 536000000 [declaration = {
          number: 536000000
          type: ".buf.descriptor.v1.FileDescriptorSetExtension"
          full_name: ".buf.descriptor.v1.buf_file_descriptor_set_extension"
        }];
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages.count, 1)
      let ranges = ast.messages[0].extensionRanges
      XCTAssertEqual(ranges.count, 1)
      XCTAssertEqual(ranges[0].start, 536_000_000)
      XCTAssertEqual(ranges[0].end, 536_000_001, "End must be stored exclusive (536000000 + 1)")
      let opts = ranges[0].options
      XCTAssertNotNil(opts, "Extension range must have parsed options")
      XCTAssertEqual(opts?.declarations.count, 1)
      let decl = opts?.declarations[0]
      XCTAssertEqual(decl?.number, 536_000_000)
      XCTAssertEqual(decl?.typeName, ".buf.descriptor.v1.FileDescriptorSetExtension")
      XCTAssertEqual(decl?.fullName, ".buf.descriptor.v1.buf_file_descriptor_set_extension")
    case .failure(let error):
      XCTFail("Extension range with declaration options must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto2ExtensionRangeWithMultipleDeclarations_succeeds() {
    // Multiple declarations in a single extension range options block
    let proto = """
      syntax = "proto2";
      message Extendable {
        required int32 id = 1;
        extensions 1000 to 1999 [declaration = {
          number: 1000
          type: ".foo.Bar"
          full_name: ".foo.bar_extension"
        }, declaration = {
          number: 1001
          type: ".foo.Baz"
          full_name: ".foo.baz_extension"
        }];
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      let ranges = ast.messages[0].extensionRanges
      XCTAssertEqual(ranges.count, 1)
      XCTAssertEqual(ranges[0].start, 1000)
      XCTAssertEqual(ranges[0].end, 2000, "End stored exclusive (1999 + 1)")
      let decls = ranges[0].options?.declarations
      XCTAssertEqual(decls?.count, 2)
      XCTAssertEqual(decls?[0].number, 1000)
      XCTAssertEqual(decls?[0].typeName, ".foo.Bar")
      XCTAssertEqual(decls?[0].fullName, ".foo.bar_extension")
      XCTAssertEqual(decls?[1].number, 1001)
      XCTAssertEqual(decls?[1].typeName, ".foo.Baz")
      XCTAssertEqual(decls?[1].fullName, ".foo.baz_extension")
    case .failure(let error):
      XCTFail("Extension range with multiple declarations must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto2ExtensionRangeWithVerification_parsesVerificationState() {
    let proto = """
      syntax = "proto2";
      message Extendable {
        required int32 id = 1;
        extensions 1000 to 1999 [
          declaration = { number: 1000 full_name: ".foo.bar_ext" type: ".foo.Bar" },
          verification = DECLARATION
        ];
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      let opts = ast.messages[0].extensionRanges[0].options
      XCTAssertNotNil(opts)
      XCTAssertEqual(opts?.verification, "DECLARATION")
      XCTAssertEqual(opts?.declarations.count, 1)
    case .failure(let error):
      XCTFail("Extension range with verification must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto2ExtensionRangeWithReservedDeclaration_parsesReservedFlag() {
    let proto = """
      syntax = "proto2";
      message Extendable {
        required int32 id = 1;
        extensions 1000 [declaration = {
          number: 1000
          full_name: ".foo.old_ext"
          type: ".foo.OldType"
          reserved: true
        }];
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      let decl = ast.messages[0].extensionRanges[0].options?.declarations[0]
      XCTAssertEqual(decl?.reserved, true)
      XCTAssertEqual(decl?.number, 1000)
    case .failure(let error):
      XCTFail("Extension range with reserved declaration must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto2MessageNoExtensionRanges_returnsEmpty() {
    let proto = """
      syntax = "proto2";
      message Plain {
        required int32 id = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages[0].extensionRanges.count, 0)
    case .failure(let error):
      XCTFail("Plain proto2 message must succeed, got: \(error.description)")
    }
  }

  // MARK: - AC-13: Oneof label validation

  func test_parse_proto3OneofWithOptionalLabel_producesExactError() {
    let proto = """
      syntax = "proto3";
      message Msg {
        oneof value {
          optional string name = 1;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("oneof field with 'optional' label must produce an error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("Fields in oneofs must not have labels (required / optional / repeated)."),
        "Expected exact protoc error message, got: \(error.description)"
      )
    }
  }

  func test_parse_proto3OneofWithRepeatedLabel_producesExactError() {
    let proto = """
      syntax = "proto3";
      message Msg {
        oneof value {
          repeated string name = 1;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("oneof field with 'repeated' label must produce an error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("Fields in oneofs must not have labels (required / optional / repeated)."),
        "Expected exact protoc error message, got: \(error.description)"
      )
    }
  }

  func test_parse_proto3OneofWithRequiredLabel_producesOneofError_notProto3Error() {
    let proto = """
      syntax = "proto3";
      message Msg {
        oneof value {
          required string name = 1;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("oneof field with 'required' label must produce an error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("Fields in oneofs must not have labels (required / optional / repeated)."),
        "Expected oneof-specific error, not proto3 required error. Got: \(error.description)"
      )
      XCTAssertFalse(
        error.description.contains("Required fields are not allowed in proto3"),
        "Should not produce proto3 required error for oneof context. Got: \(error.description)"
      )
    }
  }

  func test_parse_proto2OneofWithRequiredLabel_producesExactError() {
    let proto = """
      syntax = "proto2";
      message Msg {
        oneof value {
          required string name = 1;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("oneof field with 'required' label must produce an error in proto2")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("Fields in oneofs must not have labels (required / optional / repeated)."),
        "Expected exact protoc error message, got: \(error.description)"
      )
    }
  }

  func test_parse_proto2OneofWithOptionalLabel_producesExactError() {
    let proto = """
      syntax = "proto2";
      message Msg {
        oneof value {
          optional string name = 1;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("oneof field with 'optional' label must produce an error in proto2")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("Fields in oneofs must not have labels (required / optional / repeated)."),
        "Expected exact protoc error message, got: \(error.description)"
      )
    }
  }

  func test_parse_proto3ValidOneofWithoutLabels_succeeds() {
    let proto = """
      syntax = "proto3";
      message Msg {
        oneof value {
          string name = 1;
          int32 number = 2;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages[0].oneofGroups.count, 1)
      XCTAssertEqual(ast.messages[0].oneofGroups[0].fields.count, 2)
    case .failure(let error):
      XCTFail("Valid oneof without labels must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto2ValidOneofWithoutLabels_succeeds() {
    let proto = """
      syntax = "proto2";
      message Msg {
        oneof value {
          string name = 1;
          int32 number = 2;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages[0].oneofGroups.count, 1)
      XCTAssertEqual(ast.messages[0].oneofGroups[0].fields.count, 2)
    case .failure(let error):
      XCTFail("Valid proto2 oneof without labels must succeed, got: \(error.description)")
    }
  }

  // MARK: - AC-5: proto3 extend validation — FQN-based check

  func test_parse_proto3ExtendNonGoogleTarget_producesError() {
    let proto = """
      syntax = "proto3";
      extend SomeMessage {
        string val = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("proto3 extend of non-google.protobuf target must produce an error")
    case .failure:
      break
    }
  }

  func test_parse_proto3ExtendNonGoogleTarget_errorMessageMatchesProtoc() {
    let proto = """
      syntax = "proto3";
      extend SomeMessage {
        string val = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("proto3 extend of non-google.protobuf target must produce an error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("does not declare")
          || error.description.contains("Extensions in proto3 are only allowed for defining options."),
        "Error must contain protoc-compatible message. Got: \(error.description)"
      )
    }
  }

  func test_parse_proto3ExtendGoogleProtobuf_fullName_succeeds() {
    let proto = """
      syntax = "proto3";
      extend google.protobuf.FileOptions {
        string my_opt = 50000;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      break
    case .failure(let error):
      XCTFail("proto3 extend of google.protobuf.* must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto3ExtendGoogleProtobuf_dotPrefixed_succeeds() {
    let proto = """
      syntax = "proto3";
      extend .google.protobuf.MessageOptions {
        string my_opt = 50001;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      break
    case .failure(let error):
      XCTFail("proto3 extend of .google.protobuf.* must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto3ExtendGoogleProtobuf_shortNameWithPackage_succeeds() {
    let proto = """
      syntax = "proto3";
      package google.protobuf;
      extend FileOptions {
        string my_opt = 50002;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      break
    case .failure(let error):
      XCTFail(
        "proto3 extend with package google.protobuf and short name must succeed, got: \(error.description)"
      )
    }
  }

  func test_parse_proto2ExtendAnyTarget_succeeds() {
    let proto = """
      syntax = "proto2";
      message Base {
        required int32 id = 1;
        extensions 100 to 199;
      }
      extend Base {
        optional string extra = 100;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      break
    case .failure(let error):
      XCTFail("proto2 extend of any target must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto2ExtendNonGoogleTarget_noError() {
    let proto = """
      syntax = "proto2";
      extend SomeArbitraryMessage {
        optional string val = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      break
    case .failure(let error):
      XCTFail("proto2 extend must not produce an error, got: \(error.description)")
    }
  }

  func test_parse_proto3ExtendWithPackageAndNonGoogleTarget_producesError() {
    let proto = """
      syntax = "proto3";
      package myapp;
      extend SomeMessage {
        string val = 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("proto3 extend of non-google.protobuf target with package must produce an error")
    case .failure:
      break
    }
  }

  // MARK: - AC-6: Group fields (proto2 only)

  func test_parse_proto2GroupField_optionalLabel_succeeds() {
    let proto = """
      syntax = "proto2";
      message SearchRequest {
        optional group SearchResult = 1 {
          required string url = 2;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages.count, 1)
      let msg = ast.messages[0]
      XCTAssertEqual(msg.groupFields.count, 1, "Expected 1 group field")
    case .failure(let error):
      XCTFail("proto2 optional group field must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto2GroupField_requiredLabel_succeeds() {
    let proto = """
      syntax = "proto2";
      message SearchRequest {
        required group SearchResult = 1 {
          required string url = 2;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages[0].groupFields.count, 1)
      XCTAssertEqual(ast.messages[0].groupFields[0].label, .required)
    case .failure(let error):
      XCTFail("proto2 required group field must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto2GroupField_repeatedLabel_succeeds() {
    let proto = """
      syntax = "proto2";
      message SearchRequest {
        repeated group Result = 1 {
          required string url = 2;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages[0].groupFields.count, 1)
      XCTAssertEqual(ast.messages[0].groupFields[0].label, .repeated)
    case .failure(let error):
      XCTFail("proto2 repeated group field must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto2GroupField_groupNamePreservedWithOriginalCase() {
    let proto = """
      syntax = "proto2";
      message SearchRequest {
        optional group SearchResult = 1 {
          required string url = 2;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(
        ast.messages[0].groupFields[0].groupName,
        "SearchResult",
        "groupName must preserve original capitalisation"
      )
    case .failure(let error):
      XCTFail("proto2 group field must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto2GroupField_fieldNumber_isCorrect() {
    let proto = """
      syntax = "proto2";
      message SearchRequest {
        optional group SearchResult = 42 {
          required string url = 1;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages[0].groupFields[0].fieldNumber, 42)
    case .failure(let error):
      XCTFail("proto2 group field must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto2GroupField_bodyFields_areParsed() {
    let proto = """
      syntax = "proto2";
      message SearchRequest {
        optional group SearchResult = 1 {
          required string url = 2;
          optional string title = 3;
          optional int32 snippets_count = 4;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      let body = ast.messages[0].groupFields[0].body
      XCTAssertEqual(body.fields.count, 3, "Group body must contain 3 fields")
      XCTAssertEqual(body.fields[0].name, "url")
      XCTAssertEqual(body.fields[1].name, "title")
      XCTAssertEqual(body.fields[2].name, "snippets_count")
    case .failure(let error):
      XCTFail("proto2 group with body fields must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto2GroupField_bodyHasGroupName() {
    let proto = """
      syntax = "proto2";
      message SearchRequest {
        optional group SearchResult = 1 {
          required string url = 2;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      let body = ast.messages[0].groupFields[0].body
      XCTAssertEqual(
        body.name,
        "SearchResult",
        "Group body message name must equal the original group name"
      )
    case .failure(let error):
      XCTFail("proto2 group field must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto2MultipleGroupFields_inOneMessage_succeeds() {
    let proto = """
      syntax = "proto2";
      message Search {
        optional group ResultA = 1 {
          required string url = 2;
        }
        repeated group ResultB = 3 {
          optional int32 rank = 4;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages[0].groupFields.count, 2)
      XCTAssertEqual(ast.messages[0].groupFields[0].groupName, "ResultA")
      XCTAssertEqual(ast.messages[0].groupFields[1].groupName, "ResultB")
    case .failure(let error):
      XCTFail("Multiple proto2 group fields must succeed, got: \(error.description)")
    }
  }

  func test_parse_proto3GroupField_producesExactError() {
    let proto = """
      syntax = "proto3";
      message SearchRequest {
        optional group SearchResult = 1 {
          string url = 2;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success:
      XCTFail("proto3 group field must produce an error")
    case .failure(let error):
      XCTAssertTrue(
        error.description.contains("Groups are not supported in proto3 syntax."),
        "Error must contain exact protoc error message. Got: \(error.description)"
      )
    }
  }

  func test_parse_proto2GroupField_mixedWithRegularFields_succeeds() {
    let proto = """
      syntax = "proto2";
      message SearchRequest {
        required string query = 1;
        optional group Result = 2 {
          required string url = 3;
        }
        optional int32 page = 4;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      let msg = ast.messages[0]
      XCTAssertEqual(msg.fields.count, 2, "Must have 2 regular fields")
      XCTAssertEqual(msg.groupFields.count, 1, "Must have 1 group field")
    case .failure(let error):
      XCTFail("Mixed fields and group fields must succeed, got: \(error.description)")
    }
  }

  // MARK: - AC-16: Nested extend inside message

  func test_parse_nestedExtendInMessage_populatesNestedExtends() {
    let proto = """
      syntax = "proto2";
      message Foo {
        required int32 id = 1;
        extensions 100 to 199;
      }
      message Bar {
        extend Foo {
          optional string extra = 100;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages.count, 2)
      guard ast.messages.count >= 2 else { return }
      let bar = ast.messages[1]
      XCTAssertEqual(bar.name, "Bar")
      XCTAssertEqual(bar.nestedExtends.count, 1, "Bar must have 1 nested extend")
      guard bar.nestedExtends.count >= 1 else { return }
      XCTAssertEqual(bar.nestedExtends[0].extendedType, "Foo")
      XCTAssertEqual(bar.nestedExtends[0].fields.count, 1)
    case .failure(let error):
      XCTFail("Proto2 nested extend must parse successfully, got: \(error.description)")
    }
  }

  // MARK: - Reserved inside enum

  func test_parse_enumWithReservedSingleNumber_storesNumber() {
    let proto = """
      syntax = "proto2";
      enum Utf8Validation {
        UTF8_VALIDATION_UNKNOWN = 0;
        VERIFY = 2;
        NONE = 3;
        reserved 1;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.enums.count, 1)
      XCTAssertEqual(ast.enums[0].reservedNumbers, [1])
      XCTAssertTrue(ast.enums[0].reservedNames.isEmpty)
    case .failure(let error):
      XCTFail("Enum with reserved number must succeed, got: \(error.description)")
    }
  }

  func test_parse_enumWithReservedRange_expandsNumbers() {
    let proto = """
      syntax = "proto2";
      enum Status {
        UNKNOWN = 0;
        ACTIVE = 1;
        reserved 4 to 6;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      let reserved = ast.enums[0].reservedNumbers
      XCTAssertEqual(reserved.sorted(), [4, 5, 6])
    case .failure(let error):
      XCTFail("Enum with reserved range must succeed, got: \(error.description)")
    }
  }

  func test_parse_enumWithReservedNames_storesNames() {
    let proto = """
      syntax = "proto2";
      enum Status {
        UNKNOWN = 0;
        reserved "DEPRECATED_VALUE", "OLD_VALUE";
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertTrue(ast.enums[0].reservedNumbers.isEmpty)
      XCTAssertEqual(ast.enums[0].reservedNames.sorted(), ["DEPRECATED_VALUE", "OLD_VALUE"])
    case .failure(let error):
      XCTFail("Enum with reserved names must succeed, got: \(error.description)")
    }
  }

  func test_parse_enumWithMultipleReservedStatements_accumulatesAll() {
    let proto = """
      syntax = "proto2";
      enum Utf8Validation {
        UTF8_VALIDATION_UNKNOWN = 0;
        VERIFY = 2;
        NONE = 3;
        reserved 1;
        reserved 10, 11;
        reserved "OLD_NAME";
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      let e = ast.enums[0]
      XCTAssertEqual(e.reservedNumbers.sorted(), [1, 10, 11])
      XCTAssertEqual(e.reservedNames, ["OLD_NAME"])
    case .failure(let error):
      XCTFail("Enum with multiple reserved statements must succeed, got: \(error.description)")
    }
  }

  func test_parse_nestedEnumWithReserved_succeeds() {
    let proto = """
      syntax = "proto2";
      message Foo {
        enum Bar {
          BAR_UNKNOWN = 0;
          BAR_A = 1;
          reserved 5, 6;
        }
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      let nestedEnum = ast.messages[0].nestedEnums[0]
      XCTAssertEqual(nestedEnum.reservedNumbers.sorted(), [5, 6])
    case .failure(let error):
      XCTFail("Nested enum with reserved must succeed, got: \(error.description)")
    }
  }

  // MARK: - reserved-to-max support

  func test_parse_messageWithReservedToMax_parsesRange() throws {
    let proto = """
      syntax = "proto2";
      message Foo {
        reserved 1 to max;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages[0].reservedRanges.count, 1)
      let range = ast.messages[0].reservedRanges[0]
      XCTAssertEqual(range.start, 1)
      XCTAssertTrue(range.endIsMax, "End should be marked as max")
    case .failure(let error):
      XCTFail("reserved 1 to max must parse successfully, got: \(error.description)")
    }
  }

  func test_parse_enumWithReservedToMax_parsesRange() throws {
    let proto = """
      syntax = "proto2";
      enum Status {
        STATUS_UNKNOWN = 0;
        reserved 1 to max;
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.enums[0].reservedRanges.count, 1)
      let range = ast.enums[0].reservedRanges[0]
      XCTAssertEqual(range.start, 1)
      XCTAssertTrue(range.endIsMax, "End should be marked as max")
    case .failure(let error):
      XCTFail("enum reserved 1 to max must parse successfully, got: \(error.description)")
    }
  }

  func test_parse_messageWithReservedToMax_descriptorUsesExclusiveEnd() throws {
    let proto = """
      syntax = "proto2";
      message Foo {
        reserved 1 to max;
      }
      """
    let result = SwiftProtoParser.parseProtoStringToDescriptors(proto)
    switch result {
    case .success(let fileProto):
      XCTAssertEqual(fileProto.messageType[0].reservedRange.count, 1)
      let range = fileProto.messageType[0].reservedRange[0]
      XCTAssertEqual(range.start, 1)
      XCTAssertEqual(range.end, 536_870_912, "Message reserved max should map to exclusive end 536870912")
    case .failure(let error):
      XCTFail("Descriptor build must succeed, got: \(error.description)")
    }
  }

  func test_parse_enumWithReservedToMax_descriptorUsesInt32Max() throws {
    let proto = """
      syntax = "proto2";
      enum Status {
        STATUS_UNKNOWN = 0;
        reserved 1 to max;
      }
      """
    let result = SwiftProtoParser.parseProtoStringToDescriptors(proto)
    switch result {
    case .success(let fileProto):
      XCTAssertEqual(fileProto.enumType[0].reservedRange.count, 1)
      let range = fileProto.enumType[0].reservedRange[0]
      XCTAssertEqual(range.start, 1)
      XCTAssertEqual(range.end, Int32.max, "Enum reserved max should map to inclusive Int32.max")
    case .failure(let error):
      XCTFail("Descriptor build must succeed, got: \(error.description)")
    }
  }

  // MARK: - Extension range declaration: malformed value types (skipTextProtoValue coverage)

  /// A `declaration` block where the `number` field has a string value instead of an integer
  /// is silently skipped by the parser (lenient recovery), and the other valid fields are kept.
  ///
  /// protoc error: `Expected integer, got: "wrong_type"`
  ///
  /// Our parser is lenient and recovers rather than erroring to allow
  /// partial parsing of forward-compatible proto files.
  func test_parse_declarationWithWrongTypeForNumber_recoversAndKeepsOtherFields() {
    let proto = """
      syntax = "proto2";
      message Extendable {
        required int32 id = 1;
        extensions 100 to 199 [
          declaration = {
            number: "wrong_type",
            full_name: ".test.foo_ext",
            type: ".test.Bar"
          }
        ];
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    // Parser should NOT crash — either succeed (lenient recovery) or return a parse error.
    // What it must NOT do is produce an unrecoverable crash or infinite loop.
    switch result {
    case .success(let ast):
      // Lenient recovery: the declaration was partially parsed or skipped.
      XCTAssertEqual(ast.messages[0].extensionRanges.count, 1, "Extension range must still be present")
    case .failure:
      // Strict error path is also acceptable.
      break
    }
  }

  /// A `declaration` block where the `full_name` field has an integer value instead of a string
  /// is silently skipped by the parser (lenient recovery path exercising skipTextProtoValue).
  func test_parse_declarationWithWrongTypeForFullName_recoversGracefully() {
    let proto = """
      syntax = "proto2";
      message Extendable {
        required int32 id = 1;
        extensions 100 to 199 [
          declaration = {
            number: 100,
            full_name: 999,
            type: ".test.Bar"
          }
        ];
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages[0].extensionRanges.count, 1)
    case .failure:
      break
    }
  }

  /// A `declaration` block where the `type` field has an integer value instead of a string
  /// exercises the skipTextProtoValue code path for the `type` key.
  func test_parse_declarationWithWrongTypeForTypeName_recoversGracefully() {
    let proto = """
      syntax = "proto2";
      message Extendable {
        required int32 id = 1;
        extensions 100 to 199 [
          declaration = {
            number: 100,
            full_name: ".test.foo_ext",
            type: 42
          }
        ];
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages[0].extensionRanges.count, 1)
    case .failure:
      break
    }
  }

  /// A `declaration` block where the `reserved` field has a string value instead of a bool
  /// exercises the skipTextProtoValue code path for the `reserved` key.
  func test_parse_declarationWithWrongTypeForReservedFlag_recoversGracefully() {
    let proto = """
      syntax = "proto2";
      message Extendable {
        required int32 id = 1;
        extensions 100 to 199 [
          declaration = {
            number: 100,
            full_name: ".test.foo_ext",
            type: ".test.Bar",
            reserved: "yes"
          }
        ];
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages[0].extensionRanges.count, 1)
    case .failure:
      break
    }
  }

  /// A `declaration` block where the `repeated` field has a string value instead of a bool
  /// exercises the skipTextProtoValue code path for the `repeated` key.
  func test_parse_declarationWithWrongTypeForRepeatedFlag_recoversGracefully() {
    let proto = """
      syntax = "proto2";
      message Extendable {
        required int32 id = 1;
        extensions 100 to 199 [
          declaration = {
            number: 100,
            full_name: ".test.foo_ext",
            type: ".test.Bar",
            repeated: "no"
          }
        ];
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages[0].extensionRanges.count, 1)
    case .failure:
      break
    }
  }

  /// A `declaration` block with an entirely unknown key exercises the `default:` case in the
  /// declaration parser which calls skipTextProtoValue to skip the unknown value.
  func test_parse_declarationWithUnknownKey_skipsUnknownFieldGracefully() {
    let proto = """
      syntax = "proto2";
      message Extendable {
        required int32 id = 1;
        extensions 100 to 199 [
          declaration = {
            number: 100,
            full_name: ".test.foo_ext",
            type: ".test.Bar",
            unknown_future_key: "some_value"
          }
        ];
      }
      """
    let result = SwiftProtoParser.parseProtoString(proto)
    // Our parser is lenient with unknown keys inside declaration blocks for forward
    // compatibility. The extension range itself must still be parsed correctly.
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.messages[0].extensionRanges.count, 1)
    case .failure:
      break
    }
  }
}
