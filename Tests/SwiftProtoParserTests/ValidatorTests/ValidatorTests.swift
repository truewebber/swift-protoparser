import XCTest

@testable import SwiftProtoParser

final class ValidatorTests: XCTestCase {
  private func parse(_ input: String) throws -> FileNode {
    let lexer = Lexer(input: input)
    let parser = try Parser(lexer: lexer)
    return try parser.parseFile()
  }

  private func validate(_ input: String) throws {
    let file = try parse(input)
    let validator = ValidatorV2()
    try validator.validate(file)
  }

  func testEnumFirstValueNotZero() throws {
    let input = """
      enum Invalid {
          FIRST = 1;
      }
      """
    XCTAssertThrowsError(try validate(input)) { error in
      guard let error = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      switch error {
      case .firstEnumValueNotZero(_):
        return
      default:
        XCTFail("Expected firstEnumValueNotZero error, got: \(error)")
      }
    }
  }

  func testDuplicateEnumValues() throws {
    let input = """
      enum Duplicate {
          UNKNOWN = 0;
          FIRST = 1;
          SECOND = 1;  // Should fail without allow_alias
      }
      """
    XCTAssertThrowsError(try validate(input)) { error in
      guard let error = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      switch error {
      case .duplicateEnumValue(_, _):
        return
      default:
        XCTFail("Expected duplicateEnumValue error, got: \(error)")
      }
    }
  }

  func testEmptyEnum() throws {
    let input = "enum Empty {}"
    XCTAssertThrowsError(try validate(input)) { error in
      guard let error = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      switch error {
      case .emptyEnum(_):
        return
      default:
        XCTFail("Expected emptyEnum error, got: \(error)")
      }
    }
  }

  func testDuplicateOptions() throws {
    let input = """
      option java_package = "first";
      option java_package = "second";
      """
    XCTAssertThrowsError(try validate(input)) { error in
      guard let error = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      switch error {
      case .duplicateOption(_):
        return
      default:
        XCTFail("Expected duplicateOption error, got: \(error)")
      }
    }
  }

  func testEmptyBlocks() throws {
    // Test empty oneof
    let emptyOneofInput = """
      message Test {
          oneof test {}  // oneof needs fields
      }
      """

    XCTAssertThrowsError(try validate(emptyOneofInput)) { error in
      guard let error = error as? ValidationError else {
        XCTFail("Expected ValidationError")
        return
      }

      switch error {
      case .emptyOneof(_):
        return
      default:
        XCTFail("Expected emptyOneof error, got: \(error)")
      }
    }
  }

  func testNameCollisions() throws {
    let inputs = [
      // Same name for different types at file level
      """
      message Test {}
      enum Test {}
      """,

      // Same name in different scopes
      """
      message Outer {
          message Inner {}
          enum Inner {
            UNKNOWN = 0;
            FIRST = 1;
          }
      }
      """,

      // Duplicate field names in message
      """
      message Test {
          string name = 1;
          int32 name = 2;
      }
      """,
    ]

    for input in inputs {
      XCTAssertThrowsError(try validate(input)) { error in
        guard let error = error as? ValidationError else {
          XCTFail("Expected ValidationError")
          return
        }

        switch error {
        case .duplicateTypeName(_),  // For first case
          .duplicateNestedTypeName(_),  // For second case
          .duplicateFieldName(_, _):  // For third case
          return
        default:
          XCTFail("Expected name collision error, got: \(error)")
        }
      }
    }
  }
  // MARK: - Field Number Tests

  func testFieldNumberRange() throws {
    // Test minimum valid field number
    XCTAssertNoThrow(
      try validate(
        """
        message Test {
            string field = 1;
        }
        """))

    // Test maximum valid field number
    XCTAssertNoThrow(
      try validate(
        """
        message Test {
            string field = 536870911;
        }
        """))

    // Test invalid field numbers
    let invalidNumbers = [
      0,  // Zero
      -1,  // Negative
      536_870_912,  // Too large
      Int.max,  // System max
    ]

    for number in invalidNumbers {
      let input = """
        message Test {
            string field = \(number);
        }
        """
      XCTAssertThrowsError(try validate(input)) { error in
        guard let error = error as? ValidationError else {
          XCTFail("Expected ValidationError")
          return
        }
        switch error {
        case .invalidFieldNumber(_, _):
          break
        default:
          XCTFail("Expected invalidFieldNumber error, got: \(error)")
        }
      }
    }
  }

  func testReservedFieldNumbers() throws {
    // Test reserved range (19000-19999)
    for number in stride(from: 19000, through: 19999, by: 100) {
      let input = """
        message Test {
            string field = \(number);
        }
        """
      XCTAssertThrowsError(try validate(input)) { error in
        guard case .invalidFieldNumber(_, _) = error as? ValidationError else {
          XCTFail("Expected invalidFieldNumber error")
          return
        }
      }
    }

    // Test numbers just outside reserved range are valid
    XCTAssertNoThrow(
      try validate(
        """
        message Test {
            string before = 18999;
            string after = 20000;
        }
        """))
  }
}
