import Foundation

/// Base protocol for all AST nodes
public protocol Node: AnyObject {
  /// The source location of this node
  var location: SourceLocation { get }

  /// Comments that appear before this node
  var leadingComments: [String] { get }

  /// Comment that appears on the same line after this node
  var trailingComment: String? { get }
}

/// Base protocol for all definition nodes (message, enum, service)
public protocol DefinitionNode: Node {
  /// The name of the definition
  var name: String { get }
}

/// Represents an import statement with its modifier
public class ImportNode: Node {
  public enum Modifier {
    case none
    case weak
    case `public`
  }

  public let location: SourceLocation
  public let leadingComments: [String]
  public let trailingComment: String?
  public let path: String
  public let modifier: Modifier

  public init(
    location: SourceLocation,
    leadingComments: [String] = [],
    trailingComment: String? = nil,
    path: String,
    modifier: Modifier = .none
  ) {
    self.location = location
    self.leadingComments = leadingComments
    self.trailingComment = trailingComment
    self.path = path
    self.modifier = modifier
  }
}

public typealias ImportModifier = ImportNode.Modifier

/// Represents a proto option
public class OptionNode: Node {
  public enum Value: Equatable {
    case string(String)
    case number(Double)
    case identifier(String)
    case array([Value])
    case map([String: Value])
  }

  public let location: SourceLocation
  public let leadingComments: [String]
  public let trailingComment: String?
  public let name: String
  public let value: Value

  public init(
    location: SourceLocation,
    leadingComments: [String] = [],
    trailingComment: String? = nil,
    name: String,
    value: Value
  ) {
    self.location = location
    self.leadingComments = leadingComments
    self.trailingComment = trailingComment
    self.name = name
    self.value = value
  }
}

/// Represents a field type in proto
public enum TypeNode: Equatable {
  /// Built-in scalar types
  case scalar(ScalarType)
  /// Message or enum type reference
  case named(String)
  /// Map type with key and value types
  indirect case map(key: ScalarType, value: TypeNode)

  /// All available scalar types in proto3
  public enum ScalarType: String {
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

    /// Whether this type can be used as a map key
    public var canBeMapKey: Bool {
      switch self {
      case .int32, .int64, .uint32, .uint64,
        .sint32, .sint64, .fixed32, .fixed64,
        .sfixed32, .sfixed64, .bool, .string:
        return true
      default:
        return false
      }
    }
  }
}

/// Represents a reserved statement in a message
public class ReservedNode: Node {
  public enum Range: Equatable {
    case single(Int)
    case range(start: Int, end: Int)
    case name(String)
  }

  public let location: SourceLocation
  public let leadingComments: [String]
  public let trailingComment: String?
  public let ranges: [Range]

  public init(
    location: SourceLocation,
    leadingComments: [String] = [],
    trailingComment: String? = nil,
    ranges: [Range]
  ) {
    self.location = location
    self.leadingComments = leadingComments
    self.trailingComment = trailingComment
    self.ranges = ranges
  }
}

/// Common protocol for nodes that can have options
public protocol OptionContainer {
  var options: [OptionNode] { get }
}

/// Common protocol for nodes that can have nested definitions
public protocol DefinitionContainer {
  var messages: [MessageNode] { get }
  var enums: [EnumNode] { get }
}

/// Extension to provide default implementations
extension Node {
  public var leadingComments: [String] { [] }
  public var trailingComment: String? { nil }
}

/// Extension to provide common functionality for definition nodes
extension DefinitionNode {
  /// The fully qualified name of this definition, including package name
  public func fullName(inPackage package: String?) -> String {
    if let package = package, !package.isEmpty {
      return "\(package).\(name)"
    }
    return name
  }
}

/// Extension to provide common functionality for definition containers
extension DefinitionContainer {
  /// Returns all nested definitions recursively
  public var allNestedDefinitions: [DefinitionNode] {
    var results: [DefinitionNode] = []
    results.append(contentsOf: messages as [DefinitionNode])
    results.append(contentsOf: enums as [DefinitionNode])

    // Recursively add nested definitions
    for message in messages {
      results.append(contentsOf: message.allNestedDefinitions)
    }

    return results
  }
}
