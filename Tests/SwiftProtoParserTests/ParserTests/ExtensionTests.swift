import XCTest
@testable import SwiftProtoParser

final class ExtensionTests: XCTestCase {
  
  // MARK: - Test Parsing Extensions
  
  func testParseBasicExtension() throws {
    let source = """
    syntax = "proto3";
    
    message Foo {
      int32 a = 1;
    }
    
    extend Foo {
      string bar = 2;
    }
    """
    
    let lexer = Lexer(input: source)
    let parser = try Parser(lexer: lexer)
    let file = try parser.parseFile()
    
    XCTAssertEqual(file.extensions.count, 1)
    XCTAssertEqual(file.extensions[0].typeName, "Foo")
    XCTAssertEqual(file.extensions[0].fields.count, 1)
    XCTAssertEqual(file.extensions[0].fields[0].name, "bar")
    XCTAssertEqual(file.extensions[0].fields[0].number, 2)
    
    if case .scalar(let scalarType) = file.extensions[0].fields[0].type {
      XCTAssertEqual(scalarType, TypeNode.ScalarType.string)
    } else {
      XCTFail("Expected scalar type")
    }
  }
  
  func testParseExtensionWithMultipleFields() throws {
    let source = """
    syntax = "proto3";
    
    message Foo {
      int32 a = 1;
    }
    
    extend Foo {
      string bar = 2;
      int32 baz = 3;
      bool qux = 4;
    }
    """
    
    let lexer = Lexer(input: source)
    let parser = try Parser(lexer: lexer)
    let file = try parser.parseFile()
    
    XCTAssertEqual(file.extensions.count, 1)
    XCTAssertEqual(file.extensions[0].typeName, "Foo")
    XCTAssertEqual(file.extensions[0].fields.count, 3)
    
    XCTAssertEqual(file.extensions[0].fields[0].name, "bar")
    XCTAssertEqual(file.extensions[0].fields[0].number, 2)
    if case .scalar(let scalarType) = file.extensions[0].fields[0].type {
      XCTAssertEqual(scalarType, TypeNode.ScalarType.string)
    } else {
      XCTFail("Expected scalar type")
    }
    
    XCTAssertEqual(file.extensions[0].fields[1].name, "baz")
    XCTAssertEqual(file.extensions[0].fields[1].number, 3)
    if case .scalar(let scalarType) = file.extensions[0].fields[1].type {
      XCTAssertEqual(scalarType, TypeNode.ScalarType.int32)
    } else {
      XCTFail("Expected scalar type")
    }
    
    XCTAssertEqual(file.extensions[0].fields[2].name, "qux")
    XCTAssertEqual(file.extensions[0].fields[2].number, 4)
    if case .scalar(let scalarType) = file.extensions[0].fields[2].type {
      XCTAssertEqual(scalarType, TypeNode.ScalarType.bool)
    } else {
      XCTFail("Expected scalar type")
    }
  }
  
  func testParseMultipleExtensions() throws {
    let source = """
    syntax = "proto3";
    
    message Foo {
      int32 a = 1;
    }
    
    message Bar {
      string b = 1;
    }
    
    extend Foo {
      string bar = 2;
    }
    
    extend Bar {
      int32 foo = 2;
    }
    """
    
    let lexer = Lexer(input: source)
    let parser = try Parser(lexer: lexer)
    let file = try parser.parseFile()
    
    XCTAssertEqual(file.extensions.count, 2)
    
    XCTAssertEqual(file.extensions[0].typeName, "Foo")
    XCTAssertEqual(file.extensions[0].fields.count, 1)
    XCTAssertEqual(file.extensions[0].fields[0].name, "bar")
    
    XCTAssertEqual(file.extensions[1].typeName, "Bar")
    XCTAssertEqual(file.extensions[1].fields.count, 1)
    XCTAssertEqual(file.extensions[1].fields[0].name, "foo")
  }
  
  func testParseExtensionWithFullyQualifiedType() throws {
    let source = """
    syntax = "proto3";
    
    package test;
    
    message Foo {
      int32 a = 1;
    }
    
    extend test.Foo {
      string bar = 2;
    }
    """
    
    let lexer = Lexer(input: source)
    let parser = try Parser(lexer: lexer)
    let file = try parser.parseFile()
    
    XCTAssertEqual(file.extensions.count, 1)
    XCTAssertEqual(file.extensions[0].typeName, "test.Foo")
    XCTAssertEqual(file.extensions[0].fields.count, 1)
  }
  
  func testParseExtensionWithOptions() throws {
    let source = """
    syntax = "proto3";
    
    message Foo {
      int32 a = 1;
    }
    
    extend Foo {
      string bar = 2 [deprecated = true];
    }
    """
    
    let lexer = Lexer(input: source)
    let parser = try Parser(lexer: lexer)
    let file = try parser.parseFile()
    
    XCTAssertEqual(file.extensions.count, 1)
    XCTAssertEqual(file.extensions[0].fields.count, 1)
    XCTAssertEqual(file.extensions[0].fields[0].options.count, 1)
    XCTAssertEqual(file.extensions[0].fields[0].options[0].name, "deprecated")
    
    if case .identifier(let value) = file.extensions[0].fields[0].options[0].value {
      XCTAssertEqual(value, "true")
    } else {
      XCTFail("Expected identifier value")
    }
  }
  
  // MARK: - Test Validation
  
  func testValidateExtension() throws {
    let source = """
    syntax = "proto3";
    
    message TestMessage {
      int32 a = 1;
    }
    
    extend TestMessage {
      string bar = 2;
    }
    """
    
    let lexer = Lexer(input: source)
    let parser = try Parser(lexer: lexer)
    let file = try parser.parseFile()
    
    // This should not throw
    try file.validate()
  }
  
  func testValidateExtensionWithInvalidFieldNumber() {
    let source = """
    syntax = "proto3";
    
    message Foo {
      int32 a = 1;
    }
    
    extend Foo {
      string bar = 19000;
    }
    """
    
    let lexer = Lexer(input: source)
    XCTAssertThrowsError(try {
      let parser = try Parser(lexer: lexer)
      _ = try parser.parseFile()
    }()) { error in
      XCTAssertTrue(error is ParserError)
      if let parserError = error as? ParserError {
        switch parserError {
        case .invalidFieldNumber(let number, _):
          XCTAssertEqual(number, 19000)
        default:
          XCTFail("Expected invalidFieldNumber error")
        }
      }
    }
  }
  
  func testValidateEmptyExtension() {
    let source = """
    syntax = "proto3";
    
    message Foo {
      int32 a = 1;
    }
    
    extend Foo {
    }
    """
    
    let lexer = Lexer(input: source)
    XCTAssertThrowsError(try {
      let parser = try Parser(lexer: lexer)
      _ = try parser.parseFile()
    }()) { error in
      XCTAssertTrue(error is ParserError)
      if let parserError = error as? ParserError {
        switch parserError {
        case .custom(let message):
          XCTAssertTrue(message.contains("Extension must contain at least one field"))
        default:
          XCTFail("Expected custom error")
        }
      }
    }
  }
  
  // MARK: - Test Descriptor Generation
  
  func testGenerateExtensionDescriptor() throws {
    let source = """
    syntax = "proto3";
    
    package test;
    
    message Foo {
      int32 a = 1;
    }
    
    extend Foo {
      string bar = 2;
    }
    """
    
    let lexer = Lexer(input: source)
    let parser = try Parser(lexer: lexer)
    let file = try parser.parseFile()
    
    let generator = DescriptorGenerator()
    let descriptor = try generator.generateFileDescriptor(file)
    
    XCTAssertEqual(descriptor.extension.count, 1)
    XCTAssertEqual(descriptor.extension[0].name, "bar")
    XCTAssertEqual(descriptor.extension[0].number, 2)
    XCTAssertEqual(descriptor.extension[0].extendee, ".test.Foo")
  }
} 