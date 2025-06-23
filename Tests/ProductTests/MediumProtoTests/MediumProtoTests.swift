import XCTest
@testable import SwiftProtoParser

final class MediumProtoTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - Nested Messages Testing 🟡
    
    func testNestedMessagesParsing() throws {
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/medium/nested_messages.proto"
        
        let result = SwiftProtoParser.parseProtoFile(filePath)
        
        switch result {
        case .success(let descriptor):
            // Verify package
            XCTAssertEqual(descriptor.package, "medium.nested")
            
            // Verify main message
            XCTAssertEqual(descriptor.messageTypes.count, 1) // Only Company is top-level
            let company = descriptor.messageTypes[0]
            XCTAssertEqual(company.name, "Company")
            
            // Verify nested structure
            XCTAssertEqual(company.nestedTypes.count, 1) // Department
            let department = company.nestedTypes[0]
            XCTAssertEqual(department.name, "Department")
            
            // Verify deeper nesting
            XCTAssertEqual(department.nestedTypes.count, 1) // Employee
            let employee = department.nestedTypes[0]
            XCTAssertEqual(employee.name, "Employee")
            
            // Verify deepest nesting
            XCTAssertEqual(employee.nestedTypes.count, 1) // Address
            let address = employee.nestedTypes[0]
            XCTAssertEqual(address.name, "Address")
            XCTAssertEqual(address.fields.count, 4)
            
            // Verify fields using nested types
            let departmentsField = company.fields.first { $0.name == "departments" }
            XCTAssertNotNil(departmentsField)
            XCTAssertTrue(departmentsField?.label == .repeated)
            XCTAssertEqual(departmentsField?.type.description, "Department")
            
            // Verify enum exists
            XCTAssertEqual(descriptor.enumTypes.count, 1)
            let position = descriptor.enumTypes[0]
            XCTAssertEqual(position.name, "Position")
            XCTAssertEqual(position.values.count, 6)
            
        case .failure(let error):
            XCTFail("Failed to parse nested_messages.proto: \(error)")
        }
    }
    
    func testRepeatedFieldsParsing() throws {
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/medium/repeated_fields.proto"
        
        let result = SwiftProtoParser.parseProtoFile(filePath)
        
        switch result {
        case .success(let descriptor):
            // Verify package
            XCTAssertEqual(descriptor.package, "medium.repeated")
            
            // Verify main message with repeated fields
            let repeatedMessage = descriptor.messageTypes.first { $0.name == "RepeatedMessage" }
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
            
            // Verify nested message
            let nestedItem = descriptor.messageTypes.first { $0.name == "NestedItem" }
            XCTAssertNotNil(nestedItem)
            XCTAssertEqual(nestedItem?.fields.count, 3)
            
            // Verify arrays of arrays
            let arrayOfArrays = descriptor.messageTypes.first { $0.name == "ArrayOfArrays" }
            XCTAssertNotNil(arrayOfArrays)
            
        case .failure(let error):
            XCTFail("Failed to parse repeated_fields.proto: \(error)")
        }
    }
    
    func testMapTypesParsing() throws {
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/medium/map_types.proto"
        
        let result = SwiftProtoParser.parseProtoFile(filePath)
        
        switch result {
        case .success(let descriptor):
            // Verify package
            XCTAssertEqual(descriptor.package, "medium.maps")
            
            // Verify main message with maps
            let mapMessage = descriptor.messageTypes.first { $0.name == "MapMessage" }
            XCTAssertNotNil(mapMessage)
            XCTAssertEqual(mapMessage?.fields.count, 10)
            
            // Check basic map types
            let stringMapField = mapMessage?.fields.first { $0.name == "string_map" }
            XCTAssertNotNil(stringMapField)
            XCTAssertTrue(stringMapField?.type.isMap ?? false)
            
            let intMapField = mapMessage?.fields.first { $0.name == "int_map" }
            XCTAssertNotNil(intMapField)
            XCTAssertTrue(intMapField?.type.isMap ?? false)
            
            // Check map with enum values
            let statusMapField = mapMessage?.fields.first { $0.name == "status_map" }
            XCTAssertNotNil(statusMapField)
            XCTAssertTrue(statusMapField?.type.isMap ?? false)
            
            // Check map with message values
            let userMapField = mapMessage?.fields.first { $0.name == "user_map" }
            XCTAssertNotNil(userMapField)
            XCTAssertTrue(userMapField?.type.isMap ?? false)
            
            // Check different key types
            let idToNameField = mapMessage?.fields.first { $0.name == "id_to_name" }
            XCTAssertNotNil(idToNameField)
            XCTAssertTrue(idToNameField?.type.isMap ?? false)
            
            // Verify enum and message types exist
            XCTAssertEqual(descriptor.enumTypes.count, 1)
            let status = descriptor.enumTypes[0]
            XCTAssertEqual(status.name, "Status")
            
            let userInfo = descriptor.messageTypes.first { $0.name == "UserInfo" }
            XCTAssertNotNil(userInfo)
            
        case .failure(let error):
            XCTFail("Failed to parse map_types.proto: \(error)")
        }
    }
    
    func testOneofGroupsParsing() throws {
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/medium/oneof_groups.proto"
        
        let result = SwiftProtoParser.parseProtoFile(filePath)
        
        switch result {
        case .success(let descriptor):
            // Verify package
            XCTAssertEqual(descriptor.package, "medium.oneof")
            
            // Verify message with oneof
            let oneofMessage = descriptor.messageTypes.first { $0.name == "OneofMessage" }
            XCTAssertNotNil(oneofMessage)
            
            // Check oneof fields
            XCTAssertEqual(oneofMessage?.oneofDecls.count, 1)
            let testOneof = oneofMessage?.oneofDecls[0]
            XCTAssertEqual(testOneof?.name, "test_oneof")
            
            // Verify oneof contains correct fields
            let oneofFields = oneofMessage?.fields.filter { $0.oneofIndex != nil }
            XCTAssertEqual(oneofFields?.count, 5)
            
            // Check specific oneof fields
            let nameField = oneofMessage?.fields.first { $0.name == "name" }
            XCTAssertNotNil(nameField)
            XCTAssertNotNil(nameField?.oneofIndex)
            
            let nestedField = oneofMessage?.fields.first { $0.name == "nested" }
            XCTAssertNotNil(nestedField)
            XCTAssertNotNil(nestedField?.oneofIndex)
            XCTAssertEqual(nestedField?.type.description, "NestedMessage")
            
            // Verify message with multiple oneofs
            let multipleOneofs = descriptor.messageTypes.first { $0.name == "MultipleOneofs" }
            XCTAssertNotNil(multipleOneofs)
            XCTAssertEqual(multipleOneofs?.oneofDecls.count, 2)
            
            // Verify complex oneof
            let complexOneof = descriptor.messageTypes.first { $0.name == "ComplexOneof" }
            XCTAssertNotNil(complexOneof)
            
        case .failure(let error):
            XCTFail("Failed to parse oneof_groups.proto: \(error)")
        }
    }
    
    func testFieldOptionsParsing() throws {
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/medium/field_options.proto"
        
        let result = SwiftProtoParser.parseProtoFile(filePath)
        
        switch result {
        case .success(let descriptor):
            // Verify package
            XCTAssertEqual(descriptor.package, "medium.options")
            
            // Verify import of descriptor.proto
            XCTAssertTrue(descriptor.dependencies.contains("google/protobuf/descriptor.proto"))
            
            // Verify message with options
            let fieldOptionsMessage = descriptor.messageTypes.first { $0.name == "FieldOptionsMessage" }
            XCTAssertNotNil(fieldOptionsMessage)
            
            // Check message options exist (even if we don't parse them fully yet)
            XCTAssertEqual(fieldOptionsMessage?.fields.count, 5)
            
            // Verify field names and types
            let emailField = fieldOptionsMessage?.fields.first { $0.name == "email" }
            XCTAssertNotNil(emailField)
            XCTAssertEqual(emailField?.type.description, "string")
            
            let usernameField = fieldOptionsMessage?.fields.first { $0.name == "username" }
            XCTAssertNotNil(usernameField)
            
            // Verify service with options
            XCTAssertEqual(descriptor.services.count, 1)
            let optionsService = descriptor.services[0]
            XCTAssertEqual(optionsService.name, "OptionsService")
            XCTAssertEqual(optionsService.methods.count, 2)
            
            // Check method names
            let getUserMethod = optionsService.methods.first { $0.name == "GetUser" }
            XCTAssertNotNil(getUserMethod)
            
            let createUserMethod = optionsService.methods.first { $0.name == "CreateUser" }
            XCTAssertNotNil(createUserMethod)
            
        case .failure(let error):
            XCTFail("Failed to parse field_options.proto: \(error)")
        }
    }
    
    // MARK: - Performance Testing 🟡
    
    func testMediumProtoParsingPerformance() throws {
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/medium/nested_messages.proto"
        
        // Performance test: medium complexity should still be fast
        measure {
            for _ in 0..<50 {
                let result = SwiftProtoParser.parseProtoFile(filePath)
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
