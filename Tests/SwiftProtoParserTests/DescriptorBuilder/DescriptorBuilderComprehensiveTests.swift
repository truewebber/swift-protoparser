import XCTest
import SwiftProtobuf
@testable import SwiftProtoParser

final class DescriptorBuilderComprehensiveTests: XCTestCase {

  // MARK: - File Options Tests - Java Options

  func testBuildFileDescriptorWithJavaPackageOption() throws {
    let option = OptionNode(name: "java_package", value: .string("com.example.test"))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.javaPackage, "com.example.test")
  }

  func testBuildFileDescriptorWithJavaOuterClassnameOption() throws {
    let option = OptionNode(name: "java_outer_classname", value: .string("TestProtos"))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.javaOuterClassname, "TestProtos")
  }

  func testBuildFileDescriptorWithJavaMultipleFilesOption() throws {
    let option = OptionNode(name: "java_multiple_files", value: .boolean(true))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertTrue(descriptor.options.javaMultipleFiles)
  }

  func testBuildFileDescriptorWithJavaGenerateEqualsAndHashOption() throws {
    let option = OptionNode(name: "java_generate_equals_and_hash", value: .boolean(true))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertTrue(descriptor.options.javaGenerateEqualsAndHash)
  }

  func testBuildFileDescriptorWithJavaStringCheckUtf8Option() throws {
    let option = OptionNode(name: "java_string_check_utf8", value: .boolean(false))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertFalse(descriptor.options.javaStringCheckUtf8)
  }

  // MARK: - Optimize For Options

  func testBuildFileDescriptorWithOptimizeForSpeed() throws {
    let option = OptionNode(name: "optimize_for", value: .identifier("SPEED"))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.optimizeFor, .speed)
  }

  func testBuildFileDescriptorWithOptimizeForCodeSize() throws {
    let option = OptionNode(name: "optimize_for", value: .identifier("CODE_SIZE"))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.optimizeFor, .codeSize)
  }

  func testBuildFileDescriptorWithOptimizeForLiteRuntime() throws {
    let option = OptionNode(name: "optimize_for", value: .identifier("LITE_RUNTIME"))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.optimizeFor, .liteRuntime)
  }

  func testBuildFileDescriptorWithOptimizeForUnknownValue() throws {
    let option = OptionNode(name: "optimize_for", value: .identifier("UNKNOWN_VALUE"))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.optimizeFor, .speed) // Default fallback
  }

  // MARK: - Language-Specific Options

  func testBuildFileDescriptorWithGoPackageOption() throws {
    let option = OptionNode(name: "go_package", value: .string("github.com/example/proto"))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.goPackage, "github.com/example/proto")
  }

  func testBuildFileDescriptorWithCcGenericServicesOption() throws {
    let option = OptionNode(name: "cc_generic_services", value: .boolean(true))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertTrue(descriptor.options.ccGenericServices)
  }

  func testBuildFileDescriptorWithJavaGenericServicesOption() throws {
    let option = OptionNode(name: "java_generic_services", value: .boolean(false))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertFalse(descriptor.options.javaGenericServices)
  }

  func testBuildFileDescriptorWithPyGenericServicesOption() throws {
    let option = OptionNode(name: "py_generic_services", value: .boolean(true))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertTrue(descriptor.options.pyGenericServices)
  }

  // MARK: - Additional Options

  func testBuildFileDescriptorWithDeprecatedOption() throws {
    let option = OptionNode(name: "deprecated", value: .boolean(true))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertTrue(descriptor.options.deprecated)
  }

  func testBuildFileDescriptorWithCcEnableArenasOption() throws {
    let option = OptionNode(name: "cc_enable_arenas", value: .boolean(false))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertFalse(descriptor.options.ccEnableArenas)
  }

  func testBuildFileDescriptorWithObjcClassPrefixOption() throws {
    let option = OptionNode(name: "objc_class_prefix", value: .string("EX"))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.objcClassPrefix, "EX")
  }

  func testBuildFileDescriptorWithCsharpNamespaceOption() throws {
    let option = OptionNode(name: "csharp_namespace", value: .string("Example.Proto"))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.csharpNamespace, "Example.Proto")
  }

  func testBuildFileDescriptorWithSwiftPrefixOption() throws {
    let option = OptionNode(name: "swift_prefix", value: .string("EX"))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.swiftPrefix, "EX")
  }

  // MARK: - PHP Options

  func testBuildFileDescriptorWithPhpClassPrefixOption() throws {
    let option = OptionNode(name: "php_class_prefix", value: .string("Example\\"))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.phpClassPrefix, "Example\\")
  }

  func testBuildFileDescriptorWithPhpNamespaceOption() throws {
    let option = OptionNode(name: "php_namespace", value: .string("Example\\Proto"))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.phpNamespace, "Example\\Proto")
  }

  func testBuildFileDescriptorWithPhpMetadataNamespaceOption() throws {
    let option = OptionNode(name: "php_metadata_namespace", value: .string("Example\\Proto\\Meta"))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.phpMetadataNamespace, "Example\\Proto\\Meta")
  }

  func testBuildFileDescriptorWithRubyPackageOption() throws {
    let option = OptionNode(name: "ruby_package", value: .string("Example::Proto"))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.rubyPackage, "Example::Proto")
  }

  // MARK: - Custom Options (Uninterpreted)

  func testBuildFileDescriptorWithCustomStringOption() throws {
    let option = OptionNode(name: "custom_string_option", value: .string("custom_value"), isCustom: true)
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.uninterpretedOption.count, 1)
    
    let uninterpretedOption = descriptor.options.uninterpretedOption[0]
    XCTAssertEqual(uninterpretedOption.name.count, 1)
    XCTAssertEqual(uninterpretedOption.name[0].namePart, "custom_string_option")
    XCTAssertTrue(uninterpretedOption.name[0].isExtension)
    XCTAssertEqual(uninterpretedOption.stringValue, Data("custom_value".utf8))
  }

  func testBuildFileDescriptorWithCustomNumberOption() throws {
    let option = OptionNode(name: "custom_number_option", value: .number(42), isCustom: true)
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.uninterpretedOption.count, 1)
    
    let uninterpretedOption = descriptor.options.uninterpretedOption[0]
    XCTAssertEqual(uninterpretedOption.name[0].namePart, "custom_number_option")
    XCTAssertTrue(uninterpretedOption.name[0].isExtension)
    XCTAssertEqual(uninterpretedOption.positiveIntValue, 42)
  }

  func testBuildFileDescriptorWithCustomBooleanOption() throws {
    let option = OptionNode(name: "custom_bool_option", value: .boolean(true), isCustom: true)
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.uninterpretedOption.count, 1)
    
    let uninterpretedOption = descriptor.options.uninterpretedOption[0]
    XCTAssertEqual(uninterpretedOption.name[0].namePart, "custom_bool_option")
    XCTAssertTrue(uninterpretedOption.name[0].isExtension)
    XCTAssertEqual(uninterpretedOption.identifierValue, "true")
  }

  func testBuildFileDescriptorWithCustomIdentifierOption() throws {
    let option = OptionNode(name: "custom_id_option", value: .identifier("CUSTOM_VALUE"), isCustom: true)
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.uninterpretedOption.count, 1)
    
    let uninterpretedOption = descriptor.options.uninterpretedOption[0]
    XCTAssertEqual(uninterpretedOption.name[0].namePart, "custom_id_option")
    XCTAssertTrue(uninterpretedOption.name[0].isExtension)
    XCTAssertEqual(uninterpretedOption.identifierValue, "CUSTOM_VALUE")
  }

  func testBuildFileDescriptorWithUnknownStandardOption() throws {
    let option = OptionNode(name: "unknown_standard_option", value: .string("value"))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.uninterpretedOption.count, 1)
    
    let uninterpretedOption = descriptor.options.uninterpretedOption[0]
    XCTAssertEqual(uninterpretedOption.name[0].namePart, "unknown_standard_option")
    XCTAssertFalse(uninterpretedOption.name[0].isExtension) // Not marked as custom
  }

  // MARK: - Multiple Options Tests

  func testBuildFileDescriptorWithMultipleOptions() throws {
    let options = [
      OptionNode(name: "java_package", value: .string("com.example")),
      OptionNode(name: "java_multiple_files", value: .boolean(true)),
      OptionNode(name: "optimize_for", value: .identifier("SPEED")),
      OptionNode(name: "go_package", value: .string("github.com/example")),
      OptionNode(name: "deprecated", value: .boolean(false)),
      OptionNode(name: "custom_option", value: .string("custom"), isCustom: true)
    ]
    
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: options, messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.javaPackage, "com.example")
    XCTAssertTrue(descriptor.options.javaMultipleFiles)
    XCTAssertEqual(descriptor.options.optimizeFor, .speed)
    XCTAssertEqual(descriptor.options.goPackage, "github.com/example")
    XCTAssertFalse(descriptor.options.deprecated)
    XCTAssertEqual(descriptor.options.uninterpretedOption.count, 1)
  }

  // MARK: - Edge Cases and Error Scenarios

  func testBuildFileDescriptorWithNoOptions() throws {
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertFalse(descriptor.hasOptions)
  }

  func testBuildFileDescriptorWithEmptyOptionValue() throws {
    let option = OptionNode(name: "java_package", value: .string(""))
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: [option], messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.javaPackage, "")
  }

  func testBuildFileDescriptorWithSpecialCharactersInOptions() throws {
    let options = [
      OptionNode(name: "java_package", value: .string("com.example.test-package.v1")),
      OptionNode(name: "objc_class_prefix", value: .string("_PREFIX_")),
      OptionNode(name: "custom_option", value: .string("value with spaces and symbols!@#$%"), isCustom: true)
    ]
    
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: options, messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.javaPackage, "com.example.test-package.v1")
    XCTAssertEqual(descriptor.options.objcClassPrefix, "_PREFIX_")
    XCTAssertEqual(descriptor.options.uninterpretedOption.count, 1)
  }

  // MARK: - Integration Tests with Other Elements

  func testBuildCompleteFileDescriptorWithOptionsAndElements() throws {
    // Create comprehensive AST with options and all elements
    let options = [
      OptionNode(name: "java_package", value: .string("com.example.complete")),
      OptionNode(name: "java_multiple_files", value: .boolean(true)),
      OptionNode(name: "go_package", value: .string("github.com/example/complete"))
    ]
    
    let field = FieldNode(name: "value", type: .string, number: 1)
    let message = MessageNode(name: "TestMessage", fields: [field])
    
    let enumValue = EnumValueNode(name: "TEST_VALUE", number: 0)
    let enumNode = EnumNode(name: "TestEnum", values: [enumValue])
    
    let method = RPCMethodNode(name: "TestMethod", inputType: "TestMessage", outputType: "TestMessage")
    let service = ServiceNode(name: "TestService", methods: [method])
    
    let ast = ProtoAST(
      syntax: .proto3,
      package: "example.complete",
      imports: ["google/protobuf/empty.proto"],
      options: options,
      messages: [message],
      enums: [enumNode],
      services: [service]
    )
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "complete.proto")
    
    // Verify basic properties
    XCTAssertEqual(descriptor.name, "complete.proto")
    XCTAssertEqual(descriptor.syntax, "proto3")
    XCTAssertEqual(descriptor.package, "example.complete")
    XCTAssertEqual(descriptor.dependency.count, 1)
    
    // Verify options
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.javaPackage, "com.example.complete")
    XCTAssertTrue(descriptor.options.javaMultipleFiles)
    XCTAssertEqual(descriptor.options.goPackage, "github.com/example/complete")
    
    // Verify elements
    XCTAssertEqual(descriptor.messageType.count, 1)
    XCTAssertEqual(descriptor.enumType.count, 1)
    XCTAssertEqual(descriptor.service.count, 1)
  }

  // MARK: - Performance Tests

  func testBuildFileDescriptorWithManyOptions() throws {
    // Create AST with all possible standard options
    let options = [
      OptionNode(name: "java_package", value: .string("com.example.many")),
      OptionNode(name: "java_outer_classname", value: .string("ManyProtos")),
      OptionNode(name: "java_multiple_files", value: .boolean(true)),
      OptionNode(name: "java_generate_equals_and_hash", value: .boolean(true)),
      OptionNode(name: "java_string_check_utf8", value: .boolean(false)),
      OptionNode(name: "optimize_for", value: .identifier("SPEED")),
      OptionNode(name: "go_package", value: .string("github.com/example/many")),
      OptionNode(name: "cc_generic_services", value: .boolean(false)),
      OptionNode(name: "java_generic_services", value: .boolean(false)),
      OptionNode(name: "py_generic_services", value: .boolean(false)),
      OptionNode(name: "deprecated", value: .boolean(false)),
      OptionNode(name: "cc_enable_arenas", value: .boolean(true)),
      OptionNode(name: "objc_class_prefix", value: .string("EX")),
      OptionNode(name: "csharp_namespace", value: .string("Example.Many")),
      OptionNode(name: "swift_prefix", value: .string("EX")),
      OptionNode(name: "php_class_prefix", value: .string("Example\\")),
      OptionNode(name: "php_namespace", value: .string("Example\\Many")),
      OptionNode(name: "php_metadata_namespace", value: .string("Example\\Many\\Meta")),
      OptionNode(name: "ruby_package", value: .string("Example::Many"))
    ]
    
    let ast = ProtoAST(syntax: .proto3, package: nil, imports: [], options: options, messages: [], enums: [], services: [])
    
    let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "many.proto")
    
    XCTAssertTrue(descriptor.hasOptions)
    XCTAssertEqual(descriptor.options.javaPackage, "com.example.many")
    XCTAssertEqual(descriptor.options.javaOuterClassname, "ManyProtos")
    XCTAssertTrue(descriptor.options.javaMultipleFiles)
    XCTAssertTrue(descriptor.options.javaGenerateEqualsAndHash)
    XCTAssertFalse(descriptor.options.javaStringCheckUtf8)
    XCTAssertEqual(descriptor.options.optimizeFor, .speed)
    XCTAssertEqual(descriptor.options.goPackage, "github.com/example/many")
    XCTAssertFalse(descriptor.options.ccGenericServices)
    XCTAssertFalse(descriptor.options.javaGenericServices)
    XCTAssertFalse(descriptor.options.pyGenericServices)
    XCTAssertFalse(descriptor.options.deprecated)
    XCTAssertTrue(descriptor.options.ccEnableArenas)
    XCTAssertEqual(descriptor.options.objcClassPrefix, "EX")
    XCTAssertEqual(descriptor.options.csharpNamespace, "Example.Many")
    XCTAssertEqual(descriptor.options.swiftPrefix, "EX")
    XCTAssertEqual(descriptor.options.phpClassPrefix, "Example\\")
    XCTAssertEqual(descriptor.options.phpNamespace, "Example\\Many")
    XCTAssertEqual(descriptor.options.phpMetadataNamespace, "Example\\Many\\Meta")
    XCTAssertEqual(descriptor.options.rubyPackage, "Example::Many")
  }
}
