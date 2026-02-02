// MARK: - ProtoVersion

/// Represents the Protocol Buffers version supported by SwiftProtoParser.
///
/// SwiftProtoParser focuses on Protocol Buffers 3 (proto3) syntax only.
/// Proto2 is explicitly not supported to keep the implementation simple and focused.
public enum ProtoVersion: String, CaseIterable, Sendable {
  /// Protocol Buffers version 3 (proto3).
  case proto3 = "proto3"

  // Proto2 is explicitly not supported

  /// The default version used when no version is explicitly specified.
  public static let `default`: ProtoVersion = .proto3

  /// The syntax string as it appears in .proto files.
  public var syntaxString: String {
    return rawValue
  }

  /// Human-readable description of the version.
  public var description: String {
    switch self {
    case .proto3:
      return "Protocol Buffers 3 (proto3)"
    }
  }
}

// MARK: - ProtoVersion + CustomStringConvertible

extension ProtoVersion: CustomStringConvertible {}

// MARK: - ProtoVersion + Equatable, Hashable

extension ProtoVersion: Equatable, Hashable {}
