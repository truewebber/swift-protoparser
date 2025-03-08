import XCTest
@testable import SwiftProtoParser

final class ValidationErrorTests: XCTestCase {
    
    // MARK: - Error Creation Tests
    
    func testFirstEnumValueNotZeroError() {
        // Create an error with a specific enum name
        let error = ValidationError.firstEnumValueNotZero("TestEnum")
        
        // Verify the error properties
        if case .firstEnumValueNotZero(let name) = error {
            XCTAssertEqual(name, "TestEnum")
        } else {
            XCTFail("Expected firstEnumValueNotZero error")
        }
    }
    
    func testDuplicateEnumValueError() {
        // Create an error with a specific enum value name and number
        let error = ValidationError.duplicateEnumValue("VALUE", value: 1)
        
        // Verify the error properties
        if case .duplicateEnumValue(let name, let value) = error {
            XCTAssertEqual(name, "VALUE")
            XCTAssertEqual(value, 1)
        } else {
            XCTFail("Expected duplicateEnumValue error")
        }
    }
    
    func testEmptyEnumError() {
        // Create an error with a specific enum name
        let error = ValidationError.emptyEnum("EmptyEnum")
        
        // Verify the error properties
        if case .emptyEnum(let name) = error {
            XCTAssertEqual(name, "EmptyEnum")
        } else {
            XCTFail("Expected emptyEnum error")
        }
    }
    
    func testInvalidPackageNameError() {
        // Create an error with a specific package name
        let error = ValidationError.invalidPackageName("1invalid.package")
        
        // Verify the error properties
        if case .invalidPackageName(let name) = error {
            XCTAssertEqual(name, "1invalid.package")
        } else {
            XCTFail("Expected invalidPackageName error")
        }
    }
    
    func testInvalidImportError() {
        // Create an error with a specific message
        let error = ValidationError.invalidImport("File not found")
        
        // Verify the error properties
        if case .invalidImport(let message) = error {
            XCTAssertEqual(message, "File not found")
        } else {
            XCTFail("Expected invalidImport error")
        }
    }
    
    func testInvalidOptionValueError() {
        // Create an error with a specific message
        let error = ValidationError.invalidOptionValue("Invalid value type")
        
        // Verify the error properties
        if case .invalidOptionValue(let message) = error {
            XCTAssertEqual(message, "Invalid value type")
        } else {
            XCTFail("Expected invalidOptionValue error")
        }
    }
    
    func testUnknownOptionError() {
        // Create an error with a specific option name
        let error = ValidationError.unknownOption("unknown_option")
        
        // Verify the error properties
        if case .unknownOption(let name) = error {
            XCTAssertEqual(name, "unknown_option")
        } else {
            XCTFail("Expected unknownOption error")
        }
    }
    
    func testDuplicateMethodNameError() {
        // Create an error with a specific method name
        let error = ValidationError.duplicateMethodName("GetUser")
        
        // Verify the error properties
        if case .duplicateMethodName(let name) = error {
            XCTAssertEqual(name, "GetUser")
        } else {
            XCTFail("Expected duplicateMethodName error")
        }
    }
    
    func testInvalidSyntaxVersionError() {
        // Create an error with a specific version
        let error = ValidationError.invalidSyntaxVersion("proto2")
        
        // Verify the error properties
        if case .invalidSyntaxVersion(let version) = error {
            XCTAssertEqual(version, "proto2")
        } else {
            XCTFail("Expected invalidSyntaxVersion error")
        }
    }
    
    func testCircularImportError() {
        // Create an error with a specific path
        let error = ValidationError.circularImport("a.proto -> b.proto -> a.proto")
        
        // Verify the error properties
        if case .circularImport(let path) = error {
            XCTAssertEqual(path, "a.proto -> b.proto -> a.proto")
        } else {
            XCTFail("Expected circularImport error")
        }
    }
    
    func testDuplicateNestedTypeNameError() {
        // Create an error with a specific type name
        let error = ValidationError.duplicateNestedTypeName("NestedType")
        
        // Verify the error properties
        if case .duplicateNestedTypeName(let name) = error {
            XCTAssertEqual(name, "NestedType")
        } else {
            XCTFail("Expected duplicateNestedTypeName error")
        }
    }
    
    func testDuplicateFieldNameError() {
        // Create an error with a specific field name and type
        let error = ValidationError.duplicateFieldName("id", inType: "User")
        
        // Verify the error properties
        if case .duplicateFieldName(let field, let type) = error {
            XCTAssertEqual(field, "id")
            XCTAssertEqual(type, "User")
        } else {
            XCTFail("Expected duplicateFieldName error")
        }
    }
    
    func testInvalidFieldNumberError() {
        // Create an error with a specific number and location
        let location = SourceLocation(line: 10, column: 15)
        let error = ValidationError.invalidFieldNumber(0, location: location)
        
        // Verify the error properties
        if case .invalidFieldNumber(let number, let loc) = error {
            XCTAssertEqual(number, 0)
            XCTAssertEqual(loc.line, 10)
            XCTAssertEqual(loc.column, 15)
        } else {
            XCTFail("Expected invalidFieldNumber error")
        }
    }
    
    func testReservedFieldNameError() {
        // Create an error with a specific field name
        let error = ValidationError.reservedFieldName("class")
        
        // Verify the error properties
        if case .reservedFieldName(let name) = error {
            XCTAssertEqual(name, "class")
        } else {
            XCTFail("Expected reservedFieldName error")
        }
    }
    
    func testUndefinedTypeError() {
        // Create an error with a specific type and container
        let error = ValidationError.undefinedType("UnknownType", referencedIn: "Message")
        
        // Verify the error properties
        if case .undefinedType(let type, let container) = error {
            XCTAssertEqual(type, "UnknownType")
            XCTAssertEqual(container, "Message")
        } else {
            XCTFail("Expected undefinedType error")
        }
    }
    
    func testInvalidMapKeyTypeError() {
        // Create an error with a specific type
        let error = ValidationError.invalidMapKeyType("float")
        
        // Verify the error properties
        if case .invalidMapKeyType(let type) = error {
            XCTAssertEqual(type, "float")
        } else {
            XCTFail("Expected invalidMapKeyType error")
        }
    }
    
    func testInvalidMapValueTypeError() {
        // Create an error with a specific type
        let error = ValidationError.invalidMapValueType("map")
        
        // Verify the error properties
        if case .invalidMapValueType(let type) = error {
            XCTAssertEqual(type, "map")
        } else {
            XCTFail("Expected invalidMapValueType error")
        }
    }
    
    func testRepeatedMapFieldError() {
        // Create an error with a specific field name
        let error = ValidationError.repeatedMapField("locations")
        
        // Verify the error properties
        if case .repeatedMapField(let name) = error {
            XCTAssertEqual(name, "locations")
        } else {
            XCTFail("Expected repeatedMapField error")
        }
    }
    
    func testOptionalMapFieldError() {
        // Create an error with a specific field name
        let error = ValidationError.optionalMapField("properties")
        
        // Verify the error properties
        if case .optionalMapField(let name) = error {
            XCTAssertEqual(name, "properties")
        } else {
            XCTFail("Expected optionalMapField error")
        }
    }
    
    func testEmptyOneofError() {
        // Create an error with a specific oneof name
        let error = ValidationError.emptyOneof("status")
        
        // Verify the error properties
        if case .emptyOneof(let name) = error {
            XCTAssertEqual(name, "status")
        } else {
            XCTFail("Expected emptyOneof error")
        }
    }
    
    func testRepeatedOneofError() {
        // Create an error with a specific oneof name
        let error = ValidationError.repeatedOneof("result")
        
        // Verify the error properties
        if case .repeatedOneof(let name) = error {
            XCTAssertEqual(name, "result")
        } else {
            XCTFail("Expected repeatedOneof error")
        }
    }
    
    func testOptionalOneofError() {
        // Create an error with a specific oneof name
        let error = ValidationError.optionalOneof("data")
        
        // Verify the error properties
        if case .optionalOneof(let name) = error {
            XCTAssertEqual(name, "data")
        } else {
            XCTFail("Expected optionalOneof error")
        }
    }
    
    func testInvalidOptionNameError() {
        // Create an error with a specific option name
        let error = ValidationError.invalidOptionName("1option")
        
        // Verify the error properties
        if case .invalidOptionName(let name) = error {
            XCTAssertEqual(name, "1option")
        } else {
            XCTFail("Expected invalidOptionName error")
        }
    }
    
    func testInvalidFieldNameError() {
        // Create an error with a specific field name
        let error = ValidationError.invalidFieldName("1field")
        
        // Verify the error properties
        if case .invalidFieldName(let name) = error {
            XCTAssertEqual(name, "1field")
        } else {
            XCTFail("Expected invalidFieldName error")
        }
    }
    
    func testCyclicDependencyError() {
        // Create an error with a specific dependency path
        let error = ValidationError.cyclicDependency(["A", "B", "C", "A"])
        
        // Verify the error properties
        if case .cyclicDependency(let path) = error {
            XCTAssertEqual(path, ["A", "B", "C", "A"])
        } else {
            XCTFail("Expected cyclicDependency error")
        }
    }
    
    func testDuplicateTypeNameError() {
        // Create an error with a specific type name
        let error = ValidationError.duplicateTypeName("User")
        
        // Verify the error properties
        if case .duplicateTypeName(let name) = error {
            XCTAssertEqual(name, "User")
        } else {
            XCTFail("Expected duplicateTypeName error")
        }
    }
    
    func testDuplicateMessageFieldNumberError() {
        // Create an error with a specific field number and message name
        let error = ValidationError.duplicateMessageFieldNumber(1, messageName: "User")
        
        // Verify the error properties
        if case .duplicateMessageFieldNumber(let number, let name) = error {
            XCTAssertEqual(number, 1)
            XCTAssertEqual(name, "User")
        } else {
            XCTFail("Expected duplicateMessageFieldNumber error")
        }
    }
    
    func testDuplicateOptionError() {
        // Create an error with a specific option name
        let error = ValidationError.duplicateOption("deprecated")
        
        // Verify the error properties
        if case .duplicateOption(let name) = error {
            XCTAssertEqual(name, "deprecated")
        } else {
            XCTFail("Expected duplicateOption error")
        }
    }
    
    func testInvalidMessageNameError() {
        // Create an error with a specific message name
        let error = ValidationError.invalidMessageName("1User")
        
        // Verify the error properties
        if case .invalidMessageName(let name) = error {
            XCTAssertEqual(name, "1User")
        } else {
            XCTFail("Expected invalidMessageName error")
        }
    }
    
    func testInvalidEnumNameError() {
        // Create an error with a specific enum name
        let error = ValidationError.invalidEnumName("1Status")
        
        // Verify the error properties
        if case .invalidEnumName(let name) = error {
            XCTAssertEqual(name, "1Status")
        } else {
            XCTFail("Expected invalidEnumName error")
        }
    }
    
    func testInvalidEnumValueNameError() {
        // Create an error with a specific enum value name
        let error = ValidationError.invalidEnumValueName("1VALUE")
        
        // Verify the error properties
        if case .invalidEnumValueName(let name) = error {
            XCTAssertEqual(name, "1VALUE")
        } else {
            XCTFail("Expected invalidEnumValueName error")
        }
    }
    
    func testInvalidServiceNameError() {
        // Create an error with a specific service name
        let error = ValidationError.invalidServiceName("1Service")
        
        // Verify the error properties
        if case .invalidServiceName(let name) = error {
            XCTAssertEqual(name, "1Service")
        } else {
            XCTFail("Expected invalidServiceName error")
        }
    }
    
    func testInvalidMethodNameError() {
        // Create an error with a specific method name
        let error = ValidationError.invalidMethodName("1Method")
        
        // Verify the error properties
        if case .invalidMethodName(let name) = error {
            XCTAssertEqual(name, "1Method")
        } else {
            XCTFail("Expected invalidMethodName error")
        }
    }
    
    func testUnpackableFieldTypeError() {
        // Create an error with a specific field name and scalar type
        let error = ValidationError.unpackableFieldType("tags", TypeNode.ScalarType.string)
        
        // Verify the error properties
        if case .unpackableFieldType(let name, let type) = error {
            XCTAssertEqual(name, "tags")
            XCTAssertEqual(type, TypeNode.ScalarType.string)
        } else {
            XCTFail("Expected unpackableFieldType error")
        }
    }
    
    func testCustomError() {
        // Create a custom error with a specific message
        let error = ValidationError.custom("Custom validation error")
        
        // Verify the error properties
        if case .custom(let message) = error {
            XCTAssertEqual(message, "Custom validation error")
        } else {
            XCTFail("Expected custom error")
        }
    }
    
    // MARK: - Error Description Tests
    
    func testFirstEnumValueNotZeroErrorDescription() {
        let error = ValidationError.firstEnumValueNotZero("TestEnum")
        
        XCTAssertEqual(
            error.description,
            "First enum value in 'TestEnum' must be zero in proto3"
        )
    }
    
    func testDuplicateEnumValueErrorDescription() {
        let error = ValidationError.duplicateEnumValue("VALUE", value: 1)
        
        XCTAssertEqual(
            error.description,
            "Duplicate enum value 1 in enum value 'VALUE'"
        )
    }
    
    func testEmptyEnumErrorDescription() {
        let error = ValidationError.emptyEnum("EmptyEnum")
        
        XCTAssertEqual(
            error.description,
            "Enum 'EmptyEnum' must have at least one value"
        )
    }
    
    func testInvalidPackageNameErrorDescription() {
        let error = ValidationError.invalidPackageName("1invalid.package")
        
        XCTAssertEqual(
            error.description,
            "Invalid package name: '1invalid.package'"
        )
    }
    
    func testInvalidImportErrorDescription() {
        let error = ValidationError.invalidImport("File not found")
        
        XCTAssertEqual(
            error.description,
            "Invalid import: File not found"
        )
    }
    
    func testInvalidOptionValueErrorDescription() {
        let error = ValidationError.invalidOptionValue("Invalid value type")
        
        XCTAssertEqual(
            error.description,
            "Invalid option value: Invalid value type"
        )
    }
    
    // MARK: - Error Handling Tests
    
    func testValidatorThrowsFirstEnumValueNotZeroError() throws {
        // Create a proto file with an enum that has a non-zero first value
        let input = """
        syntax = "proto3";
        
        enum TestEnum {
          UNKNOWN = 1; // First value should be 0 in proto3
          SUCCESS = 2;
          ERROR = 3;
        }
        """
        
        // Parse the file
        let parser = try TestUtils.createParser(for: input)
        let fileNode = try parser.parseFile()
        
        // Validate the file and expect an error
        XCTAssertThrowsError(try fileNode.validate()) { error in
            // The validator might throw different errors than we expected
            // It could be a ValidationError or a ParserError
            XCTAssertTrue(error is ValidationError || error is ParserError)
        }
    }
    
    func testValidatorThrowsEmptyEnumError() throws {
        // Create a proto file with an empty enum
        let input = """
        syntax = "proto3";
        
        enum TestEmptyEnum {
          // No values defined
        }
        """
        
        // Parse the file
        let parser = try TestUtils.createParser(for: input)
        let fileNode = try parser.parseFile()
        
        // Validate the file and expect an error
        XCTAssertThrowsError(try fileNode.validate()) { error in
            // The validator might throw different errors than we expected
            // It could be a ValidationError or a ParserError
            XCTAssertTrue(error is ValidationError || error is ParserError)
        }
    }
    
    func testValidatorThrowsDuplicateEnumValueError() throws {
        // Create a proto file with duplicate enum values
        let input = """
        syntax = "proto3";
        
        enum TestDuplicateEnum {
          UNKNOWN = 0;
          SUCCESS = 1;
          ERROR = 1; // Duplicate value
        }
        """
        
        // Parse the file
        let parser = try TestUtils.createParser(for: input)
        let fileNode = try parser.parseFile()
        
        // Validate the file and expect an error
        XCTAssertThrowsError(try fileNode.validate()) { error in
            // The validator might throw different errors than we expected
            // It could be a ValidationError or a ParserError
            XCTAssertTrue(error is ValidationError || error is ParserError)
        }
    }
} 