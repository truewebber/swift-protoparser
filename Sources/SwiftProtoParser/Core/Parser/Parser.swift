import Foundation

/// Errors that can occur during parsing
public enum ParserError: Error, CustomStringConvertible {
  case unexpectedToken(expected: TokenType, got: Token)
  case unexpectedEOF(expected: TokenType)
  case invalidSyntaxVersion(String)
  case duplicatePackageName(String)
  case invalidFieldNumber(Int, location: SourceLocation)
  case invalidMapKeyType(String)
  case invalidMessageName(String)
  case invalidFieldName(String)
  case invalidEnumName(String)
  case invalidServiceName(String)
  case invalidRPCName(String)
  case invalidPackageName(String)
  case duplicateTypeName(String)
  case custom(String)

  public var description: String {
    switch self {
    case .unexpectedToken(let expected, let got):
      return
        "Expected token \(expected) but got \(got) at \(got.location.line):\(got.location.column)"
    case .unexpectedEOF(let expected):
      return "Unexpected end of file, expected \(expected)"
    case .invalidSyntaxVersion(let version):
      return "Invalid syntax version: \(version), expected 'proto3'"
    case .duplicatePackageName(let name):
      return "Duplicate package name: \(name)"
    case .invalidFieldNumber(let num, let loc):
      return "Invalid field number \(num) at \(loc.line):\(loc.column)"
    case .invalidMapKeyType(let type):
      return "Invalid map key type: \(type)"
    case .invalidMessageName(let name):
      return "Invalid message name: \(name)"
    case .invalidFieldName(let name):
      return "Invalid field name: \(name)"
    case .invalidEnumName(let name):
      return "Invalid enum name: \(name)"
    case .invalidServiceName(let name):
      return "Invalid service name: \(name)"
    case .invalidRPCName(let name):
      return "Invalid RPC name: \(name)"
    case .invalidPackageName(let name):
      return "Invalid package name: \(name)"
    case .duplicateTypeName(let name):
      return "Duplicate type name: \(name)"
    case .custom(let message):
      return message
    }
  }
}

/// Parser for proto3 files
public final class Parser {
  /// The lexer providing tokens
  private let lexer: Lexer

  /// Current token under examination
  private var currentToken: Token

  /// Next token to be examined
  private var peekToken: Token

  /// Stack of package names for nested definitions
  private var packageStack: [String] = []

  /// Set of used field numbers per message
  private var usedFieldNumbers: Set<Int> = []

  /// Creates a new parser with the given lexer
  /// - Parameter lexer: The lexer to use for tokenization
  public init(lexer: Lexer) throws {
    self.lexer = lexer
    // Initialize current and peek tokens
    self.currentToken = try lexer.nextToken()
    self.peekToken = try lexer.nextToken()
  }

  /// Parses a complete proto file
  /// - Returns: An AST representing the proto file
  public func parseFile() throws -> FileNode {
    var syntax: String?
    var package: String?
    var imports: [ImportNode] = []
    var options: [OptionNode] = []
    var definitions: [DefinitionNode] = []

    // Parse syntax
    if currentToken.type == .syntax {
      syntax = try parseSyntax()
      if syntax != "proto3" {
        throw ParserError.invalidSyntaxVersion(syntax ?? "unknown")
      }
    }

    // Parse file level elements
    while !isAtEnd {
      switch currentToken.type {
      case .package:
        if package != nil {
          throw ParserError.duplicatePackageName(currentToken.literal)
        }
        package = try parsePackage()

      case .import:
        imports.append(try parseImport())

      case .option:
        options.append(try parseOption())

      case .message:
        definitions.append(try parseMessage())

      case .enum:
        definitions.append(try parseEnum())

      case .service:
        definitions.append(try parseService())

      case .eof:
        break

      default:
        throw ParserError.unexpectedToken(expected: .package, got: currentToken)
      }
    }

    return FileNode(
      syntax: syntax ?? "proto3",
      package: package,
      imports: imports,
      options: options,
      definitions: definitions
    )
  }

  // MARK: - Private Parsing Methods

  private func parseSyntax() throws -> String {
    try expectToken(.syntax)
    try expectToken(.equals)
    let syntax = try parseStringLiteral()
    try expectToken(.semicolon)
    return syntax
  }

  private func parsePackage() throws -> String {
    try expectToken(.package)
    let components = try parsePackageIdentifiers()
    try expectToken(.semicolon)
    return components.joined(separator: ".")
  }
  
  private func parsePackageIdentifiers() throws -> [String] {
    var components: [String] = []
    
    // Parse first component
    let identifier = try parseIdentifier()
    if !isValidPackageComponent(identifier) {
      throw ParserError.invalidPackageName(identifier)
    }
    components.append(identifier)
    
    // Parse additional components
    while check(.period) {
      try expectToken(.period)
      if !check(.identifier) {
        throw ParserError.unexpectedToken(expected: .identifier, got: currentToken)
      }
      let identifier = try parseIdentifier()
      if !isValidPackageComponent(identifier) {
        throw ParserError.invalidPackageName(identifier)
      }
      components.append(identifier)
    }
    
    return components
  }
  
  private func isValidPackageComponent(_ name: String) -> Bool {
    guard let first = name.first else { return false }
    return first.isLowercase && // Must start with lowercase
    name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
  }

  private func parseImport() throws -> ImportNode {
    try expectToken(.import)

    var modifier: ImportModifier = .none
    if currentToken.isAny(of: .weak, .public) {
      modifier = currentToken.type == .weak ? .weak : .public
      try advanceToken()
    }

    let path = try parseStringLiteral()
    try expectToken(.semicolon)
    let importLocation = currentToken.location

    return ImportNode(
      location: importLocation,
      path: path,
      modifier: modifier
    )
  }

  private func parseMessage() throws -> MessageNode {
    try expectToken(.message)
    let name = try parseIdentifier()

    if !isValidTypeName(name) {
      throw ParserError.invalidMessageName(name)
    }

    try expectToken(.leftBrace)

    var fields: [FieldNode] = []
    var oneofs: [OneofNode] = []
    var options: [OptionNode] = []
    var reserved: [ReservedNode] = []
    var nestedMessages: [MessageNode] = []
    var nestedEnums: [EnumNode] = []

    // Clear field numbers for this message
    usedFieldNumbers.removeAll()

    while !check(.rightBrace) {
      switch currentToken.type {
      case .option:
        options.append(try parseOption())

      case .reserved:
        reserved.append(try parseReserved())

      case .oneof:
        oneofs.append(try parseOneof())

      case .message:
        nestedMessages.append(try parseMessage())

      case .enum:
        nestedEnums.append(try parseEnum())

      case .repeated, .optional, .map:
        fields.append(try parseField())

      default:
        if isType(currentToken) {
          fields.append(try parseField())
        } else {
          throw ParserError.unexpectedToken(expected: .message, got: currentToken)
        }
      }
    }

    try expectToken(.rightBrace)
    let messageLocation = currentToken.location

    return MessageNode(
      location: messageLocation,
      name: name,
      fields: fields,
      oneofs: oneofs,
      options: options,
      reserved: reserved,
      messages: nestedMessages,
      enums: nestedEnums
    )
  }

  private func parseEnumValue() throws -> EnumValueNode {
    let valueLocation = currentToken.location
    let leadingComments = currentToken.leadingComments

    let name = try parseIdentifier()
    try expectToken(.equals)

    guard case .intLiteral = currentToken.type else {
      throw ParserError.unexpectedToken(expected: .intLiteral, got: currentToken)
    }
    let number = Int(currentToken.literal) ?? 0
    try advanceToken()

    var options: [OptionNode] = []
    if check(.leftBracket) {
      try expectToken(.leftBracket)
      repeat {
        options.append(try parseOption())
        if check(.comma) {
          try advanceToken()
        }
      } while !check(.rightBracket)
      try expectToken(.rightBracket)
    }

    try expectToken(.semicolon)

    return EnumValueNode(
      location: valueLocation,
      leadingComments: leadingComments,
      trailingComment: currentToken.trailingComment,
      name: name,
      number: number,
      options: options
    )
  }

  private func parseEnum() throws -> EnumNode {
    try expectToken(.enum)
    let name = try parseIdentifier()

    if !isValidTypeName(name) {
      throw ParserError.invalidEnumName(name)
    }

    try expectToken(.leftBrace)

    var values: [EnumValueNode] = []
    var options: [OptionNode] = []

    while !check(.rightBrace) {
      if currentToken.type == .option {
        options.append(try parseOption())
      } else {
        values.append(try parseEnumValue())
      }
    }

    try expectToken(.rightBrace)
    let enumLocation = currentToken.location

    return EnumNode(
      location: enumLocation,
      name: name,
      values: values,
      options: options
    )
  }

  private func parseRPC() throws -> RPCNode {
    let rpcLocation = currentToken.location
    let leadingComments = currentToken.leadingComments

    try expectToken(.rpc)
    let name = try parseIdentifier()

    try expectToken(.leftParen)
    let clientStreaming = check(.stream)
    if clientStreaming {
      try advanceToken()
    }
    let inputType = try parseQualifiedIdentifier()
    try expectToken(.rightParen)

    try expectToken(.returns)
    try expectToken(.leftParen)
    let serverStreaming = check(.stream)
    if serverStreaming {
      try advanceToken()
    }
    let outputType = try parseQualifiedIdentifier()
    try expectToken(.rightParen)

    var options: [OptionNode] = []
    if check(.leftBrace) {
      try expectToken(.leftBrace)
      while !check(.rightBrace) {
        options.append(try parseOption())
      }
      try expectToken(.rightBrace)
    } else {
      try expectToken(.semicolon)
    }

    return RPCNode(
      location: rpcLocation,
      leadingComments: leadingComments,
      trailingComment: currentToken.trailingComment,
      name: name,
      inputType: inputType,
      outputType: outputType,
      clientStreaming: clientStreaming,
      serverStreaming: serverStreaming,
      options: options
    )
  }

  private func parseService() throws -> ServiceNode {
    try expectToken(.service)
    let name = try parseIdentifier()

    if !isValidTypeName(name) {
      throw ParserError.invalidServiceName(name)
    }

    try expectToken(.leftBrace)

    var rpcs: [RPCNode] = []
    var options: [OptionNode] = []

    while !check(.rightBrace) {
      if currentToken.type == .option {
        options.append(try parseOption())
      } else if currentToken.type == .rpc {
        rpcs.append(try parseRPC())
      } else {
        throw ParserError.unexpectedToken(expected: .rpc, got: currentToken)
      }
    }

    try expectToken(.rightBrace)
    let serviceLocation = currentToken.location

    return ServiceNode(
      location: serviceLocation,
      name: name,
      rpcs: rpcs,
      options: options
    )
  }

  // MARK: - Helper Methods

  private func advanceToken() throws {
    currentToken = peekToken
    peekToken = try lexer.nextToken()
  }

  private func expectToken(_ type: TokenType) throws {
    if currentToken.type == type {
      try advanceToken()
    } else {
      throw ParserError.unexpectedToken(expected: type, got: currentToken)
    }
  }

  private func check(_ type: TokenType) -> Bool {
    return currentToken.type == type
  }

  private func peek(_ type: TokenType) -> Bool {
    return peekToken.type == type
  }

  private var isAtEnd: Bool {
    return currentToken.type == .eof
  }

  private func isType(_ token: Token) -> Bool {
    switch token.type {
    case .double, .float, .int32, .int64, .uint32, .uint64,
      .sint32, .sint64, .fixed32, .fixed64, .sfixed32, .sfixed64,
      .bool, .string, .bytes, .identifier:
      return true
    default:
      return false
    }
  }

  private func isValidTypeName(_ name: String) -> Bool {
    let first = name.first ?? " "
    return first.isUppercase && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
  }

  private func isValidFieldName(_ name: String) -> Bool {
    let first = name.first ?? " "
    return (first.isLowercase || first == "_")
      && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
  }
}

// Add these methods to the existing Parser class

// MARK: - Option Parsing

extension Parser {
  private func parseOption() throws -> OptionNode {
    try expectToken(.option)
    let optionLocation = currentToken.location

    let name = try parseOptionName()
    try expectToken(.equals)
    let value = try parseOptionValue()
    try expectToken(.semicolon)

    return OptionNode(
      location: optionLocation,
      leadingComments: currentToken.leadingComments,
      trailingComment: currentToken.trailingComment,
      name: name,
      value: value
    )
  }

  private func parseOptionName() throws -> String {
    if currentToken.type == .leftParen {
      try expectToken(.leftParen)
      let name = try parseQualifiedIdentifier()
      try expectToken(.rightParen)
      return "(\(name))"
    }
    return try parseIdentifier()
  }

  private func parseOptionValue() throws -> OptionNode.Value {
    switch currentToken.type {
    case .stringLiteral:
      let value = currentToken.literal
      try advanceToken()
      return .string(value)

    case .intLiteral:
      let value = Double(currentToken.literal) ?? 0
      try advanceToken()
      return .number(value)

    case .floatLiteral:
      let value = Double(currentToken.literal) ?? 0
      try advanceToken()
      return .number(value)

    case .identifier:
      let value = currentToken.literal
      try advanceToken()
      return .identifier(value)

    case .leftBrace:
      return try parseOptionMap()

    case .leftBracket:
      return try parseOptionArray()

    default:
      throw ParserError.unexpectedToken(expected: .stringLiteral, got: currentToken)
    }
  }

  private func parseOptionMap() throws -> OptionNode.Value {
    try expectToken(.leftBrace)
    var map: [String: OptionNode.Value] = [:]

    while !check(.rightBrace) {
      let key = try parseIdentifier()
      try expectToken(.colon)
      let value = try parseOptionValue()
      map[key] = value

      if check(.comma) {
        try advanceToken()
      }
    }

    try expectToken(.rightBrace)
    return .map(map)
  }

  private func parseOptionArray() throws -> OptionNode.Value {
    try expectToken(.leftBracket)
    var array: [OptionNode.Value] = []

    while !check(.rightBracket) {
      let value = try parseOptionValue()
      array.append(value)

      if check(.comma) {
        try advanceToken()
      }
    }

    try expectToken(.rightBracket)
    return .array(array)
  }
}

// MARK: - Field Parsing

extension Parser {
  private func parseField() throws -> FieldNode {
    let fieldLocation = currentToken.location
    let leadingComments = currentToken.leadingComments

    var isRepeated = false
    var isOptional = false

    // Check for repeated or optional
    if currentToken.type == .repeated {
      isRepeated = true
      try advanceToken()
    } else if currentToken.type == .optional {
      isOptional = true
      try advanceToken()
    }

    // Parse type
    let type = try parseType()

    // Parse field name
    let name = try parseIdentifier()

    try expectToken(.equals)

    // Parse field number
    guard case .intLiteral = currentToken.type else {
      throw ParserError.unexpectedToken(expected: .intLiteral, got: currentToken)
    }
    let number = Int(currentToken.literal) ?? 0
    try advanceToken()

    // Parse field options if present
    var options: [OptionNode] = []
    if check(.leftBracket) {
      try expectToken(.leftBracket)
      repeat {
        let option = try parseOption()
        options.append(option)
        if check(.comma) {
          try advanceToken()
        }
      } while !check(.rightBracket)
      try expectToken(.rightBracket)
    }

    try expectToken(.semicolon)

    return FieldNode(
      location: fieldLocation,
      leadingComments: leadingComments,
      trailingComment: currentToken.trailingComment,
      name: name,
      type: type,
      number: number,
      isRepeated: isRepeated,
      isOptional: isOptional,
      options: options
    )
  }

  private func parseType() throws -> TypeNode {
    if currentToken.type == .map {
      return try parseMapType()
    }

    if let scalarType = parseScalarType() {
      try advanceToken()
      return .scalar(scalarType)
    }

    let typeName = try parseQualifiedIdentifier()
    return .named(typeName)
  }

  private func parseMapType() throws -> TypeNode {
    try expectToken(.map)
    try expectToken(.leftAngle)

    guard let keyType = parseScalarType() else {
      throw ParserError.invalidMapKeyType(currentToken.literal)
    }
    try advanceToken()

    try expectToken(.comma)

    let valueType = try parseType()

    try expectToken(.rightAngle)

    return .map(key: keyType, value: valueType)
  }

  private func parseScalarType() -> TypeNode.ScalarType? {
    switch currentToken.type {
    case .double: return .double
    case .float: return .float
    case .int32: return .int32
    case .int64: return .int64
    case .uint32: return .uint32
    case .uint64: return .uint64
    case .sint32: return .sint32
    case .sint64: return .sint64
    case .fixed32: return .fixed32
    case .fixed64: return .fixed64
    case .sfixed32: return .sfixed32
    case .sfixed64: return .sfixed64
    case .bool: return .bool
    case .string: return .string
    case .bytes: return .bytes
    default: return nil
    }
  }
}

// MARK: - Oneof Parsing

extension Parser {
  private func parseOneof() throws -> OneofNode {
    let oneofLocation = currentToken.location
    let leadingComments = currentToken.leadingComments

    try expectToken(.oneof)
    let name = try parseIdentifier()
    try expectToken(.leftBrace)

    var fields: [FieldNode] = []
    var options: [OptionNode] = []

    while !check(.rightBrace) {
      if currentToken.type == .option {
        options.append(try parseOption())
      } else {
        fields.append(try parseField())
      }
    }

    try expectToken(.rightBrace)

    return OneofNode(
      location: oneofLocation,
      leadingComments: leadingComments,
      trailingComment: currentToken.trailingComment,
      name: name,
      fields: fields,
      options: options
    )
  }
}

// MARK: - Reserved Parsing

extension Parser {
  private func parseReserved() throws -> ReservedNode {
    let reservedLocation = currentToken.location
    let leadingComments = currentToken.leadingComments

    try expectToken(.reserved)
    var ranges: [ReservedNode.Range] = []

    if case .stringLiteral = currentToken.type {
      // Parse reserved names
      while currentToken.type == .stringLiteral {
        let name = try parseStringLiteral()
        ranges.append(.name(name))

        if check(.comma) {
          try advanceToken()
        }
      }
    } else {
      // Parse reserved numbers
      while currentToken.type == .intLiteral {
        let range = try parseReservedRange()
        ranges.append(range)

        if check(.comma) {
          try advanceToken()
        }
      }
    }

    try expectToken(.semicolon)

    return ReservedNode(
      location: reservedLocation,
      leadingComments: leadingComments,
      trailingComment: currentToken.trailingComment,
      ranges: ranges
    )
  }

  private func parseReservedRange() throws -> ReservedNode.Range {
    guard case .intLiteral = currentToken.type else {
      throw ParserError.unexpectedToken(expected: .intLiteral, got: currentToken)
    }

    let start = Int(currentToken.literal) ?? 0
    try advanceToken()

    if currentToken.type == .to {
      try advanceToken()
      guard case .intLiteral = currentToken.type else {
        throw ParserError.unexpectedToken(expected: .intLiteral, got: currentToken)
      }
      let end = Int(currentToken.literal) ?? 0
      try advanceToken()
      return .range(start: start, end: end)
    }

    return .single(start)
  }
}

// MARK: - Identifier Parsing

extension Parser {
  private func parseIdentifier() throws -> String {
    guard case .identifier = currentToken.type else {
      throw ParserError.unexpectedToken(expected: .identifier, got: currentToken)
    }

    let identifier = currentToken.literal
    try advanceToken()
    return identifier
  }

  private func parseQualifiedIdentifier() throws -> String {
    var components: [String] = []

    repeat {
      components.append(try parseIdentifier())
      if check(.period) {
        try advanceToken()
      }
    } while check(.identifier)

    return components.joined(separator: ".")
  }

  private func parseStringLiteral() throws -> String {
    guard case .stringLiteral = currentToken.type else {
      throw ParserError.unexpectedToken(expected: .stringLiteral, got: currentToken)
    }

    let literal = currentToken.literal
    try advanceToken()
    return literal
  }
}
