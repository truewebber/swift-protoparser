import XCTest
@testable import SwiftProtoParser

final class SimpleProtoTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - Basic Message Testing 🟢
    
    func testBasicMessageParsing() throws {
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/simple/basic_message.proto"
        
        let result = SwiftProtoParser.parseProtoFile(filePath)
        
        switch result {
        case .success(let descriptor):
            // Verify package name
            XCTAssertEqual(descriptor.package, "simple.basic")
            
            // Verify syntax
            XCTAssertEqual(descriptor.syntax, "proto3")
            
            // Verify message exists
            XCTAssertEqual(descriptor.messageTypes.count, 1)
            let basicMessage = descriptor.messageTypes[0]
            XCTAssertEqual(basicMessage.name, "BasicMessage")
            
            // Verify all field types
            XCTAssertEqual(basicMessage.fields.count, 9)
            
            // Check specific fields
            let nameField = basicMessage.fields.first { $0.name == "name" }
            XCTAssertNotNil(nameField)
            XCTAssertEqual(nameField?.number, 1)
            XCTAssertEqual(nameField?.type.description, "string")
            
            let ageField = basicMessage.fields.first { $0.name == "age" }
            XCTAssertNotNil(ageField)
            XCTAssertEqual(ageField?.number, 2)
            XCTAssertEqual(ageField?.type.description, "int32")
            
            let activeField = basicMessage.fields.first { $0.name == "active" }
            XCTAssertNotNil(activeField)
            XCTAssertEqual(activeField?.number, 3)
            XCTAssertEqual(activeField?.type.description, "bool")
            
            let scoreField = basicMessage.fields.first { $0.name == "score" }
            XCTAssertNotNil(scoreField)
            XCTAssertEqual(scoreField?.number, 4)
            XCTAssertEqual(scoreField?.type.description, "double")
            
            let dataField = basicMessage.fields.first { $0.name == "data" }
            XCTAssertNotNil(dataField)
            XCTAssertEqual(dataField?.number, 9)
            XCTAssertEqual(dataField?.type.description, "bytes")
            
        case .failure(let error):
            XCTFail("Failed to parse basic_message.proto: \(error)")
        }
    }
    
    func testBasicEnumParsing() throws {
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/simple/basic_enum.proto"
        
        let result = SwiftProtoParser.parseProtoFile(filePath)
        
        switch result {
        case .success(let descriptor):
            // Verify package
            XCTAssertEqual(descriptor.package, "simple.enum")
            
            // Verify enum exists
            XCTAssertEqual(descriptor.enumTypes.count, 1)
            let statusEnum = descriptor.enumTypes[0]
            XCTAssertEqual(statusEnum.name, "Status")
            
            // Verify enum values
            XCTAssertEqual(statusEnum.values.count, 4)
            
            // Check default value (0)
            let unknownValue = statusEnum.values.first { $0.name == "STATUS_UNKNOWN" }
            XCTAssertNotNil(unknownValue)
            XCTAssertEqual(unknownValue?.number, 0)
            
            // Check other values
            let activeValue = statusEnum.values.first { $0.name == "STATUS_ACTIVE" }
            XCTAssertNotNil(activeValue)
            XCTAssertEqual(activeValue?.number, 1)
            
            // Verify message using enum
            XCTAssertEqual(descriptor.messageTypes.count, 1)
            let statusMessage = descriptor.messageTypes[0]
            XCTAssertEqual(statusMessage.name, "StatusMessage")
            
            let statusField = statusMessage.fields.first { $0.name == "status" }
            XCTAssertNotNil(statusField)
            XCTAssertEqual(statusField?.type.description, "Status")
            
        case .failure(let error):
            XCTFail("Failed to parse basic_enum.proto: \(error)")
        }
    }
    
    func testBasicServiceParsing() throws {
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/simple/basic_service.proto"
        
        let result = SwiftProtoParser.parseProtoFile(filePath)
        
        switch result {
        case .success(let descriptor):
            // Verify package
            XCTAssertEqual(descriptor.package, "simple.service")
            
            // Verify service exists
            XCTAssertEqual(descriptor.services.count, 1)
            let userService = descriptor.services[0]
            XCTAssertEqual(userService.name, "UserService")
            
            // Verify RPC methods
            XCTAssertEqual(userService.methods.count, 3)
            
            let getUser = userService.methods.first { $0.name == "GetUser" }
            XCTAssertNotNil(getUser)
            XCTAssertEqual(getUser?.inputType, "GetUserRequest")
            XCTAssertEqual(getUser?.outputType, "GetUserResponse")
            XCTAssertFalse(getUser?.clientStreaming ?? true)
            XCTAssertFalse(getUser?.serverStreaming ?? true)
            
            let createUser = userService.methods.first { $0.name == "CreateUser" }
            XCTAssertNotNil(createUser)
            XCTAssertEqual(createUser?.inputType, "CreateUserRequest")
            XCTAssertEqual(createUser?.outputType, "CreateUserResponse")
            
            // Verify request/response messages exist
            let messageNames = descriptor.messageTypes.map { $0.name }
            XCTAssertTrue(messageNames.contains("GetUserRequest"))
            XCTAssertTrue(messageNames.contains("GetUserResponse"))
            XCTAssertTrue(messageNames.contains("CreateUserRequest"))
            XCTAssertTrue(messageNames.contains("CreateUserResponse"))
            XCTAssertTrue(messageNames.contains("DeleteUserRequest"))
            XCTAssertTrue(messageNames.contains("DeleteUserResponse"))
            
        case .failure(let error):
            XCTFail("Failed to parse basic_service.proto: \(error)")
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
