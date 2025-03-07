import Foundation
@testable import SwiftProtoParser

/// A generator for creating random proto files for testing
struct TestProtoGenerator {
    /// Generates a random valid proto file
    /// - Parameters:
    ///   - messageCount: Number of messages to generate
    ///   - enumCount: Number of enums to generate
    ///   - serviceCount: Number of services to generate
    ///   - maxFieldsPerMessage: Maximum number of fields per message
    ///   - maxValuesPerEnum: Maximum number of values per enum
    ///   - maxMethodsPerService: Maximum number of methods per service
    ///   - includeOptions: Whether to include options
    ///   - includeExtensions: Whether to include extensions
    /// - Returns: A string containing a valid proto file
    static func generateValidProtoFile(
        messageCount: Int = 1,
        enumCount: Int = 1,
        serviceCount: Int = 1,
        maxFieldsPerMessage: Int = 5,
        maxValuesPerEnum: Int = 3,
        maxMethodsPerService: Int = 3,
        includeOptions: Bool = false,
        includeExtensions: Bool = false
    ) -> String {
        var proto = "syntax = \"proto3\";\n\n"
        proto += "package test;\n\n"
        
        // Add imports if needed
        if includeOptions {
            proto += "import \"google/protobuf/descriptor.proto\";\n\n"
        }
        
        // Add options if needed
        if includeOptions {
            proto += "option java_package = \"com.example.test\";\n\n"
        }
        
        // Add extensions if needed
        if includeExtensions && includeOptions {
            proto += generateExtensions()
        }
        
        // Add messages
        for i in 0..<messageCount {
            proto += generateMessage(
                index: i,
                maxFields: maxFieldsPerMessage,
                includeOptions: includeOptions
            )
            proto += "\n"
        }
        
        // Add enums
        for i in 0..<enumCount {
            proto += generateEnum(
                index: i,
                maxValues: maxValuesPerEnum,
                includeOptions: includeOptions
            )
            proto += "\n"
        }
        
        // Add services
        for i in 0..<serviceCount {
            proto += generateService(
                index: i,
                maxMethods: maxMethodsPerService,
                includeOptions: includeOptions
            )
            proto += "\n"
        }
        
        return proto
    }
    
    /// Generates a random invalid proto file
    /// - Parameter errorType: The type of error to introduce
    /// - Returns: A string containing an invalid proto file
    static func generateInvalidProtoFile(errorType: InvalidProtoType) -> String {
        switch errorType {
        case .missingSyntax:
            return "package test;\n\nmessage Test {\n  string name = 1;\n}\n"
        case .invalidSyntax:
            return "syntax = \"proto2\";\n\npackage test;\n\nmessage Test {\n  string name = 1;\n}\n"
        case .missingSemicolon:
            return "syntax = \"proto3\"\n\npackage test\n\nmessage Test {\n  string name = 1\n}\n"
        case .invalidFieldNumber:
            return "syntax = \"proto3\";\n\npackage test;\n\nmessage Test {\n  string name = 0;\n}\n"
        case .duplicateFieldNumber:
            return "syntax = \"proto3\";\n\npackage test;\n\nmessage Test {\n  string name = 1;\n  int32 id = 1;\n}\n"
        case .invalidEnumFirstValue:
            return "syntax = \"proto3\";\n\npackage test;\n\nenum Test {\n  UNKNOWN = 1;\n  VALUE = 2;\n}\n"
        case .missingBrace:
            return "syntax = \"proto3\";\n\npackage test;\n\nmessage Test {\n  string name = 1;\n"
        case .invalidImport:
            return "syntax = \"proto3\";\n\npackage test;\n\nimport \"nonexistent.proto\";\n\nmessage Test {\n  string name = 1;\n}\n"
        }
    }
    
    // MARK: - Private Helpers
    
    private static func generateMessage(index: Int, maxFields: Int, includeOptions: Bool) -> String {
        let fieldCount = Int.random(in: 1...maxFields)
        var message = "message Message\(index) {\n"
        
        // Add options if needed
        if includeOptions {
            message += "  option deprecated = true;\n"
        }
        
        // Add fields
        for i in 0..<fieldCount {
            message += "  \(generateField(index: i, includeOptions: includeOptions))\n"
        }
        
        // Add a nested message sometimes
        if Bool.random() {
            message += "\n  message NestedMessage {\n"
            message += "    string value = 1;\n"
            message += "  }\n"
            message += "\n  NestedMessage nested = \(fieldCount + 1);\n"
        }
        
        // Add a oneof sometimes
        if Bool.random() {
            message += "\n  oneof test_oneof {\n"
            message += "    string oneof_string = \(fieldCount + 2);\n"
            message += "    int32 oneof_int = \(fieldCount + 3);\n"
            message += "  }\n"
        }
        
        // Add a map sometimes
        if Bool.random() {
            message += "\n  map<string, string> metadata = \(fieldCount + 4);\n"
        }
        
        message += "}\n"
        return message
    }
    
    private static func generateField(index: Int, includeOptions: Bool) -> String {
        let types = ["string", "int32", "int64", "bool", "float", "double", "bytes"]
        let type = types.randomElement()!
        var field = "\(type) field\(index) = \(index + 1);"
        
        // Add options if needed
        if includeOptions {
            field = "\(type) field\(index) = \(index + 1) [deprecated = true];"
        }
        
        return field
    }
    
    private static func generateEnum(index: Int, maxValues: Int, includeOptions: Bool) -> String {
        let valueCount = Int.random(in: 1...maxValues)
        var enumDef = "enum Enum\(index) {\n"
        
        // Add options if needed
        if includeOptions {
            enumDef += "  option allow_alias = true;\n"
        }
        
        // First value must be 0 in proto3
        enumDef += "  UNKNOWN = 0;\n"
        
        // Add values
        for i in 1..<valueCount {
            if includeOptions {
                enumDef += "  VALUE\(i) = \(i) [deprecated = true];\n"
            } else {
                enumDef += "  VALUE\(i) = \(i);\n"
            }
        }
        
        enumDef += "}\n"
        return enumDef
    }
    
    private static func generateService(index: Int, maxMethods: Int, includeOptions: Bool) -> String {
        let methodCount = Int.random(in: 1...maxMethods)
        var service = "service Service\(index) {\n"
        
        // Add options if needed
        if includeOptions {
            service += "  option deprecated = true;\n"
        }
        
        // Add methods
        for i in 0..<methodCount {
            service += "  \(generateMethod(index: i, includeOptions: includeOptions))\n"
        }
        
        service += "}\n"
        return service
    }
    
    private static func generateMethod(index: Int, includeOptions: Bool) -> String {
        let streamingTypes = ["", "stream ", ""]
        let inputStreaming = streamingTypes.randomElement()!
        let outputStreaming = streamingTypes.randomElement()!
        
        var method = "rpc Method\(index)(\(inputStreaming)Message0) returns (\(outputStreaming)Message0);"
        
        // Add options if needed
        if includeOptions {
            method = "rpc Method\(index)(\(inputStreaming)Message0) returns (\(outputStreaming)Message0) { option deprecated = true; };"
        }
        
        return method
    }
    
    private static func generateExtensions() -> String {
        var extensions = "extend google.protobuf.FileOptions {\n"
        extensions += "  string my_file_option = 50000;\n"
        extensions += "}\n\n"
        
        extensions += "extend google.protobuf.MessageOptions {\n"
        extensions += "  int32 my_message_option = 50001;\n"
        extensions += "}\n\n"
        
        extensions += "extend google.protobuf.FieldOptions {\n"
        extensions += "  bool my_field_option = 50002;\n"
        extensions += "}\n\n"
        
        extensions += "option (my_file_option) = \"Hello, world!\";\n\n"
        
        return extensions
    }
}

/// Types of invalid proto files
enum InvalidProtoType {
    case missingSyntax
    case invalidSyntax
    case missingSemicolon
    case invalidFieldNumber
    case duplicateFieldNumber
    case invalidEnumFirstValue
    case missingBrace
    case invalidImport
} 