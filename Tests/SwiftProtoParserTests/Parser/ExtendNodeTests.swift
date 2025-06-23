import XCTest
@testable import SwiftProtoParser

final class ExtendNodeTests: XCTestCase {

  // MARK: - Initialization Tests

  func testExtendNodeInitialization() {
    let position = Token.Position(line: 1, column: 1)
    let field = FieldNode(name: "test_field", type: .string, number: 50001)
    let option = OptionNode(name: "deprecated", value: .boolean(true))
    
    let extend = ExtendNode(
      extendedType: "google.protobuf.FileOptions",
      fields: [field],
      options: [option],
      position: position
    )
    
    XCTAssertEqual(extend.extendedType, "google.protobuf.FileOptions")
    XCTAssertEqual(extend.fields.count, 1)
    XCTAssertEqual(extend.fields[0].name, "test_field")
    XCTAssertEqual(extend.options.count, 1)
    XCTAssertEqual(extend.options[0].name, "deprecated")
    XCTAssertEqual(extend.position.line, 1)
    XCTAssertEqual(extend.position.column, 1)
  }
  
  func testExtendNodeEmptyInitialization() {
    let position = Token.Position(line: 5, column: 10)
    
    let extend = ExtendNode(
      extendedType: "google.protobuf.MessageOptions",
      position: position
    )
    
    XCTAssertEqual(extend.extendedType, "google.protobuf.MessageOptions")
    XCTAssertEqual(extend.fields.count, 0)
    XCTAssertEqual(extend.options.count, 0)
    XCTAssertEqual(extend.position.line, 5)
    XCTAssertEqual(extend.position.column, 10)
  }

  // MARK: - Field Management Tests
  
  func testUsedFieldNumbers() {
    let position = Token.Position(line: 1, column: 1)
    let field1 = FieldNode(name: "field1", type: .string, number: 50001)
    let field2 = FieldNode(name: "field2", type: .int32, number: 50002)
    let field3 = FieldNode(name: "field3", type: .bool, number: 50003)
    
    let extend = ExtendNode(
      extendedType: "google.protobuf.FileOptions",
      fields: [field1, field2, field3],
      position: position
    )
    
    let usedNumbers = extend.usedFieldNumbers
    XCTAssertEqual(usedNumbers.count, 3)
    XCTAssertTrue(usedNumbers.contains(50001))
    XCTAssertTrue(usedNumbers.contains(50002))
    XCTAssertTrue(usedNumbers.contains(50003))
  }
  
  func testUsedFieldNames() {
    let position = Token.Position(line: 1, column: 1)
    let field1 = FieldNode(name: "custom_option", type: .string, number: 50001)
    let field2 = FieldNode(name: "version", type: .int32, number: 50002)
    let field3 = FieldNode(name: "enabled", type: .bool, number: 50003)
    
    let extend = ExtendNode(
      extendedType: "google.protobuf.MessageOptions",
      fields: [field1, field2, field3],
      position: position
    )
    
    let usedNames = extend.usedFieldNames
    XCTAssertEqual(usedNames.count, 3)
    XCTAssertTrue(usedNames.contains("custom_option"))
    XCTAssertTrue(usedNames.contains("version"))
    XCTAssertTrue(usedNames.contains("enabled"))
  }
  
  func testFieldByName() {
    let position = Token.Position(line: 1, column: 1)
    let field1 = FieldNode(name: "target_field", type: .string, number: 50001)
    let field2 = FieldNode(name: "other_field", type: .int32, number: 50002)
    
    let extend = ExtendNode(
      extendedType: "google.protobuf.FieldOptions",
      fields: [field1, field2],
      position: position
    )
    
    let foundField = extend.field(named: "target_field")
    XCTAssertNotNil(foundField)
    XCTAssertEqual(foundField?.name, "target_field")
    XCTAssertEqual(foundField?.number, 50001)
    
    let notFoundField = extend.field(named: "nonexistent_field")
    XCTAssertNil(notFoundField)
  }
  
  func testFieldByNumber() {
    let position = Token.Position(line: 1, column: 1)
    let field1 = FieldNode(name: "field1", type: .string, number: 50001)
    let field2 = FieldNode(name: "field2", type: .int32, number: 50002)
    
    let extend = ExtendNode(
      extendedType: "google.protobuf.EnumValueOptions",
      fields: [field1, field2],
      position: position
    )
    
    let foundField = extend.field(withNumber: 50002)
    XCTAssertNotNil(foundField)
    XCTAssertEqual(foundField?.name, "field2")
    XCTAssertEqual(foundField?.number, 50002)
    
    let notFoundField = extend.field(withNumber: 99999)
    XCTAssertNil(notFoundField)
  }

  // MARK: - Proto3 Validation Tests
  
  func testValidProto3ExtendTargets() {
    let position = Token.Position(line: 1, column: 1)
    
    let validTargets = [
      "google.protobuf.FileOptions",
      "google.protobuf.MessageOptions", 
      "google.protobuf.FieldOptions",
      "google.protobuf.EnumOptions",
      "google.protobuf.EnumValueOptions",
      "google.protobuf.ServiceOptions",
      "google.protobuf.MethodOptions"
    ]
    
    for target in validTargets {
      let extend = ExtendNode(extendedType: target, position: position)
      XCTAssertTrue(extend.isValidProto3ExtendTarget, "Target \(target) should be valid for proto3 extend")
    }
  }
  
  func testInvalidProto3ExtendTargets() {
    let position = Token.Position(line: 1, column: 1)
    
    let invalidTargets = [
      "UserMessage",
      "com.example.CustomMessage",
      "SomeOtherType",
      "google.protobuf",  // incomplete
      "protobuf.FileOptions",  // missing google.
      "custom.protobuf.FileOptions"  // wrong prefix
    ]
    
    for target in invalidTargets {
      let extend = ExtendNode(extendedType: target, position: position)
      XCTAssertFalse(extend.isValidProto3ExtendTarget, "Target \(target) should be invalid for proto3 extend")
    }
  }
  
  func testCanonicalExtendedType() {
    let position = Token.Position(line: 1, column: 1)
    let extend = ExtendNode(
      extendedType: "google.protobuf.FileOptions",
      position: position
    )
    
    XCTAssertEqual(extend.canonicalExtendedType, "google.protobuf.FileOptions")
  }

  // MARK: - Equatable Tests
  
  func testExtendNodeEquality() {
    let position = Token.Position(line: 1, column: 1)
    let field = FieldNode(name: "test_field", type: .string, number: 50001)
    let option = OptionNode(name: "deprecated", value: .boolean(true))
    
    let extend1 = ExtendNode(
      extendedType: "google.protobuf.FileOptions",
      fields: [field],
      options: [option],
      position: position
    )
    
    let extend2 = ExtendNode(
      extendedType: "google.protobuf.FileOptions", 
      fields: [field],
      options: [option],
      position: position
    )
    
    XCTAssertEqual(extend1, extend2)
  }
  
  func testExtendNodeInequality() {
    let position = Token.Position(line: 1, column: 1)
    let field = FieldNode(name: "test_field", type: .string, number: 50001)
    
    let extend1 = ExtendNode(
      extendedType: "google.protobuf.FileOptions",
      fields: [field],
      position: position
    )
    
    let extend2 = ExtendNode(
      extendedType: "google.protobuf.MessageOptions", // Different type
      fields: [field],
      position: position
    )
    
    XCTAssertNotEqual(extend1, extend2)
  }

  // MARK: - CustomStringConvertible Tests
  
  func testStringDescription() {
    let position = Token.Position(line: 1, column: 1)
    let field = FieldNode(name: "my_option", type: .string, number: 50001, label: .optional)
    let option = OptionNode(name: "deprecated", value: .boolean(true))
    
    let extend = ExtendNode(
      extendedType: "google.protobuf.FileOptions",
      fields: [field],
      options: [option],
      position: position
    )
    
    let description = extend.description
    
    XCTAssertTrue(description.contains("extend google.protobuf.FileOptions {"))
    XCTAssertTrue(description.contains("option deprecated = true;"))
    XCTAssertTrue(description.contains("optional string my_option = 50001;"))
    XCTAssertTrue(description.contains("}"))
  }
  
  func testEmptyExtendStringDescription() {
    let position = Token.Position(line: 1, column: 1)
    let extend = ExtendNode(
      extendedType: "google.protobuf.MessageOptions",
      position: position
    )
    
    let description = extend.description
    
    XCTAssertEqual(description, "extend google.protobuf.MessageOptions {\n}")
  }

  // MARK: - Edge Cases Tests
  
  func testLargeFieldNumbers() {
    let position = Token.Position(line: 1, column: 1)
    let field1 = FieldNode(name: "field1", type: .string, number: 536870911) // Max valid field number
    let field2 = FieldNode(name: "field2", type: .int32, number: 50000)
    
    let extend = ExtendNode(
      extendedType: "google.protobuf.FileOptions",
      fields: [field1, field2],
      position: position
    )
    
    let usedNumbers = extend.usedFieldNumbers
    XCTAssertTrue(usedNumbers.contains(536870911))
    XCTAssertTrue(usedNumbers.contains(50000))
  }
  
  func testDuplicateFieldNames() {
    // Note: This tests the data structure, not validation
    // Validation should be done at the parser level
    let position = Token.Position(line: 1, column: 1)
    let field1 = FieldNode(name: "duplicate", type: .string, number: 50001)
    let field2 = FieldNode(name: "duplicate", type: .int32, number: 50002)
    
    let extend = ExtendNode(
      extendedType: "google.protobuf.FileOptions",
      fields: [field1, field2],
      position: position
    )
    
    // Should return the first field with that name
    let foundField = extend.field(named: "duplicate")
    XCTAssertEqual(foundField?.number, 50001)
    XCTAssertEqual(foundField?.type, .string)
  }
  
  func testEmptyExtendedType() {
    let position = Token.Position(line: 1, column: 1)
    let extend = ExtendNode(extendedType: "", position: position)
    
    XCTAssertFalse(extend.isValidProto3ExtendTarget)
    XCTAssertEqual(extend.canonicalExtendedType, "")
  }

  // MARK: - Debug Parser Tests
  
  func testExtendWithCustomOptions() {
    let content = """
    syntax = "proto3";

    extend google.protobuf.ServiceOptions {
      optional string service_version = 50008;
    }

    service TestService {
      option (service_version) = "v1.0";
    }
    """
    
    let result = SwiftProtoParser.parseProtoString(content)
    
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.extends.count, 1, "Should parse one extend statement")
      XCTAssertEqual(ast.services.count, 1, "Should parse one service")
      let service = ast.services[0]
      XCTAssertEqual(service.options.count, 1, "Service should have one option")
      
    case .failure(let error):
      XCTFail("Failed to parse extend with custom options: \(error)")
    }
  }
  
  func testExtendWithRPCMethodOptions() {
    let content = """
    syntax = "proto3";

    extend google.protobuf.MethodOptions {
      optional bool requires_auth = 50009;
    }

    message TestMessage {
      string name = 1;
    }

    service TestService {
      rpc GetUser(TestMessage) returns (TestMessage) {
        option (requires_auth) = true;
      }
    }
    """
    
    let result = SwiftProtoParser.parseProtoString(content)
    
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.extends.count, 1, "Should parse one extend statement")
      XCTAssertEqual(ast.services.count, 1, "Should parse one service")
      XCTAssertEqual(ast.messages.count, 1, "Should parse one message")
      
      let service = ast.services[0]
      XCTAssertEqual(service.methods.count, 1, "Service should have one method")
      let method = service.methods[0]
      XCTAssertEqual(method.options.count, 1, "Method should have one option")
      
    case .failure(let error):
      XCTFail("Failed to parse extend with RPC method options: \(error)")
    }
  }
  
  func testFullCustomOptionsFlow() {
    let content = """
    syntax = "proto3";

    import "google/protobuf/descriptor.proto";

    extend google.protobuf.FileOptions {
      optional string my_file_option = 50001;
    }

    extend google.protobuf.MethodOptions {
      optional bool requires_auth = 50009;
    }

    option (my_file_option) = "test_file";

    message TestMessage {
      string name = 1;
    }

    service TestService {
      rpc GetUser(TestMessage) returns (TestMessage) {
        option (requires_auth) = true;
      }
    }
    """
    
    let result = SwiftProtoParser.parseProtoString(content)
    
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.extends.count, 2, "Should parse two extend statements")
      XCTAssertEqual(ast.services.count, 1, "Should parse one service")
      XCTAssertEqual(ast.messages.count, 1, "Should parse one message")
      
    case .failure(let error):
      XCTFail("Failed to parse full custom options flow: \(error)")
    }
  }
  
  func testInvalidExtendValidation() {
    let content = """
    syntax = "proto3";

    message UserMessage {
      string name = 1;
    }

    // This should be INVALID in proto3 - only google.protobuf.* allowed
    extend UserMessage {
      optional string email = 100;
    }
    """
    
    let result = SwiftProtoParser.parseProtoString(content)
    
    switch result {
    case .success(let ast):
      // Parser should parse the structure but mark it as invalid
      XCTAssertEqual(ast.extends.count, 1, "Should parse the extend statement")
      let extend = ast.extends[0]
      XCTAssertEqual(extend.extendedType, "UserMessage")
      XCTAssertFalse(extend.isValidProto3ExtendTarget, "UserMessage extend should be INVALID in proto3")
      
    case .failure(let error):
      // Should fail with validation error
      XCTAssertTrue(error.localizedDescription.contains("extend"), "Error should mention extend validation")
    }
  }
  
  func testValidGoogleProtobufExtend() {
    let content = """
    syntax = "proto3";

    // This should be VALID in proto3
    extend google.protobuf.FileOptions {
      optional string my_option = 50001;
    }
    """
    
    let result = SwiftProtoParser.parseProtoString(content)
    
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.extends.count, 1, "Should parse the extend statement")
      let extend = ast.extends[0]
      XCTAssertEqual(extend.extendedType, "google.protobuf.FileOptions")
      XCTAssertTrue(extend.isValidProto3ExtendTarget, "google.protobuf.FileOptions extend should be VALID in proto3")
      
    case .failure(let error):
      XCTFail("Valid google.protobuf extend should not fail: \(error)")
    }
  }
  
  func testSimpleExtendParsing() {
    let content = """
    syntax = "proto3";

    extend google.protobuf.FileOptions {
      optional string my_option = 50001;
    }
    """
    
    let result = SwiftProtoParser.parseProtoString(content)
    
    switch result {
    case .success(let ast):
      XCTAssertEqual(ast.extends.count, 1, "Should parse one extend statement")
      let extend = ast.extends[0]
      XCTAssertEqual(extend.extendedType, "google.protobuf.FileOptions")
      XCTAssertEqual(extend.fields.count, 1)
      XCTAssertEqual(extend.fields[0].name, "my_option")
      XCTAssertEqual(extend.fields[0].number, 50001)
      
    case .failure(let error):
      XCTFail("Failed to parse simple extend: \(error)")
    }
  }

  // MARK: - Complex Scenarios Tests
  
  func testComplexExtendWithMultipleFields() {
    let position = Token.Position(line: 10, column: 5)
    
    let fields = [
      FieldNode(name: "string_option", type: .string, number: 50001, label: .optional),
      FieldNode(name: "int_option", type: .int32, number: 50002, label: .optional),
      FieldNode(name: "bool_option", type: .bool, number: 50003, label: .optional),
      FieldNode(name: "message_option", type: .message("MyMessage"), number: 50004, label: .optional)
    ]
    
    let options = [
      OptionNode(name: "deprecated", value: .boolean(true)),
      OptionNode(name: "go_package", value: .string("github.com/example/proto"))
    ]
    
    let extend = ExtendNode(
      extendedType: "google.protobuf.FileOptions",
      fields: fields,
      options: options,
      position: position
    )
    
    // Test field access
    XCTAssertEqual(extend.usedFieldNumbers.count, 4)
    XCTAssertEqual(extend.usedFieldNames.count, 4)
    
    // Test specific field lookups
    XCTAssertNotNil(extend.field(named: "string_option"))
    XCTAssertNotNil(extend.field(withNumber: 50004))
    
    // Test validation
    XCTAssertTrue(extend.isValidProto3ExtendTarget)
    
    // Test description contains all elements
    let description = extend.description
    XCTAssertTrue(description.contains("string_option"))
    XCTAssertTrue(description.contains("deprecated"))
    XCTAssertTrue(description.contains("google.protobuf.FileOptions"))
  }
}
