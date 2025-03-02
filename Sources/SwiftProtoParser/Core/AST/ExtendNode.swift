import Foundation

/// Represents an extend statement in a proto file
public final class ExtendNode: Node {
  /// The source location of this node
  public let location: SourceLocation

  /// Comments that appear before this node
  public let leadingComments: [String]

  /// Comment that appears on the same line after this node
  public let trailingComment: String?

  /// The name of the type being extended
  public let typeName: String

  /// The fields being added to the extended type
  public let fields: [FieldNode]

  /// Creates a new extend node
  /// - Parameters:
  ///   - location: The source location of the extend statement
  ///   - leadingComments: Any comments that appear before the extend statement
  ///   - trailingComment: Any comment that appears after the extend statement on the same line
  ///   - typeName: The name of the type being extended
  ///   - fields: The fields being added to the extended type
  public init(
    location: SourceLocation,
    leadingComments: [String] = [],
    trailingComment: String? = nil,
    typeName: String,
    fields: [FieldNode]
  ) {
    self.location = location
    self.leadingComments = leadingComments
    self.trailingComment = trailingComment
    self.typeName = typeName
    self.fields = fields
  }
}

// MARK: - CustomStringConvertible

extension ExtendNode: CustomStringConvertible {
  public var description: String {
    return "ExtendNode(typeName: \(typeName), fields: \(fields))"
  }
}
