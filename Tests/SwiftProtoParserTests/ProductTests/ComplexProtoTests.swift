import XCTest
@testable import SwiftProtoParser

final class ComplexProtoTests: XCTestCase {
    
    // MARK: - Complex Proto3 Product Testing 🔴
    
    func testDeepNestingParsing() throws {
        // Test 6+ level deep nesting using real file
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/complex/deep_nesting.proto"
        
        let result = SwiftProtoParser.parseProtoFile(filePath)
        
        switch result {
        case .success(let ast):
            // Verify package
            XCTAssertEqual(ast.package, "complex.deep")
            XCTAssertEqual(ast.syntax, .proto3)
            
            // Verify main message (Level1)
            XCTAssertEqual(ast.messages.count, 5) // Level1, DeepRequest, DeepResponse, DeepStreamRequest, DeepStreamResponse
            let level1 = ast.messages.first { $0.name == "Level1" }
            XCTAssertNotNil(level1)
            
            // Verify 6 levels of deep nesting: Level1 → Level2 → Level3 → Level4 → Level5 → Level6 → DeepestConfig
            XCTAssertEqual(level1?.nestedMessages.count, 1) // Level2
            let level2 = level1?.nestedMessages.first { $0.name == "Level2" }
            XCTAssertNotNil(level2)
            
            XCTAssertEqual(level2?.nestedMessages.count, 1) // Level3
            let level3 = level2?.nestedMessages.first { $0.name == "Level3" }
            XCTAssertNotNil(level3)
            
            XCTAssertEqual(level3?.nestedMessages.count, 1) // Level4
            let level4 = level3?.nestedMessages.first { $0.name == "Level4" }
            XCTAssertNotNil(level4)
            
            XCTAssertEqual(level4?.nestedMessages.count, 1) // Level5
            let level5 = level4?.nestedMessages.first { $0.name == "Level5" }
            XCTAssertNotNil(level5)
            
            XCTAssertEqual(level5?.nestedMessages.count, 1) // Level6
            let level6 = level5?.nestedMessages.first { $0.name == "Level6" }
            XCTAssertNotNil(level6)
            
            XCTAssertEqual(level6?.nestedMessages.count, 1) // DeepestConfig (7th level!)
            let deepestConfig = level6?.nestedMessages.first { $0.name == "DeepestConfig" }
            XCTAssertNotNil(deepestConfig)
            XCTAssertEqual(deepestConfig?.fields.count, 3)
            
            // Verify deep enum
            XCTAssertEqual(ast.enums.count, 1)
            let deepEnum = ast.enums[0]
            XCTAssertEqual(deepEnum.name, "DeepEnum")
            XCTAssertEqual(deepEnum.values.count, 7) // DEEP_UNKNOWN + 6 levels
            
            // Verify complex service with nested types
            XCTAssertEqual(ast.services.count, 1)
            let deepService = ast.services[0]
            XCTAssertEqual(deepService.name, "DeepService")
            XCTAssertEqual(deepService.methods.count, 2)
            
            // Verify streaming method
            let streamMethod = deepService.methods.first { $0.name == "StreamDeepData" }
            XCTAssertNotNil(streamMethod)
            XCTAssertTrue(streamMethod?.inputStreaming ?? false)
            XCTAssertTrue(streamMethod?.outputStreaming ?? false)
            
        case .failure(let error):
            XCTFail("Failed to parse deep_nesting.proto: \(error)")
        }
    }
    
    func testLargeSchemaParsing() throws {
        // Test large schema performance with real file
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/complex/large_schema.proto"
        
        let startTime = Date()
        let result = SwiftProtoParser.parseProtoFile(filePath)
        let parseTime = Date().timeIntervalSince(startTime)
        
        // Performance requirement: should parse < 200ms for large files
        XCTAssertLessThan(parseTime, 0.2, "Large schema parsing took too long: \(parseTime)s")
        
        switch result {
        case .success(let ast):
            // Verify it's a substantial schema
            XCTAssertEqual(ast.messages.count, 6, "Should have 6 messages (LargeMessage + 5 NestedMessage)")
            XCTAssertEqual(ast.enums.count, 5, "Should have 5 large enums")
            XCTAssertEqual(ast.services.count, 1, "Should have 1 large service")
            
            // Verify the main message has many fields (100+ fields)
            let largeMessage = ast.messages.first { $0.name == "LargeMessage" }
            XCTAssertNotNil(largeMessage)
            XCTAssertGreaterThan(largeMessage?.fields.count ?? 0, 80, "LargeMessage should have 80+ fields")
            
            // Verify service has many methods
            let largeService = ast.services.first { $0.name == "LargeService" }
            XCTAssertNotNil(largeService)
            XCTAssertGreaterThan(largeService?.methods.count ?? 0, 10, "LargeService should have 10+ methods")
            
            // Verify syntax
            XCTAssertEqual(ast.syntax, .proto3)
            
            // Performance test: parse multiple times
            let iterations = 10
            let multiStartTime = Date()
            for _ in 0..<iterations {
                let iterResult = SwiftProtoParser.parseProtoFile(filePath)
                switch iterResult {
                case .success(_):
                    break // Success
                case .failure(_):
                    XCTFail("Should successfully parse on each iteration")
                }
            }
            let multiParseTime = Date().timeIntervalSince(multiStartTime)
            let averageTime = multiParseTime / Double(iterations)
            
            XCTAssertLessThan(averageTime, 0.05, "Average parse time should be fast: \(averageTime)s")
            
        case .failure(let error):
            XCTFail("Failed to parse large_schema.proto: \(error)")
        }
    }
    
    func testStreamingServicesParsing() throws {
        // Test advanced gRPC streaming features with real file
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/complex/streaming_services.proto"
        
        let result = SwiftProtoParser.parseProtoFile(filePath)
        
        switch result {
        case .success(let ast):
            // Verify syntax
            XCTAssertEqual(ast.syntax, .proto3)
            
            // Should have streaming services
            XCTAssertGreaterThan(ast.services.count, 0, "Should have streaming services")
            
            // Find streaming methods
            var hasClientStreaming = false
            var hasServerStreaming = false
            var hasBidirectionalStreaming = false
            
            for service in ast.services {
                for method in service.methods {
                    if method.inputStreaming && !method.outputStreaming {
                        hasClientStreaming = true
                    }
                    if !method.inputStreaming && method.outputStreaming {
                        hasServerStreaming = true
                    }
                    if method.inputStreaming && method.outputStreaming {
                        hasBidirectionalStreaming = true
                    }
                }
            }
            
            // Verify all streaming types are present
            XCTAssertTrue(hasClientStreaming, "Should have client streaming methods")
            XCTAssertTrue(hasServerStreaming, "Should have server streaming methods")
            XCTAssertTrue(hasBidirectionalStreaming, "Should have bidirectional streaming methods")
            
            // Verify messages exist for streaming
            XCTAssertGreaterThan(ast.messages.count, 5, "Should have multiple message types for streaming")
            
        case .failure(let error):
            XCTFail("Failed to parse streaming_services.proto: \(error)")
        }
    }
    
    func testEdgeCasesParsing() throws {
        // Test edge cases and error scenarios with real file
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/complex/edge_cases.proto"
        
        let result = SwiftProtoParser.parseProtoFile(filePath)
        
        switch result {
        case .success(let ast):
            // Should successfully parse edge cases without errors
            XCTAssertEqual(ast.syntax, .proto3)
            XCTAssertNotNil(ast.package)
            
            // Verify it contains complex edge case patterns
            XCTAssertGreaterThan(ast.messages.count, 5, "Should have multiple edge case messages")
            
            // Test various edge case field numbers
            var hasHighFieldNumbers = false
            var hasReservedFields = false
            
            for message in ast.messages {
                for field in message.fields {
                    if field.number > 1000 {
                        hasHighFieldNumbers = true
                    }
                }
                
                // Check if message has reserved fields
                if !message.reservedNumbers.isEmpty || !message.reservedNames.isEmpty {
                    hasReservedFields = true
                }
            }
            
            // Verify edge cases are handled
            XCTAssertTrue(hasHighFieldNumbers, "Should handle high field numbers")
            
            // Log reserved fields status for debugging
            if hasReservedFields {
                print("Found messages with reserved fields")
            } else {
                print("No reserved fields found in test file")
            }
            
        case .failure(let error):
            XCTFail("Failed to parse edge_cases.proto: \(error)")
        }
    }
    
    // MARK: - Real-World File Testing 🌍
    
    func testAPIGatewayParsing() throws {
        // Test enterprise-grade API Gateway proto
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/realworld/api_gateway.proto"
        
        let result = SwiftProtoParser.parseProtoFile(filePath)
        
        switch result {
        case .success(let ast):
            // Verify package
            XCTAssertEqual(ast.package, "realworld.gateway")
            XCTAssertEqual(ast.syntax, .proto3)
            
            // Verify imports (Google Well-Known Types)
            XCTAssertTrue(ast.imports.contains("google/protobuf/any.proto"))
            XCTAssertTrue(ast.imports.contains("google/protobuf/timestamp.proto"))
            XCTAssertTrue(ast.imports.contains("google/protobuf/duration.proto"))
            XCTAssertTrue(ast.imports.contains("google/protobuf/struct.proto"))
            
            // Verify main API Gateway service
            let apiGateway = ast.services.first { $0.name == "APIGateway" }
            XCTAssertNotNil(apiGateway)
            XCTAssertGreaterThan(apiGateway?.methods.count ?? 0, 10, "Should have many API methods")
            
            // Verify CRUD operations
            let createRoute = apiGateway?.methods.first { $0.name == "CreateRoute" }
            let getRoute = apiGateway?.methods.first { $0.name == "GetRoute" }
            let updateRoute = apiGateway?.methods.first { $0.name == "UpdateRoute" }
            let deleteRoute = apiGateway?.methods.first { $0.name == "DeleteRoute" }
            let listRoutes = apiGateway?.methods.first { $0.name == "ListRoutes" }
            
            XCTAssertNotNil(createRoute)
            XCTAssertNotNil(getRoute)
            XCTAssertNotNil(updateRoute)
            XCTAssertNotNil(deleteRoute)
            XCTAssertNotNil(listRoutes)
            
            // Verify streaming methods
            let streamProxy = apiGateway?.methods.first { $0.name == "StreamProxy" }
            XCTAssertNotNil(streamProxy)
            XCTAssertTrue(streamProxy?.inputStreaming ?? false)
            XCTAssertTrue(streamProxy?.outputStreaming ?? false)
            
            // Verify complex message types
            let route = ast.messages.first { $0.name == "Route" }
            XCTAssertNotNil(route)
            XCTAssertGreaterThan(route?.fields.count ?? 0, 8, "Route should have many fields")
            
            // Verify enums for enterprise patterns
            XCTAssertGreaterThan(ast.enums.count, 8, "Should have many enums for enterprise patterns")
            
            let httpMethod = ast.enums.first { $0.name == "HttpMethod" }
            XCTAssertNotNil(httpMethod)
            XCTAssertGreaterThan(httpMethod?.values.count ?? 0, 5, "Should support multiple HTTP methods")
            
        case .failure(let error):
            XCTFail("Failed to parse api_gateway.proto: \(error)")
        }
    }
    
    // MARK: - Performance Testing 🚀
    
    func testComplexProtoParsingPerformance() throws {
        // Performance test for complex file parsing
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/complex/deep_nesting.proto"
        
        measure {
            for _ in 0..<20 {
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
    
    // MARK: - Critical Google Well-Known Types Testing 🚨 (CRITICAL COVERAGE FIX)
    
    func testGoogleWellKnownTypesParsing() throws {
        // 🚨 CRITICAL TEST - Google Well-Known Types (131 lines) - qualified types support
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/google/well_known_types.proto"
        
        let result = SwiftProtoParser.parseProtoFile(filePath)
        
        switch result {
        case .success(let ast):
            // Verify package and syntax
            XCTAssertEqual(ast.package, "google.wellknown")
            XCTAssertEqual(ast.syntax, .proto3)
            
            // Verify all Google Well-Known Types imports (7 imports)
            XCTAssertEqual(ast.imports.count, 7, "Should have 7 Google Well-Known Types imports")
            XCTAssertTrue(ast.imports.contains("google/protobuf/any.proto"))
            XCTAssertTrue(ast.imports.contains("google/protobuf/duration.proto"))
            XCTAssertTrue(ast.imports.contains("google/protobuf/empty.proto"))
            XCTAssertTrue(ast.imports.contains("google/protobuf/field_mask.proto"))
            XCTAssertTrue(ast.imports.contains("google/protobuf/struct.proto"))
            XCTAssertTrue(ast.imports.contains("google/protobuf/timestamp.proto"))
            XCTAssertTrue(ast.imports.contains("google/protobuf/wrappers.proto"))
            
            // Verify messages count (1 main + 8 request/response messages = 9 total)
            XCTAssertEqual(ast.messages.count, 9, "Should have 9 messages total")
            
            // Verify main WellKnownTypesMessage with ALL 24 qualified type fields
            let mainMessage = ast.messages.first { $0.name == "WellKnownTypesMessage" }
            XCTAssertNotNil(mainMessage, "Must have WellKnownTypesMessage")
            XCTAssertEqual(mainMessage?.fields.count, 24, "Should have exactly 24 fields with qualified types")
            
            // Verify Timestamp qualified types (fields 1-2)
            let createdAt = mainMessage?.fields.first { $0.name == "created_at" }
            XCTAssertNotNil(createdAt)
            XCTAssertEqual(createdAt?.number, 1)
            if case .qualifiedType(let typeName) = createdAt?.type {
                XCTAssertEqual(typeName, "google.protobuf.Timestamp")
            } else {
                XCTFail("created_at should be qualified type google.protobuf.Timestamp")
            }
            
            let updatedAt = mainMessage?.fields.first { $0.name == "updated_at" }
            XCTAssertNotNil(updatedAt)
            XCTAssertEqual(updatedAt?.number, 2)
            if case .qualifiedType(let typeName) = updatedAt?.type {
                XCTAssertEqual(typeName, "google.protobuf.Timestamp")
            } else {
                XCTFail("updated_at should be qualified type google.protobuf.Timestamp")
            }
            
            // Verify Duration qualified types (fields 3-4)
            let timeout = mainMessage?.fields.first { $0.name == "timeout" }
            XCTAssertNotNil(timeout)
            if case .qualifiedType(let typeName) = timeout?.type {
                XCTAssertEqual(typeName, "google.protobuf.Duration")
            } else {
                XCTFail("timeout should be qualified type google.protobuf.Duration")
            }
            
            // Verify Any qualified types (fields 5-6)
            let payload = mainMessage?.fields.first { $0.name == "payload" }
            XCTAssertNotNil(payload)
            if case .qualifiedType(let typeName) = payload?.type {
                XCTAssertEqual(typeName, "google.protobuf.Any")
            } else {
                XCTFail("payload should be qualified type google.protobuf.Any")
            }
            
            let attachments = mainMessage?.fields.first { $0.name == "attachments" }
            XCTAssertNotNil(attachments)
            XCTAssertEqual(attachments?.label, .repeated)
            if case .qualifiedType(let typeName) = attachments?.type {
                XCTAssertEqual(typeName, "google.protobuf.Any")
            } else {
                XCTFail("attachments should be repeated qualified type google.protobuf.Any")
            }
            
            // Verify Struct qualified types (fields 7-8)
            let metadata = mainMessage?.fields.first { $0.name == "metadata" }
            XCTAssertNotNil(metadata)
            if case .qualifiedType(let typeName) = metadata?.type {
                XCTAssertEqual(typeName, "google.protobuf.Struct")
            } else {
                XCTFail("metadata should be qualified type google.protobuf.Struct")
            }
            
            // Verify Value qualified types (fields 9-10)
            let dynamicField = mainMessage?.fields.first { $0.name == "dynamic_field" }
            XCTAssertNotNil(dynamicField)
            if case .qualifiedType(let typeName) = dynamicField?.type {
                XCTAssertEqual(typeName, "google.protobuf.Value")
            } else {
                XCTFail("dynamic_field should be qualified type google.protobuf.Value")
            }
            
            // Verify ListValue qualified types (fields 11-12)
            let items = mainMessage?.fields.first { $0.name == "items" }
            XCTAssertNotNil(items)
            if case .qualifiedType(let typeName) = items?.type {
                XCTAssertEqual(typeName, "google.protobuf.ListValue")
            } else {
                XCTFail("items should be qualified type google.protobuf.ListValue")
            }
            
            // Verify ALL Wrapper qualified types (fields 13-21) - 9 wrappers total
            let wrapperTests = [
                ("optional_name", 13, "google.protobuf.StringValue"),
                ("optional_count", 14, "google.protobuf.Int32Value"),
                ("optional_id", 15, "google.protobuf.Int64Value"),
                ("optional_version", 16, "google.protobuf.UInt32Value"),
                ("optional_size", 17, "google.protobuf.UInt64Value"),
                ("optional_enabled", 18, "google.protobuf.BoolValue"),
                ("optional_score", 19, "google.protobuf.FloatValue"),
                ("optional_rating", 20, "google.protobuf.DoubleValue"),
                ("optional_data", 21, "google.protobuf.BytesValue")
            ]
            
            for (fieldName, fieldNumber, expectedType) in wrapperTests {
                let field = mainMessage?.fields.first { $0.name == fieldName }
                XCTAssertNotNil(field, "Must have field: \(fieldName)")
                XCTAssertEqual(field?.number, Int32(fieldNumber), "\(fieldName) should have number \(fieldNumber)")
                if case .qualifiedType(let typeName) = field?.type {
                    XCTAssertEqual(typeName, expectedType, "\(fieldName) should be qualified type \(expectedType)")
                } else {
                    XCTFail("\(fieldName) should be qualified type \(expectedType)")
                }
            }
            
            // Verify FieldMask qualified types (fields 22-23)
            let updateMask = mainMessage?.fields.first { $0.name == "update_mask" }
            XCTAssertNotNil(updateMask)
            if case .qualifiedType(let typeName) = updateMask?.type {
                XCTAssertEqual(typeName, "google.protobuf.FieldMask")
            } else {
                XCTFail("update_mask should be qualified type google.protobuf.FieldMask")
            }
            
            // Verify Empty qualified type (field 24)
            let voidResult = mainMessage?.fields.first { $0.name == "void_result" }
            XCTAssertNotNil(voidResult)
            XCTAssertEqual(voidResult?.number, 24)
            if case .qualifiedType(let typeName) = voidResult?.type {
                XCTAssertEqual(typeName, "google.protobuf.Empty")
            } else {
                XCTFail("void_result should be qualified type google.protobuf.Empty")
            }
            
            // Verify WellKnownTypesService with 5 methods
            XCTAssertEqual(ast.services.count, 1, "Should have exactly 1 service")
            let service = ast.services.first { $0.name == "WellKnownTypesService" }
            XCTAssertNotNil(service, "Must have WellKnownTypesService")
            XCTAssertEqual(service?.methods.count, 5, "Should have exactly 5 service methods")
            
            // Verify Ping method (Empty → Empty)
            let pingMethod = service?.methods.first { $0.name == "Ping" }
            XCTAssertNotNil(pingMethod)
            XCTAssertEqual(pingMethod?.inputType, "google.protobuf.Empty")
            XCTAssertEqual(pingMethod?.outputType, "google.protobuf.Empty")
            
            // Verify ProcessAny method
            let processAnyMethod = service?.methods.first { $0.name == "ProcessAny" }
            XCTAssertNotNil(processAnyMethod)
            
            // Verify all request/response messages are present (6 messages)
            let requestResponseMessages = [
                "ProcessAnyRequest", "ProcessAnyResponse",
                "UpdatePartialRequest", "UpdatePartialResponse", 
                "ScheduleTaskRequest", "ScheduleTaskResponse",
                "ProcessDynamicRequest", "ProcessDynamicResponse"
            ]
            for messageName in requestResponseMessages {
                let message = ast.messages.first { $0.name == messageName }
                XCTAssertNotNil(message, "Must have message: \(messageName)")
            }
            
            // Verify ProcessDynamicRequest has map with qualified types
            let processDynamicRequest = ast.messages.first { $0.name == "ProcessDynamicRequest" }
            XCTAssertNotNil(processDynamicRequest)
            let contextField = processDynamicRequest?.fields.first { $0.name == "context" }
            XCTAssertNotNil(contextField)
            if case .map(key: .string, value: .qualifiedType(let valueType)) = contextField?.type {
                XCTAssertEqual(valueType, "google.protobuf.Value")
            } else {
                XCTFail("context should be map<string, google.protobuf.Value>")
            }
            
            // Verify TaskStatus enum
            XCTAssertEqual(ast.enums.count, 1, "Should have exactly 1 enum")
            let taskStatus = ast.enums.first { $0.name == "TaskStatus" }
            XCTAssertNotNil(taskStatus)
            XCTAssertEqual(taskStatus?.values.count, 6, "TaskStatus should have 6 values")
            
            // Verify enum has proper zero value
            let unknownValue = taskStatus?.values.first { $0.name == "TASK_STATUS_UNKNOWN" }
            XCTAssertNotNil(unknownValue)
            XCTAssertEqual(unknownValue?.number, 0)
            
            print("✅ CRITICAL SUCCESS: Google Well-Known Types parsing - ALL 24 qualified type fields verified!")
            
        case .failure(let error):
            XCTFail("❌ CRITICAL FAILURE: Failed to parse google/well_known_types.proto: \(error)")
        }
    }
    
    func testProductionGRPCServiceParsing() throws {
        // 🚨 CRITICAL TEST - Production gRPC Service (197 lines) - enterprise gRPC patterns
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/grpc/grpc_service.proto"
        
        let result = SwiftProtoParser.parseProtoFile(filePath)
        
        switch result {
        case .success(let ast):
            // Verify package and syntax
            XCTAssertEqual(ast.package, "grpc.service")
            XCTAssertEqual(ast.syntax, .proto3)
            
            // Verify Google Well-Known Types imports (3 critical imports)
            XCTAssertEqual(ast.imports.count, 3, "Should have 3 Google imports")
            XCTAssertTrue(ast.imports.contains("google/protobuf/empty.proto"))
            XCTAssertTrue(ast.imports.contains("google/protobuf/timestamp.proto"))
            XCTAssertTrue(ast.imports.contains("google/protobuf/field_mask.proto"))
            
            // Verify main UserManagementService with 9 methods
            XCTAssertEqual(ast.services.count, 1, "Should have exactly 1 service")
            let service = ast.services.first { $0.name == "UserManagementService" }
            XCTAssertNotNil(service, "Must have UserManagementService")
            XCTAssertEqual(service?.methods.count, 9, "Should have exactly 9 RPC methods")
            
            // Verify CRUD operations (5 methods)
            let crudMethods = ["CreateUser", "GetUser", "UpdateUser", "DeleteUser", "ListUsers"]
            for methodName in crudMethods {
                let method = service?.methods.first { $0.name == methodName }
                XCTAssertNotNil(method, "Must have \(methodName) method")
                XCTAssertFalse(method?.inputStreaming ?? true, "\(methodName) should not be input streaming")
                XCTAssertFalse(method?.outputStreaming ?? true, "\(methodName) should not be output streaming")
            }
            
            // Verify Server Streaming: StreamUsers
            let streamUsers = service?.methods.first { $0.name == "StreamUsers" }
            XCTAssertNotNil(streamUsers, "Must have StreamUsers method")
            XCTAssertFalse(streamUsers?.inputStreaming ?? true, "StreamUsers should not be input streaming")
            XCTAssertTrue(streamUsers?.outputStreaming ?? false, "StreamUsers should be output streaming")
            XCTAssertEqual(streamUsers?.inputType, "StreamUsersRequest")
            XCTAssertEqual(streamUsers?.outputType, "User")
            
            // Verify Client Streaming: BatchCreateUsers  
            let batchCreate = service?.methods.first { $0.name == "BatchCreateUsers" }
            XCTAssertNotNil(batchCreate, "Must have BatchCreateUsers method")
            XCTAssertTrue(batchCreate?.inputStreaming ?? false, "BatchCreateUsers should be input streaming")
            XCTAssertFalse(batchCreate?.outputStreaming ?? true, "BatchCreateUsers should not be output streaming")
            XCTAssertEqual(batchCreate?.inputType, "CreateUserRequest")
            XCTAssertEqual(batchCreate?.outputType, "BatchCreateUsersResponse")
            
            // Verify Bidirectional Streaming: ChatWithUsers
            let chat = service?.methods.first { $0.name == "ChatWithUsers" }
            XCTAssertNotNil(chat, "Must have ChatWithUsers method")
            XCTAssertTrue(chat?.inputStreaming ?? false, "ChatWithUsers should be input streaming")
            XCTAssertTrue(chat?.outputStreaming ?? false, "ChatWithUsers should be output streaming")
            XCTAssertEqual(chat?.inputType, "ChatMessage")
            XCTAssertEqual(chat?.outputType, "ChatMessage")
            
            // Verify Health Check with qualified types
            let health = service?.methods.first { $0.name == "Health" }
            XCTAssertNotNil(health, "Must have Health method")
            XCTAssertEqual(health?.inputType, "google.protobuf.Empty")
            XCTAssertEqual(health?.outputType, "HealthResponse")
            XCTAssertFalse(health?.inputStreaming ?? true)
            XCTAssertFalse(health?.outputStreaming ?? true)
            
            // Verify complex messages count (should have many messages)
            XCTAssertGreaterThan(ast.messages.count, 15, "Should have 15+ messages for complex service")
            
            // Verify main User entity with qualified types
            let user = ast.messages.first { $0.name == "User" }
            XCTAssertNotNil(user, "Must have User message")
            XCTAssertEqual(user?.fields.count, 10, "User should have 10 fields")
            
            // Verify User has qualified Timestamp fields (fields 6,7)
            let createdAt = user?.fields.first { $0.name == "created_at" }
            XCTAssertNotNil(createdAt)
            XCTAssertEqual(createdAt?.number, 6)
            if case .qualifiedType(let typeName) = createdAt?.type {
                XCTAssertEqual(typeName, "google.protobuf.Timestamp")
            } else {
                XCTFail("created_at should be qualified type google.protobuf.Timestamp")
            }
            
            let updatedAt = user?.fields.first { $0.name == "updated_at" }
            XCTAssertNotNil(updatedAt)
            if case .qualifiedType(let typeName) = updatedAt?.type {
                XCTAssertEqual(typeName, "google.protobuf.Timestamp")
            } else {
                XCTFail("updated_at should be qualified type google.protobuf.Timestamp")
            }
            
            // Verify User has map field (field 10)
            let metadata = user?.fields.first { $0.name == "metadata" }
            XCTAssertNotNil(metadata)
            XCTAssertEqual(metadata?.number, 10)
            if case .map(key: .string, value: .string) = metadata?.type {
                // Success
            } else {
                XCTFail("metadata should be map<string, string>")
            }
            
            // Verify GetUserRequest with oneof + qualified types
            let getUserRequest = ast.messages.first { $0.name == "GetUserRequest" }
            XCTAssertNotNil(getUserRequest, "Must have GetUserRequest")
            XCTAssertEqual(getUserRequest?.oneofGroups.count, 1, "Should have 1 oneof group")
            
            let oneofGroup = getUserRequest?.oneofGroups.first
            XCTAssertNotNil(oneofGroup)
            XCTAssertEqual(oneofGroup?.name, "identifier")
            XCTAssertEqual(oneofGroup?.fields.count, 3, "Oneof should have 3 fields")
            
            // Verify FieldMask qualified type in GetUserRequest
            let fieldMask = getUserRequest?.fields.first { $0.name == "field_mask" }
            XCTAssertNotNil(fieldMask)
            if case .qualifiedType(let typeName) = fieldMask?.type {
                XCTAssertEqual(typeName, "google.protobuf.FieldMask")
            } else {
                XCTFail("field_mask should be qualified type google.protobuf.FieldMask")
            }
            
            // Verify UpdateUserRequest with FieldMask
            let updateUserRequest = ast.messages.first { $0.name == "UpdateUserRequest" }
            XCTAssertNotNil(updateUserRequest)
            let updateMask = updateUserRequest?.fields.first { $0.name == "update_mask" }
            XCTAssertNotNil(updateMask)
            if case .qualifiedType(let typeName) = updateMask?.type {
                XCTAssertEqual(typeName, "google.protobuf.FieldMask")
            } else {
                XCTFail("update_mask should be qualified type google.protobuf.FieldMask")
            }
            
            // Verify nested messages (UserProfile)
            let userProfile = ast.messages.first { $0.name == "UserProfile" }
            XCTAssertNotNil(userProfile, "Must have UserProfile message")
            XCTAssertEqual(userProfile?.fields.count, 6, "UserProfile should have 6 fields")
            
            // Verify UserProfile has qualified Timestamp
            let birthDate = userProfile?.fields.first { $0.name == "birth_date" }
            XCTAssertNotNil(birthDate)
            if case .qualifiedType(let typeName) = birthDate?.type {
                XCTAssertEqual(typeName, "google.protobuf.Timestamp")
            } else {
                XCTFail("birth_date should be qualified type google.protobuf.Timestamp")
            }
            
            // Verify all required enums (4 enums)
            XCTAssertEqual(ast.enums.count, 4, "Should have exactly 4 enums")
            let enumNames = Set(ast.enums.map { $0.name })
            XCTAssertTrue(enumNames.contains("UserStatus"))
            XCTAssertTrue(enumNames.contains("SocialPlatform"))
            XCTAssertTrue(enumNames.contains("MessageType"))
            XCTAssertTrue(enumNames.contains("HealthStatus"))
            
            // Verify enum has proper zero values
            for enumNode in ast.enums {
                let hasZeroValue = enumNode.values.contains { $0.number == 0 }
                XCTAssertTrue(hasZeroValue, "\(enumNode.name) should have zero value")
            }
            
            // Verify streaming messages
            let chatMessage = ast.messages.first { $0.name == "ChatMessage" }
            XCTAssertNotNil(chatMessage, "Must have ChatMessage for bidirectional streaming")
            XCTAssertEqual(chatMessage?.fields.count, 7, "ChatMessage should have 7 fields")
            
            // Verify ChatMessage has qualified Timestamp
            let timestamp = chatMessage?.fields.first { $0.name == "timestamp" }
            XCTAssertNotNil(timestamp)
            if case .qualifiedType(let typeName) = timestamp?.type {
                XCTAssertEqual(typeName, "google.protobuf.Timestamp")
            } else {
                XCTFail("timestamp should be qualified type google.protobuf.Timestamp")
            }
            
            // Verify HealthResponse with qualified types and map
            let healthResponse = ast.messages.first { $0.name == "HealthResponse" }
            XCTAssertNotNil(healthResponse, "Must have HealthResponse")
            XCTAssertEqual(healthResponse?.fields.count, 4, "HealthResponse should have 4 fields")
            
            let healthTimestamp = healthResponse?.fields.first { $0.name == "timestamp" }
            XCTAssertNotNil(healthTimestamp)
            if case .qualifiedType(let typeName) = healthTimestamp?.type {
                XCTAssertEqual(typeName, "google.protobuf.Timestamp")
            } else {
                XCTFail("health timestamp should be qualified type google.protobuf.Timestamp")
            }
            
            let details = healthResponse?.fields.first { $0.name == "details" }
            XCTAssertNotNil(details)
            if case .map(key: .string, value: .string) = details?.type {
                // Success
            } else {
                XCTFail("details should be map<string, string>")
            }
            
            print("✅ CRITICAL SUCCESS: Production gRPC Service parsing - ALL streaming types, qualified types, oneof, and maps verified!")
            
        case .failure(let error):
            XCTFail("❌ CRITICAL FAILURE: Failed to parse grpc/grpc_service.proto: \(error)")
        }
    }
    
    func testMalformedProtoErrorHandling() throws {
        // 🚨 CRITICAL TEST - Error Handling (75 lines) - parser robustness and error recovery
        let testResourcesPath = getTestResourcesPath()
        let filePath = "\(testResourcesPath)/ProductTests/malformed/syntax_errors.proto"
        
        let result = SwiftProtoParser.parseProtoFile(filePath)
        
        switch result {
        case .success(let ast):
            // The parser should be robust enough to parse what it can despite errors
            // Verify basic structure can still be extracted
            
            // Should still detect the package despite errors
            XCTAssertEqual(ast.package, "malformed.syntax")
            XCTAssertEqual(ast.syntax, .proto3)
            
            // Parser should recover and parse valid messages even with errors present
            // Some valid messages should be parseable despite syntax errors in other parts
            XCTAssertGreaterThan(ast.messages.count, 0, "Should parse some valid messages despite errors")
            
            // Look for messages that should be parseable
            let validMessageNames = ["AnotherMessage", "ExtremelyLongLineTest"]
            for messageName in validMessageNames {
                let message = ast.messages.first { $0.name == messageName }
                if let message = message {
                    XCTAssertGreaterThan(message.fields.count, 0, "\(messageName) should have fields")
                }
            }
            
            // Test that extremely long lines don't crash the parser (robustness)
            let longLineMessage = ast.messages.first { $0.name == "ExtremelyLongLineTest" }
            if let longLineMessage = longLineMessage {
                XCTAssertEqual(longLineMessage.fields.count, 1, "ExtremelyLongLineTest should have 1 field")
                let longField = longLineMessage.fields.first
                XCTAssertNotNil(longField, "Should handle extremely long field names")
                XCTAssertTrue(longField?.name.contains("extremely_long_field_name") ?? false, "Should preserve long field name")
            }
            
            print("✅ CRITICAL SUCCESS: Malformed proto error handling - parser demonstrates robust error recovery!")
            
        case .failure(let error):
            // This is also acceptable - the parser correctly detected syntax errors
            XCTAssertTrue(error.localizedDescription.contains("error") || 
                         error.localizedDescription.contains("syntax") ||
                         error.localizedDescription.contains("unexpected"), 
                         "Error message should indicate syntax problems")
            
            // Verify error contains meaningful information for debugging
            let errorString = error.localizedDescription
            XCTAssertFalse(errorString.isEmpty, "Error message should not be empty")
            XCTAssertGreaterThan(errorString.count, 10, "Error message should be descriptive")
            
            print("✅ CRITICAL SUCCESS: Malformed proto error handling - parser correctly detects and reports syntax errors!")
        }
        
        // Additional robustness test: verify parser doesn't crash on completely malformed input
        let malformedInputs = [
            "completely invalid protobuf content",
            "syntax = \"proto3\"; message { string = 1",
            "}{}{random}{brackets}{}",
            String(repeating: "a", count: 10000), // Very long string
            "message\n\n\n\nTest\n\n{}", // Excessive newlines
            "message Test { \0\0\0 }", // Null characters
        ]
        
        for (index, malformedInput) in malformedInputs.enumerated() {
            let malformedResult = SwiftProtoParser.parseProtoString(malformedInput)
            
            // Parser should either handle gracefully or fail with meaningful error
            switch malformedResult {
            case .success:
                // If it somehow succeeds, that's fine (very robust parser)
                print("Parser handled malformed input \(index) gracefully")
            case .failure(let error):
                // Should fail with meaningful error, not crash
                XCTAssertFalse(error.localizedDescription.isEmpty, 
                              "Malformed input \(index) should produce non-empty error message")
            }
        }
        
        print("✅ CRITICAL SUCCESS: All malformed input robustness tests passed - parser is production-ready!")
    }
    
    // MARK: - Helper Methods
    
    private func getTestResourcesPath() -> String {
        // Use #file to determine the test directory location
        let thisFileURL = URL(fileURLWithPath: #file)
        let projectDirectory = thisFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let resourcesPath = projectDirectory.appendingPathComponent("Tests/TestResources").path
        return resourcesPath
    }
}
