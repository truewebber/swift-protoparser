import XCTest
@testable import SwiftProtoParser

final class ParserErrorTests: XCTestCase {
  
  // MARK: - Basic Error Creation Tests
  
  func testUnexpectedTokenError() {
    let token = Token.identifier("test")
    let error = ParserError.unexpectedToken(token, expected: "keyword", line: 10, column: 5)
    
    XCTAssertEqual(error.line, 10)
    XCTAssertEqual(error.column, 5)
    
    let description = error.description
    XCTAssertTrue(description.contains("Unexpected token"))
    XCTAssertTrue(description.contains("test"))
    XCTAssertTrue(description.contains("line 10"))
    XCTAssertTrue(description.contains("column 5"))
    XCTAssertTrue(description.contains("keyword"))
  }
  
  func testMissingRequiredElementError() {
    let error = ParserError.missingRequiredElement("syntax", line: 1, column: 1)
    
    XCTAssertEqual(error.line, 1)
    XCTAssertEqual(error.column, 1)
    
    let description = error.description
    XCTAssertTrue(description.contains("Missing required element"))
    XCTAssertTrue(description.contains("syntax"))
    XCTAssertTrue(description.contains("line 1"))
    XCTAssertTrue(description.contains("column 1"))
  }
  
  func testDuplicateElementError() {
    let error = ParserError.duplicateElement("package", line: 5, column: 10)
    
    XCTAssertEqual(error.line, 5)
    XCTAssertEqual(error.column, 10)
    
    let description = error.description
    XCTAssertTrue(description.contains("Duplicate element"))
    XCTAssertTrue(description.contains("package"))
    XCTAssertTrue(description.contains("line 5"))
    XCTAssertTrue(description.contains("column 10"))
  }
  
  func testInvalidFieldNumberError() {
    let error = ParserError.invalidFieldNumber(0, line: 15, column: 20)
    
    XCTAssertEqual(error.line, 15)
    XCTAssertEqual(error.column, 20)
    
    let description = error.description
    XCTAssertTrue(description.contains("Invalid field number"))
    XCTAssertTrue(description.contains("0"))
    XCTAssertTrue(description.contains("line 15"))
    XCTAssertTrue(description.contains("column 20"))
  }
  
  func testUnexpectedEndOfInputError() {
    let error = ParserError.unexpectedEndOfInput(expected: "semicolon")
    
    XCTAssertEqual(error.line, 0)
    XCTAssertEqual(error.column, 0)
    
    let description = error.description
    XCTAssertTrue(description.contains("Unexpected end of input"))
    XCTAssertTrue(description.contains("semicolon"))
  }
  
  func testInvalidSyntaxError() {
    let error = ParserError.invalidSyntax("unsupported proto2", line: 1, column: 1)
    
    XCTAssertEqual(error.line, 1)
    XCTAssertEqual(error.column, 1)
    
    let description = error.description
    XCTAssertTrue(description.contains("Invalid syntax"))
    XCTAssertTrue(description.contains("unsupported proto2"))
    XCTAssertTrue(description.contains("line 1"))
    XCTAssertTrue(description.contains("column 1"))
  }
  
  func testReservedFieldNumberError() {
    let error = ParserError.reservedFieldNumber(19500, line: 25, column: 12)
    
    XCTAssertEqual(error.line, 25)
    XCTAssertEqual(error.column, 12)
    
    let description = error.description
    XCTAssertTrue(description.contains("Reserved field number"))
    XCTAssertTrue(description.contains("19500"))
    XCTAssertTrue(description.contains("line 25"))
    XCTAssertTrue(description.contains("column 12"))
    XCTAssertTrue(description.contains("19000-19999"))
  }
  
  func testFieldNumberOutOfRangeError() {
    let error = ParserError.fieldNumberOutOfRange(536870912, line: 30, column: 15)
    
    XCTAssertEqual(error.line, 30)
    XCTAssertEqual(error.column, 15)
    
    let description = error.description
    XCTAssertTrue(description.contains("Field number"))
    XCTAssertTrue(description.contains("out of range"))
    XCTAssertTrue(description.contains("536870912"))
    XCTAssertTrue(description.contains("line 30"))
    XCTAssertTrue(description.contains("column 15"))
    XCTAssertTrue(description.contains("1-536870911"))
  }
  
  func testDuplicateFieldNumberError() {
    let error = ParserError.duplicateFieldNumber(5, line: 40, column: 8)
    
    XCTAssertEqual(error.line, 40)
    XCTAssertEqual(error.column, 8)
    
    let description = error.description
    XCTAssertTrue(description.contains("Duplicate field number"))
    XCTAssertTrue(description.contains("5"))
    XCTAssertTrue(description.contains("line 40"))
    XCTAssertTrue(description.contains("column 8"))
  }
  
  func testInvalidMessageDefinitionError() {
    let error = ParserError.invalidMessageDefinition("empty message", line: 45, column: 3)
    
    XCTAssertEqual(error.line, 45)
    XCTAssertEqual(error.column, 3)
    
    let description = error.description
    XCTAssertTrue(description.contains("Invalid message definition"))
    XCTAssertTrue(description.contains("empty message"))
    XCTAssertTrue(description.contains("line 45"))
    XCTAssertTrue(description.contains("column 3"))
  }
  
  func testInvalidEnumDefinitionError() {
    let error = ParserError.invalidEnumDefinition("no values", line: 50, column: 6)
    
    XCTAssertEqual(error.line, 50)
    XCTAssertEqual(error.column, 6)
    
    let description = error.description
    XCTAssertTrue(description.contains("Invalid enum definition"))
    XCTAssertTrue(description.contains("no values"))
    XCTAssertTrue(description.contains("line 50"))
    XCTAssertTrue(description.contains("column 6"))
  }
  
  func testInvalidServiceDefinitionError() {
    let error = ParserError.invalidServiceDefinition("no methods", line: 55, column: 9)
    
    XCTAssertEqual(error.line, 55)
    XCTAssertEqual(error.column, 9)
    
    let description = error.description
    XCTAssertTrue(description.contains("Invalid service definition"))
    XCTAssertTrue(description.contains("no methods"))
    XCTAssertTrue(description.contains("line 55"))
    XCTAssertTrue(description.contains("column 9"))
  }
  
  func testInvalidOptionValueError() {
    let error = ParserError.invalidOptionValue("malformed value", line: 60, column: 12)
    
    XCTAssertEqual(error.line, 60)
    XCTAssertEqual(error.column, 12)
    
    let description = error.description
    XCTAssertTrue(description.contains("Invalid option value"))
    XCTAssertTrue(description.contains("malformed value"))
    XCTAssertTrue(description.contains("line 60"))
    XCTAssertTrue(description.contains("column 12"))
  }
  
  func testMissingEnumZeroValueError() {
    let error = ParserError.missingEnumZeroValue("Status", line: 65, column: 1)
    
    XCTAssertEqual(error.line, 65)
    XCTAssertEqual(error.column, 1)
    
    let description = error.description
    XCTAssertTrue(description.contains("Enum 'Status'"))
    XCTAssertTrue(description.contains("missing a zero value"))
    XCTAssertTrue(description.contains("proto3"))
    XCTAssertTrue(description.contains("line 65"))
    XCTAssertTrue(description.contains("column 1"))
  }
  
  func testInternalError() {
    let error = ParserError.internalError("test internal error")
    
    XCTAssertEqual(error.line, 0)
    XCTAssertEqual(error.column, 0)
    
    let description = error.description
    XCTAssertTrue(description.contains("Internal parser error"))
    XCTAssertTrue(description.contains("test internal error"))
  }
  
  // MARK: - Convenience Constructor Tests
  
  func testUnexpectedTokenConvenience() {
    let position = Token.Position(line: 10, column: 5)
    let token = Token(type: .identifier("test"), position: position)
    let error = ParserError.unexpectedToken(token, expected: "keyword")
    
    XCTAssertEqual(error.line, 10)
    XCTAssertEqual(error.column, 5)
    
    let description = error.description
    XCTAssertTrue(description.contains("Unexpected token"))
    XCTAssertTrue(description.contains("test"))
    XCTAssertTrue(description.contains("keyword"))
  }
  
  func testMissingElementConvenience() {
    let position = Token.Position(line: 15, column: 8)
    let error = ParserError.missingElement("syntax", at: position)
    
    XCTAssertEqual(error.line, 15)
    XCTAssertEqual(error.column, 8)
    
    let description = error.description
    XCTAssertTrue(description.contains("Missing required element"))
    XCTAssertTrue(description.contains("syntax"))
  }
  
  func testDuplicateElementConvenience() {
    let position = Token.Position(line: 20, column: 12)
    let error = ParserError.duplicateElement("package", at: position)
    
    XCTAssertEqual(error.line, 20)
    XCTAssertEqual(error.column, 12)
    
    let description = error.description
    XCTAssertTrue(description.contains("Duplicate element"))
    XCTAssertTrue(description.contains("package"))
  }
  
  func testInvalidFieldNumberConvenience() {
    let position = Token.Position(line: 25, column: 5)
    let error = ParserError.invalidFieldNumber(-1, at: position)
    
    XCTAssertEqual(error.line, 25)
    XCTAssertEqual(error.column, 5)
    
    let description = error.description
    XCTAssertTrue(description.contains("Invalid field number"))
    XCTAssertTrue(description.contains("-1"))
  }
  
  func testReservedFieldNumberConvenience() {
    let position = Token.Position(line: 30, column: 3)
    let error = ParserError.reservedFieldNumber(19000, at: position)
    
    XCTAssertEqual(error.line, 30)
    XCTAssertEqual(error.column, 3)
    
    let description = error.description
    XCTAssertTrue(description.contains("Reserved field number"))
    XCTAssertTrue(description.contains("19000"))
  }
  
  func testFieldNumberOutOfRangeConvenience() {
    let position = Token.Position(line: 35, column: 7)
    let error = ParserError.fieldNumberOutOfRange(0, at: position)
    
    XCTAssertEqual(error.line, 35)
    XCTAssertEqual(error.column, 7)
    
    let description = error.description
    XCTAssertTrue(description.contains("Field number"))
    XCTAssertTrue(description.contains("out of range"))
    XCTAssertTrue(description.contains("0"))
  }
  
  func testDuplicateFieldNumberConvenience() {
    let position = Token.Position(line: 40, column: 10)
    let error = ParserError.duplicateFieldNumber(1, at: position)
    
    XCTAssertEqual(error.line, 40)
    XCTAssertEqual(error.column, 10)
    
    let description = error.description
    XCTAssertTrue(description.contains("Duplicate field number"))
    XCTAssertTrue(description.contains("1"))
  }
  
  func testMissingEnumZeroValueConvenience() {
    let position = Token.Position(line: 45, column: 2)
    let error = ParserError.missingEnumZeroValue("MyEnum", at: position)
    
    XCTAssertEqual(error.line, 45)
    XCTAssertEqual(error.column, 2)
    
    let description = error.description
    XCTAssertTrue(description.contains("Enum 'MyEnum'"))
    XCTAssertTrue(description.contains("missing a zero value"))
  }
  
  // MARK: - Equality Tests
  
  func testParserErrorEquality() {
    let token = Token.identifier("test")
    let error1 = ParserError.unexpectedToken(token, expected: "keyword", line: 10, column: 5)
    let error2 = ParserError.unexpectedToken(token, expected: "keyword", line: 10, column: 5)
    let error3 = ParserError.unexpectedToken(token, expected: "identifier", line: 10, column: 5)
    
    XCTAssertEqual(error1, error2)
    XCTAssertNotEqual(error1, error3)
  }
  
  func testMissingElementEquality() {
    let error1 = ParserError.missingRequiredElement("syntax", line: 1, column: 1)
    let error2 = ParserError.missingRequiredElement("syntax", line: 1, column: 1)
    let error3 = ParserError.missingRequiredElement("package", line: 1, column: 1)
    
    XCTAssertEqual(error1, error2)
    XCTAssertNotEqual(error1, error3)
  }
  
  func testFieldNumberErrorEquality() {
    let error1 = ParserError.invalidFieldNumber(0, line: 5, column: 3)
    let error2 = ParserError.invalidFieldNumber(0, line: 5, column: 3)
    let error3 = ParserError.invalidFieldNumber(1, line: 5, column: 3)
    
    XCTAssertEqual(error1, error2)
    XCTAssertNotEqual(error1, error3)
  }
  
  func testInternalErrorEquality() {
    let error1 = ParserError.internalError("test message")
    let error2 = ParserError.internalError("test message")
    let error3 = ParserError.internalError("other message")
    
    XCTAssertEqual(error1, error2)
    XCTAssertNotEqual(error1, error3)
  }
  
  // MARK: - CustomStringConvertible Tests
  
  func testLocalizedDescription() {
    let error = ParserError.internalError("test error")
    XCTAssertEqual(error.localizedDescription, error.description)
  }
  
  func testDescriptionConsistency() {
    let errors: [ParserError] = [
      .unexpectedToken(.identifier("test"), expected: "keyword", line: 1, column: 1),
      .missingRequiredElement("syntax", line: 2, column: 2),
      .duplicateElement("package", line: 3, column: 3),
      .invalidFieldNumber(0, line: 4, column: 4),
      .unexpectedEndOfInput(expected: "semicolon"),
      .invalidSyntax("proto2", line: 5, column: 5),
      .reservedFieldNumber(19000, line: 6, column: 6),
      .fieldNumberOutOfRange(536870912, line: 7, column: 7),
      .duplicateFieldNumber(1, line: 8, column: 8),
      .invalidMessageDefinition("empty", line: 9, column: 9),
      .invalidEnumDefinition("no values", line: 10, column: 10),
      .invalidServiceDefinition("no methods", line: 11, column: 11),
      .invalidOptionValue("bad value", line: 12, column: 12),
      .missingEnumZeroValue("Status", line: 13, column: 13),
      .internalError("test")
    ]
    
    for error in errors {
      let description = error.description
      XCTAssertFalse(description.isEmpty, "Description should not be empty for \(error)")
      XCTAssertEqual(error.localizedDescription, description, "localizedDescription should match description")
    }
  }
  
  // MARK: - Error Type Coverage Tests
  
  func testAllErrorTypesHaveValidPosition() {
    let position = Token.Position(line: 42, column: 10)
    
    let errorsWithPosition: [ParserError] = [
      .unexpectedToken(.identifier("test"), expected: "keyword", line: position.line, column: position.column),
      .missingRequiredElement("syntax", line: position.line, column: position.column),
      .duplicateElement("package", line: position.line, column: position.column),
      .invalidFieldNumber(0, line: position.line, column: position.column),
      .invalidSyntax("proto2", line: position.line, column: position.column),
      .reservedFieldNumber(19000, line: position.line, column: position.column),
      .fieldNumberOutOfRange(536870912, line: position.line, column: position.column),
      .duplicateFieldNumber(1, line: position.line, column: position.column),
      .invalidMessageDefinition("empty", line: position.line, column: position.column),
      .invalidEnumDefinition("no values", line: position.line, column: position.column),
      .invalidServiceDefinition("no methods", line: position.line, column: position.column),
      .invalidOptionValue("bad value", line: position.line, column: position.column),
      .missingEnumZeroValue("Status", line: position.line, column: position.column)
    ]
    
    for error in errorsWithPosition {
      XCTAssertEqual(error.line, position.line)
      XCTAssertEqual(error.column, position.column)
    }
    
    // Test errors without position
    let errorsWithoutPosition: [ParserError] = [
      .unexpectedEndOfInput(expected: "semicolon"),
      .internalError("test")
    ]
    
    for error in errorsWithoutPosition {
      XCTAssertEqual(error.line, 0)
      XCTAssertEqual(error.column, 0)
    }
  }
}
