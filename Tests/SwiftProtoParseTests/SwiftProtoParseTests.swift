// SwiftProtoParseTests.swift

import XCTest
@testable import SwiftProtoParse

class SwiftProtoParseTests: XCTestCase {

	// MARK: - Positive Test Cases

	// Test Case 1: Valid Syntax Declaration
	func testValidSyntaxDeclaration() {
		let protoContent = """
		syntax = "proto3";
		"""
		do {
			let fileDescriptor = try SwiftProtoParse.parse(protoContent: protoContent)
			XCTAssertEqual(fileDescriptor.syntax, "proto3")
		} catch {
			XCTFail("Parsing failed with error: \(error)")
		}
	}

	// Test Case 2: Syntax Declaration with Single Quotes
	func testSyntaxDeclarationWithSingleQuotes() {
		let protoContent = """
		syntax = 'proto3';
		"""
		do {
			let fileDescriptor = try SwiftProtoParse.parse(protoContent: protoContent)
			XCTAssertEqual(fileDescriptor.syntax, "proto3")
		} catch {
			XCTFail("Parsing failed with error: \(error)")
		}
	}

	// Test Case 3: Valid Package Declaration
	func testValidPackageDeclaration() {
		let protoContent = """
		syntax = "proto3";
		package com.example.project;
		"""
		do {
			let fileDescriptor = try SwiftProtoParse.parse(protoContent: protoContent)
			XCTAssertEqual(fileDescriptor.package, "com.example.project")
		} catch {
			XCTFail("Parsing failed with error: \(error)")
		}
	}

	// Test Case 4: Package Declaration with Nested Packages
	func testPackageDeclarationWithNestedPackages() {
		let protoContent = """
		syntax = "proto3";
		package com.example.project.subproject;
		"""
		do {
			let fileDescriptor = try SwiftProtoParse.parse(protoContent: protoContent)
			XCTAssertEqual(fileDescriptor.package, "com.example.project.subproject")
		} catch {
			XCTFail("Parsing failed with error: \(error)")
		}
	}

	// Test Case 5: Valid Import Statements
	func testValidImportStatements() {
		let protoContent = """
		syntax = "proto3";
		import "common.proto";
		import public "shared.proto";
		import weak "legacy.proto";
		"""
		do {
			let fileDescriptor = try SwiftProtoParse.parse(protoContent: protoContent)
			XCTAssertEqual(fileDescriptor.dependencies.count, 3)
			XCTAssertEqual(fileDescriptor.dependencies[0], "common.proto")
			XCTAssertEqual(fileDescriptor.dependencies[1], "shared.proto")
			XCTAssertEqual(fileDescriptor.dependencies[2], "legacy.proto")
		} catch {
			XCTFail("Parsing failed with error: \(error)")
		}
	}

	// Test Case 6: Valid Option Statements
	func testValidOptionStatements() {
		let protoContent = """
		syntax = "proto3";
		option java_package = "com.example.project";
		option optimize_for = SPEED;
		"""
		do {
			let fileDescriptor = try SwiftProtoParse.parse(protoContent: protoContent)
			XCTAssertEqual(fileDescriptor.options.count, 2)
			XCTAssertEqual(fileDescriptor.options[0].name, "java_package")
			if case .string(let value) = fileDescriptor.options[0].value {
				XCTAssertEqual(value, "com.example.project")
			} else {
				XCTFail("Option value is not a string")
			}
			XCTAssertEqual(fileDescriptor.options[1].name, "optimize_for")
			if case .string(let value) = fileDescriptor.options[1].value {
				XCTAssertEqual(value, "SPEED")
			} else {
				XCTFail("Option value is not a string")
			}
		} catch {
			XCTFail("Parsing failed with error: \(error)")
		}
	}

	// Test Case 7: Simple Message Definition
	func testSimpleMessageDefinition() {
		let protoContent = """
		syntax = "proto3";

		message Person {
			string name = 1;
			int32 id = 2;
			bool is_employee = 3;
		}
		"""
		do {
			let fileDescriptor = try SwiftProtoParse.parse(protoContent: protoContent)
			XCTAssertEqual(fileDescriptor.messages.count, 1)
			let message = fileDescriptor.messages.first!
			XCTAssertEqual(message.name, "Person")
			XCTAssertEqual(message.fields.count, 3)
			XCTAssertEqual(message.fields[0].name, "name")
			XCTAssertEqual(message.fields[0].type, .string)
			XCTAssertEqual(message.fields[1].name, "id")
			XCTAssertEqual(message.fields[1].type, .int32)
			XCTAssertEqual(message.fields[2].name, "is_employee")
			XCTAssertEqual(message.fields[2].type, .bool)
		} catch {
			XCTFail("Parsing failed with error: \(error)")
		}
	}

	// Test Case 8: Message with Repeated Fields
	func testMessageWithRepeatedFields() {
		let protoContent = """
		syntax = "proto3";

		message Company {
			string name = 1;
			repeated Person employees = 2;
		}

		message Person {
			string name = 1;
			int32 id = 2;
		}
		"""
		do {
			let fileDescriptor = try SwiftProtoParse.parse(protoContent: protoContent)
			XCTAssertEqual(fileDescriptor.messages.count, 2)
			let companyMessage = fileDescriptor.messages.first { $0.name == "Company" }!
			XCTAssertEqual(companyMessage.fields.count, 2)
			let employeesField = companyMessage.fields.first { $0.name == "employees" }!
			XCTAssertEqual(employeesField.label, .repeated)
			XCTAssertEqual(employeesField.type, .message("Person"))
		} catch {
			XCTFail("Parsing failed with error: \(error)")
		}
	}

	// Test Case 9: Message with Map Fields
	func testMessageWithMapFields() {
		let protoContent = """
		syntax = "proto3";

		message Dictionary {
			map<string, int32> word_counts = 1;
		}
		"""
		// Note: Assuming the parser supports map fields and represents them appropriately
		// in the descriptors. Since our initial code did not include map support,
		// this test case might need additional implementation in the parser.
		do {
			let fileDescriptor = try SwiftProtoParse.parse(protoContent: protoContent)
			XCTAssertEqual(fileDescriptor.messages.count, 1)
			let message = fileDescriptor.messages.first!
			XCTAssertEqual(message.name, "Dictionary")
			XCTAssertEqual(message.fields.count, 1)
			let field = message.fields.first!
			XCTAssertEqual(field.name, "word_counts")
			// Validate that the field represents a map from string to int32
			if case .map(let keyType, let valueType) = field {
				XCTAssertEqual(keyType, .string)
				XCTAssertEqual(valueType, .int32)
			} else {
				XCTFail("Field is not a map")
			}
		} catch {
			XCTFail("Parsing failed with error: \(error)")
		}
	}

	// Test Case 10: Simple Enum Definition
	func testSimpleEnumDefinition() {
		let protoContent = """
		syntax = "proto3";

		enum Status {
			UNKNOWN = 0;
			STARTED = 1;
			COMPLETED = 2;
		}
		"""
		do {
			let fileDescriptor = try SwiftProtoParse.parse(protoContent: protoContent)
			XCTAssertEqual(fileDescriptor.enums.count, 1)
			let enumType = fileDescriptor.enums.first!
			XCTAssertEqual(enumType.name, "Status")
			XCTAssertEqual(enumType.values.count, 3)
			XCTAssertEqual(enumType.values[0].name, "UNKNOWN")
			XCTAssertEqual(enumType.values[0].number, 0)
			XCTAssertEqual(enumType.values[1].name, "STARTED")
			XCTAssertEqual(enumType.values[1].number, 1)
			XCTAssertEqual(enumType.values[2].name, "COMPLETED")
			XCTAssertEqual(enumType.values[2].number, 2)
		} catch {
			XCTFail("Parsing failed with error: \(error)")
		}
	}

	// Test Case 11: Enum with Options
	func testEnumWithOptions() {
		let protoContent = """
		syntax = "proto3";

		enum ResponseCode {
			option allow_alias = true;
			OK = 0;
			NOT_FOUND = 404;
			INTERNAL_ERROR = 500;
		}
		"""
		do {
			let fileDescriptor = try SwiftProtoParse.parse(protoContent: protoContent)
			XCTAssertEqual(fileDescriptor.enums.count, 1)
			let enumType = fileDescriptor.enums.first!
			XCTAssertEqual(enumType.name, "ResponseCode")
			XCTAssertEqual(enumType.options.count, 1)
			XCTAssertEqual(enumType.options[0].name, "allow_alias")
			if case .boolean(let value) = enumType.options[0].value {
				XCTAssertTrue(value)
			} else {
				XCTFail("Option value is not a boolean")
			}
			XCTAssertEqual(enumType.values.count, 3)
			XCTAssertEqual(enumType.values[0].name, "OK")
			XCTAssertEqual(enumType.values[0].number, 0)
			XCTAssertEqual(enumType.values[1].name, "NOT_FOUND")
			XCTAssertEqual(enumType.values[1].number, 404)
			XCTAssertEqual(enumType.values[2].name, "INTERNAL_ERROR")
			XCTAssertEqual(enumType.values[2].number, 500)
		} catch {
			XCTFail("Parsing failed with error: \(error)")
		}
	}

	// Test Case 12: Simple Service Definition
	func testSimpleServiceDefinition() {
		let protoContent = """
		syntax = "proto3";

		service UserService {
			rpc GetUser (GetUserRequest) returns (GetUserResponse);
		}

		message GetUserRequest {
			int32 user_id = 1;
		}

		message GetUserResponse {
			User user = 1;
		}

		message User {
			int32 id = 1;
			string name = 2;
		}
		"""
		do {
			let fileDescriptor = try SwiftProtoParse.parse(protoContent: protoContent)
			XCTAssertEqual(fileDescriptor.services.count, 1)
			let service = fileDescriptor.services.first!
			XCTAssertEqual(service.name, "UserService")
			XCTAssertEqual(service.methods.count, 1)
			let method = service.methods.first!
			XCTAssertEqual(method.name, "GetUser")
			XCTAssertEqual(method.inputType, "GetUserRequest")
			XCTAssertEqual(method.outputType, "GetUserResponse")
			XCTAssertFalse(method.clientStreaming)
			XCTAssertFalse(method.serverStreaming)
			XCTAssertEqual(fileDescriptor.messages.count, 3)
		} catch {
			XCTFail("Parsing failed with error: \(error)")
		}
	}

	// Test Case 13: Streaming RPC Methods
	func testStreamingRPCMethods() {
		let protoContent = """
		syntax = "proto3";

		service ChatService {
			rpc ChatStream (stream ChatMessage) returns (stream ChatMessage);
		}

		message ChatMessage {
			string sender = 1;
			string message = 2;
		}
		"""
		do {
			let fileDescriptor = try SwiftProtoParse.parse(protoContent: protoContent)
			XCTAssertEqual(fileDescriptor.services.count, 1)
			let service = fileDescriptor.services.first!
			XCTAssertEqual(service.name, "ChatService")
			XCTAssertEqual(service.methods.count, 1)
			let method = service.methods.first!
			XCTAssertEqual(method.name, "ChatStream")
			XCTAssertEqual(method.inputType, "ChatMessage")
			XCTAssertEqual(method.outputType, "ChatMessage")
			XCTAssertTrue(method.clientStreaming)
			XCTAssertTrue(method.serverStreaming)
		} catch {
			XCTFail("Parsing failed with error: \(error)")
		}
	}

	// Test Case 14: Message with Oneof
	func testMessageWithOneof() {
		let protoContent = """
		syntax = "proto3";

		message Shape {
			oneof shape_type {
				Circle circle = 1;
				Rectangle rectangle = 2;
			}
		}

		message Circle {
			float radius = 1;
		}

		message Rectangle {
			float width = 1;
			float height = 2;
		}
		"""
		do {
			let fileDescriptor = try SwiftProtoParse.parse(protoContent: protoContent)
			XCTAssertEqual(fileDescriptor.messages.count, 3)
			let shapeMessage = fileDescriptor.messages.first { $0.name == "Shape" }!
			XCTAssertEqual(shapeMessage.oneofs.count, 1)
			let oneof = shapeMessage.oneofs.first!
			XCTAssertEqual(oneof.name, "shape_type")
			XCTAssertEqual(oneof.fields.count, 2)
			XCTAssertEqual(oneof.fields[0].name, "circle")
			XCTAssertEqual(oneof.fields[1].name, "rectangle")
		} catch {
			XCTFail("Parsing failed with error: \(error)")
		}
	}

	// Test Case 15: Message with Map and Repeated Fields
	func testMessageWithMapAndRepeatedFields() {
		let protoContent = """
		syntax = "proto3";

		message Inventory {
			map<string, Item> items = 1;
			repeated string tags = 2;
		}

		message Item {
			string name = 1;
			int32 quantity = 2;
		}
		"""
		do {
			let fileDescriptor = try SwiftProtoParse.parse(protoContent: protoContent)
			XCTAssertEqual(fileDescriptor.messages.count, 2)
			let inventoryMessage = fileDescriptor.messages.first { $0.name == "Inventory" }!
			XCTAssertEqual(inventoryMessage.fields.count, 2)
			let itemsField = inventoryMessage.fields.first { $0.name == "items" }!
			let tagsField = inventoryMessage.fields.first { $0.name == "tags" }!
			// Validate map field
			if case .map(let keyType, let valueType) = itemsField.type {
				XCTAssertEqual(keyType, .string)
				XCTAssertEqual(valueType, .message("Item"))
			} else {
				XCTFail("items field is not a map")
			}
			// Validate repeated field
			XCTAssertEqual(tagsField.label, .repeated)
			XCTAssertEqual(tagsField.type, .string)
		} catch {
			XCTFail("Parsing failed with error: \(error)")
		}
	}

	// Test Case 16: Message with Reserved Fields and Names
	func testMessageWithReservedFieldsAndNames() {
		let protoContent = """
		syntax = "proto3";

		message LegacyMessage {
			reserved 2, 15, 9 to 11;
			reserved "old_field", "unused_field";
			int32 id = 1;
		}
		"""
		do {
			let fileDescriptor = try SwiftProtoParse.parse(protoContent: protoContent)
			XCTAssertEqual(fileDescriptor.messages.count, 1)
			let message = fileDescriptor.messages.first!
			XCTAssertEqual(message.name, "LegacyMessage")
			// Assuming the parser captures reserved fields and names
			// Validate reserved numbers and names if applicable
		} catch {
			XCTFail("Parsing failed with error: \(error)")
		}
	}

	// Test Case 17: Nested Messages and Enums
	func testNestedMessagesAndEnums() {
		let protoContent = """
		syntax = "proto3";

		message Outer {
			message Inner {
				int32 number = 1;
			}

			enum Color {
				RED = 0;
				GREEN = 1;
				BLUE = 2;
			}

			Inner inner_message = 1;
			Color favorite_color = 2;
		}
		"""
		do {
			let fileDescriptor = try SwiftProtoParse.parse(protoContent: protoContent)
			XCTAssertEqual(fileDescriptor.messages.count, 1)
			let outerMessage = fileDescriptor.messages.first!
			XCTAssertEqual(outerMessage.name, "Outer")
			XCTAssertEqual(outerMessage.nestedTypes.count, 1)
			XCTAssertEqual(outerMessage.enumTypes.count, 1)
			let innerMessage = outerMessage.nestedTypes.first!
			XCTAssertEqual(innerMessage.name, "Inner")
			let colorEnum = outerMessage.enumTypes.first!
			XCTAssertEqual(colorEnum.name, "Color")
		} catch {
			XCTFail("Parsing failed with error: \(error)")
		}
	}

	// Test Case 18: Using Custom Options
	func testUsingCustomOptions() {
		let protoContent = """
		syntax = "proto3";
		import "google/protobuf/descriptor.proto";

		extend google.protobuf.MessageOptions {
			string custom_option = 50001;
		}

		message CustomOptionMessage {
			option (custom_option) = "custom_value";
			string data = 1 [(custom_option) = "field_custom_value"];
		}
		"""
		do {
			let fileDescriptor = try SwiftProtoParse.parse(protoContent: protoContent)
			// Validate that custom options are parsed correctly
			// This requires the parser to handle custom options and extensions
			// Assuming the parser supports this functionality
		} catch {
			XCTFail("Parsing failed with error: \(error)")
		}
	}

	// Test Case 19: Using Extensions
	func testUsingExtensions() {
		let protoContent = """
		syntax = "proto3";

		message ExtendableMessage {
			int32 id = 1;
			extensions 100 to max;
		}

		extend ExtendableMessage {
			string extended_field = 100;
		}
		"""
		do {
			let fileDescriptor = try SwiftProtoParse.parse(protoContent: protoContent)
			// Validate that extensions are parsed correctly
			// This requires the parser to handle extensions
			// Assuming the parser supports this functionality
		} catch {
			XCTFail("Parsing failed with error: \(error)")
		}
	}

	// Test Case 34: Field Number at Maximum Allowed Value
	func testMaximumFieldNumber() {
		let protoContent = """
		syntax = "proto3";

		message MaxFieldNumber {
			string data = 536870911;
		}
		"""
		do {
			let fileDescriptor = try SwiftProtoParse.parse(protoContent: protoContent)
			XCTAssertEqual(fileDescriptor.messages.count, 1)
			let message = fileDescriptor.messages.first!
			XCTAssertEqual(message.fields.count, 1)
			let field = message.fields.first!
			XCTAssertEqual(field.number, 536870911)
		} catch {
			XCTFail("Parsing failed with error: \(error)")
		}
	}

	// Test Case 35: Field Number at Minimum Allowed Value
	func testMinimumFieldNumber() {
		let protoContent = """
		syntax = "proto3";

		message MinFieldNumber {
			string data = 1;
		}
		"""
		do {
			let fileDescriptor = try SwiftProtoParse.parse(protoContent: protoContent)
			XCTAssertEqual(fileDescriptor.messages.count, 1)
			let message = fileDescriptor.messages.first!
			XCTAssertEqual(message.fields.count, 1)
			let field = message.fields.first!
			XCTAssertEqual(field.number, 1)
		} catch {
			XCTFail("Parsing failed with error: \(error)")
		}
	}

	// Test Case 37: Large .proto File with Many Definitions
	func testLargeProtoFile() {
		var protoContent = "syntax = \"proto3\";\n"
		// Generate a large number of messages
		for i in 1...500 {
			protoContent += """
			message Message\(i) {
				string field\(i) = \(i);
			}

			"""
		}
		do {
			let fileDescriptor = try SwiftProtoParse.parse(protoContent: protoContent)
			XCTAssertEqual(fileDescriptor.messages.count, 500)
			for i in 1...500 {
				let message = fileDescriptor.messages.first { $0.name == "Message\(i)" }
				XCTAssertNotNil(message)
				XCTAssertEqual(message?.fields.count, 1)
				XCTAssertEqual(message?.fields.first?.name, "field\(i)")
				XCTAssertEqual(message?.fields.first?.number, Int32(i))
			}
		} catch {
			XCTFail("Parsing failed with error: \(error)")
		}
	}
}

