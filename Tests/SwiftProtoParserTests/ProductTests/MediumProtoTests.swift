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
        // Test 4-level deep nested messages
        let protoContent = """
        syntax = "proto3";

        package medium.nested;

        message Company {
          string name = 1;
          
          message Department {
            string name = 1;
            
            message Employee {
              string name = 1;
              string email = 2;
              Position position = 3;
              
              message Address {
                string street = 1;
                string city = 2;
                string country = 3;
                int32 postal_code = 4;
              }
              
              Address home_address = 4;
              Address work_address = 5;
            }
            
            repeated Employee employees = 2;
            Employee manager = 3;
          }
          
          repeated Department departments = 2;
        }

        enum Position {
          POSITION_UNKNOWN = 0;
          JUNIOR = 1;
          SENIOR = 2;
          LEAD = 3;
          MANAGER = 4;
          DIRECTOR = 5;
        }
        """
        
        let result = SwiftProtoParser.parseProtoString(protoContent)
        
        switch result {
        case .success(let ast):
            // Verify package
            XCTAssertEqual(ast.package, "medium.nested")
            XCTAssertEqual(ast.syntax, .proto3)
            
            // Verify main message
            XCTAssertEqual(ast.messages.count, 1)
            let company = ast.messages[0]
            XCTAssertEqual(company.name, "Company")
            XCTAssertEqual(company.fields.count, 2)
            
            // Verify nested structure (4 levels deep)
            XCTAssertEqual(company.nestedMessages.count, 1)
            let department = company.nestedMessages[0]
            XCTAssertEqual(department.name, "Department")
            
            XCTAssertEqual(department.nestedMessages.count, 1)
            let employee = department.nestedMessages[0]
            XCTAssertEqual(employee.name, "Employee")
            
            XCTAssertEqual(employee.nestedMessages.count, 1)
            let address = employee.nestedMessages[0]
            XCTAssertEqual(address.name, "Address")
            XCTAssertEqual(address.fields.count, 4)
            
            // Verify fields using nested types
            let departmentsField = company.fields.first { $0.name == "departments" }
            XCTAssertNotNil(departmentsField)
            XCTAssertEqual(departmentsField?.label, .repeated)
            XCTAssertEqual(departmentsField?.type.description, "Department")
            
            // Verify enum exists
            XCTAssertEqual(ast.enums.count, 1)
            let position = ast.enums[0]
            XCTAssertEqual(position.name, "Position")
            XCTAssertEqual(position.values.count, 6)
            
            // Verify default value (proto3 requirement)
            let defaultValue = position.values.first { $0.number == 0 }
            XCTAssertNotNil(defaultValue)
            XCTAssertEqual(defaultValue?.name, "POSITION_UNKNOWN")
            
        case .failure(let error):
            XCTFail("Failed to parse nested messages: \(error)")
        }
    }
    
    func testRepeatedFieldsParsing() throws {
        // Test various repeated field types
        let protoContent = """
        syntax = "proto3";

        package medium.repeated;

        message RepeatedMessage {
          repeated string tags = 1;
          repeated int32 numbers = 2;
          repeated bool flags = 3;
          repeated double scores = 4;
          repeated bytes data_chunks = 5;
          
          repeated NestedItem items = 6;
          repeated Category categories = 7;
        }

        message NestedItem {
          string id = 1;
          string name = 2;
          int32 quantity = 3;
        }

        enum Category {
          CATEGORY_UNKNOWN = 0;
          ELECTRONICS = 1;
          CLOTHING = 2;
          BOOKS = 3;
          FOOD = 4;
        }

        message ArrayOfArrays {
          repeated StringList string_lists = 1;
          repeated NumberList number_lists = 2;
        }

        message StringList {
          repeated string values = 1;
        }

        message NumberList {
          repeated int32 values = 1;
        }
        """
        
        let result = SwiftProtoParser.parseProtoString(protoContent)
        
        switch result {
        case .success(let ast):
            // Verify package
            XCTAssertEqual(ast.package, "medium.repeated")
            
            // Verify main message with repeated fields
            let repeatedMessage = ast.messages.first { $0.name == "RepeatedMessage" }
            XCTAssertNotNil(repeatedMessage)
            XCTAssertEqual(repeatedMessage?.fields.count, 7)
            
            // Check all repeated fields
            let repeatedFields = repeatedMessage?.fields.filter { $0.label == .repeated }
            XCTAssertEqual(repeatedFields?.count, 7)
            
            // Verify specific repeated field types
            let tagsField = repeatedMessage?.fields.first { $0.name == "tags" }
            XCTAssertNotNil(tagsField)
            XCTAssertEqual(tagsField?.label, .repeated)
            XCTAssertEqual(tagsField?.type.description, "string")
            
            let numbersField = repeatedMessage?.fields.first { $0.name == "numbers" }
            XCTAssertNotNil(numbersField)
            XCTAssertEqual(numbersField?.label, .repeated)
            XCTAssertEqual(numbersField?.type.description, "int32")
            
            let itemsField = repeatedMessage?.fields.first { $0.name == "items" }
            XCTAssertNotNil(itemsField)
            XCTAssertEqual(itemsField?.label, .repeated)
            XCTAssertEqual(itemsField?.type.description, "NestedItem")
            
            // Verify nested message and enum
            let nestedItem = ast.messages.first { $0.name == "NestedItem" }
            XCTAssertNotNil(nestedItem)
            XCTAssertEqual(nestedItem?.fields.count, 3)
            
            XCTAssertEqual(ast.enums.count, 1)
            let category = ast.enums[0]
            XCTAssertEqual(category.name, "Category")
            
            // Verify arrays of arrays
            let arrayOfArrays = ast.messages.first { $0.name == "ArrayOfArrays" }
            XCTAssertNotNil(arrayOfArrays)
            XCTAssertEqual(arrayOfArrays?.fields.count, 2)
            
        case .failure(let error):
            XCTFail("Failed to parse repeated fields: \(error)")
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
    
    func testOneofGroupsParsing() throws {
        // Test oneof groups (union types)
        let protoContent = """
        syntax = "proto3";

        package medium.oneof;

        message OneofMessage {
          oneof test_oneof {
            string name = 1;
            int32 number = 2;
            bool flag = 3;
            bytes data = 4;
            NestedMessage nested = 5;
          }
          
          string common_field = 6;
        }

        message NestedMessage {
          string content = 1;
          int32 value = 2;
        }

        message MultipleOneofs {
          oneof first_choice {
            string option_a = 1;
            int32 option_b = 2;
          }
          
          oneof second_choice {
            bool flag_x = 3;
            double value_y = 4;
            Status status_z = 5;
          }
          
          string always_present = 6;
        }

        enum Status {
          STATUS_UNKNOWN = 0;
          READY = 1;
          PROCESSING = 2;
          COMPLETED = 3;
          FAILED = 4;
        }

        message ComplexOneof {
          oneof complex_choice {
            UserProfile user = 1;
            AdminProfile admin = 2;
            GuestProfile guest = 3;
          }
        }

        message UserProfile {
          string user_id = 1;
          string username = 2;
          repeated string permissions = 3;
        }

        message AdminProfile {
          string admin_id = 1;
          string department = 2;
          int32 access_level = 3;
        }

        message GuestProfile {
          string session_id = 1;
          int64 expires_at = 2;
        }
        """
        
        let result = SwiftProtoParser.parseProtoString(protoContent)
        
        switch result {
        case .success(let ast):
            // Verify package
            XCTAssertEqual(ast.package, "medium.oneof")
            
            // Verify message with oneof
            let oneofMessage = ast.messages.first { $0.name == "OneofMessage" }
            XCTAssertNotNil(oneofMessage)
            
            // Check oneof groups using correct API
            XCTAssertEqual(oneofMessage?.oneofGroups.count, 1)
            let testOneof = oneofMessage?.oneofGroups.first
            XCTAssertEqual(testOneof?.name, "test_oneof")
            XCTAssertEqual(testOneof?.fields.count, 5)
            
            // Verify oneof field types
            let nameField = testOneof?.fields.first { $0.name == "name" }
            XCTAssertNotNil(nameField)
            XCTAssertEqual(nameField?.type.description, "string")
            
            let nestedField = testOneof?.fields.first { $0.name == "nested" }
            XCTAssertNotNil(nestedField)
            XCTAssertEqual(nestedField?.type.description, "NestedMessage")
            
            // Check non-oneof field
            let commonField = oneofMessage?.fields.first { $0.name == "common_field" }
            XCTAssertNotNil(commonField)
            XCTAssertEqual(commonField?.number, 6)
            
            // Verify message with multiple oneofs
            let multipleOneofs = ast.messages.first { $0.name == "MultipleOneofs" }
            XCTAssertNotNil(multipleOneofs)
            XCTAssertEqual(multipleOneofs?.oneofGroups.count, 2)
            
            // Verify complex oneof
            let complexOneof = ast.messages.first { $0.name == "ComplexOneof" }
            XCTAssertNotNil(complexOneof)
            XCTAssertEqual(complexOneof?.oneofGroups.count, 1)
            
            // Verify all profile messages exist
            let userProfile = ast.messages.first { $0.name == "UserProfile" }
            XCTAssertNotNil(userProfile)
            let adminProfile = ast.messages.first { $0.name == "AdminProfile" }
            XCTAssertNotNil(adminProfile)
            let guestProfile = ast.messages.first { $0.name == "GuestProfile" }
            XCTAssertNotNil(guestProfile)
            
        case .failure(let error):
            XCTFail("Failed to parse oneof groups: \(error)")
        }
    }
    
    func testFieldOptionsParsing() throws {
        // Test proto with imports and complex service structure
        let protoContent = """
        syntax = "proto3";

        package medium.options;

        import "google/protobuf/descriptor.proto";

        message FieldOptionsMessage {
          string email = 1;
          string username = 2;
          string password = 3;
          int32 age = 4;
          string bio = 5;
        }

        service OptionsService {
          rpc GetUser(GetUserRequest) returns (GetUserResponse);
          rpc CreateUser(CreateUserRequest) returns (CreateUserResponse);
        }

        message GetUserRequest {
          string user_id = 1;
        }

        message GetUserResponse {
          FieldOptionsMessage user = 1;
          bool found = 2;
        }

        message CreateUserRequest {
          FieldOptionsMessage user = 1;
        }

        message CreateUserResponse {
          string user_id = 1;
          bool success = 2;
        }
        """
        
        let result = SwiftProtoParser.parseProtoString(protoContent)
        
        switch result {
        case .success(let ast):
            // Verify package
            XCTAssertEqual(ast.package, "medium.options")
            
            // Verify import
            XCTAssertTrue(ast.imports.contains("google/protobuf/descriptor.proto"))
            
            // Verify message with options
            let fieldOptionsMessage = ast.messages.first { $0.name == "FieldOptionsMessage" }
            XCTAssertNotNil(fieldOptionsMessage)
            XCTAssertEqual(fieldOptionsMessage?.fields.count, 5)
            
            // Verify field names and types
            let emailField = fieldOptionsMessage?.fields.first { $0.name == "email" }
            XCTAssertNotNil(emailField)
            XCTAssertEqual(emailField?.type.description, "string")
            
            let usernameField = fieldOptionsMessage?.fields.first { $0.name == "username" }
            XCTAssertNotNil(usernameField)
            XCTAssertEqual(usernameField?.type.description, "string")
            
            // Verify service with options
            XCTAssertEqual(ast.services.count, 1)
            let optionsService = ast.services[0]
            XCTAssertEqual(optionsService.name, "OptionsService")
            XCTAssertEqual(optionsService.methods.count, 2)
            
            // Check method names
            let getUserMethod = optionsService.methods.first { $0.name == "GetUser" }
            XCTAssertNotNil(getUserMethod)
            XCTAssertEqual(getUserMethod?.inputType, "GetUserRequest")
            XCTAssertEqual(getUserMethod?.outputType, "GetUserResponse")
            
            let createUserMethod = optionsService.methods.first { $0.name == "CreateUser" }
            XCTAssertNotNil(createUserMethod)
            XCTAssertEqual(createUserMethod?.inputType, "CreateUserRequest")
            XCTAssertEqual(createUserMethod?.outputType, "CreateUserResponse")
            
            // Verify all request/response messages exist
            XCTAssertGreaterThanOrEqual(ast.messages.count, 5)
            let messageNames = Set(ast.messages.map { $0.name })
            XCTAssertTrue(messageNames.contains("GetUserRequest"))
            XCTAssertTrue(messageNames.contains("GetUserResponse"))
            XCTAssertTrue(messageNames.contains("CreateUserRequest"))
            XCTAssertTrue(messageNames.contains("CreateUserResponse"))
            
        case .failure(let error):
            XCTFail("Failed to parse field options: \(error)")
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
        let testBundle = Bundle(for: type(of: self))
        let testResourcesPath = testBundle.resourcePath?.appending("/TestResources") ?? 
                               URL(fileURLWithPath: #file)
                                   .deletingLastPathComponent()
                                   .deletingLastPathComponent()
                                   .deletingLastPathComponent()
                                   .appendingPathComponent("TestResources")
                                   .path
        return testResourcesPath
    }
}
