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
    
    // MARK: - Helper Methods
    
    private func getTestResourcesPath() -> String {
        // Use #file to determine the test directory location
        let thisFileURL = URL(fileURLWithPath: #file)
        let projectDirectory = thisFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let resourcesPath = projectDirectory.appendingPathComponent("Tests/TestResources").path
        return resourcesPath
    }
}
