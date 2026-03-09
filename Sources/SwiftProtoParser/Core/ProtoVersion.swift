// MARK: - ProtoVersion

/// Represents the Protocol Buffers syntax version of a .proto file.
enum ProtoVersion: String, CaseIterable, Sendable {
  /// Protocol Buffers version 2 (proto2).
  case proto2 = "proto2"

  /// Protocol Buffers version 3 (proto3).
  case proto3 = "proto3"

  /// The default version used when no syntax declaration is present.
  ///
  /// Matches protoc behaviour: files without a syntax declaration are treated as proto2.
  static let `default`: ProtoVersion = .proto2

  /// The syntax string as it appears in .proto files.
  var syntaxString: String {
    return rawValue
  }

  /// The syntax field value written into `FileDescriptorProto.syntax`.
  ///
  /// - proto3 → `"proto3"`
  /// - proto2 → `""` (empty string — protoc verified: protoc emits `""` for proto2, not `"proto2"`)
  var descriptorSyntaxValue: String {
    switch self {
    case .proto3:
      return "proto3"
    case .proto2:
      return ""
    }
  }

  /// Human-readable description of the version.
  var description: String {
    switch self {
    case .proto2:
      return "Protocol Buffers 2 (proto2)"
    case .proto3:
      return "Protocol Buffers 3 (proto3)"
    }
  }
}

// MARK: - ProtoVersion + CustomStringConvertible

extension ProtoVersion: CustomStringConvertible {}

// MARK: - ProtoVersion + Equatable, Hashable

extension ProtoVersion: Equatable, Hashable {}
