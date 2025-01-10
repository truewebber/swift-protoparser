import Foundation
import SwiftProtobuf

/// Generates source code information for proto descriptors
public final class SourceInfoGenerator {
  /// Information about a location in the source
  private struct LocationInfo {
    let path: [Int32]
    let span: Google_Protobuf_SourceCodeInfo.Location.Span
    let leadingComments: String
    let trailingComments: String
    let leadingDetachedComments: [String]
  }

  /// The current path in the descriptor tree
  private var currentPath: [Int32] = []

  /// All collected locations
  private var locations: [LocationInfo] = []

  /// Initialize a new source info generator
  public init() {}

  /// Generates source code info for a file descriptor
  /// - Parameter file: The file node to process
  /// - Returns: Source code info for the file
  public func generateSourceInfo(_ file: FileNode) -> Google_Protobuf_SourceCodeInfo {
    // Reset state
    currentPath.removeAll()
    locations.removeAll()

    // Process file elements
    processFileNode(file)

    // Create source code info
    var sourceInfo = Google_Protobuf_SourceCodeInfo()
    sourceInfo.location = locations.map { info in
      var location = Google_Protobuf_SourceCodeInfo.Location()
      location.path = info.path
      location.span = [
        Int32(info.span.start),
        Int32(info.span.leadingCharacters),
        Int32(info.span.end),
        Int32(info.span.trailingCharacters),
      ]
      location.leadingComments = info.leadingComments
      location.trailingComments = info.trailingComments
      location.leadingDetachedComments = info.leadingDetachedComments
      return location
    }

    return sourceInfo
  }

  // MARK: - Processing Methods

  private func processFileNode(_ file: FileNode) {
    // Record file-level comments
    addLocation(for: file)

    // Process syntax
    withPath(4) {  // syntax = 4
      addLocation(at: file.location, comments: file.leadingComments)
    }

    // Process package
    if file.package != nil {
      withPath(2) {  // package = 2
        addLocation(at: file.location)
      }
    }

    // Process imports
    for (index, import_) in file.imports.enumerated() {
      withPath(3, Int32(index)) {  // imports = 3
        addLocation(for: import_)
      }
    }

    // Process options
    for (index, option) in file.options.enumerated() {
      withPath(8, Int32(index)) {  // options = 8
        addLocation(for: option)
      }
    }

    // Process messages
    for (index, message) in file.messages.enumerated() {
      withPath(4, Int32(index)) {  // messages = 4
        processMessageNode(message)
      }
    }

    // Process enums
    for (index, enum_) in file.enums.enumerated() {
      withPath(5, Int32(index)) {  // enums = 5
        processEnumNode(enum_)
      }
    }

    // Process services
    for (index, service) in file.services.enumerated() {
      withPath(6, Int32(index)) {  // services = 6
        processServiceNode(service)
      }
    }
  }

  private func processMessageNode(_ message: MessageNode) {
    addLocation(for: message)

    // Process fields
    for (index, field) in message.fields.enumerated() {
      withPath(2, Int32(index)) {  // fields = 2
        processFieldNode(field)
      }
    }

    // Process nested messages
    for (index, nestedMessage) in message.messages.enumerated() {
      withPath(3, Int32(index)) {  // nested_types = 3
        processMessageNode(nestedMessage)
      }
    }

    // Process nested enums
    for (index, nestedEnum) in message.enums.enumerated() {
      withPath(4, Int32(index)) {  // enum_types = 4
        processEnumNode(nestedEnum)
      }
    }

    // Process oneofs
    for (index, oneof) in message.oneofs.enumerated() {
      withPath(8, Int32(index)) {  // oneof_decl = 8
        processOneofNode(oneof)
      }
    }

    // Process options
    for (index, option) in message.options.enumerated() {
      withPath(7, Int32(index)) {  // options = 7
        addLocation(for: option)
      }
    }

    // Process reserved ranges and names
    for reserved in message.reserved {
      withPath(9) {  // reserved_range = 9
        addLocation(for: reserved)
      }
    }
  }

  private func processFieldNode(_ field: FieldNode) {
    addLocation(for: field)

    // Process options
    for (index, option) in field.options.enumerated() {
      withPath(8, Int32(index)) {  // options = 8
        addLocation(for: option)
      }
    }
  }

  private func processEnumNode(_ enumNode: EnumNode) {
    addLocation(for: enumNode)

    // Process values
    for (index, value) in enumNode.values.enumerated() {
      withPath(2, Int32(index)) {  // values = 2
        addLocation(for: value)

        // Process value options
        for (optIndex, option) in value.options.enumerated() {
          withPath(3, Int32(optIndex)) {  // options = 3
            addLocation(for: option)
          }
        }
      }
    }

    // Process options
    for (index, option) in enumNode.options.enumerated() {
      withPath(3, Int32(index)) {  // options = 3
        addLocation(for: option)
      }
    }
  }

  private func processServiceNode(_ service: ServiceNode) {
    addLocation(for: service)

    // Process methods
    for (index, method) in service.rpcs.enumerated() {
      withPath(2, Int32(index)) {  // methods = 2
        addLocation(for: method)

        // Process method options
        for (optIndex, option) in method.options.enumerated() {
          withPath(4, Int32(optIndex)) {  // options = 4
            addLocation(for: option)
          }
        }
      }
    }

    // Process options
    for (index, option) in service.options.enumerated() {
      withPath(3, Int32(index)) {  // options = 3
        addLocation(for: option)
      }
    }
  }

  private func processOneofNode(_ oneof: OneofNode) {
    addLocation(for: oneof)

    // Process options
    for (index, option) in oneof.options.enumerated() {
      withPath(1, Int32(index)) {  // options = 1
        addLocation(for: option)
      }
    }
  }

  // MARK: - Helper Methods

  private func withPath(_ numbers: Int32..., block: () -> Void) {
    let oldPath = currentPath
    currentPath.append(contentsOf: numbers)
    block()
    currentPath = oldPath
  }

  private func addLocation(
    for node: Node,
    detachedComments: [String] = []
  ) {
    addLocation(
      at: node.location,
      comments: node.leadingComments,
      trailingComment: node.trailingComment,
      detachedComments: detachedComments
    )
  }

  private func addLocation(
    at location: SourceLocation,
    comments: [String] = [],
    trailingComment: String? = nil,
    detachedComments: [String] = []
  ) {
    let span = Google_Protobuf_SourceCodeInfo.Location.Span(
      start: location.line,
      end: location.line,
      leadingCharacters: location.column,
      trailingCharacters: location.column
    )

    let info = LocationInfo(
      path: currentPath,
      span: span,
      leadingComments: comments.joined(separator: "\n"),
      trailingComments: trailingComment ?? "",
      leadingDetachedComments: detachedComments
    )

    locations.append(info)
  }
}

// MARK: - Span Extension

extension Google_Protobuf_SourceCodeInfo.Location {
  /// Represents a source code span
  struct Span {
    let start: Int
    let end: Int
    let leadingCharacters: Int
    let trailingCharacters: Int
  }
}
