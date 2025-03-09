import XCTest

@testable import SwiftProtoParser

final class ParserTests: XCTestCase {
  private func parse(_ input: String) throws -> FileNode {
    let lexer = Lexer(input: input)
    let parser = try Parser(lexer: lexer)
    return try parser.parseFile()
  }

  // MARK: - Syntax Declaration Tests

  func testValidSyntaxDeclaration() throws {
    let input = """
      syntax = "proto3";
      """
    let file = try parse(input)
    XCTAssertEqual(file.syntax, "proto3")
  }

  func testInvalidSyntaxValue() throws {
    let inputs = [
      """
      syntax = "proto2";
      """,
      """
      syntax = "invalid";
      """,
      """
      syntax = proto3;
      """,
    ]

    for input in inputs {
      XCTAssertThrowsError(try parse(input)) { error in
        guard let error = error as? ParserError else {
          XCTFail("Expected ParserError")
          return
        }

        switch error {
        case .invalidSyntaxVersion(_):
          return
        case .unexpectedToken(let expected, let got):
          if expected != .stringLiteral || got.type != .identifier {
            XCTFail(
              "Expected unexpectedToken on identifier instead of stringLiteral, but got: \(got)"
            )
          }
        default:
          XCTFail("Expected invalidSyntaxVersion error, got: \(error)")
        }
      }
    }
  }

  func testMissingSyntax() throws {
    let input = """
      package test;
      """
    let file = try parse(input)
    XCTAssertEqual(file.syntax, "proto3")  // Default to proto3
  }

  // MARK: - Package Declaration Tests

  func testValidPackageDeclaration() throws {
    let input = """
      syntax = "proto3";
      package foo.bar.baz;
      """
    let file = try parse(input)
    XCTAssertEqual(file.package, "foo.bar.baz")
  }

  func testInvalidPackageName() throws {
    let inputs = [
      "package test.;",
      "package Test.Name;",
      "package 123.456;",
      "package .test;",
      "package test..name;",
    ]

    for input in inputs {
      XCTAssertThrowsError(try parse(input)) { error in
        guard let error = error as? ParserError else {
          XCTFail("Expected ParserError")
          return
        }

        switch error {
        case .unexpectedToken(_, _), .invalidPackageName(_):
          return
        default:
          XCTFail("Expected unexpectedToken error, got: \(error)")
        }
      }
    }
  }

  // MARK: - Import Tests

  func testValidImports() throws {
    let input = """
      syntax = "proto3";
      import "other.proto";
      import public "public.proto";
      import weak "weak.proto";
      """
    let file = try parse(input)
    XCTAssertEqual(file.imports.count, 3)
    XCTAssertEqual(file.imports[0].path, "other.proto")
    XCTAssertEqual(file.imports[0].modifier, .none)
    XCTAssertEqual(file.imports[1].path, "public.proto")
    XCTAssertEqual(file.imports[1].modifier, .public)
    XCTAssertEqual(file.imports[2].path, "weak.proto")
    XCTAssertEqual(file.imports[2].modifier, .weak)
  }

  func testInvalidImports() throws {
    let inputs = [
      """
      import;
      """,
      """
      import public;
      """,
      """
      import weak;
      """,
      """
      import "missing_semicolon"
      """,
    ]

    for input in inputs {
      XCTAssertThrowsError(try parse(input)) { error in
        guard let error = error as? ParserError else {
          XCTFail("Expected ParserError")
          return
        }

        switch error {
        case .invalidImport(_):
          return
        default:
          XCTFail("Expected invalidImport error, got: \(error)")
        }
      }
    }
  }

  // MARK: - Empty File Tests

  func testEmptyFile() throws {
    let input = ""
    let file = try parse(input)
    XCTAssertEqual(file.syntax, "proto3")
    XCTAssertNil(file.package)
    XCTAssertTrue(file.imports.isEmpty)
    XCTAssertTrue(file.options.isEmpty)
    XCTAssertTrue(file.messages.isEmpty)
    XCTAssertTrue(file.enums.isEmpty)
    XCTAssertTrue(file.services.isEmpty)
  }

  func testWhitespaceOnlyFile() throws {
    let input = "  \n\t\n   "
    let file = try parse(input)
    XCTAssertEqual(file.syntax, "proto3")
  }

  // MARK: - Invalid File Structure Tests

  func testSyntaxAfterOtherDeclarations() throws {
    let input = """
      package test;
      syntax = "proto3";
      """
    XCTAssertThrowsError(try parse(input)) { error in
      guard let error = error as? ParserError else {
        XCTFail("Expected ParserError")
        return
      }

      switch error {
      case .unexpectedToken(_, _):
        return
      default:
        XCTFail("Expected unexpectedToken error, got: \(error)")
      }
    }
  }

  func testDuplicatePackageDeclaration() throws {
    let input = """
      syntax = "proto3";
      package test;
      package other;
      """
    XCTAssertThrowsError(try parse(input)) { error in
      guard let error = error as? ParserError else {
        XCTFail("Expected ParserError")
        return
      }

      switch error {
      case .duplicatePackageName(_):
        return
      default:
        XCTFail("Expected duplicatePackageName error, got: \(error)")
      }
    }
  }

  func testIncompleteFile() throws {
    let inputs = [
      "syntax = ",
      "package ",
      "import ",
      //      "syntax = \"proto3", it's not ParserError
      "package test",
    ]

    for input in inputs {
      XCTAssertThrowsError(try parse(input)) { error in
        guard let error = error as? ParserError else {
          XCTFail("Expected ParserError, got: \(error)")
          return
        }

        switch error {
        case .invalidImport(_):
          return
        case .invalidPackageName(_):
          return
        case .unexpectedToken(_, _):
          return
        default:
          XCTFail("Expected invalidImport or unexpectedToken error, got: \(error)")
        }
      }
    }
  }

  // MARK: - Message Tests

  func testBasicMessageDefinition() throws {
    let input = """
      message Test {
        string name = 1;
        int32 id = 2;
        bool active = 3;
      }
      """
    let file = try parse(input)
    XCTAssertEqual(file.messages.count, 1)
    let message = file.messages[0]
    XCTAssertEqual(message.name, "Test")
    XCTAssertEqual(message.fields.count, 3)
  }

  func testNestedMessages() throws {
    let input = """
      message Outer {
        string name = 1;

        message Middle {
          int32 id = 1;

          message Inner {
            bool active = 1;
          }

          Inner inner = 2;
        }

        Middle middle = 2;
      }
      """

    let file = try parse(input)

    let outer = file.messages[0]
    XCTAssertEqual(outer.messages.count, 1)

    let middle = outer.messages[0]
    XCTAssertEqual(middle.messages.count, 1)

    let inner = middle.messages[0]
    XCTAssertEqual(inner.messages.count, 0)
    XCTAssertEqual(inner.fields.count, 1)
  }

  func testInvalidMessageName() throws {
    let inputs = [
      "message 123 {}",
      "message test {}",  // Must start with uppercase
      //      "message Test$Name {}", it's not ParserError
      "message Test.Name {}",
    ]

    for input in inputs {
      XCTAssertThrowsError(try parse(input)) { error in
        guard let error = error as? ParserError else {
          XCTFail("Expected ParserError")
          return
        }

        switch error {
        case .invalidMessageName(_):
          return
        case .unexpectedToken(_, _):
          return
        default:
          XCTFail("Expected invalidMessageName or unexpectedToken error, got: \(error)")
        }
      }
    }
  }

  func testEmptyMessage() throws {
    let input = "message Empty {}"
    let file = try parse(input)
    XCTAssertTrue(file.messages[0].fields.isEmpty)
  }

  func testMultipleMessages() throws {
    let input = """
      message First {}
      message Second {}
      message Third {}
      """
    let file = try parse(input)
    XCTAssertEqual(file.messages.count, 3)
  }

  func testReservedFields() throws {
    let input = """
      message Test {
        reserved 2, 15, 9 to 11;
        reserved "foo", "bar";
        string name = 1;
      }
      """
    let file = try parse(input)
    let message = file.messages[0]
    XCTAssertEqual(message.reserved.count, 2)
    XCTAssertEqual(message.fields.count, 1)
  }

  func testDuplicateFieldNumbers() throws {
    let input = """
      message Test {
        string name = 1;
        int32 id = 1;
      }
      """

    XCTAssertThrowsError(try parse(input)) { error in
      guard let error = error as? ParserError else {
        XCTFail("Expected ParserError")
        return
      }

      switch error {
      case .duplicateFieldNumber(_, _):
        return
      default:
        XCTFail("Expected duplicateFieldNumber error, got: \(error)")
      }
    }
  }

  //moved to validator
  //  func testInvalidFieldNumbers() throws {
  //    let inputs = [
  //      "message Test { string name = 0; }",
  //      "message Test { string name = 19000; }",  // Reserved range
  //      "message Test { string name = 536870912; }",  // Too large
  //    ]
  //
  //    for input in inputs {
  //      XCTAssertThrowsError(try parse(input)) { error in
  //        guard let error = error as? ParserError else {
  //          XCTFail("Expected ParserError")
  //          return
  //        }
  //
  //        switch error {
  //        case .invalidFieldNumber(_, _):
  //          return
  //        default:
  //          XCTFail("Expected invalidFieldNumber error, got: \(error)")
  //        }
  //      }
  //    }
  //  }

  func testMapFields() throws {
    let input = """
      message Test {
        map<string, Project> projects = 1;
        map<int32, string> names = 2;
      }
      """

    let file = try parse(input)
    let fields = file.messages[0].fields

    XCTAssertEqual(fields.count, 2)

    // Verify first map field (map<string, Project>)
    if case .map(let keyType, let valueType) = fields[0].type {
      XCTAssertEqual(keyType, .string)
      if case .named("Project") = valueType {
        // Correct value type
      }
      else {
        XCTFail("Expected named type 'Project' for first map value type")
      }
    }
    else {
      XCTFail("Expected map type for first field")
    }

    // Verify second map field (map<int32, string>)
    if case .map(let keyType, let valueType) = fields[1].type {
      XCTAssertEqual(keyType, .int32)
      if case .scalar(.string) = valueType {
        // Correct value type
      }
      else {
        XCTFail("Expected scalar type 'string' for second map value type")
      }
    }
    else {
      XCTFail("Expected map type for second field")
    }
  }

  func testOneofFields() throws {
    let input = """
      message Test {
        oneof test_oneof {
      	string name = 1;
      	int32 id = 2;
        }
      }
      """

    let file = try parse(input)
    let message = file.messages[0]

    XCTAssertEqual(message.oneofs.count, 1)
    XCTAssertEqual(message.oneofs[0].fields.count, 2)
  }

  func testOptionalFields() throws {
    let input = """
      message Test {
        optional string name = 1;
        optional int32 id = 2;
      }
      """

    let file = try parse(input)
    let fields = file.messages[0].fields

    XCTAssertTrue(fields[0].isOptional)
    XCTAssertTrue(fields[1].isOptional)
  }

  func testRequiredFields() throws {
    let input = "message Test { required string name = 1; }"
    XCTAssertThrowsError(try parse(input)) { error in
      guard let error = error as? ParserError else {
        XCTFail("Expected ParserError")
        return
      }

      switch error {
      case .unexpectedToken(_, _):
        return
      default:
        XCTFail("Expected unexpectedToken error, got: \(error)")
      }
    }
  }

  // MARK: - Field Tests

  func testScalarTypeFields() throws {
    let input = """
      message Test {
        double d = 1;
        float f = 2;
        int32 i32 = 3;
        int64 i64 = 4;
        uint32 u32 = 5;
        uint64 u64 = 6;
        sint32 s32 = 7;
        sint64 s64 = 8;
        fixed32 f32 = 9;
        fixed64 f64 = 10;
        sfixed32 sf32 = 11;
        sfixed64 sf64 = 12;
        bool b = 13;
        string s = 14;
        bytes by = 15;
      }
      """
    let file = try parse(input)
    let fields = file.messages[0].fields
    XCTAssertEqual(fields.count, 15)

    // Verify each field type
    if case .scalar(let type) = fields[0].type {
      XCTAssertEqual(type, .double)
    }
    if case .scalar(let type) = fields[1].type {
      XCTAssertEqual(type, .float)
    }
    if case .scalar(let type) = fields[2].type {
      XCTAssertEqual(type, .int32)
    }
    if case .scalar(let type) = fields[3].type {
      XCTAssertEqual(type, .int64)
    }
    if case .scalar(let type) = fields[4].type {
      XCTAssertEqual(type, .uint32)
    }
    if case .scalar(let type) = fields[5].type {
      XCTAssertEqual(type, .uint64)
    }
    if case .scalar(let type) = fields[6].type {
      XCTAssertEqual(type, .sint32)
    }
    if case .scalar(let type) = fields[7].type {
      XCTAssertEqual(type, .sint64)
    }
    if case .scalar(let type) = fields[8].type {
      XCTAssertEqual(type, .fixed32)
    }
    if case .scalar(let type) = fields[9].type {
      XCTAssertEqual(type, .fixed64)
    }
    if case .scalar(let type) = fields[10].type {
      XCTAssertEqual(type, .sfixed32)
    }
    if case .scalar(let type) = fields[11].type {
      XCTAssertEqual(type, .sfixed64)
    }
    if case .scalar(let type) = fields[12].type {
      XCTAssertEqual(type, .bool)
    }
    if case .scalar(let type) = fields[13].type {
      XCTAssertEqual(type, .string)
    }
    if case .scalar(let type) = fields[14].type {
      XCTAssertEqual(type, .bytes)
    }
  }

  func testRepeatedFields() throws {
    let input = """
      message Test {
      	repeated string names = 1;
      	repeated int32 numbers = 2;
      	repeated Test nested = 3;
      }
      """
    let file = try parse(input)
    let fields = file.messages[0].fields
    XCTAssertTrue(fields.allSatisfy { $0.isRepeated })
  }

  func testFieldOptions() throws {
    let input = """
      message Test {
        string name = 1 [deprecated = true];
        int32 id = 2 [packed = true, json_name = "identifier"];
        bool active = 3 [(custom.option) = "value"];
      }
      """
    let file = try parse(input)
    let fields = file.messages[0].fields

    // Check first field - deprecated option
    XCTAssertEqual(fields[0].options.count, 1)
    XCTAssertEqual(fields[0].options[0].name, "deprecated")
    XCTAssertEqual(fields[0].options[0].value, .identifier("true"))

    // Check second field - packed and json_name options
    XCTAssertEqual(fields[1].options.count, 2)
    XCTAssertEqual(fields[1].options[0].name, "packed")
    XCTAssertEqual(fields[1].options[0].value, .identifier("true"))
    XCTAssertEqual(fields[1].options[1].name, "json_name")
    XCTAssertEqual(fields[1].options[1].value, .string("identifier"))

    // Check third field - custom option
    XCTAssertEqual(fields[2].options.count, 1)
    XCTAssertEqual(fields[2].options[0].name, "(custom.option)")
    XCTAssertEqual(fields[2].options[0].value, .string("value"))
  }

  func testFieldNames() throws {
    // Valid field names - these should pass
    let validInputs = [
      "message Test { string field = 1; }",  // Regular name
      "message Test { string Field = 1; }",  // Uppercase first letter
      "message Test { string FIELD = 1; }",  // All uppercase
      "message Test { string _field = 1; }",  // Starts with underscore
      "message Test { string field_name = 1; }",  // With underscore
      "message Test { string field123 = 1; }",  // With numbers
      "message Test { string string = 1; }",  // Type name is valid
      "message Test { string message = 1; }",  // message type keyword is valid
      "message Test { string enum = 1; }",  // enum keyword is valid
      "message Test { string optional = 1; }",  // optional keyword is valid
    ]

    for input in validInputs {
      XCTAssertNoThrow(try parse(input), "Should accept valid field name in: \(input)")
    }

    // Invalid field names - these should fail
    let invalidInputs = [
      "message Test { string syntax = 1; }",  // Reserved keyword
      "message Test { string import = 1; }",  // Reserved keyword
      "message Test { string package = 1; }",  // Reserved keyword
      "message Test { string option = 1; }",  // Reserved keyword
      "message Test { string service = 1; }",  // Reserved keyword
      "message Test { string rpc = 1; }",  // Reserved keyword
      "message Test { string returns = 1; }",  // Reserved keyword
      "message Test { string reserved = 1; }",  // Reserved keyword
      "message Test { string oneof = 1; }",  // Reserved keyword
      "message Test { string repeated = 1; }",  // Reserved keyword
      "message Test { string 123field = 1; }",  // Starts with number
      "message Test { string field-name = 1; }",  // Contains hyphen
      "message Test { string field.name = 1; }",  // Contains dot
      "message Test { string = 1; }",  // Empty name
    ]

    for input in invalidInputs {
      XCTAssertThrowsError(try parse(input))
    }
  }

  func testReservedFieldNumbers() throws {
    let input = """
      message Test {
      	reserved 2, 4, 6;
      	string name = 2;  // Should fail
      }
      """
    XCTAssertThrowsError(try parse(input))
  }

  func testReservedFieldNames() throws {
    let input = """
      message Test {
      	reserved "foo", "bar";
      	string foo = 1;  // Should fail
      }
      """
    XCTAssertThrowsError(try parse(input))
  }

  func testCustomTypeFields() throws {
    let input = """
      message Test {
      	OtherMessage other = 1;
      	nested.Message nested = 2;
      	.fully.qualified.Type qualified = 3;
      }
      """
    let file = try parse(input)
    let fields = file.messages[0].fields

    XCTAssertEqual(fields[0].type, .named("OtherMessage"))
    XCTAssertEqual(fields[1].type, .named("nested.Message"))
    XCTAssertEqual(fields[2].type, .named(".fully.qualified.Type"))

    for field in fields {
      if case .named = field.type {
        // Custom type verified
      }
      else {
        XCTFail("Expected named type")
      }
    }
  }

  func testMapFieldKeyTypes() throws {
    let validInputs = [
      "map<int32, string>",
      "map<int64, string>",
      "map<uint32, string>",
      "map<uint64, string>",
      "map<sint32, string>",
      "map<sint64, string>",
      "map<fixed32, string>",
      "map<fixed64, string>",
      "map<sfixed32, string>",
      "map<sfixed64, string>",
      "map<bool, string>",
      "map<string, string>",
    ]

    let invalidInputs = [
      "map<float, string>",
      "map<double, string>",
      "map<bytes, string>",
      "map<CustomType, string>",
      "map<repeated string, string>",
    ]

    for input in validInputs {
      let testInput = "message Test { \(input) field = 1; }"
      XCTAssertNoThrow(try parse(testInput))
    }

    for input in invalidInputs {
      let testInput = "message Test { \(input) field = 1; }"
      XCTAssertThrowsError(try parse(testInput))
    }
  }

  func testMapFieldValidation() throws {
    let invalidInputs = [
      "message Test { repeated map<string, string> field = 1; }",  // Cannot be repeated
      "message Test { map<string> field = 1; }",  // Missing value type
      "message Test { map<string, oneof> field = 1; }",  // Invalid value type
      "message Test { map<map<string, string>, string> field = 1; }",  // Nested maps
    ]

    for input in invalidInputs {
      XCTAssertThrowsError(try parse(input))
    }
  }

  // MARK: - Enum Tests

  func testBasicEnum() throws {
    let input = """
      enum Status {
      	STATUS_UNKNOWN = 0;
      	STATUS_ACTIVE = 1;
      	STATUS_INACTIVE = 2;
      }
      """

    let file = try parse(input)
    let firstEnum = file.enums[0]

    XCTAssertEqual(firstEnum.values.count, 3)
    XCTAssertEqual(firstEnum.values[0].number, 0)
  }

  func testEnumAllowAlias() throws {
    let input = """
      enum Alias {
      	option allow_alias = true;
      	UNKNOWN = 0;
      	STARTED = 1;
      	RUNNING = 1;  // Alias
      }
      """
    let file = try parse(input)
    XCTAssertEqual(file.enums[0].values.count, 3)
    XCTAssertEqual(file.enums[0].options.count, 1)
    XCTAssertEqual(file.enums[0].options[0].name, "allow_alias")
    XCTAssertEqual(file.enums[0].options[0].value, .identifier("true"))
  }

  func testEnumValueOptions() throws {
    let input = """
      enum Test {
      	UNKNOWN = 0;
      	FIRST = 1 [deprecated = true];
      	SECOND = 2 [(custom_option) = "value"];
      }
      """
    let file = try parse(input)
    let values = file.enums[0].values
    XCTAssertFalse(values[1].options.isEmpty)
    XCTAssertFalse(values[2].options.isEmpty)
  }

  func testInvalidEnumNames() throws {
    let inputs = [
      "enum 123test {}",
      "enum test {}",  // Must start uppercase
      "enum Test$Name {}",
      "enum Test.Name {}",
    ]
    for input in inputs {
      XCTAssertThrowsError(try parse(input))
    }
  }

  func testReservedEnumValues() throws {
    let input = """
      enum Test {
      	reserved 2, 15, 9 to 11;
      	reserved "FOO", "BAR";
      	UNKNOWN = 0;
      	FOO = 2;  // Should fail
      }
      """
    XCTAssertThrowsError(try parse(input))
  }

  func testNestedEnums() throws {
    let input = """
      message Container {
      	enum Status {
      		UNKNOWN = 0;
      		ACTIVE = 1;
      	}
      	Status status = 1;
      }
      """
    let file = try parse(input)
    XCTAssertEqual(file.messages[0].enums.count, 1)
  }

  // MARK: - Service Tests

  func testBasicService() throws {
    let input = """
      service Greeter {
      	rpc SayHello (HelloRequest) returns (HelloResponse);
      }
      """
    let file = try parse(input)
    let service = file.services[0]
    XCTAssertEqual(service.rpcs.count, 1)
    XCTAssertEqual(service.rpcs[0].name, "SayHello")
    XCTAssertFalse(service.rpcs[0].clientStreaming)
    XCTAssertFalse(service.rpcs[0].serverStreaming)
  }

  func testStreamingRPC() throws {
    let input = """
      service StreamService {
      	rpc ClientStream (stream Request) returns (Response);
      	rpc ServerStream (Request) returns (stream Response);
      	rpc BidiStream (stream Request) returns (stream Response);
      }
      """
    let file = try parse(input)
    let service = file.services[0]
    XCTAssertTrue(service.rpcs[0].clientStreaming)
    XCTAssertTrue(service.rpcs[1].serverStreaming)
    XCTAssertTrue(service.rpcs[2].clientStreaming && service.rpcs[2].serverStreaming)
  }

  func testServiceOptions() throws {
    let input = """
      service Test {
      	option deprecated = true;
      	option (custom.option) = "value";
      	rpc Method (Request) returns (Response);
      }
      """
    let file = try parse(input)
    XCTAssertFalse(file.services[0].options.isEmpty)
  }

  func testRPCOptions() throws {
    let input = """
      service Test {
      	rpc Method (Request) returns (Response) {
      		option deprecated = true;
      		option idempotency_level = IDEMPOTENT;
      	}
      }
      """
    let file = try parse(input)
    XCTAssertFalse(file.services[0].rpcs[0].options.isEmpty)
  }

  func testInvalidServiceName() throws {
    let inputs = [
      "service 123test {}",
      "service test {}",  // Must start uppercase
      "service Test$Name {}",
      "service Test.Name {}",
    ]
    for input in inputs {
      XCTAssertThrowsError(try parse(input))
    }
  }

  func testInvalidMethodName() throws {
    let inputs = [
      "rpc 123method",
      "rpc Method$Name",
      "rpc Method.Name",
    ]
    for name in inputs {
      let input = """
        service Test {
        	\(name) (Request) returns (Response);
        }
        """
      XCTAssertThrowsError(try parse(input))
    }
  }

  func testEmptyService() throws {
    let input = "service Empty {}"
    let file = try parse(input)
    XCTAssertTrue(file.services[0].rpcs.isEmpty)
  }

  func testInvalidStreamDeclaration() throws {
    let inputs = [
      "rpc Method (stream) returns (Response);",
      "rpc Method (Request) returns (stream);",
      "rpc Method (stream stream Request) returns (Response);",
      "rpc Method (Request) returns (stream stream Response);",
    ]
    for rpc in inputs {
      let input = """
        service Test {
        	\(rpc)
        }
        """
      XCTAssertThrowsError(try parse(input))
    }
  }

  func testMissingTypes() throws {
    let inputs = [
      "rpc Method () returns (Response);",
      "rpc Method (Request) returns ();",
      "rpc Method (stream) returns (Response);",
      "rpc Method (Request) returns (stream);",
    ]
    for rpc in inputs {
      let input = """
        service Test {
        	\(rpc)
        }
        """
      XCTAssertThrowsError(try parse(input))
    }
  }

  // MARK: - Option Tests

  func testFileOptions() throws {
    let input = """
      syntax = "proto3";
      option java_package = "com.example.foo";
      option java_outer_classname = "Foo";
      option optimize_for = SPEED;
      option go_package = "foo";
      option (custom.file_option) = true;
      """
    let file = try parse(input)
    XCTAssertEqual(file.options.count, 5)
  }

  func testMessageOptions() throws {
    let input = """
      message Test {
      	option message_set_wire_format = true;
      	option deprecated = true;
      	option (custom.message_option) = "value";
      	string name = 1;
      }
      """
    let file = try parse(input)
    XCTAssertEqual(file.messages[0].options.count, 3)
  }

  func testNestedOptions() throws {
    let input = """
      option (my_option) = {
      	string_field: "hello"
      	int_field: 42
      	nested_field: {
      		a: 1
      		b: 2
      	}
      };
      """
    let file = try parse(input)
    let option = file.options[0]
    if case .map(let fields) = option.value {
      XCTAssertEqual(fields.count, 3)
    }
    else {
      XCTFail("Expected map value")
    }
  }

  func testArrayOptionValue() throws {
    let input = """
      message Test {
      	string name = 1 [(custom.list) = ["a", "b", "c"]];
      }
      """
    let file = try parse(input)
    let option = file.messages[0].fields[0].options[0]
    if case .array(let values) = option.value {
      XCTAssertEqual(values.count, 3)
    }
    else {
      XCTFail("Expected array value")
    }
  }

  func testInvalidOptionNames() throws {
    let inputs = [
      "option 123invalid = true;",
      "option (123.invalid) = true;",
      "option (invalid.) = true;",
    ]
    for input in inputs {
      XCTAssertThrowsError(try parse(input))
    }
  }

  func testIncompleteOptions() throws {
    let inputs = [
      "option = true;",
      "option name =;",
      "option name true;",
      "option (custom.) = true;",
    ]
    for input in inputs {
      XCTAssertThrowsError(try parse(input))
    }
  }

  // MARK: - Corner Cases Tests

  //  func testLongIdentifiers() throws {
  //    let longName = String(repeating: "a", count: 1000)
  //    let input = """
  //      message \(longName) {
  //      	string \(longName) = 1;
  //      }
  //      """
  //    let file = try parse(input)
  //    XCTAssertEqual(file.messages[0].name, longName)
  //    XCTAssertEqual(file.messages[0].fields[0].name, longName)
  //  }

  func testComplexTypeReferences() throws {
    let input = """
      message Test {
      	.foo.bar.Baz field1 = 1;
      	foo.bar.Baz field2 = 2;
      	Baz field3 = 3;
      	.Baz field4 = 4;
      }
      """
    let file = try parse(input)
    let fields = file.messages[0].fields
    XCTAssertEqual(fields.count, 4)
    for field in fields {
      if case .named = field.type {
        // Type reference verified
      }
      else {
        XCTFail("Expected named type")
      }
    }
  }

  func testCircularDependencies() throws {
    let input = """
      message A {
      	B b = 1;
      }
      message B {
      	A a = 1;
      }
      """
    let file = try parse(input)
    XCTAssertEqual(file.messages.count, 2)
  }

  func testUnicodeInNames() throws {
    let inputs = [
      "message 测试 {}",
      "message Test { string 名前 = 1; }",
      "enum テスト {}",
    ]

    for input in inputs {
      XCTAssertThrowsError(try parse(input))
    }
  }

  func testWhitespaceHandling() throws {
    let input = """
      message\tTest\t{\n
      	string\t\tname\t=\t1\t;\n
      	int32\t\tid\t=\t2\t;\n
      }\n
      """
    let file = try parse(input)
    XCTAssertEqual(file.messages[0].fields.count, 2)
  }

  func testIncompleteInput() throws {
    let inputs = [
      "message Test {",
      "enum Status {",
      "service Test {",
      "message Test { string name = ",
      "message Test { oneof test {",
      "message Test { map<string,",
    ]

    for input in inputs {
      XCTAssertThrowsError(try parse(input))
    }
  }
}
