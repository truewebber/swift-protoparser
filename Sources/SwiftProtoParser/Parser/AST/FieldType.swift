import Foundation

/// Represents the type of a protobuf field
public indirect enum FieldType: Equatable {
    // Scalar types
    case double
    case float
    case int32
    case int64
    case uint32
    case uint64
    case sint32
    case sint64
    case fixed32
    case fixed64
    case sfixed32
    case sfixed64
    case bool
    case string
    case bytes
    
    // Complex types
    case message(String)    // message type name
    case enumType(String)   // enum type name
    case map(key: FieldType, value: FieldType)  // map<key_type, value_type>
    
    /// Returns true if this is a scalar type
    public var isScalar: Bool {
        switch self {
        case .double, .float, .int32, .int64, .uint32, .uint64,
             .sint32, .sint64, .fixed32, .fixed64, .sfixed32, .sfixed64,
             .bool, .string, .bytes:
            return true
        case .message, .enumType, .map:
            return false
        }
    }
    
    /// Returns true if this is a numeric type
    public var isNumeric: Bool {
        switch self {
        case .double, .float, .int32, .int64, .uint32, .uint64,
             .sint32, .sint64, .fixed32, .fixed64, .sfixed32, .sfixed64:
            return true
        case .bool, .string, .bytes, .message, .enumType, .map:
            return false
        }
    }
    
    /// Returns the string representation of the type as it would appear in a .proto file
    public var protoTypeName: String {
        switch self {
        case .double: return "double"
        case .float: return "float"
        case .int32: return "int32"
        case .int64: return "int64"
        case .uint32: return "uint32"
        case .uint64: return "uint64"
        case .sint32: return "sint32"
        case .sint64: return "sint64"
        case .fixed32: return "fixed32"
        case .fixed64: return "fixed64"
        case .sfixed32: return "sfixed32"
        case .sfixed64: return "sfixed64"
        case .bool: return "bool"
        case .string: return "string"
        case .bytes: return "bytes"
        case .message(let name): return name
        case .enumType(let name): return name
        case .map(let key, let value): return "map<\(key.protoTypeName), \(value.protoTypeName)>"
        }
    }
}

// MARK: - CustomStringConvertible
extension FieldType: CustomStringConvertible {
    public var description: String {
        return protoTypeName
    }
}
