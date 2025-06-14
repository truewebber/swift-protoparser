import XCTest
@testable import SwiftProtoParser

// MARK: - KeywordRecognizerTests

final class KeywordRecognizerTests: XCTestCase {
    
    // MARK: - Recognition Tests
    
    func testRecognizeKeywords() {
        // Test core keywords
        let syntaxToken = KeywordRecognizer.recognize("syntax")
        XCTAssertTrue(syntaxToken.isKeyword(.syntax))
        
        let packageToken = KeywordRecognizer.recognize("package")
        XCTAssertTrue(packageToken.isKeyword(.package))
        
        let importToken = KeywordRecognizer.recognize("import")
        XCTAssertTrue(importToken.isKeyword(.import))
        
        let optionToken = KeywordRecognizer.recognize("option")
        XCTAssertTrue(optionToken.isKeyword(.option))
        
        // Test type definition keywords
        let messageToken = KeywordRecognizer.recognize("message")
        XCTAssertTrue(messageToken.isKeyword(.message))
        
        let enumToken = KeywordRecognizer.recognize("enum")
        XCTAssertTrue(enumToken.isKeyword(.enum))
        
        let serviceToken = KeywordRecognizer.recognize("service")
        XCTAssertTrue(serviceToken.isKeyword(.service))
        
        let rpcToken = KeywordRecognizer.recognize("rpc")
        XCTAssertTrue(rpcToken.isKeyword(.rpc))
    }
    
    func testRecognizeIdentifiers() {
        let identifiers = [
            "MyMessage",
            "field_name",
            "customType",
            "user_id",
            "timestamp",
            "data_123",
            "proto_file"
        ]
        
        for identifier in identifiers {
            let token = KeywordRecognizer.recognize(identifier)
            
            if case .identifier(let name) = token {
                XCTAssertEqual(name, identifier)
            } else {
                XCTFail("Expected identifier token for '\(identifier)'")
            }
        }
    }
    
    func testRecognizeAllKeywords() {
        // Test that all ProtoKeyword cases are recognized correctly
        for keyword in ProtoKeyword.allCases {
            let token = KeywordRecognizer.recognize(keyword.rawValue)
            XCTAssertTrue(token.isKeyword(keyword), "Failed to recognize keyword: \(keyword.rawValue)")
        }
    }
    
    func testCaseSensitivity() {
        // Keywords should be case-sensitive
        let variations = [
            ("syntax", true),
            ("SYNTAX", false),
            ("Syntax", false),
            ("message", true),
            ("MESSAGE", false),
            ("Message", false),
            ("enum", true),
            ("ENUM", false),
            ("Enum", false)
        ]
        
        for (variant, shouldBeKeyword) in variations {
            let token = KeywordRecognizer.recognize(variant)
            
            if shouldBeKeyword {
                XCTAssertTrue(token.isLiteral == false && token.isIgnorable == false, 
                             "'\(variant)' should be recognized as keyword")
            } else {
                if case .identifier(let name) = token {
                    XCTAssertEqual(name, variant)
                } else {
                    XCTFail("'\(variant)' should be recognized as identifier")
                }
            }
        }
    }
    
    // MARK: - Keyword Check Tests
    
    func testIsKeyword() {
        // Test positive cases
        let keywords = ["syntax", "package", "import", "option", "message", "enum", "service", "rpc"]
        for keyword in keywords {
            XCTAssertTrue(KeywordRecognizer.isKeyword(keyword), "'\(keyword)' should be recognized as keyword")
        }
        
        // Test negative cases
        let identifiers = ["MyMessage", "field_name", "SYNTAX", "Message", "xyz"]
        for identifier in identifiers {
            XCTAssertFalse(KeywordRecognizer.isKeyword(identifier), "'\(identifier)' should not be recognized as keyword")
        }
    }
    
    func testIsValidIdentifier() {
        // Test that keywords are not valid identifiers
        for keyword in ProtoKeyword.allCases {
            XCTAssertFalse(KeywordRecognizer.isValidIdentifier(keyword.rawValue), 
                          "Keyword '\(keyword.rawValue)' should not be valid identifier")
        }
        
        // Test that non-keywords are valid identifiers
        let validIdentifiers = ["MyMessage", "field_name", "user_id", "SYNTAX", "Message"]
        for identifier in validIdentifiers {
            XCTAssertTrue(KeywordRecognizer.isValidIdentifier(identifier), 
                         "'\(identifier)' should be valid identifier")
        }
    }
    
    func testGetKeyword() {
        // Test valid keywords
        for keyword in ProtoKeyword.allCases {
            let result = KeywordRecognizer.getKeyword(keyword.rawValue)
            XCTAssertEqual(result, keyword, "Should return correct keyword for '\(keyword.rawValue)'")
        }
        
        // Test invalid keywords
        let nonKeywords = ["MyMessage", "SYNTAX", "Message", "xyz", ""]
        for nonKeyword in nonKeywords {
            let result = KeywordRecognizer.getKeyword(nonKeyword)
            XCTAssertNil(result, "Should return nil for non-keyword '\(nonKeyword)'")
        }
    }
    
    // MARK: - Validation Tests
    
    func testValidateIdentifierName() {
        // Keywords should not be valid identifiers
        for keyword in ProtoKeyword.allCases {
            XCTAssertFalse(KeywordRecognizer.validateIdentifierName(keyword.rawValue),
                          "Keyword '\(keyword.rawValue)' should not be valid identifier name")
        }
        
        // Non-keywords should be valid identifiers
        let validNames = ["MyMessage", "field_name", "user_id", "timestamp", "data_123"]
        for name in validNames {
            XCTAssertTrue(KeywordRecognizer.validateIdentifierName(name),
                         "'\(name)' should be valid identifier name")
        }
    }
    
    func testSuggestAlternative() {
        // Test suggestions for keywords
        let keywordSuggestions = [
            ("syntax", "syntax_value"),
            ("message", "message_value"),
            ("enum", "enum_value"),
            ("service", "service_value")
        ]
        
        for (keyword, expectedSuggestion) in keywordSuggestions {
            let suggestion = KeywordRecognizer.suggestAlternative(for: keyword)
            XCTAssertEqual(suggestion, expectedSuggestion, 
                          "Wrong suggestion for keyword '\(keyword)'")
        }
        
        // Test that non-keywords return unchanged
        let nonKeywords = ["MyMessage", "field_name", "SYNTAX"]
        for nonKeyword in nonKeywords {
            let suggestion = KeywordRecognizer.suggestAlternative(for: nonKeyword)
            XCTAssertEqual(suggestion, nonKeyword, 
                          "Non-keyword '\(nonKeyword)' should return unchanged")
        }
    }
    
    // MARK: - Category Tests
    
    func testCoreKeywords() {
        let coreKeywords: [ProtoKeyword] = [.syntax, .package, .import, .option]
        let nonCoreKeywords: [ProtoKeyword] = [.message, .enum, .service, .rpc, .repeated]
        
        for keyword in coreKeywords {
            XCTAssertTrue(KeywordRecognizer.isCoreKeyword(keyword), 
                         "'\(keyword.rawValue)' should be core keyword")
        }
        
        for keyword in nonCoreKeywords {
            XCTAssertFalse(KeywordRecognizer.isCoreKeyword(keyword), 
                          "'\(keyword.rawValue)' should not be core keyword")
        }
    }
    
    func testTypeDefinitionKeywords() {
        let typeKeywords: [ProtoKeyword] = [.message, .enum, .service, .rpc]
        let nonTypeKeywords: [ProtoKeyword] = [.syntax, .package, .repeated, .option]
        
        for keyword in typeKeywords {
            XCTAssertTrue(KeywordRecognizer.isTypeDefinitionKeyword(keyword), 
                         "'\(keyword.rawValue)' should be type definition keyword")
        }
        
        for keyword in nonTypeKeywords {
            XCTAssertFalse(KeywordRecognizer.isTypeDefinitionKeyword(keyword), 
                          "'\(keyword.rawValue)' should not be type definition keyword")
        }
    }
    
    func testFieldModifierKeywords() {
        let modifierKeywords: [ProtoKeyword] = [.repeated, .optional, .required]
        let nonModifierKeywords: [ProtoKeyword] = [.syntax, .message, .enum, .service]
        
        for keyword in modifierKeywords {
            XCTAssertTrue(KeywordRecognizer.isFieldModifierKeyword(keyword), 
                         "'\(keyword.rawValue)' should be field modifier keyword")
        }
        
        for keyword in nonModifierKeywords {
            XCTAssertFalse(KeywordRecognizer.isFieldModifierKeyword(keyword), 
                          "'\(keyword.rawValue)' should not be field modifier keyword")
        }
    }
    
    func testServiceKeywords() {
        let serviceKeywords: [ProtoKeyword] = [.returns, .stream, .rpc]
        let nonServiceKeywords: [ProtoKeyword] = [.syntax, .message, .enum, .repeated]
        
        for keyword in serviceKeywords {
            XCTAssertTrue(KeywordRecognizer.isServiceKeyword(keyword), 
                         "'\(keyword.rawValue)' should be service keyword")
        }
        
        for keyword in nonServiceKeywords {
            XCTAssertFalse(KeywordRecognizer.isServiceKeyword(keyword), 
                          "'\(keyword.rawValue)' should not be service keyword")
        }
    }
    
    func testProto2CompatibilityKeywords() {
        let proto2Keywords: [ProtoKeyword] = [.optional, .required, .extend, .extensions, .group]
        let proto3Keywords: [ProtoKeyword] = [.syntax, .message, .enum, .service, .repeated]
        
        for keyword in proto2Keywords {
            XCTAssertTrue(KeywordRecognizer.isProto2CompatibilityKeyword(keyword), 
                         "'\(keyword.rawValue)' should be proto2 compatibility keyword")
        }
        
        for keyword in proto3Keywords {
            XCTAssertFalse(KeywordRecognizer.isProto2CompatibilityKeyword(keyword), 
                          "'\(keyword.rawValue)' should not be proto2 compatibility keyword")
        }
    }
    
    // MARK: - Performance and Utility Tests
    
    func testKeywordCount() {
        let expectedCount = ProtoKeyword.allCases.count
        let actualCount = KeywordRecognizer.keywordCount
        XCTAssertEqual(actualCount, expectedCount, "Keyword count should match ProtoKeyword cases count")
        XCTAssertEqual(actualCount, 21, "Expected 21 keywords total")
    }
    
    func testAllKeywordStrings() {
        let keywordStrings = KeywordRecognizer.allKeywordStrings
        let expectedStrings = ProtoKeyword.allCases.map { $0.rawValue }.sorted()
        
        XCTAssertEqual(keywordStrings.count, ProtoKeyword.allCases.count, 
                      "Should return all keyword strings")
        XCTAssertEqual(keywordStrings, expectedStrings, "Should return sorted keyword strings")
        
        // Test that all strings are unique
        let uniqueStrings = Set(keywordStrings)
        XCTAssertEqual(keywordStrings.count, uniqueStrings.count, 
                      "All keyword strings should be unique")
    }
    
    // MARK: - Performance Tests
    
    func testRecognitionPerformance() {
        let testStrings = [
            "syntax", "message", "enum", "service", "rpc",
            "MyMessage", "field_name", "user_id", "timestamp",
            "not_a_keyword", "custom_type", "data_123"
        ]
        
        measure {
            for _ in 0..<1000 {
                for string in testStrings {
                    _ = KeywordRecognizer.recognize(string)
                }
            }
        }
    }
    
    func testKeywordCheckPerformance() {
        let testStrings = ProtoKeyword.allCases.map { $0.rawValue } + 
                         ["MyMessage", "field_name", "user_id", "not_keyword"]
        
        measure {
            for _ in 0..<1000 {
                for string in testStrings {
                    _ = KeywordRecognizer.isKeyword(string)
                }
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyString() {
        let token = KeywordRecognizer.recognize("")
        if case .identifier(let name) = token {
            XCTAssertEqual(name, "")
        } else {
            XCTFail("Empty string should be recognized as identifier")
        }
        
        XCTAssertFalse(KeywordRecognizer.isKeyword(""))
        XCTAssertTrue(KeywordRecognizer.isValidIdentifier(""))
        XCTAssertNil(KeywordRecognizer.getKeyword(""))
    }
    
    func testSpecialCharacters() {
        let specialStrings = ["syntax-", "message_", "enum123", "service!", "rpc.proto"]
        
        for string in specialStrings {
            let token = KeywordRecognizer.recognize(string)
            if case .identifier(let name) = token {
                XCTAssertEqual(name, string)
            } else {
                XCTFail("String with special characters should be recognized as identifier")
            }
            
            XCTAssertFalse(KeywordRecognizer.isKeyword(string))
            XCTAssertTrue(KeywordRecognizer.isValidIdentifier(string))
        }
    }
}
