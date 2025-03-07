import XCTest
import SwiftProtobuf
@testable import SwiftProtoParser

final class CustomOptionsTests: XCTestCase {
    
    // MARK: - Helper Methods
    
    private func createCustomOption(
        name: String,
        value: OptionNode.Value,
        nestedFields: [String] = []
    ) -> OptionNode {
        let location = SourceLocation(line: 1, column: 1)
        
        var parts: [OptionNode.PathPart] = [OptionNode.PathPart(name: name, isExtension: true)]
        
        // Add any nested fields
        for field in nestedFields {
            parts.append(OptionNode.PathPart(name: field))
        }
        
        return OptionNode(
            location: location,
            name: "(\(name))" + (nestedFields.isEmpty ? "" : "." + nestedFields.joined(separator: ".")),
            value: value,
            pathParts: parts,
            isCustomOption: true
        )
    }
    
    private func parse(_ input: String) throws -> FileNode {
        let lexer = Lexer(input: input)
        let parser = try Parser(lexer: lexer)
        return try parser.parseFile()
    }
    
    // MARK: - Tests
    
    func testBasicCustomOption() throws {
        // Test proto content with a basic custom option
        let protoContent = """
        syntax = "proto3";
        import "google/protobuf/descriptor.proto";
        
        extend google.protobuf.FileOptions {
          string my_file_option = 50000;
        }
        
        option (my_file_option) = "Hello, world!";
        """
        
        // Parse the proto content
        let fileNode = try parse(protoContent)
        
        // Verify the custom option was parsed correctly
        XCTAssertEqual(fileNode.options.count, 1)
        let option = fileNode.options[0]
        XCTAssertTrue(option.isCustomOption)
        XCTAssertEqual(option.pathParts.count, 1)
        XCTAssertEqual(option.pathParts[0].name, "my_file_option")
        XCTAssertTrue(option.pathParts[0].isExtension)
        
        if case .string(let value) = option.value {
            XCTAssertEqual(value, "Hello, world!")
        } else {
            XCTFail("Option value should be a string")
        }
    }
    
    func testNestedCustomOption() throws {
        // Test proto content with a nested custom option
        let protoContent = """
        syntax = "proto3";
        import "google/protobuf/descriptor.proto";
        
        message MyOption {
          string value = 1;
        }
        
        extend google.protobuf.MessageOptions {
          MyOption my_message_option = 50000;
        }
        
        message Test {
          option (my_message_option).value = "Hello, nested!";
        }
        """
        
        // Parse the proto content
        let fileNode = try parse(protoContent)
        
        // Verify the message with the custom option
        XCTAssertEqual(fileNode.messages.count, 2)
        let testMessage = fileNode.messages[1]
        XCTAssertEqual(testMessage.name, "Test")
        XCTAssertEqual(testMessage.options.count, 1)
        
        let option = testMessage.options[0]
        XCTAssertTrue(option.isCustomOption)
        XCTAssertEqual(option.pathParts.count, 2)
        XCTAssertEqual(option.pathParts[0].name, "my_message_option")
        XCTAssertTrue(option.pathParts[0].isExtension)
        XCTAssertEqual(option.pathParts[1].name, "value")
        XCTAssertFalse(option.pathParts[1].isExtension)
        
        if case .string(let value) = option.value {
            XCTAssertEqual(value, "Hello, nested!")
        } else {
            XCTFail("Option value should be a string")
        }
    }
    
    func testCustomOptionValueTypes() throws {
        // Test proto content with different value types for custom options
        let protoContent = """
        syntax = "proto3";
        import "google/protobuf/descriptor.proto";
        
        extend google.protobuf.FileOptions {
          string string_option = 50000;
          int32 int_option = 50001;
          bool bool_option = 50002;
        }
        
        option (string_option) = "string value";
        option (int_option) = 42;
        option (bool_option) = true;
        """
        
        // Parse the proto content
        let fileNode = try parse(protoContent)
        
        // Verify the custom options were parsed correctly
        XCTAssertEqual(fileNode.options.count, 3)
        
        // String option
        let stringOption = fileNode.options[0]
        XCTAssertTrue(stringOption.isCustomOption)
        XCTAssertEqual(stringOption.pathParts[0].name, "string_option")
        if case .string(let value) = stringOption.value {
            XCTAssertEqual(value, "string value")
        } else {
            XCTFail("Option value should be a string")
        }
        
        // Int option
        let intOption = fileNode.options[1]
        XCTAssertTrue(intOption.isCustomOption)
        XCTAssertEqual(intOption.pathParts[0].name, "int_option")
        if case .number(let value) = intOption.value {
            XCTAssertEqual(value, 42)
        } else {
            XCTFail("Option value should be a number")
        }
        
        // Bool option
        let boolOption = fileNode.options[2]
        XCTAssertTrue(boolOption.isCustomOption)
        XCTAssertEqual(boolOption.pathParts[0].name, "bool_option")
        if case .identifier(let value) = boolOption.value {
            XCTAssertEqual(value, "true")
        } else {
            XCTFail("Option value should be an identifier")
        }
    }
    
    func testCustomOptionParsing() throws {
        // Create a proto content with custom options
        let protoContent = """
        syntax = "proto3";
        package test;
        
        import "google/protobuf/descriptor.proto";
        
        extend google.protobuf.FileOptions {
          string custom_file_option = 50000;
        }
        
        extend google.protobuf.MessageOptions {
          int32 custom_message_option = 50001;
        }
        
        option (custom_file_option) = "file option value";
        
        message TestMessage {
          option (custom_message_option) = 42;
          string name = 1;
        }
        """
        
        // Parse the proto content
        let fileNode = try parse(protoContent)
        
        // Verify file options
        XCTAssertEqual(fileNode.options.count, 1)
        XCTAssertEqual(fileNode.options[0].name, "(custom_file_option)")
        
        // Verify message options
        let messageNode = fileNode.messages.first
        XCTAssertNotNil(messageNode)
        XCTAssertEqual(messageNode?.options.count, 1)
        XCTAssertEqual(messageNode?.options[0].name, "(custom_message_option)")
    }
    
    func testCustomOptionDescriptorGeneration() throws {
        // Create a simple file node with a custom option
        let customOption = createCustomOption(
            name: "custom.file.option",
            value: .string("file option value")
        )
        
        let fileNode = FileNode(
            location: SourceLocation(line: 1, column: 1),
            syntax: "proto3",
            package: "test",
            filePath: "test.proto",
            options: [customOption]
        )
        
        // Generate descriptor
        let descriptorGenerator = DescriptorGenerator()
        let descriptor = try descriptorGenerator.generateFileDescriptor(fileNode)
        
        // Verify file options
        XCTAssertGreaterThanOrEqual(descriptor.options.uninterpretedOption.count, 1)
    }
} 