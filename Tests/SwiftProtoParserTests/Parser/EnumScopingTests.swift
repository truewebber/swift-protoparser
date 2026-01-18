import XCTest

@testable import SwiftProtoParser

/// Comprehensive tests for scope-aware enum resolution.
///
/// These tests verify that the EnumFieldTypeResolver correctly enforces
/// protobuf scoping rules, matching the behavior of the official protoc compiler.
final class EnumScopingTests: XCTestCase {

  // MARK: - Valid Same-Scope References

  func testSameScopeEnumIsResolved() throws {
    let protoSource = """
      syntax = "proto3";

      message Request {
        enum Status {
          UNKNOWN = 0;
          ACTIVE = 1;
        }
        Status status = 1;
      }
      """

    let ast = try parseProto(protoSource)

    // Verify field type is .enumType
    let message = try XCTUnwrap(ast.messages.first)
    let field = try XCTUnwrap(message.fields.first)

    switch field.type {
    case .enumType(let name):
      XCTAssertEqual(name, "Status", "Same-scope enum should be resolved")
    default:
      XCTFail("Expected .enumType but got \(field.type)")
    }
  }

  // MARK: - Valid Parent-Scope References

  func testParentScopeEnumIsResolved() throws {
    let protoSource = """
      syntax = "proto3";

      message Outer {
        enum Status {
          UNKNOWN = 0;
          ACTIVE = 1;
        }
        
        message Inner {
          Status status = 1;
        }
      }
      """

    let ast = try parseProto(protoSource)

    // Navigate to Inner message
    let outer = try XCTUnwrap(ast.messages.first)
    let inner = try XCTUnwrap(outer.nestedMessages.first)
    let field = try XCTUnwrap(inner.fields.first)

    switch field.type {
    case .enumType(let name):
      XCTAssertEqual(name, "Status", "Parent-scope enum should be resolved")
    default:
      XCTFail("Expected .enumType but got \(field.type)")
    }
  }

  func testGrandparentScopeEnumIsResolved() throws {
    let protoSource = """
      syntax = "proto3";

      message L1 {
        enum Status {
          UNKNOWN = 0;
        }
        
        message L2 {
          message L3 {
            Status status = 1;
          }
        }
      }
      """

    let ast = try parseProto(protoSource)

    // Navigate to L3 message
    let l1 = try XCTUnwrap(ast.messages.first)
    let l2 = try XCTUnwrap(l1.nestedMessages.first)
    let l3 = try XCTUnwrap(l2.nestedMessages.first)
    let field = try XCTUnwrap(l3.fields.first)

    switch field.type {
    case .enumType(let name):
      XCTAssertEqual(name, "Status", "Grandparent-scope enum should be resolved")
    default:
      XCTFail("Expected .enumType but got \(field.type)")
    }
  }

  // MARK: - Valid Top-Level References

  func testTopLevelEnumIsResolved() throws {
    let protoSource = """
      syntax = "proto3";

      enum GlobalStatus {
        UNKNOWN = 0;
        ACTIVE = 1;
      }

      message Request {
        GlobalStatus status = 1;
      }
      """

    let ast = try parseProto(protoSource)

    let message = try XCTUnwrap(ast.messages.first)
    let field = try XCTUnwrap(message.fields.first)

    switch field.type {
    case .enumType(let name):
      XCTAssertEqual(name, "GlobalStatus", "Top-level enum should be resolved")
    default:
      XCTFail("Expected .enumType but got \(field.type)")
    }
  }

  func testTopLevelEnumInNestedMessageIsResolved() throws {
    let protoSource = """
      syntax = "proto3";

      enum GlobalStatus {
        UNKNOWN = 0;
      }

      message Outer {
        message Inner {
          GlobalStatus status = 1;
        }
      }
      """

    let ast = try parseProto(protoSource)

    let outer = try XCTUnwrap(ast.messages.first)
    let inner = try XCTUnwrap(outer.nestedMessages.first)
    let field = try XCTUnwrap(inner.fields.first)

    switch field.type {
    case .enumType(let name):
      XCTAssertEqual(name, "GlobalStatus", "Top-level enum should be visible in nested messages")
    default:
      XCTFail("Expected .enumType but got \(field.type)")
    }
  }

  // MARK: - Invalid Cross-Message References (Critical Test)

  func testCrossMessageEnumIsNotResolved() throws {
    let protoSource = """
      syntax = "proto3";

      message MessageA {
        enum Status {
          UNKNOWN = 0;
          ACTIVE = 1;
        }
      }

      message MessageB {
        Status status = 1;
      }
      """

    let ast = try parseProto(protoSource)

    // Navigate to MessageB
    let messageB = try XCTUnwrap(ast.messages.last)
    let field = try XCTUnwrap(messageB.fields.first)

    switch field.type {
    case .message(let name):
      XCTAssertEqual(name, "Status", "Cross-message enum should NOT be resolved (remains .message)")
    default:
      XCTFail("Expected .message but got \(field.type) - cross-message enum should not be resolved")
    }
  }

  func testSiblingMessageEnumIsNotResolved() throws {
    let protoSource = """
      syntax = "proto3";

      message Outer {
        message MessageA {
          enum Status {
            UNKNOWN = 0;
          }
        }
        
        message MessageB {
          Status status = 1;
        }
      }
      """

    let ast = try parseProto(protoSource)

    // Navigate to MessageB
    let outer = try XCTUnwrap(ast.messages.first)
    let messageB = try XCTUnwrap(outer.nestedMessages.last)
    let field = try XCTUnwrap(messageB.fields.first)

    switch field.type {
    case .message(let name):
      XCTAssertEqual(name, "Status", "Sibling message enum should NOT be resolved")
    default:
      XCTFail("Expected .message but got \(field.type)")
    }
  }

  // MARK: - Qualified Enum References

  func testQualifiedEnumReferenceIsResolved() throws {
    let protoSource = """
      syntax = "proto3";

      message MessageA {
        enum Status {
          UNKNOWN = 0;
          ACTIVE = 1;
        }
      }

      message MessageB {
        MessageA.Status status = 1;
      }
      """

    let ast = try parseProto(protoSource)

    // Navigate to MessageB
    let messageB = try XCTUnwrap(ast.messages.last)
    let field = try XCTUnwrap(messageB.fields.first)

    switch field.type {
    case .enumType(let name):
      XCTAssertEqual(name, "MessageA.Status", "Qualified enum reference should be resolved to .enumType")
    default:
      XCTFail("Expected .enumType but got \(field.type)")
    }
  }

  func testQualifiedMessageReferenceRemainsQualified() throws {
    let protoSource = """
      syntax = "proto3";

      message MessageA {
        message InnerMessage {
          string text = 1;
        }
      }

      message MessageB {
        MessageA.InnerMessage inner = 1;
      }
      """

    let ast = try parseProto(protoSource)

    // Navigate to MessageB
    let messageB = try XCTUnwrap(ast.messages.last)
    let field = try XCTUnwrap(messageB.fields.first)

    switch field.type {
    case .qualifiedType(let name):
      XCTAssertEqual(name, "MessageA.InnerMessage", "Qualified message reference should remain .qualifiedType")
    default:
      XCTFail("Expected .qualifiedType but got \(field.type)")
    }
  }

  // MARK: - Name Shadowing

  func testNameShadowing_NestedPreferredOverTopLevel() throws {
    let protoSource = """
      syntax = "proto3";

      enum Status {
        TOP_LEVEL = 0;
      }

      message Outer {
        enum Status {
          NESTED = 0;
        }
        Status status = 1;
      }
      """

    let ast = try parseProto(protoSource)

    // Verify Outer.status uses nested Status (shadowing top-level)
    let outer = try XCTUnwrap(ast.messages.first)
    let field = try XCTUnwrap(outer.fields.first)

    switch field.type {
    case .enumType(let name):
      XCTAssertEqual(name, "Status", "Should resolve to nested Status (shadowing)")
    // Note: We can't distinguish which Status it resolved to from the name alone,
    // but the resolver should prefer nested over top-level
    default:
      XCTFail("Expected .enumType but got \(field.type)")
    }
  }

  func testNameShadowing_SiblingDoesNotSeeNestedEnum() throws {
    let protoSource = """
      syntax = "proto3";

      message MessageA {
        enum Status {
          NESTED = 0;
        }
      }

      message MessageB {
        Status status = 1;
      }
      """

    let ast = try parseProto(protoSource)

    // MessageB should NOT see MessageA's Status
    let messageB = try XCTUnwrap(ast.messages.last)
    let field = try XCTUnwrap(messageB.fields.first)

    switch field.type {
    case .message(let name):
      XCTAssertEqual(name, "Status", "Sibling should NOT resolve nested enum")
    default:
      XCTFail("Expected .message but got \(field.type)")
    }
  }

  // MARK: - Complex Hierarchies

  func testComplexHierarchy_4LevelNesting() throws {
    let protoSource = """
      syntax = "proto3";

      message L1 {
        enum E1 { V1 = 0; }
        
        message L2 {
          enum E2 { V2 = 0; }
          
          message L3 {
            enum E3 { V3 = 0; }
            
            message L4 {
              E1 e1 = 1;
              E2 e2 = 2;
              E3 e3 = 3;
            }
          }
        }
      }
      """

    let ast = try parseProto(protoSource)

    // Navigate to L4
    let l1 = try XCTUnwrap(ast.messages.first)
    let l2 = try XCTUnwrap(l1.nestedMessages.first)
    let l3 = try XCTUnwrap(l2.nestedMessages.first)
    let l4 = try XCTUnwrap(l3.nestedMessages.first)

    // Check all fields are resolved
    XCTAssertEqual(l4.fields.count, 3)

    for (index, expectedName) in ["E1", "E2", "E3"].enumerated() {
      let field = l4.fields[index]
      switch field.type {
      case .enumType(let name):
        XCTAssertEqual(name, expectedName, "Field e\(index + 1) should resolve to \(expectedName)")
      default:
        XCTFail("Field e\(index + 1) should be .enumType but got \(field.type)")
      }
    }
  }

  func testComplexHierarchy_MixedEnumLocations() throws {
    let protoSource = """
      syntax = "proto3";

      enum GlobalEnum { G = 0; }

      message Outer {
        enum OuterEnum { O = 0; }
        
        message Middle {
          enum MiddleEnum { M = 0; }
          
          message Inner {
            enum InnerEnum { I = 0; }
            
            GlobalEnum g = 1;
            OuterEnum o = 2;
            MiddleEnum m = 3;
            InnerEnum i = 4;
          }
        }
      }
      """

    let ast = try parseProto(protoSource)

    // Navigate to Inner
    let outer = try XCTUnwrap(ast.messages.first)
    let middle = try XCTUnwrap(outer.nestedMessages.first)
    let inner = try XCTUnwrap(middle.nestedMessages.first)

    XCTAssertEqual(inner.fields.count, 4)

    for field in inner.fields {
      switch field.type {
      case .enumType:
        // All should be resolved
        break
      default:
        XCTFail("Field \(field.name) should be .enumType but got \(field.type)")
      }
    }
  }

  // MARK: - Map Types with Enums

  func testMapWithEnumValue() throws {
    let protoSource = """
      syntax = "proto3";

      enum Status {
        UNKNOWN = 0;
        ACTIVE = 1;
      }

      message Request {
        map<string, Status> statuses = 1;
      }
      """

    let ast = try parseProto(protoSource)

    let message = try XCTUnwrap(ast.messages.first)
    let field = try XCTUnwrap(message.fields.first)

    switch field.type {
    case .map(_, let valueType):
      switch valueType {
      case .enumType(let name):
        XCTAssertEqual(name, "Status", "Map value type should be resolved to enum")
      default:
        XCTFail("Map value type should be .enumType but got \(valueType)")
      }
    default:
      XCTFail("Expected .map but got \(field.type)")
    }
  }

  func testMapWithCrossMessageEnumValueNotResolved() throws {
    let protoSource = """
      syntax = "proto3";

      message MessageA {
        enum Status {
          UNKNOWN = 0;
        }
      }

      message MessageB {
        map<string, Status> statuses = 1;
      }
      """

    let ast = try parseProto(protoSource)

    let messageB = try XCTUnwrap(ast.messages.last)
    let field = try XCTUnwrap(messageB.fields.first)

    switch field.type {
    case .map(_, let valueType):
      switch valueType {
      case .message(let name):
        XCTAssertEqual(name, "Status", "Cross-message enum in map should NOT be resolved")
      default:
        XCTFail("Map value type should remain .message but got \(valueType)")
      }
    default:
      XCTFail("Expected .map but got \(field.type)")
    }
  }

  // MARK: - Oneof Fields

  func testOneofFieldEnumIsResolved() throws {
    let protoSource = """
      syntax = "proto3";

      message Request {
        enum Status {
          UNKNOWN = 0;
          ACTIVE = 1;
        }
        
        oneof result {
          Status status = 1;
          string error = 2;
        }
      }
      """

    let ast = try parseProto(protoSource)

    let message = try XCTUnwrap(ast.messages.first)
    let oneof = try XCTUnwrap(message.oneofGroups.first)
    let field = try XCTUnwrap(oneof.fields.first)

    switch field.type {
    case .enumType(let name):
      XCTAssertEqual(name, "Status", "Oneof field enum should be resolved")
    default:
      XCTFail("Expected .enumType but got \(field.type)")
    }
  }

  // MARK: - Regression Tests

  func testExistingTestsStillWork_TopLevelEnum() throws {
    // From EnumFieldTypeResolverTests
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

    let message = try XCTUnwrap(ast.messages.first)
    let field = try XCTUnwrap(message.fields.first)

    switch field.type {
    case .enumType(let name):
      XCTAssertEqual(name, "Status")
    default:
      XCTFail("Expected .enumType but got \(field.type)")
    }
  }

  func testExistingTestsStillWork_NestedEnum() throws {
    // From EnumFieldTypeResolverTests
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

    let message = try XCTUnwrap(ast.messages.first)
    let field = try XCTUnwrap(message.fields.first)

    switch field.type {
    case .enumType(let name):
      XCTAssertEqual(name, "Status")
    default:
      XCTFail("Expected .enumType but got \(field.type)")
    }
  }

  // MARK: - Helper Methods

  private func parseProto(_ source: String) throws -> ProtoAST {
    let lexer = Lexer(input: source)
    let tokensResult = lexer.tokenize()

    guard case .success(let tokens) = tokensResult else {
      throw NSError(
        domain: "test",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Tokenization failed"]
      )
    }

    let parser = Parser(tokens: tokens)
    let parseResult = parser.parse()

    guard case .success(let ast) = parseResult else {
      throw NSError(
        domain: "test",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Parsing failed"]
      )
    }

    return ast
  }
}
