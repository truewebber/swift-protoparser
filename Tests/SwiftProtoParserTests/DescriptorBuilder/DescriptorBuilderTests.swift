import SwiftProtobuf
import XCTest

@testable import SwiftProtoParser

class DescriptorBuilderTests: XCTestCase {

  func testBuildSimpleFileDescriptor() throws {
    // Create simple AST
    let ast = ProtoAST(
      syntax: .proto3,
      package: "test.package",
      imports: ["google/protobuf/empty.proto"],
      options: [],
      messages: [],
      enums: [],
      services: []
    )

    // Build descriptor
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")

    // Verify basic properties
    XCTAssertEqual(descriptor.name, "test.proto")
    XCTAssertEqual(descriptor.syntax, "proto3")
    XCTAssertEqual(descriptor.package, "test.package")
    XCTAssertEqual(descriptor.dependency.count, 1)
    XCTAssertEqual(descriptor.dependency[0], "google/protobuf/empty.proto")
    XCTAssertEqual(descriptor.messageType.count, 0)
    XCTAssertEqual(descriptor.enumType.count, 0)
    XCTAssertEqual(descriptor.service.count, 0)
  }

  func testBuildFileDescriptorWithMessages() throws {
    // Create message node
    let field = FieldNode(
      name: "id",
      type: .int32,
      number: 1,
      label: .singular
    )

    let message = MessageNode(
      name: "TestMessage",
      fields: [field]
    )

    let ast = ProtoAST(
      syntax: .proto3,
      package: nil,
      imports: [],
      options: [],
      messages: [message],
      enums: [],
      services: []
    )

    // Build descriptor
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")

    // Verify message conversion
    XCTAssertEqual(descriptor.messageType.count, 1)
    XCTAssertEqual(descriptor.messageType[0].name, "TestMessage")
    XCTAssertEqual(descriptor.messageType[0].field.count, 1)
    XCTAssertEqual(descriptor.messageType[0].field[0].name, "id")
    XCTAssertEqual(descriptor.messageType[0].field[0].number, 1)
  }

  func testBuildFileDescriptorWithEnums() throws {
    // Create enum node
    let enumValue = EnumValueNode(name: "VALUE_ZERO", number: 0)
    let enumNode = EnumNode(name: "TestEnum", values: [enumValue])

    let ast = ProtoAST(
      syntax: .proto3,
      package: nil,
      imports: [],
      options: [],
      messages: [],
      enums: [enumNode],
      services: []
    )

    // Build descriptor
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")

    // Verify enum conversion
    XCTAssertEqual(descriptor.enumType.count, 1)
    XCTAssertEqual(descriptor.enumType[0].name, "TestEnum")
    XCTAssertEqual(descriptor.enumType[0].value.count, 1)
    XCTAssertEqual(descriptor.enumType[0].value[0].name, "VALUE_ZERO")
    XCTAssertEqual(descriptor.enumType[0].value[0].number, 0)
  }

  func testBuildFileDescriptorWithServices() throws {
    // Create service node
    let method = RPCMethodNode(
      name: "TestMethod",
      inputType: "TestRequest",
      outputType: "TestResponse"
    )

    let service = ServiceNode(name: "TestService", methods: [method])

    let ast = ProtoAST(
      syntax: .proto3,
      package: nil,
      imports: [],
      options: [],
      messages: [],
      enums: [],
      services: [service]
    )

    // Build descriptor
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")

    // Verify service conversion
    XCTAssertEqual(descriptor.service.count, 1)
    XCTAssertEqual(descriptor.service[0].name, "TestService")
    XCTAssertEqual(descriptor.service[0].method.count, 1)
    XCTAssertEqual(descriptor.service[0].method[0].name, "TestMethod")
    XCTAssertEqual(descriptor.service[0].method[0].inputType, ".TestRequest")
    XCTAssertEqual(descriptor.service[0].method[0].outputType, ".TestResponse")
  }

  func testBuildComplexFileDescriptor() throws {
    // Create complex AST with all elements
    let field = FieldNode(name: "value", type: .string, number: 1)
    let message = MessageNode(name: "TestMessage", fields: [field])

    let enumValue = EnumValueNode(name: "ZERO", number: 0)
    let enumNode = EnumNode(name: "TestEnum", values: [enumValue])

    let method = RPCMethodNode(name: "Test", inputType: "Empty", outputType: "Empty")
    let service = ServiceNode(name: "TestService", methods: [method])

    let ast = ProtoAST(
      syntax: .proto3,
      package: "complex.test",
      imports: ["google/protobuf/empty.proto", "other.proto"],
      options: [],
      messages: [message],
      enums: [enumNode],
      services: [service]
    )

    // Build descriptor
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "complex.proto")

    // Verify all elements
    XCTAssertEqual(descriptor.name, "complex.proto")
    XCTAssertEqual(descriptor.syntax, "proto3")
    XCTAssertEqual(descriptor.package, "complex.test")
    XCTAssertEqual(descriptor.dependency.count, 2)
    XCTAssertEqual(descriptor.messageType.count, 1)
    XCTAssertEqual(descriptor.enumType.count, 1)
    XCTAssertEqual(descriptor.service.count, 1)
  }

  func testBuildFileDescriptorMinimal() throws {
    // Test with minimal AST
    let ast = ProtoAST(syntax: .proto3)

    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "minimal.proto")

    XCTAssertEqual(descriptor.name, "minimal.proto")
    XCTAssertEqual(descriptor.syntax, "proto3")
    XCTAssertTrue(descriptor.package.isEmpty)
    XCTAssertEqual(descriptor.dependency.count, 0)
    XCTAssertEqual(descriptor.messageType.count, 0)
    XCTAssertEqual(descriptor.enumType.count, 0)
    XCTAssertEqual(descriptor.service.count, 0)
  }

  // MARK: - fileProto.name contract

  func testBuildFileDescriptor_FileNameIsPreservedExactly_BareFilename() throws {
    let ast = ProtoAST(syntax: .proto3, package: "example")

    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "user.proto")

    XCTAssertEqual(descriptor.name, "user.proto")
  }

  func testBuildFileDescriptor_FileNameIsPreservedExactly_SingleSubdirectory() throws {
    let ast = ProtoAST(syntax: .proto3, package: "example")

    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "api/user.proto")

    XCTAssertEqual(descriptor.name, "api/user.proto")
  }

  func testBuildFileDescriptor_FileNameIsPreservedExactly_DeepPath() throws {
    let ast = ProtoAST(syntax: .proto3, package: "google.protobuf")

    let descriptor = try DescriptorBuilder.buildFileDescriptor(
      from: ast,
      fileName: "google/protobuf/timestamp.proto"
    )

    XCTAssertEqual(descriptor.name, "google/protobuf/timestamp.proto")
  }

  func testBuildFileDescriptor_FileNameMatchesDependencyStrings() throws {
    let ast = ProtoAST(
      syntax: .proto3,
      package: "example.service",
      imports: ["api/user.proto", "common/base.proto"]
    )

    let descriptor = try DescriptorBuilder.buildFileDescriptor(
      from: ast,
      fileName: "api/v1/service.proto"
    )

    XCTAssertEqual(descriptor.name, "api/v1/service.proto")
    XCTAssertEqual(descriptor.dependency[0], "api/user.proto")
    XCTAssertEqual(descriptor.dependency[1], "common/base.proto")
  }

  func testBuildFileDescriptorWithOptions() throws {
    // Create AST with options (currently ignored but should not fail)
    let option = OptionNode(name: "java_package", value: .string("com.test"))

    let ast = ProtoAST(
      syntax: .proto3,
      package: nil,
      imports: [],
      options: [option],
      messages: [],
      enums: [],
      services: []
    )

    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")

    // Should complete without error
    XCTAssertEqual(descriptor.name, "test.proto")
  }

  // MARK: - Cross-package field typeName in FileDescriptorProto

  func testBuildFileDescriptor_QualifiedTypeField_TypeNameNotPackagePrefixed() throws {
    let field = FieldNode(name: "item", type: .qualifiedType("nested.common.BaseItem"), number: 1)
    let message = MessageNode(name: "GetItemResponse", fields: [field])
    let ast = ProtoAST(
      syntax: .proto3,
      package: "nested.v1",
      imports: ["common/base.proto"],
      options: [],
      messages: [message],
      enums: [],
      services: []
    )

    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "v1/service.proto")

    let responseMessage = descriptor.messageType.first { $0.name == "GetItemResponse" }
    XCTAssertNotNil(responseMessage)
    XCTAssertEqual(
      responseMessage?.field[0].typeName,
      ".nested.common.BaseItem",
      "qualified type from imported package must not get current file package prepended"
    )
  }

  func testBuildFileDescriptor_QualifiedEnumField_TypeNameNotPackagePrefixed() throws {
    let field = FieldNode(name: "status", type: .qualifiedType("nested.common.BaseStatus"), number: 1)
    let message = MessageNode(name: "GetItemResponse", fields: [field])
    let ast = ProtoAST(
      syntax: .proto3,
      package: "nested.v1",
      imports: ["common/base.proto"],
      options: [],
      messages: [message],
      enums: [],
      services: []
    )

    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "v1/service.proto")

    let responseMessage = descriptor.messageType.first { $0.name == "GetItemResponse" }
    XCTAssertNotNil(responseMessage)
    let statusField = responseMessage?.field.first { $0.name == "status" }
    XCTAssertEqual(
      statusField?.typeName,
      ".nested.common.BaseStatus",
      "qualified enum type from imported package must not get current file package prepended"
    )
    // Known limitation: cross-file enum via qualifiedType is stored as .message at this layer
    XCTAssertEqual(
      statusField?.type,
      .message,
      "cross-file enum via qualifiedType is reported as .message — known limitation at DescriptorBuilder layer"
    )
  }

  func testBuildFileDescriptor_LocalMessageField_GetsPackagePrepended() throws {
    let field = FieldNode(name: "request", type: .message("GetItemRequest"), number: 1)
    let message = MessageNode(name: "GetItemResponse", fields: [field])
    let ast = ProtoAST(
      syntax: .proto3,
      package: "nested.v1",
      imports: [],
      options: [],
      messages: [message],
      enums: [],
      services: []
    )

    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "v1/service.proto")

    let responseMessage = descriptor.messageType.first { $0.name == "GetItemResponse" }
    XCTAssertEqual(
      responseMessage?.field[0].typeName,
      ".nested.v1.GetItemRequest",
      "local (same-package) type must get current file package prepended"
    )
  }
}
