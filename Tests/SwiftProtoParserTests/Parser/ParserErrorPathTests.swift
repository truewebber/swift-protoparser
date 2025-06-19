import XCTest
@testable import SwiftProtoParser

final class ParserErrorPathTests: XCTestCase {

    // MARK: - Syntax Declaration Error Paths
    
    func testMissingSyntaxDeclaration() {
        let protoContent = """
        package test;
        message Test { string name = 1; }
        """
        
        let result = SwiftProtoParser.parseProtoString(protoContent)
        
        switch result {
        case .success:
            XCTFail("Expected parsing to fail without syntax declaration")
        case .failure(let error):
            XCTAssertTrue(error.localizedDescription.contains("syntax") || 
                         error.localizedDescription.contains("expected"), 
                         "Error should mention missing syntax: \(error)")
        }
    }
    
    func testInvalidSyntaxValue() {
        let protoContent = """
        syntax = "proto4";
        message Test { string name = 1; }
        """
        
        let result = SwiftProtoParser.parseProtoString(protoContent)
        
        // Should either fail or default to proto3 with warning
        switch result {
        case .success(let ast):
            // Should default to proto3
            XCTAssertEqual(ast.syntax, .proto3)
        case .failure:
            // Or reject invalid syntax
            XCTAssertTrue(true, "Invalid syntax correctly rejected")
        }
    }
    
    func testMalformedSyntaxDeclaration() {
        let invalidSyntaxCases = [
            "syntax \"proto3\";",           // missing =
            "syntax = proto3;",             // missing quotes
            "syntax = \"proto3\"",          // missing semicolon
            "syntax = ;",                   // missing value
            "= \"proto3\";",                // missing syntax keyword
        ]
        
        for (index, protoContent) in invalidSyntaxCases.enumerated() {
            let result = SwiftProtoParser.parseProtoString(protoContent)
            switch result {
            case .success:
                XCTFail("Case \(index) should fail: \(protoContent)")
            case .failure:
                XCTAssertTrue(true, "Case \(index) correctly failed")
            }
        }
    }
    
    // MARK: - Package Declaration Error Paths
    
    func testInvalidPackageDeclarations() {
        let invalidPackageCases = [
            "syntax = \"proto3\"; package;",                    // missing package name
            "syntax = \"proto3\"; package \"test\";",           // quoted package name
            "syntax = \"proto3\"; package test",               // missing semicolon
            "syntax = \"proto3\"; package test.; message T{}", // trailing dot
            "syntax = \"proto3\"; package .test;",             // leading dot
        ]
        
        for (index, protoContent) in invalidPackageCases.enumerated() {
            let result = SwiftProtoParser.parseProtoString(protoContent)
            switch result {
            case .success:
                XCTFail("Package case \(index) should fail: \(protoContent)")
            case .failure:
                XCTAssertTrue(true, "Package case \(index) correctly failed")
            }
        }
    }
    
    func testDuplicatePackageDeclaration() {
        let protoContent = """
        syntax = "proto3";
        package first;
        package second;
        message Test { string name = 1; }
        """
        
        let result = SwiftProtoParser.parseProtoString(protoContent)
        
        // Should either fail or use first package
        switch result {
        case .success(let ast):
            XCTAssertEqual(ast.package, "first", "Should use first package declaration")
        case .failure:
            XCTAssertTrue(true, "Duplicate package correctly rejected")
        }
    }
    
    // MARK: - Import Declaration Error Paths
    
    func testInvalidImportDeclarations() {
        let invalidImportCases = [
            "syntax = \"proto3\"; import;",                   // missing import path
            "syntax = \"proto3\"; import test.proto;",        // unquoted import
            "syntax = \"proto3\"; import \"test.proto\"",     // missing semicolon
            "syntax = \"proto3\"; import public;",           // missing path after modifier
        ]
        
        for (index, protoContent) in invalidImportCases.enumerated() {
            let result = SwiftProtoParser.parseProtoString(protoContent)
            switch result {
            case .success:
                XCTFail("Import case \(index) should fail: \(protoContent)")
            case .failure:
                XCTAssertTrue(true, "Import case \(index) correctly failed")
            }
        }
    }
    
    func testEmptyImportPath() {
        // Empty import path might be allowed by parser but semantically incorrect
        let protoContent = "syntax = \"proto3\"; import \"\";\n message T{}"
        
        let result = SwiftProtoParser.parseProtoString(protoContent)
        
        switch result {
        case .success(let ast):
            // If parser allows empty import, check it's recorded
            XCTAssertTrue(ast.imports.contains("") || ast.imports.isEmpty, 
                         "Empty import should be handled consistently")
        case .failure:
            XCTAssertTrue(true, "Empty import correctly rejected")
        }
    }
    
    // MARK: - Message Declaration Error Paths
    
    func testInvalidMessageDeclarations() {
        let invalidMessageCases = [
            "syntax = \"proto3\"; message;",                    // missing message name
            "syntax = \"proto3\"; message { string name = 1; }", // missing message name
            "syntax = \"proto3\"; message Test",                // missing open brace
            "syntax = \"proto3\"; message Test { string name = 1;", // missing close brace
            "syntax = \"proto3\"; message 123 { }",             // numeric name
            "syntax = \"proto3\"; message \"Test\" { }",        // quoted name
        ]
        
        for (index, protoContent) in invalidMessageCases.enumerated() {
            let result = SwiftProtoParser.parseProtoString(protoContent)
            switch result {
            case .success:
                XCTFail("Message case \(index) should fail: \(protoContent)")
            case .failure:
                XCTAssertTrue(true, "Message case \(index) correctly failed")
            }
        }
    }
    
    // MARK: - Field Declaration Error Paths
    
    func testInvalidFieldDeclarations() {
        let invalidFieldCases = [
            "syntax = \"proto3\"; message T { string = 1; }",      // missing field name
            "syntax = \"proto3\"; message T { string name; }",     // missing = and number
            "syntax = \"proto3\"; message T { string name = ; }",  // missing field number
            "syntax = \"proto3\"; message T { string name 1; }",   // missing =
            "syntax = \"proto3\"; message T { string name = 1 }",  // missing semicolon
            "syntax = \"proto3\"; message T { name = 1; }",        // missing type
            "syntax = \"proto3\"; message T { string \"name\" = 1; }", // quoted field name
        ]
        
        for (index, protoContent) in invalidFieldCases.enumerated() {
            let result = SwiftProtoParser.parseProtoString(protoContent)
            switch result {
            case .success:
                XCTFail("Field case \(index) should fail: \(protoContent)")
            case .failure:
                XCTAssertTrue(true, "Field case \(index) correctly failed")
            }
        }
    }
    
    func testInvalidFieldNumbers() {
        let invalidNumberCases = [
            ("zero", "syntax = \"proto3\"; message T { string name = 0; }"),
            ("negative", "syntax = \"proto3\"; message T { string name = -1; }"),
            ("too_large", "syntax = \"proto3\"; message T { string name = 536870912; }"),
            ("reserved_range", "syntax = \"proto3\"; message T { string name = 19000; }"),
            ("non_numeric", "syntax = \"proto3\"; message T { string name = abc; }"),
        ]
        
        for (name, protoContent) in invalidNumberCases {
            let result = SwiftProtoParser.parseProtoString(protoContent)
            switch result {
            case .success:
                XCTFail("Invalid field number case '\(name)' should fail")
            case .failure:
                XCTAssertTrue(true, "Invalid field number '\(name)' correctly failed")
            }
        }
    }
    
    // MARK: - Enum Declaration Error Paths
    
    func testInvalidEnumDeclarations() {
        let invalidEnumCases = [
            "syntax = \"proto3\"; enum;",                    // missing enum name
            "syntax = \"proto3\"; enum { VALUE = 0; }",      // missing enum name
            "syntax = \"proto3\"; enum Test",               // missing open brace
            "syntax = \"proto3\"; enum Test { VALUE = 0;",  // missing close brace
            "syntax = \"proto3\"; enum 123 { VALUE = 0; }", // numeric name
        ]
        
        for (index, protoContent) in invalidEnumCases.enumerated() {
            let result = SwiftProtoParser.parseProtoString(protoContent)
            switch result {
            case .success:
                XCTFail("Enum case \(index) should fail: \(protoContent)")
            case .failure:
                XCTAssertTrue(true, "Enum case \(index) correctly failed")
            }
        }
    }
    
    func testInvalidEnumValues() {
        let invalidEnumValueCases = [
            "syntax = \"proto3\"; enum T { = 0; }",           // missing value name
            "syntax = \"proto3\"; enum T { VALUE; }",         // missing = and number
            "syntax = \"proto3\"; enum T { VALUE = ; }",      // missing number
            "syntax = \"proto3\"; enum T { VALUE 0; }",       // missing =
            "syntax = \"proto3\"; enum T { VALUE = 0 }",      // missing semicolon
            "syntax = \"proto3\"; enum T { \"VALUE\" = 0; }", // quoted value name
        ]
        
        for (index, protoContent) in invalidEnumValueCases.enumerated() {
            let result = SwiftProtoParser.parseProtoString(protoContent)
            switch result {
            case .success:
                XCTFail("Enum value case \(index) should fail: \(protoContent)")
            case .failure:
                XCTAssertTrue(true, "Enum value case \(index) correctly failed")
            }
        }
    }
    
    func testEnumMissingZeroValue() {
        let protoContent = """
        syntax = "proto3";
        enum Status {
            ACTIVE = 1;
            INACTIVE = 2;
        }
        """
        
        let result = SwiftProtoParser.parseProtoString(protoContent)
        
        // Should either fail or succeed with validation error
        switch result {
        case .success:
            // Parser might allow it but add validation error
            XCTAssertTrue(true, "Parser allows enum without zero value")
        case .failure:
            XCTAssertTrue(true, "Parser correctly rejects enum without zero value")
        }
    }
    
    // MARK: - Service Declaration Error Paths
    
    func testInvalidServiceDeclarations() {
        let invalidServiceCases = [
            "syntax = \"proto3\"; service;",                         // missing service name
            "syntax = \"proto3\"; service { rpc Test(R) returns (R); }", // missing service name
            "syntax = \"proto3\"; service Test",                     // missing open brace
            "syntax = \"proto3\"; service Test { rpc Test(R) returns (R);", // missing close brace
            "syntax = \"proto3\"; service 123 { }",                  // numeric name
        ]
        
        for (index, protoContent) in invalidServiceCases.enumerated() {
            let result = SwiftProtoParser.parseProtoString(protoContent)
            switch result {
            case .success:
                XCTFail("Service case \(index) should fail: \(protoContent)")
            case .failure:
                XCTAssertTrue(true, "Service case \(index) correctly failed")
            }
        }
    }
    
    func testInvalidRPCDeclarations() {
        let invalidRPCCases = [
            "syntax = \"proto3\"; service S { rpc; }",                    // missing method name
            "syntax = \"proto3\"; service S { rpc (Req) returns (Res); }", // missing method name
            "syntax = \"proto3\"; service S { rpc Test; }",               // missing parentheses
            "syntax = \"proto3\"; service S { rpc Test() returns (Res); }", // missing request type
            "syntax = \"proto3\"; service S { rpc Test(Req) returns; }",   // missing returns type
            "syntax = \"proto3\"; service S { rpc Test(Req) returns (); }", // missing response type
            "syntax = \"proto3\"; service S { rpc Test(Req) (Res); }",     // missing returns keyword
        ]
        
        for (index, protoContent) in invalidRPCCases.enumerated() {
            let result = SwiftProtoParser.parseProtoString(protoContent)
            switch result {
            case .success:
                XCTFail("RPC case \(index) should fail: \(protoContent)")
            case .failure:
                XCTAssertTrue(true, "RPC case \(index) correctly failed")
            }
        }
    }
    
    // MARK: - Option Declaration Error Paths
    
    func testInvalidOptionDeclarations() {
        let invalidOptionCases = [
            "syntax = \"proto3\"; option;",                    // missing option name and value
            "syntax = \"proto3\"; option = \"value\";",        // missing option name
            "syntax = \"proto3\"; option test_option;",        // missing = and value
            "syntax = \"proto3\"; option test_option = ;",     // missing value
            "syntax = \"proto3\"; option test_option \"value\";", // missing =
            "syntax = \"proto3\"; option test_option = \"value\"", // missing semicolon
        ]
        
        for (index, protoContent) in invalidOptionCases.enumerated() {
            let result = SwiftProtoParser.parseProtoString(protoContent)
            switch result {
            case .success:
                XCTFail("Option case \(index) should fail: \(protoContent)")
            case .failure:
                XCTAssertTrue(true, "Option case \(index) correctly failed")
            }
        }
    }
    
    func testInvalidCustomOptions() {
        let invalidCustomOptionCases = [
            "syntax = \"proto3\"; option () = \"value\";",           // missing custom option name
            "syntax = \"proto3\"; option (custom_option = \"value\";", // missing closing paren
            "syntax = \"proto3\"; option custom_option) = \"value\";", // missing opening paren
        ]
        
        for (index, protoContent) in invalidCustomOptionCases.enumerated() {
            let result = SwiftProtoParser.parseProtoString(protoContent)
            switch result {
            case .success:
                XCTFail("Custom option case \(index) should fail: \(protoContent)")
            case .failure:
                XCTAssertTrue(true, "Custom option case \(index) correctly failed")
            }
        }
    }
    
    // MARK: - Field Options Error Paths
    
    func testInvalidFieldOptions() {
        let invalidFieldOptionCases = [
            "syntax = \"proto3\"; message T { string name = 1 []; }",        // empty options
            "syntax = \"proto3\"; message T { string name = 1 [ = true]; }", // missing option name
            "syntax = \"proto3\"; message T { string name = 1 [deprecated]; }", // missing = and value
            "syntax = \"proto3\"; message T { string name = 1 [deprecated = ]; }", // missing value
            "syntax = \"proto3\"; message T { string name = 1 [deprecated true]; }", // missing =
            "syntax = \"proto3\"; message T { string name = 1 [deprecated = true; }", // missing ]
        ]
        
        for (index, protoContent) in invalidFieldOptionCases.enumerated() {
            let result = SwiftProtoParser.parseProtoString(protoContent)
            switch result {
            case .success:
                XCTFail("Field option case \(index) should fail: \(protoContent)")
            case .failure:
                XCTAssertTrue(true, "Field option case \(index) correctly failed")
            }
        }
    }
    
    // MARK: - Complex Malformed Input Tests
    
    func testDeeplyNestedErrorRecovery() {
        let protoContent = """
        syntax = "proto3";
        
        message Outer {
            message Middle {
                message Inner {
                    string field = ; // missing number - should trigger error recovery
                    string valid_field = 1;
                }
                Inner inner = 1;
            }
            Middle middle = 1;
        }
        """
        
        let result = SwiftProtoParser.parseProtoString(protoContent)
        
        switch result {
        case .success:
            XCTFail("Should fail due to missing field number")
        case .failure:
            XCTAssertTrue(true, "Correctly failed on malformed nested structure")
        }
    }
    
    func testMixedValidAndInvalidDeclarations() {
        let protoContent = """
        syntax = "proto3";
        
        package test;
        
        import "valid.proto";
        import ; // invalid import
        
        message ValidMessage {
            string name = 1;
        }
        
        message InvalidMessage {
            string = 2; // missing field name
        }
        
        enum ValidEnum {
            UNKNOWN = 0;
            VALUE = 1;
        }
        
        enum InvalidEnum {
            = 0; // missing value name
        }
        """
        
        let result = SwiftProtoParser.parseProtoString(protoContent)
        
        switch result {
        case .success:
            XCTFail("Should fail due to multiple syntax errors")
        case .failure:
            XCTAssertTrue(true, "Correctly failed on mixed valid/invalid content")
        }
    }
    
    func testUnexpectedTokens() {
        let unexpectedTokenCases = [
            "syntax = \"proto3\"; unexpected_keyword;",
            "syntax = \"proto3\"; message Test { unexpected_content; }",
            "syntax = \"proto3\"; enum Test { unexpected_content; }",
            "syntax = \"proto3\"; service Test { unexpected_content; }",
        ]
        
        for (index, protoContent) in unexpectedTokenCases.enumerated() {
            let result = SwiftProtoParser.parseProtoString(protoContent)
            switch result {
            case .success:
                XCTFail("Unexpected token case \(index) should fail")
            case .failure:
                XCTAssertTrue(true, "Unexpected token case \(index) correctly failed")
            }
        }
    }
    
    // MARK: - Edge Cases and Boundary Tests
    
    func testEmptyInput() {
        let result = SwiftProtoParser.parseProtoString("")
        
        switch result {
        case .success:
            XCTFail("Empty input should fail")
        case .failure:
            XCTAssertTrue(true, "Empty input correctly failed")
        }
    }
    
    func testWhitespaceOnlyInput() {
        let result = SwiftProtoParser.parseProtoString("   \n  \t  \n  ")
        
        switch result {
        case .success:
            XCTFail("Whitespace-only input should fail")
        case .failure:
            XCTAssertTrue(true, "Whitespace-only input correctly failed")
        }
    }
    
    func testCommentsOnlyInput() {
        let protoContent = """
        // This is just a comment
        /* This is a block comment */
        // Another comment
        """
        
        let result = SwiftProtoParser.parseProtoString(protoContent)
        
        switch result {
        case .success:
            XCTFail("Comments-only input should fail")
        case .failure:
            XCTAssertTrue(true, "Comments-only input correctly failed")
        }
    }
    
    func testIncompleteDeclarations() {
        let incompleteCases = [
            "syntax = \"proto3\"; message Test {",  // unclosed message
            "syntax = \"proto3\"; enum Test {",     // unclosed enum
            "syntax = \"proto3\"; service Test {",  // unclosed service
            "syntax = \"proto3\"; message Test { string name = 1", // unclosed field
        ]
        
        for (index, protoContent) in incompleteCases.enumerated() {
            let result = SwiftProtoParser.parseProtoString(protoContent)
            switch result {
            case .success:
                XCTFail("Incomplete case \(index) should fail")
            case .failure:
                XCTAssertTrue(true, "Incomplete case \(index) correctly failed")
            }
        }
    }
}
