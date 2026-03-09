import Foundation

/// Root AST node representing a complete .proto file.
struct ProtoAST {
  /// Protocol Buffer syntax version (proto3 only supported).
  let syntax: ProtoVersion

  /// Package declaration.
  let package: String?

  /// Import statements.
  let imports: [ImportNode]

  /// Top-level options.
  let options: [OptionNode]

  /// Message definitions.
  let messages: [MessageNode]

  /// Enum definitions.
  let enums: [EnumNode]

  /// Service definitions.
  let services: [ServiceNode]

  /// Extend statements for custom options (proto3 only).
  let extends: [ExtendNode]

  init(
    syntax: ProtoVersion,
    package: String? = nil,
    imports: [ImportNode] = [],
    options: [OptionNode] = [],
    messages: [MessageNode] = [],
    enums: [EnumNode] = [],
    services: [ServiceNode] = [],
    extends: [ExtendNode] = []
  ) {
    self.syntax = syntax
    self.package = package
    self.imports = imports
    self.options = options
    self.messages = messages
    self.enums = enums
    self.services = services
    self.extends = extends
  }
}

// MARK: - Equatable
extension ProtoAST: Equatable {
  static func == (lhs: ProtoAST, rhs: ProtoAST) -> Bool {
    return lhs.syntax == rhs.syntax && lhs.package == rhs.package && lhs.imports == rhs.imports
      && lhs.options == rhs.options && lhs.messages == rhs.messages && lhs.enums == rhs.enums
      && lhs.services == rhs.services && lhs.extends == rhs.extends
  }
}

// MARK: - CustomStringConvertible
extension ProtoAST: CustomStringConvertible {
  var description: String {
    var components: [String] = []

    components.append("syntax = \"\(syntax)\";")

    if let package = package {
      components.append("package \(package);")
    }

    for importNode in imports {
      components.append(importNode.description)
    }

    for option in options {
      components.append(option.description)
    }

    for enumNode in enums {
      components.append(enumNode.description)
    }

    for message in messages {
      components.append(message.description)
    }

    for service in services {
      components.append(service.description)
    }

    for extend in extends {
      components.append(extend.description)
    }

    return components.joined(separator: "\n\n")
  }
}
