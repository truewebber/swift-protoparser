import XCTest

@testable import SwiftProtoParser

/**
 * Test suite for ServiceNode
 *
 * This test suite verifies the functionality of the ServiceNode component
 * according to the acceptance criteria defined in ACCEPTANCE_CRITERIA.md.
 *
 * Acceptance Criteria:
 * - Parse service definitions
 * - Parse RPC method definitions
 * - Parse streaming options
 * - Validate service and method names
 * - Validate input and output types
 */
final class ServiceNodeTests: XCTestCase {
    
    // MARK: - Basic Service Tests
    
    /**
     * Test creating and validating a basic service
     *
     * This test verifies that a basic service can be created and validated.
     */
    func testBasicService() throws {
        // Create a basic service
        let serviceNode = ServiceNode(
            location: SourceLocation(line: 1, column: 1),
            name: "UserService",
            rpcs: [],
            options: []
        )
        
        // Verify properties
        XCTAssertEqual(serviceNode.name, "UserService", "Service name should match")
        XCTAssertEqual(serviceNode.rpcs.count, 0, "Service should have no RPCs initially")
        XCTAssertEqual(serviceNode.options.count, 0, "Service should have no options initially")
        XCTAssertEqual(serviceNode.location.line, 1, "Service location line should match")
        XCTAssertEqual(serviceNode.location.column, 1, "Service location column should match")
    }
    
    /**
     * Test creating a service with RPC methods
     *
     * This test verifies that a service with RPC methods can be created and validated.
     */
    func testServiceWithRPCs() throws {
        // Create RPC methods
        let getUser = RPCNode(
            location: SourceLocation(line: 2, column: 3),
            name: "GetUser",
            inputType: "GetUserRequest",
            outputType: "GetUserResponse"
        )
        
        let createUser = RPCNode(
            location: SourceLocation(line: 3, column: 3),
            name: "CreateUser",
            inputType: "CreateUserRequest",
            outputType: "CreateUserResponse"
        )
        
        // Create a service with RPCs
        let serviceNode = ServiceNode(
            location: SourceLocation(line: 1, column: 1),
            name: "UserService",
            rpcs: [getUser, createUser],
            options: []
        )
        
        // Verify properties
        XCTAssertEqual(serviceNode.name, "UserService", "Service name should match")
        XCTAssertEqual(serviceNode.rpcs.count, 2, "Service should have 2 RPCs")
        XCTAssertEqual(serviceNode.rpcs[0].name, "GetUser", "First RPC name should match")
        XCTAssertEqual(serviceNode.rpcs[1].name, "CreateUser", "Second RPC name should match")
        
        // Verify method names set
        let methodNames = serviceNode.methodNames
        XCTAssertEqual(methodNames.count, 2, "Service should have 2 method names")
        XCTAssertTrue(methodNames.contains("GetUser"), "Method names should contain GetUser")
        XCTAssertTrue(methodNames.contains("CreateUser"), "Method names should contain CreateUser")
    }
    
    /**
     * Test creating a service with streaming RPCs
     *
     * This test verifies that a service with streaming RPC methods can be created and validated.
     */
    func testServiceWithStreamingRPCs() throws {
        // Create streaming RPC methods
        let streamUsers = RPCNode(
            location: SourceLocation(line: 2, column: 3),
            name: "StreamUsers",
            inputType: "StreamUsersRequest",
            outputType: "User",
            clientStreaming: false,
            serverStreaming: true
        )
        
        let uploadUsers = RPCNode(
            location: SourceLocation(line: 3, column: 3),
            name: "UploadUsers",
            inputType: "User",
            outputType: "UploadUsersResponse",
            clientStreaming: true,
            serverStreaming: false
        )
        
        let chatService = RPCNode(
            location: SourceLocation(line: 4, column: 3),
            name: "Chat",
            inputType: "ChatMessage",
            outputType: "ChatMessage",
            clientStreaming: true,
            serverStreaming: true
        )
        
        // Create a service with streaming RPCs
        let serviceNode = ServiceNode(
            location: SourceLocation(line: 1, column: 1),
            name: "StreamingService",
            rpcs: [streamUsers, uploadUsers, chatService],
            options: []
        )
        
        // Verify properties
        XCTAssertEqual(serviceNode.rpcs.count, 3, "Service should have 3 RPCs")
        
        // Verify streaming properties
        XCTAssertFalse(serviceNode.rpcs[0].clientStreaming, "StreamUsers should not have client streaming")
        XCTAssertTrue(serviceNode.rpcs[0].serverStreaming, "StreamUsers should have server streaming")
        
        XCTAssertTrue(serviceNode.rpcs[1].clientStreaming, "UploadUsers should have client streaming")
        XCTAssertFalse(serviceNode.rpcs[1].serverStreaming, "UploadUsers should not have server streaming")
        
        XCTAssertTrue(serviceNode.rpcs[2].clientStreaming, "Chat should have client streaming")
        XCTAssertTrue(serviceNode.rpcs[2].serverStreaming, "Chat should have server streaming")
    }
    
    /**
     * Test creating a service with options
     *
     * This test verifies that a service with options can be created and validated.
     */
    func testServiceWithOptions() throws {
        // Create options
        let deprecatedOption = OptionNode(
            location: SourceLocation(line: 2, column: 3),
            name: "deprecated",
            value: .identifier("true"),
            pathParts: []
        )
        
        let customOption = OptionNode(
            location: SourceLocation(line: 3, column: 3),
            name: "custom_option",
            value: .string("value"),
            pathParts: []
        )
        
        // Create a service with options
        let serviceNode = ServiceNode(
            location: SourceLocation(line: 1, column: 1),
            name: "UserService",
            rpcs: [],
            options: [deprecatedOption, customOption]
        )
        
        // Verify properties
        XCTAssertEqual(serviceNode.options.count, 2, "Service should have 2 options")
        XCTAssertEqual(serviceNode.options[0].name, "deprecated", "First option name should match")
        XCTAssertEqual(serviceNode.options[1].name, "custom_option", "Second option name should match")
        
        // Verify option values
        if case .identifier(let value) = serviceNode.options[0].value {
            XCTAssertEqual(value, "true", "Deprecated option value should be true")
        } else {
            XCTFail("Expected identifier value")
        }
        
        if case .string(let value) = serviceNode.options[1].value {
            XCTAssertEqual(value, "value", "Custom option value should match")
        } else {
            XCTFail("Expected string value")
        }
    }
    
    /**
     * Test creating an RPC with options
     *
     * This test verifies that an RPC with options can be created and validated.
     */
    func testRPCWithOptions() throws {
        // Create options
        let deprecatedOption = OptionNode(
            location: SourceLocation(line: 3, column: 5),
            name: "deprecated",
            value: .identifier("true"),
            pathParts: []
        )
        
        let timeoutOption = OptionNode(
            location: SourceLocation(line: 4, column: 5),
            name: "timeout",
            value: .number(30.5),
            pathParts: []
        )
        
        // Create an RPC with options
        let rpcNode = RPCNode(
            location: SourceLocation(line: 2, column: 3),
            name: "GetUser",
            inputType: "GetUserRequest",
            outputType: "GetUserResponse",
            options: [deprecatedOption, timeoutOption]
        )
        
        // Create a service with the RPC
        let serviceNode = ServiceNode(
            location: SourceLocation(line: 1, column: 1),
            name: "UserService",
            rpcs: [rpcNode],
            options: []
        )
        
        // Verify properties
        XCTAssertEqual(serviceNode.rpcs.count, 1, "Service should have 1 RPC")
        XCTAssertEqual(serviceNode.rpcs[0].options.count, 2, "RPC should have 2 options")
        XCTAssertEqual(serviceNode.rpcs[0].options[0].name, "deprecated", "First option name should match")
        XCTAssertEqual(serviceNode.rpcs[0].options[1].name, "timeout", "Second option name should match")
        
        // Verify option values
        if case .identifier(let value) = serviceNode.rpcs[0].options[0].value {
            XCTAssertEqual(value, "true", "Deprecated option value should be true")
        } else {
            XCTFail("Expected identifier value")
        }
        
        if case .number(let value) = serviceNode.rpcs[0].options[1].value {
            XCTAssertEqual(value, 30.5, "Timeout option value should match")
        } else {
            XCTFail("Expected number value")
        }
    }
} 