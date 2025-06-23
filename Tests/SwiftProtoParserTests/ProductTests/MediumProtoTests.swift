import XCTest
@testable import SwiftProtoParser

final class MediumProtoTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - Medium Proto3 Product Testing 🟡
    
    func testNestedMessagesParsing() throws {
        // ENHANCED: Test real nested_messages.proto file with deep 4-level nesting
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/medium/nested_messages.proto"
        
        let result = SwiftProtoParser.parseProtoFile(filePath)
        
        switch result {
        case .success(let ast):
            // Verify package name
            XCTAssertEqual(ast.package, "medium.nested")
            
            // Verify syntax
            XCTAssertEqual(ast.syntax, .proto3)
            
            // Verify main message
            XCTAssertEqual(ast.messages.count, 1)
            let company = ast.messages[0]
            XCTAssertEqual(company.name, "Company")
            XCTAssertEqual(company.fields.count, 2)
            
            // Test Company fields
            let companyNameField = company.fields.first { $0.name == "name" }
            XCTAssertNotNil(companyNameField)
            XCTAssertEqual(companyNameField?.number, 1)
            XCTAssertEqual(companyNameField?.type.description, "string")
            
            let departmentsField = company.fields.first { $0.name == "departments" }
            XCTAssertNotNil(departmentsField)
            XCTAssertEqual(departmentsField?.number, 2)
            XCTAssertEqual(departmentsField?.label, .repeated)
            XCTAssertEqual(departmentsField?.type.description, "Department")
            
            // Verify nested structure (4 levels deep: Company -> Department -> Employee -> Address)
            XCTAssertEqual(company.nestedMessages.count, 1)
            let department = company.nestedMessages[0]
            XCTAssertEqual(department.name, "Department")
            XCTAssertEqual(department.fields.count, 3)
            
            // Test Department fields
            let deptNameField = department.fields.first { $0.name == "name" }
            XCTAssertNotNil(deptNameField)
            XCTAssertEqual(deptNameField?.number, 1)
            
            let employeesField = department.fields.first { $0.name == "employees" }
            XCTAssertNotNil(employeesField)
            XCTAssertEqual(employeesField?.number, 2)
            XCTAssertEqual(employeesField?.label, .repeated)
            XCTAssertEqual(employeesField?.type.description, "Employee")
            
            let managerField = department.fields.first { $0.name == "manager" }
            XCTAssertNotNil(managerField)
            XCTAssertEqual(managerField?.number, 3)
            XCTAssertEqual(managerField?.type.description, "Employee")
            
            // Third level: Employee
            XCTAssertEqual(department.nestedMessages.count, 1)
            let employee = department.nestedMessages[0]
            XCTAssertEqual(employee.name, "Employee")
            XCTAssertEqual(employee.fields.count, 5)
            
            // Test Employee fields
            let empNameField = employee.fields.first { $0.name == "name" }
            XCTAssertNotNil(empNameField)
            XCTAssertEqual(empNameField?.number, 1)
            XCTAssertEqual(empNameField?.type.description, "string")
            
            let emailField = employee.fields.first { $0.name == "email" }
            XCTAssertNotNil(emailField)
            XCTAssertEqual(emailField?.number, 2)
            XCTAssertEqual(emailField?.type.description, "string")
            
            let positionField = employee.fields.first { $0.name == "position" }
            XCTAssertNotNil(positionField)
            XCTAssertEqual(positionField?.number, 3)
            XCTAssertEqual(positionField?.type.description, "Position")
            
            let homeAddressField = employee.fields.first { $0.name == "home_address" }
            XCTAssertNotNil(homeAddressField)
            XCTAssertEqual(homeAddressField?.number, 4)
            XCTAssertEqual(homeAddressField?.type.description, "Address")
            
            let workAddressField = employee.fields.first { $0.name == "work_address" }
            XCTAssertNotNil(workAddressField)
            XCTAssertEqual(workAddressField?.number, 5)
            XCTAssertEqual(workAddressField?.type.description, "Address")
            
            // Fourth level: Address (deepest nesting)
            XCTAssertEqual(employee.nestedMessages.count, 1)
            let address = employee.nestedMessages[0]
            XCTAssertEqual(address.name, "Address")
            XCTAssertEqual(address.fields.count, 4)
            
            // Test Address fields
            let addressFieldTests = [
                ("street", 1, "string"),
                ("city", 2, "string"),
                ("country", 3, "string"),
                ("postal_code", 4, "int32")
            ]
            
            for (fieldName, fieldNumber, fieldType) in addressFieldTests {
                let field = address.fields.first { $0.name == fieldName }
                XCTAssertNotNil(field, "Must have Address field: \(fieldName)")
                XCTAssertEqual(field?.number, Int32(fieldNumber))
                XCTAssertEqual(field?.type.description, fieldType)
            }
            
            // Verify Position enum with 6 values (comprehensive coverage)
            XCTAssertEqual(ast.enums.count, 1)
            let position = ast.enums[0]
            XCTAssertEqual(position.name, "Position")
            XCTAssertEqual(position.values.count, 6)
            
            // Check Position enum values
            let positionValues = [
                ("POSITION_UNKNOWN", 0),
                ("JUNIOR", 1),
                ("SENIOR", 2),
                ("LEAD", 3),
                ("MANAGER", 4),
                ("DIRECTOR", 5)
            ]
            
            for (valueName, valueNumber) in positionValues {
                let value = position.values.first { $0.name == valueName }
                XCTAssertNotNil(value, "Must have position value: \(valueName)")
                XCTAssertEqual(value?.number, Int32(valueNumber))
            }
            
            // Verify default value (proto3 requirement)
            let defaultValue = position.values.first { $0.number == 0 }
            XCTAssertNotNil(defaultValue)
            XCTAssertEqual(defaultValue?.name, "POSITION_UNKNOWN")
            
        case .failure(let error):
            XCTFail("Failed to parse real medium/nested_messages.proto: \(error)")
        }
    }
    
    func testRepeatedFieldsParsing() throws {
        // ENHANCED: Test real repeated_fields.proto file with complex repeated field types
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/medium/repeated_fields.proto"
        
        let result = SwiftProtoParser.parseProtoFile(filePath)
        
        switch result {
        case .success(let ast):
            // Verify package name
            XCTAssertEqual(ast.package, "medium.repeated")
            
            // Verify syntax
            XCTAssertEqual(ast.syntax, .proto3)
            
            // Verify all 5 messages exist (comprehensive coverage)
            XCTAssertEqual(ast.messages.count, 5)
            let messageNames = Set(ast.messages.map { $0.name })
            let expectedMessages = ["RepeatedMessage", "NestedItem", "ArrayOfArrays", "StringList", "NumberList"]
            
            for messageName in expectedMessages {
                XCTAssertTrue(messageNames.contains(messageName), "Must have message: \(messageName)")
            }
            
            // Test RepeatedMessage with 7 repeated fields
            let repeatedMessage = ast.messages.first { $0.name == "RepeatedMessage" }
            XCTAssertNotNil(repeatedMessage)
            XCTAssertEqual(repeatedMessage?.fields.count, 7)
            
            // Check all fields are repeated
            let repeatedFields = repeatedMessage?.fields.filter { $0.label == .repeated }
            XCTAssertEqual(repeatedFields?.count, 7)
            
            // Test all repeated field types comprehensively
            let repeatedFieldTests = [
                ("tags", 1, "string"),
                ("numbers", 2, "int32"),
                ("flags", 3, "bool"),
                ("scores", 4, "double"),
                ("data_chunks", 5, "bytes"),
                ("items", 6, "NestedItem"),
                ("categories", 7, "Category")
            ]
            
            for (fieldName, fieldNumber, fieldType) in repeatedFieldTests {
                let field = repeatedMessage?.fields.first { $0.name == fieldName }
                XCTAssertNotNil(field, "Must have repeated field: \(fieldName)")
                XCTAssertEqual(field?.number, Int32(fieldNumber))
                XCTAssertEqual(field?.label, .repeated)
                XCTAssertEqual(field?.type.description, fieldType)
            }
            
            // Test NestedItem message with 3 fields
            let nestedItem = ast.messages.first { $0.name == "NestedItem" }
            XCTAssertNotNil(nestedItem)
            XCTAssertEqual(nestedItem?.fields.count, 3)
            
            let nestedItemFieldTests = [
                ("id", 1, "string"),
                ("name", 2, "string"),
                ("quantity", 3, "int32")
            ]
            
            for (fieldName, fieldNumber, fieldType) in nestedItemFieldTests {
                let field = nestedItem?.fields.first { $0.name == fieldName }
                XCTAssertNotNil(field, "Must have NestedItem field: \(fieldName)")
                XCTAssertEqual(field?.number, Int32(fieldNumber))
                XCTAssertEqual(field?.type.description, fieldType)
            }
            
            // Test Category enum with 5 values
            XCTAssertEqual(ast.enums.count, 1)
            let category = ast.enums[0]
            XCTAssertEqual(category.name, "Category")
            XCTAssertEqual(category.values.count, 5)
            
            // Check Category enum values
            let categoryValues = [
                ("CATEGORY_UNKNOWN", 0),
                ("ELECTRONICS", 1),
                ("CLOTHING", 2),
                ("BOOKS", 3),
                ("FOOD", 4)
            ]
            
            for (valueName, valueNumber) in categoryValues {
                let value = category.values.first { $0.name == valueName }
                XCTAssertNotNil(value, "Must have category value: \(valueName)")
                XCTAssertEqual(value?.number, Int32(valueNumber))
            }
            
            // Test ArrayOfArrays (complex nested repeated patterns)
            let arrayOfArrays = ast.messages.first { $0.name == "ArrayOfArrays" }
            XCTAssertNotNil(arrayOfArrays)
            XCTAssertEqual(arrayOfArrays?.fields.count, 2)
            
            let stringListsField = arrayOfArrays?.fields.first { $0.name == "string_lists" }
            XCTAssertNotNil(stringListsField)
            XCTAssertEqual(stringListsField?.number, 1)
            XCTAssertEqual(stringListsField?.label, .repeated)
            XCTAssertEqual(stringListsField?.type.description, "StringList")
            
            let numberListsField = arrayOfArrays?.fields.first { $0.name == "number_lists" }
            XCTAssertNotNil(numberListsField)
            XCTAssertEqual(numberListsField?.number, 2)
            XCTAssertEqual(numberListsField?.label, .repeated)
            XCTAssertEqual(numberListsField?.type.description, "NumberList")
            
            // Test StringList message
            let stringList = ast.messages.first { $0.name == "StringList" }
            XCTAssertNotNil(stringList)
            XCTAssertEqual(stringList?.fields.count, 1)
            
            let stringValuesField = stringList?.fields.first { $0.name == "values" }
            XCTAssertNotNil(stringValuesField)
            XCTAssertEqual(stringValuesField?.number, 1)
            XCTAssertEqual(stringValuesField?.label, .repeated)
            XCTAssertEqual(stringValuesField?.type.description, "string")
            
            // Test NumberList message
            let numberList = ast.messages.first { $0.name == "NumberList" }
            XCTAssertNotNil(numberList)
            XCTAssertEqual(numberList?.fields.count, 1)
            
            let numberValuesField = numberList?.fields.first { $0.name == "values" }
            XCTAssertNotNil(numberValuesField)
            XCTAssertEqual(numberValuesField?.number, 1)
            XCTAssertEqual(numberValuesField?.label, .repeated)
            XCTAssertEqual(numberValuesField?.type.description, "int32")
            
        case .failure(let error):
            XCTFail("Failed to parse real medium/repeated_fields.proto: \(error)")
        }
    }
    
    func testMapTypesParsing() throws {
        // Test various map types with different key-value combinations
        let protoContent = """
        syntax = "proto3";

        package medium.maps;

        message MapMessage {
          // Basic maps
          map<string, string> string_map = 1;
          map<string, int32> int_map = 2;
          map<string, bool> bool_map = 3;
          map<string, double> double_map = 4;
          map<string, bytes> bytes_map = 5;
          
          // Maps with enum values
          map<string, Status> status_map = 6;
          
          // Maps with message values
          map<string, UserInfo> user_map = 7;
          
          // Maps with different key types
          map<int32, string> id_to_name = 8;
          map<int64, UserInfo> id_to_user = 9;
          map<bool, string> flag_to_description = 10;
        }

        enum Status {
          STATUS_UNKNOWN = 0;
          ACTIVE = 1;
          INACTIVE = 2;
          SUSPENDED = 3;
        }

        message UserInfo {
          string name = 1;
          string email = 2;
          int32 age = 3;
        }
        """
        
        let result = SwiftProtoParser.parseProtoString(protoContent)
        
        switch result {
        case .success(let ast):
            // Verify package
            XCTAssertEqual(ast.package, "medium.maps")
            
            // Verify main message with maps
            let mapMessage = ast.messages.first { $0.name == "MapMessage" }
            XCTAssertNotNil(mapMessage)
            XCTAssertEqual(mapMessage?.fields.count, 10)
            
            // Check basic map types using isMap property
            let stringMapField = mapMessage?.fields.first { $0.name == "string_map" }
            XCTAssertNotNil(stringMapField)
            XCTAssertTrue(stringMapField?.isMap ?? false)
            
            let intMapField = mapMessage?.fields.first { $0.name == "int_map" }
            XCTAssertNotNil(intMapField)
            XCTAssertTrue(intMapField?.isMap ?? false)
            
            // Check map with enum values
            let statusMapField = mapMessage?.fields.first { $0.name == "status_map" }
            XCTAssertNotNil(statusMapField)
            XCTAssertTrue(statusMapField?.isMap ?? false)
            
            // Check map with message values
            let userMapField = mapMessage?.fields.first { $0.name == "user_map" }
            XCTAssertNotNil(userMapField)
            XCTAssertTrue(userMapField?.isMap ?? false)
            
            // Check different key types
            let idToNameField = mapMessage?.fields.first { $0.name == "id_to_name" }
            XCTAssertNotNil(idToNameField)
            XCTAssertTrue(idToNameField?.isMap ?? false)
            
            // Verify enum and message types exist
            XCTAssertEqual(ast.enums.count, 1)
            let status = ast.enums[0]
            XCTAssertEqual(status.name, "Status")
            XCTAssertEqual(status.values.count, 4)
            
            let userInfo = ast.messages.first { $0.name == "UserInfo" }
            XCTAssertNotNil(userInfo)
            XCTAssertEqual(userInfo?.fields.count, 3)
            
        case .failure(let error):
            XCTFail("Failed to parse map types: \(error)")
        }
    }
    
    // MARK: - Extend Statement Testing 🔥
    
    func testCustomOptionsParsing() throws {
        // Test real custom_options.proto file with extend statements
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/extend/custom_options.proto"
        
        let result = SwiftProtoParser.parseProtoFile(filePath)
        
        switch result {
        case .success(let ast):
            // Verify syntax
            XCTAssertEqual(ast.syntax, .proto3)
            
            // Verify imports
            XCTAssertEqual(ast.imports.count, 1)
            XCTAssertEqual(ast.imports[0], "google/protobuf/descriptor.proto")
            
            // CRITICAL: Verify extend statements are parsed
            XCTAssertEqual(ast.extends.count, 6, "Must parse all 6 extend statements")
            
            // Test FileOptions extend
            let fileOptionsExtend = ast.extends.first { $0.extendedType == "google.protobuf.FileOptions" }
            XCTAssertNotNil(fileOptionsExtend, "Must have FileOptions extend")
            XCTAssertEqual(fileOptionsExtend?.fields.count, 2)
            XCTAssertTrue(fileOptionsExtend?.isValidProto3ExtendTarget ?? false)
            
            // Check FileOptions extend fields
            let myFileOptionField = fileOptionsExtend?.fields.first { $0.name == "my_file_option" }
            XCTAssertNotNil(myFileOptionField)
            XCTAssertEqual(myFileOptionField?.number, 50001)
            XCTAssertEqual(myFileOptionField?.type.description, "string")
            XCTAssertEqual(myFileOptionField?.label, .optional)
            
            let fileVersionField = fileOptionsExtend?.fields.first { $0.name == "file_version" }
            XCTAssertNotNil(fileVersionField)
            XCTAssertEqual(fileVersionField?.number, 50002)
            XCTAssertEqual(fileVersionField?.type.description, "int32")
            
            // Test MessageOptions extend
            let messageOptionsExtend = ast.extends.first { $0.extendedType == "google.protobuf.MessageOptions" }
            XCTAssertNotNil(messageOptionsExtend, "Must have MessageOptions extend")
            XCTAssertEqual(messageOptionsExtend?.fields.count, 2)
            XCTAssertTrue(messageOptionsExtend?.isValidProto3ExtendTarget ?? false)
            
            // Check MessageOptions extend fields
            let messageTagField = messageOptionsExtend?.fields.first { $0.name == "message_tag" }
            XCTAssertNotNil(messageTagField)
            XCTAssertEqual(messageTagField?.number, 50003)
            
            let isCriticalField = messageOptionsExtend?.fields.first { $0.name == "is_critical" }
            XCTAssertNotNil(isCriticalField)
            XCTAssertEqual(isCriticalField?.number, 50004)
            XCTAssertEqual(isCriticalField?.type.description, "bool")
            
            // Test FieldOptions extend
            let fieldOptionsExtend = ast.extends.first { $0.extendedType == "google.protobuf.FieldOptions" }
            XCTAssertNotNil(fieldOptionsExtend, "Must have FieldOptions extend")
            XCTAssertEqual(fieldOptionsExtend?.fields.count, 2)
            
            // Test EnumValueOptions extend
            let enumValueOptionsExtend = ast.extends.first { $0.extendedType == "google.protobuf.EnumValueOptions" }
            XCTAssertNotNil(enumValueOptionsExtend, "Must have EnumValueOptions extend")
            XCTAssertEqual(enumValueOptionsExtend?.fields.count, 1)
            
            let displayNameField = enumValueOptionsExtend?.fields.first { $0.name == "display_name" }
            XCTAssertNotNil(displayNameField)
            XCTAssertEqual(displayNameField?.number, 50007)
            
            // Test ServiceOptions extend
            let serviceOptionsExtend = ast.extends.first { $0.extendedType == "google.protobuf.ServiceOptions" }
            XCTAssertNotNil(serviceOptionsExtend, "Must have ServiceOptions extend")
            XCTAssertEqual(serviceOptionsExtend?.fields.count, 1)
            
            // Test MethodOptions extend
            let methodOptionsExtend = ast.extends.first { $0.extendedType == "google.protobuf.MethodOptions" }
            XCTAssertNotNil(methodOptionsExtend, "Must have MethodOptions extend")
            XCTAssertEqual(methodOptionsExtend?.fields.count, 1)
            
            let requiresAuthField = methodOptionsExtend?.fields.first { $0.name == "requires_auth" }
            XCTAssertNotNil(requiresAuthField)
            XCTAssertEqual(requiresAuthField?.number, 50009)
            XCTAssertEqual(requiresAuthField?.type.description, "bool")
            
            // Verify all extend targets are valid proto3 types
            for extend in ast.extends {
                XCTAssertTrue(extend.isValidProto3ExtendTarget, "Extend target \(extend.extendedType) must be valid for proto3")
                XCTAssertTrue(extend.extendedType.hasPrefix("google.protobuf."), "Must extend google.protobuf.* types")
            }
            
            // Verify file-level options usage
            XCTAssertEqual(ast.options.count, 2)
            let myFileOptionUsage = ast.options.first { $0.name == "my_file_option" }
            XCTAssertNotNil(myFileOptionUsage)
            XCTAssertTrue(myFileOptionUsage?.isCustom ?? false)
            
            // Verify messages and enums are also parsed correctly
            XCTAssertEqual(ast.messages.count, 1)
            let testMessage = ast.messages[0]
            XCTAssertEqual(testMessage.name, "TestMessage")
            XCTAssertEqual(testMessage.options.count, 2)
            
            XCTAssertEqual(ast.enums.count, 1)
            let status = ast.enums[0]
            XCTAssertEqual(status.name, "Status")
            
            XCTAssertEqual(ast.services.count, 1)
            let testService = ast.services[0]
            XCTAssertEqual(testService.name, "TestService")
            
        case .failure(let error):
            XCTFail("Failed to parse real extend/custom_options.proto: \(error)")
        }
    }
    
    func testInvalidExtendsParsing() throws {
        // Test error handling for invalid extend statements
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/extend/invalid_extends.proto"
        
        let result = SwiftProtoParser.parseProtoFile(filePath)
        
        switch result {
        case .success(let ast):
            // The file should parse but contain errors for invalid extends
            XCTAssertEqual(ast.syntax, .proto3)
            
            // Should have messages defined in the file
            XCTAssertEqual(ast.messages.count, 2)
            
            // Should have extend statements parsed (even if invalid)
            // The parser should collect these and report errors
            XCTAssertGreaterThan(ast.extends.count, 0, "Should parse extend statements even if invalid")
            
            // Verify invalid extend targets are detected
            for extend in ast.extends {
                if !extend.extendedType.hasPrefix("google.protobuf.") {
                    XCTAssertFalse(extend.isValidProto3ExtendTarget, "Non-google.protobuf.* extends should be invalid")
                }
            }
            
        case .failure(let parseError):
            // Expected to fail with parser errors for invalid extends
            // The public API converts parser errors to ProtoParseError.syntaxError
            switch parseError {
            case .syntaxError(let message, _, _, _):
                XCTAssertTrue(message.contains("extend") || message.contains("google.protobuf"), 
                             "Error message should mention extend or proto3 validation: \(message)")
            default:
                XCTFail("Expected syntax error for invalid extends, got: \(parseError)")
            }
        }
    }
    
    func testOneofGroupsParsing() throws {
        // ENHANCED: Test real oneof_groups.proto file with comprehensive oneof coverage
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/medium/oneof_groups.proto"
        
        let result = SwiftProtoParser.parseProtoFile(filePath)
        
        switch result {
        case .success(let ast):
            // Verify package name
            XCTAssertEqual(ast.package, "medium.oneof")
            
            // Verify syntax
            XCTAssertEqual(ast.syntax, .proto3)
            
            // Verify all 7 messages exist (comprehensive coverage)
            XCTAssertEqual(ast.messages.count, 7)
            let messageNames = Set(ast.messages.map { $0.name })
            let expectedMessages = [
                "OneofMessage", "NestedMessage", "MultipleOneofs", 
                "ComplexOneof", "UserProfile", "AdminProfile", "GuestProfile"
            ]
            
            for messageName in expectedMessages {
                XCTAssertTrue(messageNames.contains(messageName), "Must have message: \(messageName)")
            }
            
            // Test OneofMessage with 5 oneof fields
            let oneofMessage = ast.messages.first { $0.name == "OneofMessage" }
            XCTAssertNotNil(oneofMessage)
            XCTAssertEqual(oneofMessage?.oneofGroups.count, 1)
            
            let testOneof = oneofMessage?.oneofGroups.first
            XCTAssertEqual(testOneof?.name, "test_oneof")
            XCTAssertEqual(testOneof?.fields.count, 5)
            
            // Verify all oneof field types in OneofMessage
            let oneofFieldTests = [
                ("name", 1, "string"),
                ("number", 2, "int32"),
                ("flag", 3, "bool"),
                ("data", 4, "bytes"),
                ("nested", 5, "NestedMessage")
            ]
            
            for (fieldName, fieldNumber, fieldType) in oneofFieldTests {
                let field = testOneof?.fields.first { $0.name == fieldName }
                XCTAssertNotNil(field, "Must have oneof field: \(fieldName)")
                XCTAssertEqual(field?.number, Int32(fieldNumber))
                XCTAssertEqual(field?.type.description, fieldType)
            }
            
            // Check non-oneof field in OneofMessage
            let commonField = oneofMessage?.fields.first { $0.name == "common_field" }
            XCTAssertNotNil(commonField)
            XCTAssertEqual(commonField?.number, 6)
            
            // Test MultipleOneofs with 2 oneof groups
            let multipleOneofs = ast.messages.first { $0.name == "MultipleOneofs" }
            XCTAssertNotNil(multipleOneofs)
            XCTAssertEqual(multipleOneofs?.oneofGroups.count, 2)
            
            // Verify first_choice oneof
            let firstChoice = multipleOneofs?.oneofGroups.first { $0.name == "first_choice" }
            XCTAssertNotNil(firstChoice)
            XCTAssertEqual(firstChoice?.fields.count, 2)
            
            // Verify second_choice oneof
            let secondChoice = multipleOneofs?.oneofGroups.first { $0.name == "second_choice" }
            XCTAssertNotNil(secondChoice)
            XCTAssertEqual(secondChoice?.fields.count, 3)
            
            // Check status_z field uses enum
            let statusField = secondChoice?.fields.first { $0.name == "status_z" }
            XCTAssertNotNil(statusField)
            XCTAssertEqual(statusField?.type.description, "Status")
            
            // Test ComplexOneof with 3 profile types
            let complexOneof = ast.messages.first { $0.name == "ComplexOneof" }
            XCTAssertNotNil(complexOneof)
            XCTAssertEqual(complexOneof?.oneofGroups.count, 1)
            
            let complexChoice = complexOneof?.oneofGroups.first
            XCTAssertEqual(complexChoice?.name, "complex_choice")
            XCTAssertEqual(complexChoice?.fields.count, 3)
            
            // Verify profile message fields
            let profileFieldTests = [
                ("user", 1, "UserProfile"),
                ("admin", 2, "AdminProfile"),
                ("guest", 3, "GuestProfile")
            ]
            
            for (fieldName, fieldNumber, fieldType) in profileFieldTests {
                let field = complexChoice?.fields.first { $0.name == fieldName }
                XCTAssertNotNil(field, "Must have profile field: \(fieldName)")
                XCTAssertEqual(field?.number, Int32(fieldNumber))
                XCTAssertEqual(field?.type.description, fieldType)
            }
            
            // Verify Status enum with 5 values
            XCTAssertEqual(ast.enums.count, 1)
            let status = ast.enums[0]
            XCTAssertEqual(status.name, "Status")
            XCTAssertEqual(status.values.count, 5)
            
            // Check Status enum values
            let statusValues = [
                ("STATUS_UNKNOWN", 0),
                ("READY", 1),
                ("PROCESSING", 2),
                ("COMPLETED", 3),
                ("FAILED", 4)
            ]
            
            for (valueName, valueNumber) in statusValues {
                let value = status.values.first { $0.name == valueName }
                XCTAssertNotNil(value, "Must have status value: \(valueName)")
                XCTAssertEqual(value?.number, Int32(valueNumber))
            }
            
            // Verify UserProfile with repeated field
            let userProfile = ast.messages.first { $0.name == "UserProfile" }
            XCTAssertNotNil(userProfile)
            XCTAssertEqual(userProfile?.fields.count, 3)
            
            let permissionsField = userProfile?.fields.first { $0.name == "permissions" }
            XCTAssertNotNil(permissionsField)
            XCTAssertEqual(permissionsField?.label, .repeated)
            XCTAssertEqual(permissionsField?.type.description, "string")
            
            // Verify AdminProfile fields
            let adminProfile = ast.messages.first { $0.name == "AdminProfile" }
            XCTAssertNotNil(adminProfile)
            XCTAssertEqual(adminProfile?.fields.count, 3)
            
            // Verify GuestProfile fields with int64
            let guestProfile = ast.messages.first { $0.name == "GuestProfile" }
            XCTAssertNotNil(guestProfile)
            XCTAssertEqual(guestProfile?.fields.count, 2)
            
            let expiresAtField = guestProfile?.fields.first { $0.name == "expires_at" }
            XCTAssertNotNil(expiresAtField)
            XCTAssertEqual(expiresAtField?.type.description, "int64")
            
        case .failure(let error):
            XCTFail("Failed to parse real medium/oneof_groups.proto: \(error)")
        }
    }
    
    func testRealFieldOptionsFileParsing() throws {
        // ENHANCED: Test real field_options.proto file with comprehensive field types and patterns
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/medium/field_options.proto"
        
        let result = SwiftProtoParser.parseProtoFile(filePath)
        
        switch result {
        case .success(let ast):
            // Verify package name
            XCTAssertEqual(ast.package, "medium.options")
            
            // Verify syntax
            XCTAssertEqual(ast.syntax, .proto3)
            
            // Verify import
            XCTAssertEqual(ast.imports.count, 1)
            XCTAssertTrue(ast.imports.contains("google/protobuf/descriptor.proto"))
            
            // Verify FieldOptionsMessage with comprehensive field types (8 regular fields + 1 oneof)
            let fieldOptionsMessage = ast.messages.first { $0.name == "FieldOptionsMessage" }
            XCTAssertNotNil(fieldOptionsMessage)
            XCTAssertEqual(fieldOptionsMessage?.fields.count, 8) // Regular fields (oneof fields are separate)
            
            // Test regular FieldOptionsMessage fields (not including oneof)
            let regularFieldTests = [
                ("email", 1, "string"),
                ("username", 2, "string"), 
                ("password", 3, "string"),
                ("age", 4, "int32"),
                ("bio", 5, "string"),
                ("tags", 6, "string"),  // repeated
                ("metadata", 7, "map<string, string>"), // map field
                ("status", 10, "Status") // enum
            ]
            
            for (fieldName, fieldNumber, fieldType) in regularFieldTests {
                let field = fieldOptionsMessage?.fields.first { $0.name == fieldName }
                XCTAssertNotNil(field, "Must have FieldOptionsMessage field: \(fieldName)")
                XCTAssertEqual(field?.number, Int32(fieldNumber))
                XCTAssertEqual(field?.type.description, fieldType)
            }
            
            // Verify repeated field
            let tagsField = fieldOptionsMessage?.fields.first { $0.name == "tags" }
            XCTAssertEqual(tagsField?.label, .repeated)
            
            // Verify map field
            let metadataField = fieldOptionsMessage?.fields.first { $0.name == "metadata" }
            XCTAssertNotNil(metadataField)
            XCTAssertEqual(metadataField?.number, 7)
            XCTAssertTrue(metadataField?.isMap ?? false)
            
            // Verify oneof group with 2 fields
            XCTAssertEqual(fieldOptionsMessage?.oneofGroups.count, 1)
            let contactMethod = fieldOptionsMessage?.oneofGroups.first
            XCTAssertEqual(contactMethod?.name, "contact_method")
            XCTAssertEqual(contactMethod?.fields.count, 2)
            
            // Test oneof fields separately
            let oneofFieldTests = [
                ("phone", 8, "string"),
                ("social_handle", 9, "string")
            ]
            
            for (fieldName, fieldNumber, fieldType) in oneofFieldTests {
                let field = contactMethod?.fields.first { $0.name == fieldName }
                XCTAssertNotNil(field, "Must have oneof field: \(fieldName)")
                XCTAssertEqual(field?.number, Int32(fieldNumber))
                XCTAssertEqual(field?.type.description, fieldType)
            }
            
            // Verify Status enum with 5 values
            XCTAssertEqual(ast.enums.count, 1)
            let status = ast.enums[0]
            XCTAssertEqual(status.name, "Status")
            XCTAssertEqual(status.values.count, 5)
            
            let statusValues = [
                ("STATUS_UNKNOWN", 0),
                ("ACTIVE", 1),
                ("INACTIVE", 2),
                ("SUSPENDED", 3),
                ("DELETED", 4)
            ]
            
            for (valueName, valueNumber) in statusValues {
                let value = status.values.first { $0.name == valueName }
                XCTAssertNotNil(value, "Must have status value: \(valueName)")
                XCTAssertEqual(value?.number, Int32(valueNumber))
            }
            
            // Verify OptionsService with 5 CRUD methods
            XCTAssertEqual(ast.services.count, 1)
            let optionsService = ast.services[0]
            XCTAssertEqual(optionsService.name, "OptionsService")
            XCTAssertEqual(optionsService.methods.count, 5)
            
            // Test all CRUD service methods
            let serviceMethodTests = [
                ("GetUser", "GetUserRequest", "GetUserResponse"),
                ("CreateUser", "CreateUserRequest", "CreateUserResponse"),
                ("UpdateUser", "UpdateUserRequest", "UpdateUserResponse"),
                ("DeleteUser", "DeleteUserRequest", "DeleteUserResponse"),
                ("ListUsers", "ListUsersRequest", "ListUsersResponse")
            ]
            
            for (methodName, inputType, outputType) in serviceMethodTests {
                let method = optionsService.methods.first { $0.name == methodName }
                XCTAssertNotNil(method, "Must have service method: \(methodName)")
                XCTAssertEqual(method?.inputType, inputType)
                XCTAssertEqual(method?.outputType, outputType)
            }
            
            // Verify all 11 messages exist (comprehensive)
            XCTAssertEqual(ast.messages.count, 11)
            let messageNames = Set(ast.messages.map { $0.name })
            let expectedMessages = [
                "FieldOptionsMessage",
                "GetUserRequest", "GetUserResponse",
                "CreateUserRequest", "CreateUserResponse", 
                "UpdateUserRequest", "UpdateUserResponse",
                "DeleteUserRequest", "DeleteUserResponse",
                "ListUsersRequest", "ListUsersResponse"
            ]
            
            for messageName in expectedMessages {
                XCTAssertTrue(messageNames.contains(messageName), "Must have message: \(messageName)")
            }
            
            // Verify ListUsersResponse with repeated field
            let listUsersResponse = ast.messages.first { $0.name == "ListUsersResponse" }
            XCTAssertNotNil(listUsersResponse)
            XCTAssertEqual(listUsersResponse?.fields.count, 3)
            
            let usersField = listUsersResponse?.fields.first { $0.name == "users" }
            XCTAssertNotNil(usersField)
            XCTAssertEqual(usersField?.label, .repeated)
            XCTAssertEqual(usersField?.type.description, "FieldOptionsMessage")
            
        case .failure(let error):
            XCTFail("Failed to parse real medium/field_options.proto: \(error)")
        }
    }
    
    // MARK: - Performance Testing 🚀
    
    func testMediumProtoParsingPerformance() throws {
        // Performance test: medium complexity should still be fast
        let protoContent = """
        syntax = "proto3";
        package test.performance;
        
        message PerformanceMessage {
          repeated string items = 1;
          map<string, int32> counters = 2;
          oneof choice {
            string text = 3;
            int32 number = 4;
          }
        }
        """
        
        measure {
            for _ in 0..<50 {
                let result = SwiftProtoParser.parseProtoString(protoContent)
                switch result {
                case .success(_):
                    break // Success
                case .failure(_):
                    XCTFail("Performance test failed")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getTestResourcesPath() -> String {
        // Use #file to determine the test directory location (like SimpleProtoProductTestsFixed)
        let thisFileURL = URL(fileURLWithPath: #file)
        let projectDirectory = thisFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let resourcesPath = projectDirectory.appendingPathComponent("Tests/TestResources").path
        return resourcesPath
    }
}
