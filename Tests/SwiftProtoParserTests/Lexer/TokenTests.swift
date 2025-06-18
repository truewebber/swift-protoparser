import XCTest
@testable import SwiftProtoParser

// MARK: - TokenTests

final class TokenTests: XCTestCase {
    
    // MARK: - Token Creation Tests
    
    func testTokenCreation() {
        // Test keyword token
        let keywordToken = Token.keyword(.syntax)
        if case .keyword(let keyword) = keywordToken.type {
            XCTAssertEqual(keyword, .syntax)
        } else {
            XCTFail("Expected keyword token")
        }
        
        // Test identifier token
        let identifierToken = Token.identifier("MyMessage")
        if case .identifier(let identifier) = identifierToken.type {
            XCTAssertEqual(identifier, "MyMessage")
        } else {
            XCTFail("Expected identifier token")
        }
        
        // Test string literal token
        let stringToken = Token.stringLiteral("hello world")
        if case .stringLiteral(let string) = stringToken.type {
            XCTAssertEqual(string, "hello world")
        } else {
            XCTFail("Expected string literal token")
        }
    }
    
    func testLiteralTokens() {
        // Test integer literal
        let intToken = Token.integerLiteral(42)
        if case .integerLiteral(let value) = intToken.type {
            XCTAssertEqual(value, 42)
        } else {
            XCTFail("Expected integer literal token")
        }
        
        // Test float literal
        let floatToken = Token.floatLiteral(3.14)
        if case .floatLiteral(let value) = floatToken.type {
            XCTAssertEqual(value, 3.14, accuracy: 0.001)
        } else {
            XCTFail("Expected float literal token")
        }
        
        // Test bool literal
        let boolToken = Token.boolLiteral(true)
        if case .boolLiteral(let value) = boolToken.type {
            XCTAssertTrue(value)
        } else {
            XCTFail("Expected bool literal token")
        }
    }
    
    func testSymbolAndSpecialTokens() {
        // Test symbol token
        let symbolToken = Token.symbol(Character("{"))
        if case .symbol(let symbol) = symbolToken.type {
            XCTAssertEqual(String(symbol), "{")
        } else {
            XCTFail("Expected symbol token")
        }
        
        // Test comment token
        let commentToken = Token.comment("// This is a comment")
        if case .comment(let comment) = commentToken.type {
            XCTAssertEqual(comment, "// This is a comment")
        } else {
            XCTFail("Expected comment token")
        }
        
        // Test special tokens
        XCTAssertEqual(Token.whitespace, Token.whitespace)
        XCTAssertEqual(Token.newline, Token.newline)
        XCTAssertEqual(Token.eof, Token.eof)
    }
    
    // MARK: - Token Equatable Tests
    
    func testTokenEquality() {
        // Test keyword equality
        XCTAssertEqual(Token.keyword(.syntax), Token.keyword(.syntax))
        XCTAssertNotEqual(Token.keyword(.syntax), Token.keyword(.message))
        
        // Test identifier equality
        XCTAssertEqual(Token.identifier("test"), Token.identifier("test"))
        XCTAssertNotEqual(Token.identifier("test1"), Token.identifier("test2"))
        
        // Test string literal equality
        XCTAssertEqual(Token.stringLiteral("hello"), Token.stringLiteral("hello"))
        XCTAssertNotEqual(Token.stringLiteral("hello"), Token.stringLiteral("world"))
        
        // Test integer literal equality
        XCTAssertEqual(Token.integerLiteral(42), Token.integerLiteral(42))
        XCTAssertNotEqual(Token.integerLiteral(42), Token.integerLiteral(43))
        
        // Test float literal equality
        XCTAssertEqual(Token.floatLiteral(3.14), Token.floatLiteral(3.14))
        XCTAssertNotEqual(Token.floatLiteral(3.14), Token.floatLiteral(2.71))
        
        // Test bool literal equality
        XCTAssertEqual(Token.boolLiteral(true), Token.boolLiteral(true))
        XCTAssertNotEqual(Token.boolLiteral(true), Token.boolLiteral(false))
        
        // Test symbol equality
        XCTAssertEqual(Token.symbol("{"), Token.symbol("{"))
        XCTAssertNotEqual(Token.symbol("{"), Token.symbol("}"))
        
        // Test comment equality
        XCTAssertEqual(Token.comment("test"), Token.comment("test"))
        XCTAssertNotEqual(Token.comment("test1"), Token.comment("test2"))
        
        // Test special token equality
        XCTAssertEqual(Token.whitespace, Token.whitespace)
        XCTAssertEqual(Token.newline, Token.newline)
        XCTAssertEqual(Token.eof, Token.eof)
    }
    
    func testTokenInequality() {
        // Test different token types are not equal
        XCTAssertNotEqual(Token.keyword(.syntax), Token.identifier("syntax"))
        XCTAssertNotEqual(Token.identifier("42"), Token.integerLiteral(42))
        XCTAssertNotEqual(Token.stringLiteral("true"), Token.boolLiteral(true))
        XCTAssertNotEqual(Token.whitespace, Token.newline)
        XCTAssertNotEqual(Token.newline, Token.eof)
    }
    
    // MARK: - Token Description Tests
    
    func testTokenDescription() {
        XCTAssertEqual(Token.keyword(.syntax).description, "keyword(syntax)")
        XCTAssertEqual(Token.identifier("MyMessage").description, "identifier(MyMessage)")
        XCTAssertEqual(Token.stringLiteral("hello").description, "stringLiteral(\"hello\")")
        XCTAssertEqual(Token.integerLiteral(42).description, "integerLiteral(42)")
        XCTAssertEqual(Token.floatLiteral(3.14).description, "floatLiteral(3.14)")
        XCTAssertEqual(Token.boolLiteral(true).description, "boolLiteral(true)")
        XCTAssertEqual(Token.symbol("{").description, "symbol({)")
        XCTAssertEqual(Token.whitespace.description, "whitespace")
        XCTAssertEqual(Token.newline.description, "newline")
        XCTAssertEqual(Token.eof.description, "eof")
    }
    
    func testCommentDescriptionTruncation() {
        let longComment = String(repeating: "a", count: 100)
        let commentToken = Token.comment(longComment)
        let description = commentToken.description
        XCTAssertTrue(description.hasPrefix("comment("))
        XCTAssertTrue(description.hasSuffix("...)"))
        XCTAssertTrue(description.count < longComment.count + 20) // Should be truncated
    }
    
    // MARK: - Token Convenience Properties Tests
    
    func testIsIgnorable() {
        XCTAssertTrue(Token.whitespace.isIgnorable)
        XCTAssertTrue(Token.newline.isIgnorable)
        XCTAssertTrue(Token.comment("test").isIgnorable)
        
        XCTAssertFalse(Token.keyword(.syntax).isIgnorable)
        XCTAssertFalse(Token.identifier("test").isIgnorable)
        XCTAssertFalse(Token.stringLiteral("test").isIgnorable)
        XCTAssertFalse(Token.integerLiteral(42).isIgnorable)
        XCTAssertFalse(Token.floatLiteral(3.14).isIgnorable)
        XCTAssertFalse(Token.boolLiteral(true).isIgnorable)
        XCTAssertFalse(Token.symbol("{").isIgnorable)
        XCTAssertFalse(Token.eof.isIgnorable)
    }
    
    func testIsLiteral() {
        XCTAssertTrue(Token.stringLiteral("test").isLiteral)
        XCTAssertTrue(Token.integerLiteral(42).isLiteral)
        XCTAssertTrue(Token.floatLiteral(3.14).isLiteral)
        XCTAssertTrue(Token.boolLiteral(true).isLiteral)
        
        XCTAssertFalse(Token.keyword(.syntax).isLiteral)
        XCTAssertFalse(Token.identifier("test").isLiteral)
        XCTAssertFalse(Token.symbol("{").isLiteral)
        XCTAssertFalse(Token.comment("test").isLiteral)
        XCTAssertFalse(Token.whitespace.isLiteral)
        XCTAssertFalse(Token.newline.isLiteral)
        XCTAssertFalse(Token.eof.isLiteral)
    }
    
    func testIsKeyword() {
        let syntaxToken = Token.keyword(.syntax)
        let messageToken = Token.keyword(.message)
        let identifierToken = Token.identifier("syntax")
        
        XCTAssertTrue(syntaxToken.isKeyword(.syntax))
        XCTAssertFalse(syntaxToken.isKeyword(.message))
        XCTAssertTrue(messageToken.isKeyword(.message))
        XCTAssertFalse(messageToken.isKeyword(.syntax))
        XCTAssertFalse(identifierToken.isKeyword(.syntax))
    }
    
    func testIsSymbol() {
        let braceToken = Token.symbol("{")
        let semicolonToken = Token.symbol(";")
        let identifierToken = Token.identifier("{")
        
        XCTAssertTrue(braceToken.isSymbol("{"))
        XCTAssertFalse(braceToken.isSymbol("}"))
        XCTAssertTrue(semicolonToken.isSymbol(";"))
        XCTAssertFalse(semicolonToken.isSymbol("{"))
        XCTAssertFalse(identifierToken.isSymbol("{"))
    }
}

// MARK: - ProtoKeywordTests

final class ProtoKeywordTests: XCTestCase {
    
    // MARK: - Raw Value Tests
    
    func testKeywordRawValues() {
        XCTAssertEqual(ProtoKeyword.syntax.rawValue, "syntax")
        XCTAssertEqual(ProtoKeyword.package.rawValue, "package")
        XCTAssertEqual(ProtoKeyword.import.rawValue, "import")
        XCTAssertEqual(ProtoKeyword.option.rawValue, "option")
        XCTAssertEqual(ProtoKeyword.message.rawValue, "message")
        XCTAssertEqual(ProtoKeyword.enum.rawValue, "enum")
        XCTAssertEqual(ProtoKeyword.service.rawValue, "service")
        XCTAssertEqual(ProtoKeyword.rpc.rawValue, "rpc")
        XCTAssertEqual(ProtoKeyword.repeated.rawValue, "repeated")
        XCTAssertEqual(ProtoKeyword.optional.rawValue, "optional")
        XCTAssertEqual(ProtoKeyword.required.rawValue, "required")
        XCTAssertEqual(ProtoKeyword.returns.rawValue, "returns")
        XCTAssertEqual(ProtoKeyword.stream.rawValue, "stream")
        XCTAssertEqual(ProtoKeyword.reserved.rawValue, "reserved")
        XCTAssertEqual(ProtoKeyword.oneof.rawValue, "oneof")
        XCTAssertEqual(ProtoKeyword.map.rawValue, "map")
        XCTAssertEqual(ProtoKeyword.extend.rawValue, "extend")
        XCTAssertEqual(ProtoKeyword.extensions.rawValue, "extensions")
        XCTAssertEqual(ProtoKeyword.group.rawValue, "group")
        XCTAssertEqual(ProtoKeyword.public.rawValue, "public")
        XCTAssertEqual(ProtoKeyword.weak.rawValue, "weak")
    }
    
    // MARK: - RawValue Initialization Tests
    
    func testKeywordInitialization() {
        XCTAssertEqual(ProtoKeyword(rawValue: "syntax"), .syntax)
        XCTAssertEqual(ProtoKeyword(rawValue: "message"), .message)
        XCTAssertEqual(ProtoKeyword(rawValue: "service"), .service)
        XCTAssertEqual(ProtoKeyword(rawValue: "import"), .import)
        XCTAssertEqual(ProtoKeyword(rawValue: "enum"), .enum)
        
        // Test invalid keywords
        XCTAssertNil(ProtoKeyword(rawValue: "invalid"))
        XCTAssertNil(ProtoKeyword(rawValue: "SYNTAX"))
        XCTAssertNil(ProtoKeyword(rawValue: "Message"))
        XCTAssertNil(ProtoKeyword(rawValue: ""))
    }
    
    // MARK: - CaseIterable Tests
    
    func testAllCases() {
        let allCases = ProtoKeyword.allCases
        
        // Test that all expected keywords are present
        XCTAssertTrue(allCases.contains(.syntax))
        XCTAssertTrue(allCases.contains(.package))
        XCTAssertTrue(allCases.contains(.import))
        XCTAssertTrue(allCases.contains(.option))
        XCTAssertTrue(allCases.contains(.message))
        XCTAssertTrue(allCases.contains(.enum))
        XCTAssertTrue(allCases.contains(.service))
        XCTAssertTrue(allCases.contains(.rpc))
        XCTAssertTrue(allCases.contains(.repeated))
        XCTAssertTrue(allCases.contains(.optional))
        XCTAssertTrue(allCases.contains(.required))
        XCTAssertTrue(allCases.contains(.returns))
        XCTAssertTrue(allCases.contains(.stream))
        XCTAssertTrue(allCases.contains(.reserved))
        XCTAssertTrue(allCases.contains(.oneof))
        XCTAssertTrue(allCases.contains(.map))
        XCTAssertTrue(allCases.contains(.extend))
        XCTAssertTrue(allCases.contains(.extensions))
        XCTAssertTrue(allCases.contains(.group))
        XCTAssertTrue(allCases.contains(.public))
        XCTAssertTrue(allCases.contains(.weak))
        
        // Test count
        XCTAssertEqual(allCases.count, 21)
    }
    
    // MARK: - Equatable Tests
    
    func testKeywordEquality() {
        XCTAssertEqual(ProtoKeyword.syntax, ProtoKeyword.syntax)
        XCTAssertEqual(ProtoKeyword.message, ProtoKeyword.message)
        XCTAssertNotEqual(ProtoKeyword.syntax, ProtoKeyword.message)
        XCTAssertNotEqual(ProtoKeyword.service, ProtoKeyword.rpc)
    }
    
    // MARK: - Hashable Tests
    
    func testKeywordHashable() {
        let keyword1 = ProtoKeyword.syntax
        let keyword2 = ProtoKeyword.syntax
        let keyword3 = ProtoKeyword.message
        
        XCTAssertEqual(keyword1.hashValue, keyword2.hashValue)
        XCTAssertNotEqual(keyword1.hashValue, keyword3.hashValue)
        
        // Test that it can be used in Set
        let keywordSet: Set<ProtoKeyword> = [keyword1, keyword2, keyword3]
        XCTAssertEqual(keywordSet.count, 2)
        XCTAssertTrue(keywordSet.contains(.syntax))
        XCTAssertTrue(keywordSet.contains(.message))
    }
    
    // MARK: - Keyword Categories Tests
    
    func testCoreKeywords() {
        let coreKeywords: Set<ProtoKeyword> = [.syntax, .package, .import, .option]
        for keyword in coreKeywords {
            XCTAssertTrue(ProtoKeyword.allCases.contains(keyword))
        }
    }
    
    func testTypeDefinitionKeywords() {
        let typeKeywords: Set<ProtoKeyword> = [.message, .enum, .service, .rpc]
        for keyword in typeKeywords {
            XCTAssertTrue(ProtoKeyword.allCases.contains(keyword))
        }
    }
    
    func testFieldModifierKeywords() {
        let modifierKeywords: Set<ProtoKeyword> = [.repeated, .optional, .required]
        for keyword in modifierKeywords {
            XCTAssertTrue(ProtoKeyword.allCases.contains(keyword))
        }
    }
    
    func testServiceKeywords() {
        let serviceKeywords: Set<ProtoKeyword> = [.returns, .stream]
        for keyword in serviceKeywords {
            XCTAssertTrue(ProtoKeyword.allCases.contains(keyword))
        }
    }
    
    func testReservedAndSpecialKeywords() {
        let specialKeywords: Set<ProtoKeyword> = [.reserved, .oneof, .map, .extend, .extensions, .group, .public, .weak]
        for keyword in specialKeywords {
            XCTAssertTrue(ProtoKeyword.allCases.contains(keyword))
        }
    }
}
