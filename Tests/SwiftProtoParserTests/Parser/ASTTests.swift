import XCTest

@testable import SwiftProtoParser

final class ASTTests: XCTestCase {

  // MARK: - ProtoAST Tests

  func testProtoASTInitialization() {
    let ast = ProtoAST(syntax: .proto3)

    XCTAssertEqual(ast.syntax, .proto3)
    XCTAssertNil(ast.package)
    XCTAssertTrue(ast.imports.isEmpty)
    XCTAssertTrue(ast.options.isEmpty)
    XCTAssertTrue(ast.messages.isEmpty)
    XCTAssertTrue(ast.enums.isEmpty)
    XCTAssertTrue(ast.services.isEmpty)
  }

  func testProtoASTEquality() {
    let ast1 = ProtoAST(syntax: .proto3, package: "com.example")
    let ast2 = ProtoAST(syntax: .proto3, package: "com.example")
    let ast3 = ProtoAST(syntax: .proto3, package: "com.other")

    XCTAssertEqual(ast1, ast2)
    XCTAssertNotEqual(ast1, ast3)
  }

  func testProtoASTDescription() {
    let option = OptionNode(name: "java_package", value: .string("com.example"))
    let ast = ProtoAST(
      syntax: .proto3,
      package: "com.example",
      imports: ["test.proto"],
      options: [option]
    )

    let description = ast.description
    XCTAssertTrue(description.contains("syntax ="))
    XCTAssertTrue(description.contains("package com.example;"))
    XCTAssertTrue(description.contains("import \"test.proto\";"))
    XCTAssertTrue(description.contains("java_package"))
  }

  // MARK: - FieldType Tests

  func testAllScalarFieldTypes() {
    let allScalarTypes: [FieldType] = [
      .double, .float, .int32, .int64, .uint32, .uint64,
      .sint32, .sint64, .fixed32, .fixed64, .sfixed32, .sfixed64,
      .bool, .string, .bytes,
    ]

    for scalarType in allScalarTypes {
      XCTAssertTrue(scalarType.isScalar, "\(scalarType) should be scalar")
    }
  }

  func testAllNumericFieldTypes() {
    let numericTypes: [FieldType] = [
      .double, .float, .int32, .int64, .uint32, .uint64,
      .sint32, .sint64, .fixed32, .fixed64, .sfixed32, .sfixed64,
    ]

    let nonNumericTypes: [FieldType] = [
      .bool, .string, .bytes, .message("Test"), .enumType("Status"), .map(key: .string, value: .int32),
    ]

    for numericType in numericTypes {
      XCTAssertTrue(numericType.isNumeric, "\(numericType) should be numeric")
    }

    for nonNumericType in nonNumericTypes {
      XCTAssertFalse(nonNumericType.isNumeric, "\(nonNumericType) should not be numeric")
    }
  }

  func testComplexFieldTypes() {
    let messageType = FieldType.message("User")
    let enumType = FieldType.enumType("Status")
    let mapType = FieldType.map(key: .string, value: .int32)

    XCTAssertFalse(messageType.isScalar)
    XCTAssertFalse(enumType.isScalar)
    XCTAssertFalse(mapType.isScalar)

    XCTAssertFalse(messageType.isNumeric)
    XCTAssertFalse(enumType.isNumeric)
    XCTAssertFalse(mapType.isNumeric)

    if case .message(let typeName) = messageType {
      XCTAssertEqual(typeName, "User")
    }
    else {
      XCTFail("Expected message type")
    }

    if case .enumType(let typeName) = enumType {
      XCTAssertEqual(typeName, "Status")
    }
    else {
      XCTFail("Expected enum type")
    }

    if case .map(let keyType, let valueType) = mapType {
      XCTAssertEqual(keyType, .string)
      XCTAssertEqual(valueType, .int32)
    }
    else {
      XCTFail("Expected map type")
    }
  }

  func testNestedMapTypes() {
    let nestedMapType = FieldType.map(
      key: .string,
      value: .map(key: .int32, value: .bool)
    )

    XCTAssertFalse(nestedMapType.isScalar)
    XCTAssertFalse(nestedMapType.isNumeric)

    if case .map(let keyType, let valueType) = nestedMapType {
      XCTAssertEqual(keyType, .string)
      if case .map(let innerKey, let innerValue) = valueType {
        XCTAssertEqual(innerKey, .int32)
        XCTAssertEqual(innerValue, .bool)
      }
      else {
        XCTFail("Expected nested map in value type")
      }
    }
    else {
      XCTFail("Expected map type")
    }
  }

  func testFieldTypeProtoTypeName() {
    // Test all scalar types
    XCTAssertEqual(FieldType.double.protoTypeName, "double")
    XCTAssertEqual(FieldType.float.protoTypeName, "float")
    XCTAssertEqual(FieldType.int32.protoTypeName, "int32")
    XCTAssertEqual(FieldType.int64.protoTypeName, "int64")
    XCTAssertEqual(FieldType.uint32.protoTypeName, "uint32")
    XCTAssertEqual(FieldType.uint64.protoTypeName, "uint64")
    XCTAssertEqual(FieldType.sint32.protoTypeName, "sint32")
    XCTAssertEqual(FieldType.sint64.protoTypeName, "sint64")
    XCTAssertEqual(FieldType.fixed32.protoTypeName, "fixed32")
    XCTAssertEqual(FieldType.fixed64.protoTypeName, "fixed64")
    XCTAssertEqual(FieldType.sfixed32.protoTypeName, "sfixed32")
    XCTAssertEqual(FieldType.sfixed64.protoTypeName, "sfixed64")
    XCTAssertEqual(FieldType.bool.protoTypeName, "bool")
    XCTAssertEqual(FieldType.string.protoTypeName, "string")
    XCTAssertEqual(FieldType.bytes.protoTypeName, "bytes")

    // Test complex types
    XCTAssertEqual(FieldType.message("User").protoTypeName, "User")
    XCTAssertEqual(FieldType.enumType("Status").protoTypeName, "Status")
    XCTAssertEqual(FieldType.map(key: .string, value: .int32).protoTypeName, "map<string, int32>")
    XCTAssertEqual(FieldType.map(key: .int64, value: .message("Person")).protoTypeName, "map<int64, Person>")
  }

  func testFieldTypeDescription() {
    // Test that description matches protoTypeName
    let testTypes: [FieldType] = [
      .string, .int32, .bool, .double, .float, .bytes,
      .message("User"), .enumType("Status"),
      .map(key: .string, value: .int32),
    ]

    for fieldType in testTypes {
      XCTAssertEqual(
        fieldType.description,
        fieldType.protoTypeName,
        "Description should match protoTypeName for \(fieldType)"
      )
    }
  }

  func testFieldTypeEquality() {
    // Test scalar equality
    XCTAssertEqual(FieldType.string, FieldType.string)
    XCTAssertEqual(FieldType.int32, FieldType.int32)
    XCTAssertNotEqual(FieldType.string, FieldType.int32)
    XCTAssertNotEqual(FieldType.int32, FieldType.int64)

    // Test complex type equality
    XCTAssertEqual(FieldType.message("Test"), FieldType.message("Test"))
    XCTAssertNotEqual(FieldType.message("Test1"), FieldType.message("Test2"))
    XCTAssertEqual(FieldType.enumType("Status"), FieldType.enumType("Status"))
    XCTAssertNotEqual(FieldType.enumType("Status1"), FieldType.enumType("Status2"))

    // Test map equality
    let map1 = FieldType.map(key: .string, value: .int32)
    let map2 = FieldType.map(key: .string, value: .int32)
    let map3 = FieldType.map(key: .string, value: .int64)
    let map4 = FieldType.map(key: .int32, value: .int32)

    XCTAssertEqual(map1, map2)
    XCTAssertNotEqual(map1, map3)
    XCTAssertNotEqual(map1, map4)

    // Test mixed type inequality
    XCTAssertNotEqual(FieldType.string, FieldType.message("string"))
    XCTAssertNotEqual(FieldType.enumType("Test"), FieldType.message("Test"))
    XCTAssertNotEqual(FieldType.map(key: .string, value: .int32), FieldType.message("Map"))
  }

  func testFieldTypeAdvanced() {
    // Test all scalar types
    let scalarTypes: [FieldType] = [
      .double, .float, .int32, .int64, .uint32, .uint64,
      .sint32, .sint64, .fixed32, .fixed64, .sfixed32, .sfixed64,
      .bool, .string, .bytes,
    ]

    for type in scalarTypes {
      XCTAssertFalse(type.description.isEmpty)
      XCTAssertFalse(type.protoTypeName.isEmpty)
    }

    // Test message type
    let messageType = FieldType.message("MyMessage")
    XCTAssertEqual(messageType.protoTypeName, "MyMessage")

    // Test map type
    let mapType = FieldType.map(key: .string, value: .message("Value"))
    XCTAssertTrue(mapType.description.contains("map<"))
    XCTAssertTrue(mapType.description.contains("string"))
    XCTAssertTrue(mapType.description.contains("Value"))
  }

  // MARK: - FieldLabel Tests

  func testFieldLabels() {
    XCTAssertEqual(FieldLabel.singular.description, "")
    XCTAssertEqual(FieldLabel.optional.description, "optional")
    XCTAssertEqual(FieldLabel.repeated.description, "repeated")

    XCTAssertTrue(FieldLabel.repeated.allowsMultipleValues)
    XCTAssertFalse(FieldLabel.singular.allowsMultipleValues)
    XCTAssertFalse(FieldLabel.optional.allowsMultipleValues)
  }

  func testFieldLabelDescription() {
    XCTAssertEqual(FieldLabel.singular.description, "")
    XCTAssertEqual(FieldLabel.optional.description, "optional")
    XCTAssertEqual(FieldLabel.repeated.description, "repeated")
  }

  // MARK: - FieldNode Tests

  func testFieldNodeBasic() {
    let field = FieldNode(
      name: "name",
      type: .string,
      number: 1
    )

    XCTAssertEqual(field.name, "name")
    XCTAssertEqual(field.type, .string)
    XCTAssertEqual(field.number, 1)
    XCTAssertEqual(field.label, .singular)
    XCTAssertTrue(field.options.isEmpty)
    XCTAssertFalse(field.isRepeated)
    XCTAssertFalse(field.isOptional)
    XCTAssertTrue(field.hasValidFieldNumber)
  }

  func testFieldNodeRepeated() {
    let field = FieldNode(
      name: "tags",
      type: .string,
      number: 5,
      label: .repeated
    )

    XCTAssertTrue(field.isRepeated)
    XCTAssertFalse(field.isOptional)
    XCTAssertEqual(field.label, .repeated)
  }

  func testFieldNodeWithOptions() {
    let option = OptionNode(name: "deprecated", value: .boolean(true))
    let field = FieldNode(
      name: "old_field",
      type: .string,
      number: 100,
      options: [option]
    )

    XCTAssertEqual(field.options.count, 1)
    XCTAssertEqual(field.options.first?.name, "deprecated")
  }

  func testFieldNodeDescription() {
    let field = FieldNode(name: "name", type: .string, number: 1)
    let description = field.description

    XCTAssertTrue(description.contains("string"))
    XCTAssertTrue(description.contains("name"))
    XCTAssertTrue(description.contains("1"))
    XCTAssertTrue(description.contains(";"))
  }

  // MARK: - MessageNode Tests

  func testMessageNodeBasic() {
    let field = FieldNode(name: "name", type: .string, number: 1)
    let message = MessageNode(name: "User", fields: [field])

    XCTAssertEqual(message.name, "User")
    XCTAssertEqual(message.fields.count, 1)
    XCTAssertTrue(message.nestedMessages.isEmpty)
    XCTAssertTrue(message.nestedEnums.isEmpty)
    XCTAssertTrue(message.options.isEmpty)

    XCTAssertEqual(message.usedFieldNumbers, [1])
    XCTAssertEqual(message.usedFieldNames, ["name"])

    XCTAssertNotNil(message.field(named: "name"))
    XCTAssertNotNil(message.field(withNumber: 1))
    XCTAssertNil(message.field(named: "nonexistent"))
  }

  func testMessageNodeDescription() {
    let field = FieldNode(name: "name", type: .string, number: 1)
    let message = MessageNode(name: "User", fields: [field])
    let description = message.description

    XCTAssertTrue(description.contains("message User"))
    XCTAssertTrue(description.contains("string name = 1"))
  }

  // MARK: - EnumNode Tests

  func testEnumValueNode() {
    let enumValue = EnumValueNode(name: "ACTIVE", number: 1)

    XCTAssertEqual(enumValue.name, "ACTIVE")
    XCTAssertEqual(enumValue.number, 1)
    XCTAssertTrue(enumValue.options.isEmpty)

    let description = enumValue.description
    XCTAssertTrue(description.contains("ACTIVE"))
    XCTAssertTrue(description.contains("1"))
  }

  func testEnumNode() {
    let value1 = EnumValueNode(name: "UNKNOWN", number: 0)
    let value2 = EnumValueNode(name: "ACTIVE", number: 1)
    let enumNode = EnumNode(name: "Status", values: [value1, value2])

    XCTAssertEqual(enumNode.name, "Status")
    XCTAssertEqual(enumNode.values.count, 2)
    XCTAssertTrue(enumNode.hasZeroValue)

    XCTAssertNotNil(enumNode.value(named: "ACTIVE"))
    XCTAssertNotNil(enumNode.value(withNumber: 0))
    XCTAssertNil(enumNode.value(named: "NONEXISTENT"))

    let description = enumNode.description
    XCTAssertTrue(description.contains("enum Status"))
    XCTAssertTrue(description.contains("ACTIVE = 1"))
  }

  // MARK: - ServiceNode Tests

  func testRPCMethodNode() {
    let method = RPCMethodNode(
      name: "GetUser",
      inputType: "UserRequest",
      outputType: "User"
    )

    XCTAssertEqual(method.name, "GetUser")
    XCTAssertEqual(method.inputType, "UserRequest")
    XCTAssertEqual(method.outputType, "User")
    XCTAssertFalse(method.inputStreaming)
    XCTAssertFalse(method.outputStreaming)
    XCTAssertEqual(method.streamingType, .unary)

    let description = method.description
    XCTAssertTrue(description.contains("rpc GetUser"))
    XCTAssertTrue(description.contains("UserRequest"))
    XCTAssertTrue(description.contains("returns"))
    XCTAssertTrue(description.contains("User"))
  }

  func testRPCMethodStreaming() {
    let method = RPCMethodNode(
      name: "StreamData",
      inputType: "Request",
      outputType: "Response",
      inputStreaming: true,
      outputStreaming: true
    )

    XCTAssertTrue(method.inputStreaming)
    XCTAssertTrue(method.outputStreaming)
    XCTAssertEqual(method.streamingType, .bidirectionalStreaming)
  }

  func testServiceNode() {
    let method = RPCMethodNode(name: "GetUser", inputType: "Request", outputType: "Response")
    let service = ServiceNode(name: "UserService", methods: [method])

    XCTAssertEqual(service.name, "UserService")
    XCTAssertEqual(service.methods.count, 1)
    XCTAssertTrue(service.options.isEmpty)

    XCTAssertNotNil(service.method(named: "GetUser"))
    XCTAssertNil(service.method(named: "NonExistent"))
    XCTAssertEqual(service.usedMethodNames, ["GetUser"])

    let description = service.description
    XCTAssertTrue(description.contains("service UserService"))
    XCTAssertTrue(description.contains("rpc GetUser"))
  }

  func testServiceNodeAdvanced() {
    // Test ServiceNode initialization and methods
    let service = ServiceNode(
      name: "TestService",
      methods: [
        RPCMethodNode(
          name: "SimpleCall",
          inputType: "Request",
          outputType: "Response"
        ),
        RPCMethodNode(
          name: "StreamingCall",
          inputType: "StreamRequest",
          outputType: "StreamResponse",
          inputStreaming: true,
          outputStreaming: true,
          options: [OptionNode(name: "deprecated", value: .boolean(true))]
        ),
      ],
      options: [OptionNode(name: "java_package", value: .string("com.example"))]
    )

    XCTAssertEqual(service.name, "TestService")
    XCTAssertEqual(service.methods.count, 2)
    XCTAssertEqual(service.options.count, 1)

    // Test method properties
    let streamingMethod = service.methods[1]
    XCTAssertTrue(streamingMethod.inputStreaming)
    XCTAssertTrue(streamingMethod.outputStreaming)
    XCTAssertEqual(streamingMethod.options.count, 1)

    // Test description
    let description = service.description
    XCTAssertTrue(description.contains("service TestService"))
    XCTAssertTrue(description.contains("rpc SimpleCall"))
    XCTAssertTrue(description.contains("stream"))
  }

  // MARK: - OptionNode Tests

  func testOptionNode() {
    let option = OptionNode(name: "java_package", value: .string("com.example"))

    XCTAssertEqual(option.name, "java_package")
    XCTAssertFalse(option.isCustom)

    if case .string(let value) = option.value {
      XCTAssertEqual(value, "com.example")
    }
    else {
      XCTFail("Expected string value")
    }

    let description = option.description
    XCTAssertTrue(description.contains("option java_package"))
    XCTAssertTrue(description.contains("com.example"))
  }

  func testOptionValue() {
    let stringValue = OptionValue.string("test")
    let numberValue = OptionValue.number(42.0)
    let boolValue = OptionValue.boolean(true)
    let identifierValue = OptionValue.identifier("ENUM_VALUE")

    XCTAssertEqual(stringValue.protoRepresentation, "\"test\"")
    XCTAssertEqual(numberValue.protoRepresentation, "42")
    XCTAssertEqual(boolValue.protoRepresentation, "true")
    XCTAssertEqual(identifierValue.protoRepresentation, "ENUM_VALUE")
  }

  func testOptionNodeAdvanced() {
    // Test custom option
    let customOption = OptionNode(
      name: "my_custom_option",
      value: .string("custom_value"),
      isCustom: true
    )

    XCTAssertTrue(customOption.isCustom)
    XCTAssertEqual(customOption.name, "my_custom_option")
    if case .string(let value) = customOption.value {
      XCTAssertEqual(value, "custom_value")
    }
    else {
      XCTFail("Expected string value")
    }

    // Test number option
    let numberOption = OptionNode(
      name: "max_size",
      value: .number(1024.0)
    )

    if case .number(let value) = numberOption.value {
      XCTAssertEqual(value, 1024.0)
    }
    else {
      XCTFail("Expected number value")
    }

    // Test identifier option
    let identifierOption = OptionNode(
      name: "optimize_for",
      value: .identifier("SPEED")
    )

    if case .identifier(let value) = identifierOption.value {
      XCTAssertEqual(value, "SPEED")
    }
    else {
      XCTFail("Expected identifier value")
    }
  }

  // MARK: - Integration Tests

  func testComplexASTStructure() {
    let field = FieldNode(name: "name", type: .string, number: 1)
    let message = MessageNode(name: "User", fields: [field])

    let enumValue = EnumValueNode(name: "ACTIVE", number: 1)
    let enumNode = EnumNode(name: "Status", values: [enumValue])

    let method = RPCMethodNode(name: "GetUser", inputType: "Request", outputType: "Response")
    let service = ServiceNode(name: "UserService", methods: [method])

    let option = OptionNode(name: "java_package", value: .string("com.example"))

    let ast = ProtoAST(
      syntax: .proto3,
      package: "com.example.user",
      imports: ["google/protobuf/timestamp.proto"],
      options: [option],
      messages: [message],
      enums: [enumNode],
      services: [service]
    )

    XCTAssertEqual(ast.syntax, .proto3)
    XCTAssertEqual(ast.package, "com.example.user")
    XCTAssertEqual(ast.imports.count, 1)
    XCTAssertEqual(ast.options.count, 1)
    XCTAssertEqual(ast.messages.count, 1)
    XCTAssertEqual(ast.enums.count, 1)
    XCTAssertEqual(ast.services.count, 1)

    let description = ast.description
    XCTAssertTrue(description.contains("syntax ="))
    XCTAssertTrue(description.contains("package com.example.user;"))
    XCTAssertTrue(description.contains("message User"))
    XCTAssertTrue(description.contains("enum Status"))
    XCTAssertTrue(description.contains("service UserService"))
  }

  func testRPCMethodNodeEquality() {
    let method1 = RPCMethodNode(
      name: "TestMethod",
      inputType: "Request",
      outputType: "Response",
      inputStreaming: true,
      outputStreaming: false,
      options: [OptionNode(name: "deprecated", value: .boolean(true))]
    )

    let method2 = RPCMethodNode(
      name: "TestMethod",
      inputType: "Request",
      outputType: "Response",
      inputStreaming: true,
      outputStreaming: false,
      options: [OptionNode(name: "deprecated", value: .boolean(true))]
    )

    let method3 = RPCMethodNode(
      name: "DifferentMethod",
      inputType: "Request",
      outputType: "Response"
    )

    XCTAssertEqual(method1, method2)
    XCTAssertNotEqual(method1, method3)
  }

  func testFieldNodeAdvanced() {
    // Test field with all properties
    let field = FieldNode(
      name: "test_field",
      type: .map(key: .string, value: .int32),
      number: 42,
      label: .repeated,
      options: [
        OptionNode(name: "deprecated", value: .boolean(true)),
        OptionNode(name: "json_name", value: .string("testField")),
      ]
    )

    XCTAssertEqual(field.name, "test_field")
    XCTAssertEqual(field.number, 42)
    XCTAssertEqual(field.label, .repeated)
    XCTAssertEqual(field.options.count, 2)

    // Test map type
    if case .map(let keyType, let valueType) = field.type {
      XCTAssertEqual(keyType, .string)
      XCTAssertEqual(valueType, .int32)
    }
    else {
      XCTFail("Expected map type")
    }

    // Test description
    let description = field.description
    XCTAssertTrue(description.contains("repeated"))
    XCTAssertTrue(description.contains("map<string, int32>"))
    XCTAssertTrue(description.contains("test_field"))
    XCTAssertTrue(description.contains("= 42"))
  }

  func testFieldNodeEquality() {
    let field1 = FieldNode(
      name: "test",
      type: .string,
      number: 1,
      label: .optional,
      options: [OptionNode(name: "deprecated", value: .boolean(true))]
    )

    let field2 = FieldNode(
      name: "test",
      type: .string,
      number: 1,
      label: .optional,
      options: [OptionNode(name: "deprecated", value: .boolean(true))]
    )

    let field3 = FieldNode(
      name: "different",
      type: .string,
      number: 1
    )

    XCTAssertEqual(field1, field2)
    XCTAssertNotEqual(field1, field3)
  }

  func testEnumNodeAdvanced() {
    let enumNode = EnumNode(
      name: "Status",
      values: [
        EnumValueNode(name: "UNKNOWN", number: 0),
        EnumValueNode(
          name: "ACTIVE",
          number: 1,
          options: [OptionNode(name: "deprecated", value: .boolean(true))]
        ),
        EnumValueNode(name: "INACTIVE", number: 2),
      ],
      options: [OptionNode(name: "allow_alias", value: .boolean(true))]
    )

    XCTAssertEqual(enumNode.name, "Status")
    XCTAssertEqual(enumNode.values.count, 3)
    XCTAssertEqual(enumNode.options.count, 1)

    // Test value with options
    let activeValue = enumNode.values[1]
    XCTAssertEqual(activeValue.name, "ACTIVE")
    XCTAssertEqual(activeValue.number, 1)
    XCTAssertEqual(activeValue.options.count, 1)

    // Test description
    let description = enumNode.description
    XCTAssertTrue(description.contains("enum Status"))
    XCTAssertTrue(description.contains("UNKNOWN = 0"))
    XCTAssertTrue(description.contains("ACTIVE = 1"))
    XCTAssertTrue(description.contains("allow_alias"))
  }

  func testEnumValueNodeEquality() {
    let value1 = EnumValueNode(
      name: "TEST",
      number: 1,
      options: [OptionNode(name: "deprecated", value: .boolean(true))]
    )

    let value2 = EnumValueNode(
      name: "TEST",
      number: 1,
      options: [OptionNode(name: "deprecated", value: .boolean(true))]
    )

    let value3 = EnumValueNode(name: "DIFFERENT", number: 1)

    XCTAssertEqual(value1, value2)
    XCTAssertNotEqual(value1, value3)
  }

  func testOptionValueEquality() {
    // Test string values
    XCTAssertEqual(OptionValue.string("test"), OptionValue.string("test"))
    XCTAssertNotEqual(OptionValue.string("test"), OptionValue.string("other"))

    // Test number values
    XCTAssertEqual(OptionValue.number(42.0), OptionValue.number(42.0))
    XCTAssertNotEqual(OptionValue.number(42.0), OptionValue.number(43.0))

    // Test boolean values
    XCTAssertEqual(OptionValue.boolean(true), OptionValue.boolean(true))
    XCTAssertNotEqual(OptionValue.boolean(true), OptionValue.boolean(false))

    // Test identifier values
    XCTAssertEqual(OptionValue.identifier("SPEED"), OptionValue.identifier("SPEED"))
    XCTAssertNotEqual(OptionValue.identifier("SPEED"), OptionValue.identifier("SIZE"))

    // Test different types
    XCTAssertNotEqual(OptionValue.string("42"), OptionValue.number(42.0))
  }

  func testOptionValueDescription() {
    XCTAssertEqual(OptionValue.string("test").description, "\"test\"")
    XCTAssertEqual(OptionValue.number(42.0).description, "42")
    XCTAssertEqual(OptionValue.boolean(true).description, "true")
    XCTAssertEqual(OptionValue.identifier("SPEED").description, "SPEED")
  }

  func testProtoASTAdvanced() {
    let ast = ProtoAST(
      syntax: .proto3,
      package: "com.example.test",
      imports: ["google/protobuf/timestamp.proto", "common/types.proto"],
      options: [
        OptionNode(name: "java_package", value: .string("com.example.test")),
        OptionNode(name: "optimize_for", value: .identifier("SPEED")),
      ],
      messages: [
        MessageNode(name: "TestMessage"),
        MessageNode(name: "AnotherMessage"),
      ],
      enums: [
        EnumNode(
          name: "Status",
          values: [
            EnumValueNode(name: "UNKNOWN", number: 0)
          ]
        )
      ],
      services: [
        ServiceNode(
          name: "TestService",
          methods: [
            RPCMethodNode(name: "Test", inputType: "Request", outputType: "Response")
          ]
        )
      ]
    )

    // Test properties
    XCTAssertEqual(ast.syntax, .proto3)
    XCTAssertEqual(ast.package, "com.example.test")
    XCTAssertEqual(ast.imports.count, 2)
    XCTAssertEqual(ast.options.count, 2)
    XCTAssertEqual(ast.messages.count, 2)
    XCTAssertEqual(ast.enums.count, 1)
    XCTAssertEqual(ast.services.count, 1)

    // Test description
    let description = ast.description
    XCTAssertFalse(description.isEmpty)
  }

  // MARK: - Additional Coverage Tests

  /// Test all RPCStreamingType descriptions to cover the uncovered description property.
  func testRPCStreamingTypeDescriptions() {
    // Test all streaming type descriptions
    XCTAssertEqual(RPCStreamingType.unary.description, "Unary")
    XCTAssertEqual(RPCStreamingType.serverStreaming.description, "Server Streaming")
    XCTAssertEqual(RPCStreamingType.clientStreaming.description, "Client Streaming")
    XCTAssertEqual(RPCStreamingType.bidirectionalStreaming.description, "Bidirectional Streaming")
  }

  /// Test all streaming type combinations to cover uncovered streamingType property paths.
  func testRPCMethodStreamingTypes() {
    // Unary (false, false) - already covered in existing tests
    let unaryMethod = RPCMethodNode(
      name: "UnaryCall",
      inputType: "Request",
      outputType: "Response",
      inputStreaming: false,
      outputStreaming: false
    )
    XCTAssertEqual(unaryMethod.streamingType, .unary)

    // Server streaming (false, true) - covers line 77
    let serverStreamingMethod = RPCMethodNode(
      name: "ServerStreamingCall",
      inputType: "Request",
      outputType: "Response",
      inputStreaming: false,
      outputStreaming: true
    )
    XCTAssertEqual(serverStreamingMethod.streamingType, .serverStreaming)

    // Client streaming (true, false) - covers line 79
    let clientStreamingMethod = RPCMethodNode(
      name: "ClientStreamingCall",
      inputType: "Request",
      outputType: "Response",
      inputStreaming: true,
      outputStreaming: false
    )
    XCTAssertEqual(clientStreamingMethod.streamingType, .clientStreaming)

    // Bidirectional streaming (true, true) - already covered in existing tests
    let bidirectionalMethod = RPCMethodNode(
      name: "BidirectionalCall",
      inputType: "Request",
      outputType: "Response",
      inputStreaming: true,
      outputStreaming: true
    )
    XCTAssertEqual(bidirectionalMethod.streamingType, .bidirectionalStreaming)
  }

  /// Test FieldNode.isMap property to cover uncovered lines in FieldNode.
  func testFieldNodeIsMapProperty() {
    // Test map field - covers lines 45-51
    let mapField = FieldNode(
      name: "user_scores",
      type: .map(key: .string, value: .int32),
      number: 1
    )
    XCTAssertTrue(mapField.isMap)

    // Test non-map fields to ensure they return false
    let stringField = FieldNode(name: "name", type: .string, number: 2)
    XCTAssertFalse(stringField.isMap)

    let messageField = FieldNode(name: "user", type: .message("User"), number: 3)
    XCTAssertFalse(messageField.isMap)

    let enumField = FieldNode(name: "status", type: .enumType("Status"), number: 4)
    XCTAssertFalse(enumField.isMap)

    let scalarField = FieldNode(name: "count", type: .int32, number: 5)
    XCTAssertFalse(scalarField.isMap)
  }

  /// Test complex map types to ensure isMap works with nested types.
  func testFieldNodeIsMapWithComplexTypes() {
    // Test map with message value type
    let mapWithMessageField = FieldNode(
      name: "user_data",
      type: .map(key: .string, value: .message("UserData")),
      number: 1
    )
    XCTAssertTrue(mapWithMessageField.isMap)

    // Test map with enum value type
    let mapWithEnumField = FieldNode(
      name: "status_map",
      type: .map(key: .int32, value: .enumType("Status")),
      number: 2
    )
    XCTAssertTrue(mapWithEnumField.isMap)

    // Test nested map type
    let nestedMapField = FieldNode(
      name: "nested_map",
      type: .map(key: .string, value: .map(key: .int32, value: .bool)),
      number: 3
    )
    XCTAssertTrue(nestedMapField.isMap)
  }

  /// Test FieldLabel.isRequired property to cover uncovered lines.
  func testFieldLabelIsRequired() {
    // Test that all field labels return false for isRequired (proto3 doesn't have required fields)
    XCTAssertFalse(FieldLabel.singular.isRequired)
    XCTAssertFalse(FieldLabel.optional.isRequired)
    XCTAssertFalse(FieldLabel.repeated.isRequired)
  }

  /// Test OptionValue.protoRepresentation for decimal numbers to cover uncovered lines.
  func testOptionValueDecimalNumbers() {
    // Test integer number (already covered)
    let integerValue = OptionValue.number(42.0)
    XCTAssertEqual(integerValue.protoRepresentation, "42")

    // Test decimal number - covers lines 38-39 in OptionNode.swift
    let decimalValue = OptionValue.number(3.14159)
    XCTAssertEqual(decimalValue.protoRepresentation, "3.14159")

    // Test another decimal number
    let anotherDecimalValue = OptionValue.number(2.5)
    XCTAssertEqual(anotherDecimalValue.protoRepresentation, "2.5")

    // Test negative decimal number
    let negativeDecimalValue = OptionValue.number(-1.5)
    XCTAssertEqual(negativeDecimalValue.protoRepresentation, "-1.5")
  }
}
