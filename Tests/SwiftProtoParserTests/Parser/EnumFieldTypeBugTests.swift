import XCTest
@testable import SwiftProtoParser

/// Test to verify enum field type bug
final class EnumFieldTypeBugTests: XCTestCase {
    
    func testEnumFieldTypeIsCorrect() throws {
        // Create a proto file with an enum and a message that uses it
        let protoSource = """
        syntax = "proto3";
        
        package test;
        
        enum Status {
          UNKNOWN = 0;
          ACTIVE = 1;
        }
        
        message Request {
          Status status = 1;
        }
        """
        
        // Parse the proto source
        let lexer = Lexer(input: protoSource)
        let tokensResult = lexer.tokenize()
        
        guard case .success(let tokens) = tokensResult else {
            XCTFail("Failed to tokenize")
            return
        }
        
        let parser = Parser(tokens: tokens)
        let parseResult = parser.parse()
        
        guard case .success(let ast) = parseResult else {
            XCTFail("Failed to parse")
            return
        }
        
        // Verify we have the enum
        XCTAssertEqual(ast.enums.count, 1)
        XCTAssertEqual(ast.enums[0].name, "Status")
        
        // Verify we have the message
        XCTAssertEqual(ast.messages.count, 1)
        let message = ast.messages[0]
        XCTAssertEqual(message.name, "Request")
        
        // Verify the field
        XCTAssertEqual(message.fields.count, 1)
        let field = message.fields[0]
        XCTAssertEqual(field.name, "status")
        
        // THIS IS THE BUG: The field type should be .enumType("Status")
        // but it's actually .message("Status")
        print("Field type: \(field.type)")
        
        switch field.type {
        case .enumType(let name):
            XCTAssertEqual(name, "Status", "✅ Field has correct .enumType case")
        case .message(let name):
            XCTFail("❌ BUG CONFIRMED: Field type is .message(\"\(name)\") but should be .enumType(\"\(name)\")")
        default:
            XCTFail("Unexpected field type: \(field.type)")
        }
    }
}
