import XCTest
@testable import SwiftProtoParser

final class SimpleProtoProductTestsFixed: XCTestCase {
    
    // MARK: - Simple Proto3 Product Testing 🟢
    
    func testBasicMessageProductScenario() throws {
        // Test simple message with basic field types
        let protoContent = """
        syntax = "proto3";
        
        package simple.basic;
        
        message BasicMessage {
          string name = 1;
          int32 age = 2;
          bool active = 3;
          double score = 4;
          bytes data = 5;
        }
        """
        
        let result = SwiftProtoParser.parseProtoString(protoContent)
        
        switch result {
        case .success(let ast):
            // Verify package
            XCTAssertEqual(ast.package, "simple.basic")
            XCTAssertEqual(ast.syntax, .proto3)
            
            // Verify message
            XCTAssertEqual(ast.messages.count, 1)
            let message = ast.messages[0]
            XCTAssertEqual(message.name, "BasicMessage")
            XCTAssertEqual(message.fields.count, 5)
            
            // Verify field types
            let fields = message.fields.sorted { $0.number < $1.number }
            XCTAssertEqual(fields[0].name, "name")
            XCTAssertEqual(fields[0].type.description, "string")
            XCTAssertEqual(fields[1].name, "age")
            XCTAssertEqual(fields[1].type.description, "int32")
            XCTAssertEqual(fields[2].name, "active")
            XCTAssertEqual(fields[2].type.description, "bool")
            XCTAssertEqual(fields[3].name, "score")
            XCTAssertEqual(fields[3].type.description, "double")
            XCTAssertEqual(fields[4].name, "data")
            XCTAssertEqual(fields[4].type.description, "bytes")
            
        case .failure(let error):
            XCTFail("Failed to parse basic message: \(error)")
        }
    }
    
    func testBasicEnumProductScenario() throws {
        // Test simple enum with proto3 requirements
        let protoContent = """
        syntax = "proto3";
        
        package simple.enum;
        
        enum Status {
          STATUS_UNKNOWN = 0;  // Required in proto3
          STATUS_ACTIVE = 1;
          STATUS_INACTIVE = 2;
          STATUS_PENDING = 3;
        }
        
        message StatusMessage {
          Status status = 1;
          string description = 2;
        }
        """
        
        let result = SwiftProtoParser.parseProtoString(protoContent)
        
        switch result {
        case .success(let ast):
            // Verify enum
            XCTAssertEqual(ast.enums.count, 1)
            let statusEnum = ast.enums[0]
            XCTAssertEqual(statusEnum.name, "Status")
            XCTAssertEqual(statusEnum.values.count, 4)
            
            // Verify default value (required in proto3)
            let defaultValue = statusEnum.values.first { $0.number == 0 }
            XCTAssertNotNil(defaultValue)
            XCTAssertEqual(defaultValue?.name, "STATUS_UNKNOWN")
            
            // Verify message using enum
            XCTAssertEqual(ast.messages.count, 1)
            let message = ast.messages[0]
            let statusField = message.fields.first { $0.name == "status" }
            XCTAssertNotNil(statusField)
            XCTAssertEqual(statusField?.type.description, "Status")
            
        case .failure(let error):
            XCTFail("Failed to parse enum: \(error)")
        }
    }
    
    func testBasicServiceProductScenario() throws {
        // Test simple gRPC service
        let protoContent = """
        syntax = "proto3";
        
        package simple.service;
        
        service UserService {
          rpc GetUser(GetUserRequest) returns (GetUserResponse);
          rpc CreateUser(CreateUserRequest) returns (CreateUserResponse);
        }
        
        message GetUserRequest {
          string user_id = 1;
        }
        
        message GetUserResponse {
          string user_id = 1;
          string name = 2;
          string email = 3;
        }
        
        message CreateUserRequest {
          string name = 1;
          string email = 2;
        }
        
        message CreateUserResponse {
          string user_id = 1;
          bool success = 2;
        }
        """
        
        let result = SwiftProtoParser.parseProtoString(protoContent)
        
        switch result {
        case .success(let ast):
            // Verify service
            XCTAssertEqual(ast.services.count, 1)
            let service = ast.services[0]
            XCTAssertEqual(service.name, "UserService")
            XCTAssertEqual(service.methods.count, 2)
            
            // Verify RPC methods
            let getUser = service.methods.first { $0.name == "GetUser" }
            XCTAssertNotNil(getUser)
            XCTAssertEqual(getUser?.inputType, "GetUserRequest")
            XCTAssertEqual(getUser?.outputType, "GetUserResponse")
            
            // Verify messages exist
            XCTAssertEqual(ast.messages.count, 4)
            let messageNames = Set(ast.messages.map { $0.name })
            XCTAssertTrue(messageNames.contains("GetUserRequest"))
            XCTAssertTrue(messageNames.contains("GetUserResponse"))
            XCTAssertTrue(messageNames.contains("CreateUserRequest"))
            XCTAssertTrue(messageNames.contains("CreateUserResponse"))
            
        case .failure(let error):
            XCTFail("Failed to parse service: \(error)")
        }
    }
    
    func testRepeatedFieldsProductScenario() throws {
        // Test repeated fields (arrays)
        let protoContent = """
        syntax = "proto3";
        
        package simple.repeated;
        
        message RepeatedMessage {
          repeated string tags = 1;
          repeated int32 numbers = 2;
          repeated NestedItem items = 3;
        }
        
        message NestedItem {
          string name = 1;
          int32 value = 2;
        }
        """
        
        let result = SwiftProtoParser.parseProtoString(protoContent)
        
        switch result {
        case .success(let ast):
            let message = ast.messages.first { $0.name == "RepeatedMessage" }
            XCTAssertNotNil(message)
            XCTAssertEqual(message?.fields.count, 3)
            
            // Check repeated fields
            let tagsField = message?.fields.first { $0.name == "tags" }
            XCTAssertNotNil(tagsField)
            XCTAssertEqual(tagsField?.label, .repeated)
            XCTAssertEqual(tagsField?.type.description, "string")
            
            let numbersField = message?.fields.first { $0.name == "numbers" }
            XCTAssertNotNil(numbersField)
            XCTAssertEqual(numbersField?.label, .repeated)
            XCTAssertEqual(numbersField?.type.description, "int32")
            
            let itemsField = message?.fields.first { $0.name == "items" }
            XCTAssertNotNil(itemsField)
            XCTAssertEqual(itemsField?.label, .repeated)
            XCTAssertEqual(itemsField?.type.description, "NestedItem")
            
        case .failure(let error):
            XCTFail("Failed to parse repeated fields: \(error)")
        }
    }
    
    func testMapTypesProductScenario() throws {
        // Test map types (key-value pairs)
        let protoContent = """
        syntax = "proto3";
        
        package simple.maps;
        
        message MapMessage {
          map<string, string> string_map = 1;
          map<string, int32> int_map = 2;
          map<int32, string> id_to_name = 3;
        }
        """
        
        let result = SwiftProtoParser.parseProtoString(protoContent)
        
        switch result {
        case .success(let ast):
            let message = ast.messages.first { $0.name == "MapMessage" }
            XCTAssertNotNil(message)
            XCTAssertEqual(message?.fields.count, 3)
            
            // Check map fields using FieldNode.isMap
            let stringMapField = message?.fields.first { $0.name == "string_map" }
            XCTAssertNotNil(stringMapField)
            XCTAssertTrue(stringMapField?.isMap ?? false)
            
            let intMapField = message?.fields.first { $0.name == "int_map" }
            XCTAssertNotNil(intMapField)
            XCTAssertTrue(intMapField?.isMap ?? false)
            
            let idToNameField = message?.fields.first { $0.name == "id_to_name" }
            XCTAssertNotNil(idToNameField)
            XCTAssertTrue(idToNameField?.isMap ?? false)
            
        case .failure(let error):
            XCTFail("Failed to parse map types: \(error)")
        }
    }
    
    func testOneofGroupsProductScenario() throws {
        // Test oneof groups (union types)
        let protoContent = """
        syntax = "proto3";
        
        package simple.oneof;
        
        message OneofMessage {
          oneof test_oneof {
            string name = 1;
            int32 number = 2;
            bool flag = 3;
          }
          string common_field = 4;
        }
        """
        
        let result = SwiftProtoParser.parseProtoString(protoContent)
        
        switch result {
        case .success(let ast):
            let message = ast.messages.first { $0.name == "OneofMessage" }
            XCTAssertNotNil(message)
            
            // Check oneof groups using correct API
            XCTAssertEqual(message?.oneofGroups.count, 1)
            let oneof = message?.oneofGroups.first
            XCTAssertEqual(oneof?.name, "test_oneof")
            XCTAssertEqual(oneof?.fields.count, 3)
            
            // Check non-oneof field
            let commonField = message?.fields.first { $0.name == "common_field" }
            XCTAssertNotNil(commonField)
            XCTAssertEqual(commonField?.number, 4)
            
        case .failure(let error):
            XCTFail("Failed to parse oneof: \(error)")
        }
    }
    
    // MARK: - Real-World Scenario Testing 🌍
    
    func testRealWorldAPIProductScenario() throws {
        // Test realistic API scenario
        let protoContent = """
        syntax = "proto3";
        
        package api.v1;
        
        service UserAPI {
          rpc ListUsers(ListUsersRequest) returns (ListUsersResponse);
          rpc GetUser(GetUserRequest) returns (User);
          rpc CreateUser(CreateUserRequest) returns (User);
        }
        
        message User {
          string id = 1;
          string email = 2;
          string name = 3;
          UserStatus status = 4;
          repeated string roles = 5;
        }
        
        enum UserStatus {
          USER_STATUS_UNKNOWN = 0;
          ACTIVE = 1;
          INACTIVE = 2;
          SUSPENDED = 3;
        }
        
        message ListUsersRequest {
          int32 page_size = 1;
          string page_token = 2;
        }
        
        message ListUsersResponse {
          repeated User users = 1;
          string next_page_token = 2;
          int32 total_count = 3;
        }
        
        message GetUserRequest {
          string id = 1;
        }
        
        message CreateUserRequest {
          string email = 1;
          string name = 2;
          repeated string roles = 3;
        }
        """
        
        let result = SwiftProtoParser.parseProtoString(protoContent)
        
        switch result {
        case .success(let ast):
            // Verify package
            XCTAssertEqual(ast.package, "api.v1")
            
            // Verify service
            XCTAssertEqual(ast.services.count, 1)
            let service = ast.services[0]
            XCTAssertEqual(service.name, "UserAPI")
            XCTAssertEqual(service.methods.count, 3)
            
            // Verify main entity
            let user = ast.messages.first { $0.name == "User" }
            XCTAssertNotNil(user)
            XCTAssertEqual(user?.fields.count, 5)
            
            // Verify enum
            XCTAssertEqual(ast.enums.count, 1)
            let userStatus = ast.enums[0]
            XCTAssertEqual(userStatus.name, "UserStatus")
            
            // Verify CRUD operations
            let methodNames = Set(service.methods.map { $0.name })
            XCTAssertTrue(methodNames.contains("ListUsers"))
            XCTAssertTrue(methodNames.contains("GetUser"))
            XCTAssertTrue(methodNames.contains("CreateUser"))
            
            // Verify all messages exist
            XCTAssertGreaterThanOrEqual(ast.messages.count, 5)
            
        case .failure(let error):
            XCTFail("Failed to parse real-world API: \(error)")
        }
    }
    
    // MARK: - Performance Testing 🚀
    
    func testSimpleProtoParsingPerformance() throws {
        // Performance test for simple proto parsing
        let protoContent = """
        syntax = "proto3";
        package test.performance;
        message SimpleMessage {
          string name = 1;
          int32 value = 2;
          bool flag = 3;
        }
        """
        
        measure {
            for _ in 0..<100 {
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
    
    // MARK: - Error Handling Testing 🔴
    
    func testErrorHandlingProductScenario() throws {
        // Test malformed proto for error handling
        let malformedProto = """
        syntax = "proto3";
        
        package malformed;
        
        message BadMessage {
          string field = 0;  // Invalid field number
        }
        """
        
        let result = SwiftProtoParser.parseProtoString(malformedProto)
        
        switch result {
        case .success(_):
            XCTFail("Should have failed to parse malformed proto")
        case .failure(let error):
            // Verify error contains useful information
            let errorDescription = error.localizedDescription
            XCTAssertFalse(errorDescription.isEmpty)
            print("Successfully caught error: \(errorDescription)")
        }
    }
    
    // MARK: - Real File Testing 📁
    
    func testRealMapTypesFileParsing() throws {
        // FIXED: Test real map_types.proto file which was previously uncovered (70% missing functionality)
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/medium/map_types.proto"
        
        let result = SwiftProtoParser.parseProtoFile(filePath)
        
        switch result {
        case .success(let ast):
            // Verify package name
            XCTAssertEqual(ast.package, "medium.maps")
            
            // Verify syntax
            XCTAssertEqual(ast.syntax, .proto3)
            
            // Verify MapMessage with ALL 10 map fields (was only 3/10 before)
            XCTAssertEqual(ast.messages.count, 3) // MapMessage, UserInfo, NestedMaps
            let mapMessage = ast.messages.first { $0.name == "MapMessage" }
            XCTAssertNotNil(mapMessage)
            XCTAssertEqual(mapMessage?.fields.count, 10)
            
            // Verify all 10 map fields from real file (comprehensive coverage)
            let mapFieldTests = [
                ("string_map", 1, "string", "string"),
                ("int_map", 2, "string", "int32"),
                ("bool_map", 3, "string", "bool"),
                ("double_map", 4, "string", "double"),
                ("bytes_map", 5, "string", "bytes"),
                ("status_map", 6, "string", "Status"),
                ("user_map", 7, "string", "UserInfo"),
                ("id_to_name", 8, "int32", "string"),
                ("id_to_user", 9, "int64", "UserInfo"),
                ("flag_to_description", 10, "bool", "string")
            ]
            
            for (fieldName, fieldNumber, keyType, valueType) in mapFieldTests {
                let field = mapMessage?.fields.first { $0.name == fieldName }
                XCTAssertNotNil(field, "Must have field: \(fieldName)")
                XCTAssertEqual(field?.number, Int32(fieldNumber), "\(fieldName) should have number \(fieldNumber)")
                
                // Verify map structure
                if case .map(let actualKeyType, let actualValueType) = field?.type {
                    XCTAssertEqual(actualKeyType.protoTypeName, keyType, "\(fieldName) key should be \(keyType)")
                    XCTAssertEqual(actualValueType.protoTypeName, valueType, "\(fieldName) value should be \(valueType)")
                } else {
                    XCTFail("\(fieldName) should be a map type")
                }
            }
            
            // Verify Status enum with 4 values
            XCTAssertEqual(ast.enums.count, 1)
            let statusEnum = ast.enums[0]
            XCTAssertEqual(statusEnum.name, "Status")
            XCTAssertEqual(statusEnum.values.count, 4)
            
            // Check Status enum values (all with STATUS_ prefixes as per real file)
            let statusValues = [
                ("STATUS_UNKNOWN", 0),
                ("STATUS_ACTIVE", 1),
                ("STATUS_INACTIVE", 2),
                ("STATUS_PENDING", 3)
            ]
            
            for (valueName, valueNumber) in statusValues {
                let value = statusEnum.values.first { $0.name == valueName }
                XCTAssertNotNil(value, "Must have enum value: \(valueName)")
                XCTAssertEqual(value?.number, Int32(valueNumber), "\(valueName) should have number \(valueNumber)")
            }
            
            // Verify UserInfo message with 3 fields
            let userInfo = ast.messages.first { $0.name == "UserInfo" }
            XCTAssertNotNil(userInfo, "Must have UserInfo message")
            XCTAssertEqual(userInfo?.fields.count, 3)
            
            let userInfoFields = [
                ("name", 1, "string"),
                ("email", 2, "string"),
                ("age", 3, "int32")
            ]
            
            for (fieldName, fieldNumber, fieldType) in userInfoFields {
                let field = userInfo?.fields.first { $0.name == fieldName }
                XCTAssertNotNil(field, "Must have UserInfo field: \(fieldName)")
                XCTAssertEqual(field?.number, Int32(fieldNumber))
                XCTAssertEqual(field?.type.description, fieldType)
            }
            
            // FIXED: Verify NestedMaps message (was previously completely uncovered!)
            let nestedMaps = ast.messages.first { $0.name == "NestedMaps" }
            XCTAssertNotNil(nestedMaps, "Must have NestedMaps message")
            XCTAssertEqual(nestedMaps?.fields.count, 2)
            
            // Check nested_maps field
            let nestedMapsField = nestedMaps?.fields.first { $0.name == "nested_maps" }
            XCTAssertNotNil(nestedMapsField)
            XCTAssertEqual(nestedMapsField?.number, 1)
            if case .map(let keyType, let valueType) = nestedMapsField?.type {
                XCTAssertEqual(keyType.protoTypeName, "string")
                XCTAssertEqual(valueType.protoTypeName, "MapMessage")
            } else {
                XCTFail("nested_maps should be map<string, MapMessage>")
            }
            
            // Check double_nested field (tests error handling for complex nested maps)
            let doubleNestedField = nestedMaps?.fields.first { $0.name == "double_nested" }
            XCTAssertNotNil(doubleNestedField)
            XCTAssertEqual(doubleNestedField?.number, 2)
            // Note: double_nested contains map<string, map<string, string>> which may need special handling
            
        case .failure(let error):
            XCTFail("Failed to parse real medium/map_types.proto: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getTestResourcesPath() -> String {
        // Use #file to determine the test directory location (like ComplexProtoTests)
        let thisFileURL = URL(fileURLWithPath: #file)
        let projectDirectory = thisFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let resourcesPath = projectDirectory.appendingPathComponent("Tests/TestResources").path
        return resourcesPath
    }
}
