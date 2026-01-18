import XCTest

@testable import SwiftProtoParser

/// Tests for EnumFieldTypeResolver that correctly identifies enum vs message field types.
final class EnumFieldTypeResolverTests: XCTestCase {

  // MARK: - Test Case 1: Top-level enum field

  func testTopLevelEnumFieldIsResolvedCorrectly() throws {
    let protoSource = """
      syntax = "proto3";

      enum Status {
        UNKNOWN = 0;
        ACTIVE = 1;
      }

      message Request {
        Status status = 1;
      }
      """

    let ast = try parseProto(protoSource)
    let resolver = EnumFieldTypeResolver(ast: ast)
    let resolvedAST = resolver.resolveFieldTypes()

    // Verify enum field is correctly identified
    XCTAssertEqual(resolvedAST.messages.count, 1)
    let message = resolvedAST.messages[0]
    XCTAssertEqual(message.fields.count, 1)
    let field = message.fields[0]

    switch field.type {
    case .enumType(let name):
      XCTAssertEqual(name, "Status", "Field should be .enumType(\"Status\")")
    default:
      XCTFail("Expected .enumType but got \(field.type)")
    }
  }

  // MARK: - Test Case 2: Message field remains unchanged

  func testMessageFieldRemainsAsMessage() throws {
    let protoSource = """
      syntax = "proto3";

      message User {
        string name = 1;
      }

      message Request {
        User user = 1;
      }
      """

    let ast = try parseProto(protoSource)
    let resolver = EnumFieldTypeResolver(ast: ast)
    let resolvedAST = resolver.resolveFieldTypes()

    // Verify message field stays as .message
    let request = resolvedAST.messages.first { $0.name == "Request" }
    XCTAssertNotNil(request)
    let field = request?.fields[0]

    switch field?.type {
    case .message(let name):
      XCTAssertEqual(name, "User", "Field should remain .message(\"User\")")
    default:
      XCTFail("Expected .message but got \(String(describing: field?.type))")
    }
  }

  // MARK: - Test Case 3: Nested enum field

  func testNestedEnumFieldIsResolvedCorrectly() throws {
    let protoSource = """
      syntax = "proto3";

      message Outer {
        enum Status {
          UNKNOWN = 0;
          ACTIVE = 1;
        }
        
        Status status = 1;
      }
      """

    let ast = try parseProto(protoSource)
    let resolver = EnumFieldTypeResolver(ast: ast)
    let resolvedAST = resolver.resolveFieldTypes()

    // Verify nested enum field is correctly identified
    XCTAssertEqual(resolvedAST.messages.count, 1)
    let message = resolvedAST.messages[0]
    let field = message.fields[0]

    switch field.type {
    case .enumType(let name):
      XCTAssertEqual(name, "Status", "Nested enum field should be .enumType(\"Status\")")
    default:
      XCTFail("Expected .enumType but got \(field.type)")
    }
  }

  // MARK: - Test Case 4: Multiple enums with same name (scoping)

  func testMultipleEnumsWithSameNameAreHandledCorrectly() throws {
    let protoSource = """
      syntax = "proto3";

      message MessageA {
        enum Status {
          UNKNOWN = 0;
          ACTIVE = 1;
        }
        Status status = 1;
      }

      message MessageB {
        enum Status {
          PENDING = 0;
          DONE = 1;
        }
        Status status = 1;
      }
      """

    let ast = try parseProto(protoSource)
    let resolver = EnumFieldTypeResolver(ast: ast)
    let resolvedAST = resolver.resolveFieldTypes()

    // Both messages should have their Status fields resolved as enums
    XCTAssertEqual(resolvedAST.messages.count, 2)

    for message in resolvedAST.messages {
      XCTAssertEqual(message.fields.count, 1)
      let field = message.fields[0]

      switch field.type {
      case .enumType(let name):
        XCTAssertEqual(name, "Status", "Field in \(message.name) should be .enumType(\"Status\")")
      default:
        XCTFail("Expected .enumType in \(message.name) but got \(field.type)")
      }
    }
  }

  // MARK: - Test Case 5: Qualified types are not touched

  func testQualifiedTypesAreNotChanged() throws {
    let protoSource = """
      syntax = "proto3";

      message Request {
        google.protobuf.Timestamp timestamp = 1;
      }
      """

    let ast = try parseProto(protoSource)
    let resolver = EnumFieldTypeResolver(ast: ast)
    let resolvedAST = resolver.resolveFieldTypes()

    // Verify qualified type remains unchanged
    XCTAssertEqual(resolvedAST.messages.count, 1)
    let field = resolvedAST.messages[0].fields[0]

    switch field.type {
    case .qualifiedType(let name):
      XCTAssertEqual(name, "google.protobuf.Timestamp", "Qualified type should not be changed")
    default:
      XCTFail("Expected .qualifiedType but got \(field.type)")
    }
  }

  // MARK: - Test Case 6: Mixed enum and message fields

  func testMixedEnumAndMessageFields() throws {
    let protoSource = """
      syntax = "proto3";

      enum Status {
        UNKNOWN = 0;
        ACTIVE = 1;
      }

      message User {
        string name = 1;
      }

      message Request {
        Status status = 1;
        User user = 2;
        string text = 3;
      }
      """

    let ast = try parseProto(protoSource)
    let resolver = EnumFieldTypeResolver(ast: ast)
    let resolvedAST = resolver.resolveFieldTypes()

    let request = resolvedAST.messages.first { $0.name == "Request" }
    XCTAssertNotNil(request)
    XCTAssertEqual(request?.fields.count, 3)

    // Check status field (should be enum)
    let statusField = request?.fields[0]
    switch statusField?.type {
    case .enumType(let name):
      XCTAssertEqual(name, "Status")
    default:
      XCTFail("status field should be .enumType")
    }

    // Check user field (should be message)
    let userField = request?.fields[1]
    switch userField?.type {
    case .message(let name):
      XCTAssertEqual(name, "User")
    default:
      XCTFail("user field should be .message")
    }

    // Check text field (should be scalar)
    let textField = request?.fields[2]
    switch textField?.type {
    case .string:
      break  // correct
    default:
      XCTFail("text field should be .string")
    }
  }

  // MARK: - Test Case 7: Repeated enum field

  func testRepeatedEnumFieldIsResolvedCorrectly() throws {
    let protoSource = """
      syntax = "proto3";

      enum Status {
        UNKNOWN = 0;
        ACTIVE = 1;
      }

      message Request {
        repeated Status statuses = 1;
      }
      """

    let ast = try parseProto(protoSource)
    let resolver = EnumFieldTypeResolver(ast: ast)
    let resolvedAST = resolver.resolveFieldTypes()

    let field = resolvedAST.messages[0].fields[0]

    switch field.type {
    case .enumType(let name):
      XCTAssertEqual(name, "Status", "Repeated enum field should be .enumType(\"Status\")")
      XCTAssertEqual(field.label, .repeated, "Field should be repeated")
    default:
      XCTFail("Expected .enumType but got \(field.type)")
    }
  }

  // MARK: - Helper Methods

  private func parseProto(_ source: String) throws -> ProtoAST {
    let lexer = Lexer(input: source)
    let tokensResult = lexer.tokenize()

    guard case .success(let tokens) = tokensResult else {
      throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Tokenization failed"])
    }

    let parser = Parser(tokens: tokens)
    let parseResult = parser.parse()

    guard case .success(let ast) = parseResult else {
      throw NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Parsing failed"])
    }

    return ast
  }
}
