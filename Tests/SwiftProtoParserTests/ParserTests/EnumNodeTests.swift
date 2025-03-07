import XCTest
@testable import SwiftProtoParser

/**
 * Test suite for EnumNode
 *
 * This test suite verifies the functionality of the EnumNode component
 * which represents enum definitions in proto files.
 *
 * Test Categories:
 * - Initialization: Verify correct initialization of EnumNode
 * - Value Management: Verify methods for managing enum values
 * - Validation: Verify validation of enum definitions according to proto3 rules
 */
final class EnumNodeTests: XCTestCase {
    
    // MARK: - Test Fixtures
    
    private func createValidEnumNode() -> EnumNode {
        let location = SourceLocation(line: 1, column: 1)
        let valueLocation = SourceLocation(line: 2, column: 3)
        
        let values = [
            EnumValueNode(
                location: valueLocation,
                leadingComments: ["First value must be zero"],
                name: "UNKNOWN",
                number: 0
            ),
            EnumValueNode(
                location: valueLocation,
                name: "VALUE1",
                number: 1
            ),
            EnumValueNode(
                location: valueLocation,
                name: "VALUE2",
                number: 2
            )
        ]
        
        return EnumNode(
            location: location,
            leadingComments: ["Test enum"],
            name: "TestEnum",
            values: values
        )
    }
    
    private func createEnumNodeWithOptions() -> EnumNode {
        let location = SourceLocation(line: 1, column: 1)
        let valueLocation = SourceLocation(line: 2, column: 3)
        
        let values = [
            EnumValueNode(
                location: valueLocation,
                name: "UNKNOWN",
                number: 0
            ),
            EnumValueNode(
                location: valueLocation,
                name: "VALUE1",
                number: 1,
                options: [
                    OptionNode(
                        location: valueLocation,
                        name: "deprecated",
                        value: .identifier("true")
                    )
                ]
            )
        ]
        
        let options = [
            OptionNode(
                location: location,
                name: "allow_alias",
                value: .identifier("true")
            )
        ]
        
        return EnumNode(
            location: location,
            name: "TestEnum",
            values: values,
            options: options,
            allowAlias: true
        )
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        let location = SourceLocation(line: 1, column: 1)
        let leadingComments = ["Test enum"]
        let trailingComment = "Trailing comment"
        let name = "TestEnum"
        let values: [EnumValueNode] = []
        let options: [OptionNode] = []
        let allowAlias = true
        
        let enumNode = EnumNode(
            location: location,
            leadingComments: leadingComments,
            trailingComment: trailingComment,
            name: name,
            values: values,
            options: options,
            allowAlias: allowAlias
        )
        
        XCTAssertEqual(enumNode.location.line, 1)
        XCTAssertEqual(enumNode.location.column, 1)
        XCTAssertEqual(enumNode.leadingComments, leadingComments)
        XCTAssertEqual(enumNode.trailingComment, trailingComment)
        XCTAssertEqual(enumNode.name, name)
        XCTAssertEqual(enumNode.values.count, 0)
        XCTAssertEqual(enumNode.options.count, 0)
        XCTAssertEqual(enumNode.allowAlias, allowAlias)
    }
    
    func testEnumValueNodeInitialization() {
        let location = SourceLocation(line: 2, column: 3)
        let leadingComments = ["Test value"]
        let trailingComment = "Value comment"
        let name = "TEST_VALUE"
        let number = 1
        let options: [OptionNode] = []
        
        let valueNode = EnumValueNode(
            location: location,
            leadingComments: leadingComments,
            trailingComment: trailingComment,
            name: name,
            number: number,
            options: options
        )
        
        XCTAssertEqual(valueNode.location.line, 2)
        XCTAssertEqual(valueNode.location.column, 3)
        XCTAssertEqual(valueNode.leadingComments, leadingComments)
        XCTAssertEqual(valueNode.trailingComment, trailingComment)
        XCTAssertEqual(valueNode.name, name)
        XCTAssertEqual(valueNode.number, number)
        XCTAssertEqual(valueNode.options.count, 0)
    }
    
    // MARK: - Value Management Tests
    
    func testUsedNumbers() {
        let enumNode = createValidEnumNode()
        let usedNumbers = enumNode.usedNumbers
        
        XCTAssertEqual(usedNumbers.count, 3)
        XCTAssertTrue(usedNumbers.contains(0))
        XCTAssertTrue(usedNumbers.contains(1))
        XCTAssertTrue(usedNumbers.contains(2))
    }
    
    func testUsedNames() {
        let enumNode = createValidEnumNode()
        let usedNames = enumNode.usedNames
        
        XCTAssertEqual(usedNames.count, 3)
        XCTAssertTrue(usedNames.contains("UNKNOWN"))
        XCTAssertTrue(usedNames.contains("VALUE1"))
        XCTAssertTrue(usedNames.contains("VALUE2"))
    }
    
    func testFindValueByName() {
        let enumNode = createValidEnumNode()
        
        let value = enumNode.findValue(named: "VALUE1")
        XCTAssertNotNil(value)
        XCTAssertEqual(value?.name, "VALUE1")
        XCTAssertEqual(value?.number, 1)
        
        let nonExistentValue = enumNode.findValue(named: "NON_EXISTENT")
        XCTAssertNil(nonExistentValue)
    }
    
    func testFindValuesByNumber() {
        let enumNode = createValidEnumNode()
        
        let values = enumNode.findValues(withNumber: 1)
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values.first?.name, "VALUE1")
        
        let nonExistentValues = enumNode.findValues(withNumber: 99)
        XCTAssertEqual(nonExistentValues.count, 0)
    }
    
    func testFindValuesByNumberWithAliases() {
        // Create an enum with aliased values
        let location = SourceLocation(line: 1, column: 1)
        let valueLocation = SourceLocation(line: 2, column: 3)
        
        let values = [
            EnumValueNode(location: valueLocation, name: "UNKNOWN", number: 0),
            EnumValueNode(location: valueLocation, name: "VALUE1", number: 1),
            EnumValueNode(location: valueLocation, name: "ALIAS1", number: 1) // Alias for VALUE1
        ]
        
        let enumNode = EnumNode(
            location: location,
            name: "TestEnum",
            values: values,
            allowAlias: true
        )
        
        let aliasedValues = enumNode.findValues(withNumber: 1)
        XCTAssertEqual(aliasedValues.count, 2)
        XCTAssertEqual(aliasedValues[0].name, "VALUE1")
        XCTAssertEqual(aliasedValues[1].name, "ALIAS1")
    }
    
    // MARK: - Validation Tests
    
    func testValidateValidEnum() {
        let enumNode = createValidEnumNode()
        
        XCTAssertNoThrow(try enumNode.validate())
    }
    
    func testValidateInvalidEnumName() {
        let location = SourceLocation(line: 1, column: 1)
        let valueLocation = SourceLocation(line: 2, column: 3)
        
        let values = [
            EnumValueNode(location: valueLocation, name: "UNKNOWN", number: 0)
        ]
        
        // Invalid name (should start with uppercase letter)
        let enumNode = EnumNode(
            location: location,
            name: "invalidName",
            values: values
        )
        
        XCTAssertThrowsError(try enumNode.validate()) { error in
            guard let error = error as? ParserError else {
                XCTFail("Expected ParserError")
                return
            }
            
            if case .invalidEnumName(let name) = error {
                XCTAssertEqual(name, "invalidName")
            } else {
                XCTFail("Expected invalidEnumName error, but got \(error)")
            }
        }
    }
    
    func testValidateEmptyEnum() {
        let location = SourceLocation(line: 1, column: 1)
        
        // Empty enum (no values)
        let enumNode = EnumNode(
            location: location,
            name: "TestEnum",
            values: []
        )
        
        XCTAssertThrowsError(try enumNode.validate()) { error in
            guard let error = error as? ParserError else {
                XCTFail("Expected ParserError")
                return
            }
            
            if case .custom(let message) = error {
                XCTAssertTrue(message.contains("must have at least one value"))
            } else {
                XCTFail("Expected custom error about empty enum, but got \(error)")
            }
        }
    }
    
    func testValidateFirstValueNotZero() {
        let location = SourceLocation(line: 1, column: 1)
        let valueLocation = SourceLocation(line: 2, column: 3)
        
        let values = [
            // First value is not zero (invalid in proto3)
            EnumValueNode(location: valueLocation, name: "VALUE1", number: 1)
        ]
        
        let enumNode = EnumNode(
            location: location,
            name: "TestEnum",
            values: values
        )
        
        XCTAssertThrowsError(try enumNode.validate()) { error in
            guard let error = error as? ParserError else {
                XCTFail("Expected ParserError")
                return
            }
            
            if case .custom(let message) = error {
                XCTAssertTrue(message.contains("must be zero in proto3"))
            } else {
                XCTFail("Expected custom error about first value not zero, but got \(error)")
            }
        }
    }
    
    func testValidateDuplicateValueName() {
        let location = SourceLocation(line: 1, column: 1)
        let valueLocation = SourceLocation(line: 2, column: 3)
        
        let values = [
            EnumValueNode(location: valueLocation, name: "UNKNOWN", number: 0),
            EnumValueNode(location: valueLocation, name: "VALUE1", number: 1),
            // Duplicate name
            EnumValueNode(location: valueLocation, name: "VALUE1", number: 2)
        ]
        
        let enumNode = EnumNode(
            location: location,
            name: "TestEnum",
            values: values
        )
        
        XCTAssertThrowsError(try enumNode.validate()) { error in
            guard let error = error as? ParserError else {
                XCTFail("Expected ParserError")
                return
            }
            
            if case .custom(let message) = error {
                XCTAssertTrue(message.contains("Duplicate enum value name"))
            } else {
                XCTFail("Expected custom error about duplicate name, but got \(error)")
            }
        }
    }
    
    func testValidateDuplicateValueNumber() {
        let location = SourceLocation(line: 1, column: 1)
        let valueLocation = SourceLocation(line: 2, column: 3)
        
        let values = [
            EnumValueNode(location: valueLocation, name: "UNKNOWN", number: 0),
            EnumValueNode(location: valueLocation, name: "VALUE1", number: 1),
            // Duplicate number
            EnumValueNode(location: valueLocation, name: "VALUE2", number: 1)
        ]
        
        // Without allow_alias
        let enumNode = EnumNode(
            location: location,
            name: "TestEnum",
            values: values,
            allowAlias: false
        )
        
        XCTAssertThrowsError(try enumNode.validate()) { error in
            guard let error = error as? ParserError else {
                XCTFail("Expected ParserError")
                return
            }
            
            if case .custom(let message) = error {
                XCTAssertTrue(message.contains("Duplicate enum value number"))
            } else {
                XCTFail("Expected custom error about duplicate number, but got \(error)")
            }
        }
        
        // With allow_alias - should pass
        let enumNodeWithAlias = EnumNode(
            location: location,
            name: "TestEnum",
            values: values,
            allowAlias: true
        )
        
        XCTAssertNoThrow(try enumNodeWithAlias.validate())
    }
    
    func testValidateInvalidValueName() {
        let location = SourceLocation(line: 1, column: 1)
        let valueLocation = SourceLocation(line: 2, column: 3)
        
        let values = [
            EnumValueNode(location: valueLocation, name: "UNKNOWN", number: 0),
            // Invalid name (should be all uppercase)
            EnumValueNode(location: valueLocation, name: "invalidValue", number: 1)
        ]
        
        let enumNode = EnumNode(
            location: location,
            name: "TestEnum",
            values: values
        )
        
        XCTAssertThrowsError(try enumNode.validate()) { error in
            guard let error = error as? ParserError else {
                XCTFail("Expected ParserError")
                return
            }
            
            if case .custom(let message) = error {
                XCTAssertTrue(message.contains("Invalid enum value name"))
            } else {
                XCTFail("Expected custom error about invalid value name, but got \(error)")
            }
        }
    }
    
    func testValidateInvalidOption() {
        let location = SourceLocation(line: 1, column: 1)
        let valueLocation = SourceLocation(line: 2, column: 3)
        
        let values = [
            EnumValueNode(location: valueLocation, name: "UNKNOWN", number: 0)
        ]
        
        let options = [
            // Invalid option value (should be boolean)
            OptionNode(
                location: location,
                name: "allow_alias",
                value: .string("not_a_boolean")
            )
        ]
        
        let enumNode = EnumNode(
            location: location,
            name: "TestEnum",
            values: values,
            options: options
        )
        
        XCTAssertThrowsError(try enumNode.validate()) { error in
            guard let error = error as? ParserError else {
                XCTFail("Expected ParserError")
                return
            }
            
            if case .custom(let message) = error {
                XCTAssertTrue(message.contains("Invalid enum option"))
            } else {
                XCTFail("Expected custom error about invalid option, but got \(error)")
            }
        }
    }
} 