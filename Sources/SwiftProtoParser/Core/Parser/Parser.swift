import Foundation

/// Errors that can occur during parsing.
public enum ParserError: Error, CustomStringConvertible {
  case unexpectedToken(expected: TokenType, got: Token)
  case unexpectedEOF(expected: TokenType)
  case invalidSyntaxVersion(String)
  case invalidImport(String)
  case invalidFieldNumber(Int, location: SourceLocation)
  case invalidMapKeyType(String)
  case invalidMessageName(String)
  case invalidFieldName(String)
  case invalidEnumName(String)
  case invalidServiceName(String)
  case invalidRPCName(String)
  case invalidPackageName(String)
  case duplicateTypeName(String)
  case duplicatePackageName(String)
  case duplicateFieldNumber(Int, messageName: String)
  case custom(String)

  public var description: String {
    switch self {
    case .unexpectedToken(let expected, let got):
      return
        "Expected token \(expected) but got \(got) at \(got.location.line):\(got.location.column)"
    case .unexpectedEOF(let expected):
      return "Unexpected end of file, expected \(expected)"
    case .invalidImport(let importValue):
      return "Invalid import: \(importValue)"
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
    case .duplicateFieldNumber(let fieldNumber, let name):
      return "Duplicate field number: \(name) = \(fieldNumber)"
    case .custom(let message):
      return message
    }
  }
}

/// Parser for proto3 files.
public final class Parser {
  /// The lexer providing tokens.
  private let lexer: Lexer

  /// Current token under examination.
  private var currentToken: Token

  /// Next token to be examined.
  private var peekToken: Token

  /// Stack of package names for nested definitions.
  private var packageStack: [String] = []

  /// Set of used field numbers per message.
  private var usedFieldNumbers: Set<Int> = []

  /// Creates a new parser with the given lexer.
  /// - Parameter lexer: The lexer to use for tokenization.
  public init(lexer: Lexer) throws {
    self.lexer = lexer
    // Initialize current and peek tokens
    self.currentToken = try lexer.nextToken()
    self.peekToken = try lexer.nextToken()
  }

  /// Parses a complete proto file.
  /// - Parameter filePath: Optional path to the file being parsed.
  /// - Returns: A FileNode representing the parsed file.
  /// - Throws: ParserError if parsing fails.
  public func parseFile(filePath: String? = nil) throws -> FileNode {
    // Track the current location for error reporting
    let location = currentToken.location

    // Track leading comments at the file level
    let leadingComments = currentToken.leadingComments

    var syntax: String = "proto3"
    var package: String?

    // Parse syntax
    if currentToken.type == .syntax {
      syntax = try parseSyntax()
      if syntax != "proto3" {
        throw ParserError.invalidSyntaxVersion(syntax)
      }
    }

    // Parse file level elements
    var imports: [ImportNode] = []
    var options: [OptionNode] = []
    var definitions: [DefinitionNode] = []
    var extensions: [ExtendNode] = []

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

      case .extend:
        extensions.append(try parseExtend())

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

    // Create and return the file node
    return FileNode(
      location: location,
      leadingComments: leadingComments,
      syntax: syntax,
      package: package,
      filePath: filePath,
      imports: imports,
      options: options,
      definitions: definitions,
      extensions: extensions
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
    return first.isLowercase  // Must start with lowercase
      && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
  }

  private func parseImport() throws -> ImportNode {
    try expectToken(.import)

    var modifier: ImportNode.Modifier = .none
    if currentToken.type == .weak || currentToken.type == .public {
      modifier = currentToken.type == .weak ? .weak : .public
      try advanceToken()
    }

    guard currentToken.type == .stringLiteral else {
      throw ParserError.invalidImport("Expected import path string")
    }
    let path = currentToken.literal
    try advanceToken()

    guard currentToken.type == .semicolon else {
      throw ParserError.invalidImport("Missing semicolon after import")
    }
    try advanceToken()

    return ImportNode(
      location: currentToken.location,
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

    // Track reserved and used numbers and names
    var reservedNumbers = Set<Int>()
    var reservedNames = Set<String>()
    var usedFieldNumbers = Set<Int>()  // Track used field numbers

    while !check(.rightBrace) {
      switch currentToken.type {
      case .reserved:
        let reservedNode = try parseReserved()
        // Collect reserved numbers and names
        for range in reservedNode.ranges {
          switch range {
          case .single(let num):
            reservedNumbers.insert(num)
          case .range(let start, let end):
            reservedNumbers.formUnion(start...end)
          case .name(let name):
            reservedNames.insert(name)
          }
        }
        reserved.append(reservedNode)

      case .repeated, .optional, .map:
        let field = try parseField()
        // Check if field number is reserved
        if reservedNumbers.contains(field.number) {
          throw ParserError.invalidFieldNumber(field.number, location: field.location)
        }
        // Check if field name is reserved
        if reservedNames.contains(field.name) {
          throw ParserError.invalidFieldName(field.name)
        }
        // Check for duplicate field numbers
        if !usedFieldNumbers.insert(field.number).inserted {
          throw ParserError.duplicateFieldNumber(field.number, messageName: name)
        }
        fields.append(field)

      default:
        if isType(currentToken) {
          let field = try parseField()
          // Check if field number is reserved
          if reservedNumbers.contains(field.number) {
            throw ParserError.invalidFieldNumber(field.number, location: field.location)
          }
          // Check if field name is reserved
          if reservedNames.contains(field.name) {
            throw ParserError.invalidFieldName(field.name)
          }
          // Check for duplicate field numbers
          if !usedFieldNumbers.insert(field.number).inserted {
            throw ParserError.duplicateFieldNumber(field.number, messageName: name)
          }
          fields.append(field)
        }
        else {
          // Handle other message elements (options, nested types, etc.)
          switch currentToken.type {
          case .option:
            options.append(try parseOption())
          case .message:
            nestedMessages.append(try parseMessage())
          case .enum:
            nestedEnums.append(try parseEnum())
          case .oneof:
            oneofs.append(try parseOneof())
          default:
            throw ParserError.unexpectedToken(expected: .message, got: currentToken)
          }
        }
      }
    }

    try expectToken(.rightBrace)

    return MessageNode(
      location: currentToken.location,
      name: name,
      fields: fields,
      oneofs: oneofs,
      options: options,
      reserved: reserved,
      messages: nestedMessages,
      enums: nestedEnums
    )
  }

  //  private func parseEnumValue() throws -> EnumValueNode {
  //    let valueLocation = currentToken.location
  //    let leadingComments = currentToken.leadingComments
  //
  //    let name = try parseIdentifier()
  //    try expectToken(.equals)
  //
  //    guard case .intLiteral = currentToken.type else {
  //      throw ParserError.unexpectedToken(expected: .intLiteral, got: currentToken)
  //    }
  //    let number = Int(currentToken.literal) ?? 0
  //    try advanceToken()
  //
  //    var options: [OptionNode] = []
  //    if check(.leftBracket) {
  //      try expectToken(.leftBracket)
  //      repeat {
  //        options.append(try parseOption())
  //        if check(.comma) {
  //          try advanceToken()
  //        }
  //      } while !check(.rightBracket)
  //      try expectToken(.rightBracket)
  //    }
  //
  //    try expectToken(.semicolon)
  //
  //    return EnumValueNode(
  //      location: valueLocation,
  //      leadingComments: leadingComments,
  //      trailingComment: currentToken.trailingComment,
  //      name: name,
  //      number: number,
  //      options: options
  //    )
  //  }

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
        options.append(try parseFieldOption())
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
      }
      else {
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
    }
    else {
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
      }
      else if currentToken.type == .rpc {
        rpcs.append(try parseRPC())
      }
      else {
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
    }
    else {
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
    case .period:  // start of global custom type
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

  // MARK: - Option Parsing

  private func parseOption() throws -> OptionNode {
    try expectToken(.option)
    let optionLocation = currentToken.location

    // Check if this is a custom option with parentheses
    if check(.leftParen) {
      try expectToken(.leftParen)
      let extensionName = try parseQualifiedIdentifier()
      try expectToken(.rightParen)

      // Check for nested fields (dot notation)
      var nestedFields: [String] = []
      while check(.period) {
        try expectToken(.period)
        let fieldName = try parseIdentifier()
        nestedFields.append(fieldName)
      }

      try expectToken(.equals)
      let value = try parseOptionValue()
      try expectToken(.semicolon)

      // Create path parts for the custom option
      var pathParts: [OptionNode.PathPart] = [
        OptionNode.PathPart(name: extensionName, isExtension: true)
      ]

      // Add nested fields as path parts
      for field in nestedFields {
        pathParts.append(OptionNode.PathPart(name: field, isExtension: false))
      }

      // Create the option name string
      let optionName =
        "(\(extensionName))"
        + (nestedFields.isEmpty ? "" : "." + nestedFields.joined(separator: "."))

      return OptionNode(
        location: optionLocation,
        leadingComments: currentToken.leadingComments,
        trailingComment: currentToken.trailingComment,
        name: optionName,
        value: value,
        pathParts: pathParts,
        isCustomOption: true
      )
    }
    else {
      // Regular option
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
  }

  private func parseOptionName() throws -> String {
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

  // MARK: - Field Parsing

  private func parseFieldOption() throws -> OptionNode {
    // Handle custom options with parentheses
    if check(.leftParen) {
      try expectToken(.leftParen)
      let extensionName = try parseQualifiedIdentifier()
      try expectToken(.rightParen)

      // Check for nested fields (dot notation)
      var nestedFields: [String] = []
      while check(.period) {
        try expectToken(.period)
        let fieldName = try parseIdentifier()
        nestedFields.append(fieldName)
      }

      try expectToken(.equals)
      let value = try parseOptionValue()

      // Create path parts for the custom option
      var pathParts: [OptionNode.PathPart] = [
        OptionNode.PathPart(name: extensionName, isExtension: true)
      ]

      // Add nested fields as path parts
      for field in nestedFields {
        pathParts.append(OptionNode.PathPart(name: field, isExtension: false))
      }

      // Create the option name string
      let optionName =
        "(\(extensionName))"
        + (nestedFields.isEmpty ? "" : "." + nestedFields.joined(separator: "."))

      // Create a custom option with the extension name and any nested fields
      return OptionNode(
        location: currentToken.location,
        name: optionName,
        value: value,
        pathParts: pathParts,
        isCustomOption: true
      )
    }

    // Regular options
    let name = try parseIdentifier()
    try expectToken(.equals)
    let value = try parseOptionValue()

    return OptionNode(
      location: currentToken.location,
      name: name,
      value: value
    )
  }

  private func parseType() throws -> TypeNode {
    if currentToken.type == .map {
      return try parseMapType()
    }

    // Handle scalar types
    if let scalarType = parseScalarType() {
      try advanceToken()
      return .scalar(scalarType)
    }

    // For custom types, handle both normal and fully qualified paths
    // Allow starting with a period for fully qualified types
    if currentToken.type == .period || currentToken.type == .identifier
      || !currentToken.type.isAbsolutelyReserved
    {
      let typeName = try parseQualifiedIdentifier()
      return .named(typeName)
    }

    throw ParserError.unexpectedToken(expected: .identifier, got: currentToken)
  }

  private func parseMapType() throws -> TypeNode {
    try expectToken(.map)
    try expectToken(.leftAngle)

    // Parse key type
    guard let keyType = parseScalarType() else {
      throw ParserError.invalidMapKeyType(currentToken.literal)
    }

    // Validate key type
    switch keyType {
    case .int32, .int64, .uint32, .uint64, .sint32, .sint64,
      .fixed32, .fixed64, .sfixed32, .sfixed64, .bool, .string:
      // These types are valid for map keys
      break
    case .float, .double, .bytes:
      throw ParserError.invalidMapKeyType(String(describing: keyType))
    }

    try advanceToken()
    try expectToken(.comma)

    // Parse value type
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

  // MARK: - Oneof Parsing

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
      }
      else {
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

  // MARK: - Reserved Parsing

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
    }
    else {
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

  // MARK: - Identifier Parsing

  private func parseIdentifier() throws -> String {
    if .identifier == currentToken.type || !currentToken.type.isAbsolutelyReserved {
      let identifier = currentToken.literal
      try advanceToken()
      return identifier
    }

    throw ParserError.unexpectedToken(expected: .identifier, got: currentToken)
  }

  private func parseQualifiedIdentifier() throws -> String {
    var components: [String] = []

    // Handle absolute paths starting with dot
    if check(.period) {
      try advanceToken()
      components.append("")
    }

    // Parse first component
    components.append(try parseIdentifier())

    // Parse additional components
    while check(.period) {
      try advanceToken()  // consume dot
      components.append(try parseIdentifier())
    }

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

  //  /// Validates a field number according to proto3 rules
  //  private func validateFieldNumber(_ field: FieldNode, inMessage message: MessageNode) throws {
  //    let number = field.number
  //    let location = field.location
  //
  //    // Field numbers must be positive and in valid range
  //    guard number > 0 else {
  //      throw ParserError.invalidFieldNumber(number, location: location)
  //    }
  //
  //    guard number <= 536_870_911 else {
  //      throw ParserError.invalidFieldNumber(number, location: location)
  //    }
  //
  //    // Check reserved ranges (19000-19999 reserved for internal use)
  //    guard !(19000...19999).contains(number) else {
  //      throw ParserError.invalidFieldNumber(number, location: location)
  //    }
  //
  //    // Check for use of reserved field numbers in this message
  //    if message.reservedNumbers.contains(number) {
  //      throw ParserError.invalidFieldNumber(number, location: location)
  //    }
  //
  //    // Check for duplicate field numbers in this message
  //    if message.usedFieldNumbers.contains(number) {
  //      throw ParserError.duplicateFieldNumber(number, messageName: message.name)
  //    }
  //
  //    // Check for field numbers used in any oneof fields
  //    for oneof in message.oneofs {
  //      if oneof.fields.contains(where: { $0.number == number }) {
  //        throw ParserError.duplicateFieldNumber(number, messageName: message.name)
  //      }
  //    }
  //  }

  //  /// Validates reserved field numbers
  //  private func validateReservedNumbers(
  //    _ ranges: [ReservedNode.Range], inMessage message: MessageNode
  //  ) throws {
  //    var reservedNumbers = Set<Int>()
  //
  //    for range in ranges {
  //      switch range {
  //      case .single(let num):
  //        // Check valid range
  //        guard num > 0 && num <= 536_870_911 else {
  //          throw ParserError.invalidFieldNumber(num, location: message.location)
  //        }
  //
  //        // Check for duplicates in reserved numbers
  //        guard reservedNumbers.insert(num).inserted else {
  //          throw ParserError.duplicateFieldNumber(num, messageName: message.name)
  //        }
  //
  //      case .range(let start, let end):
  //        // Validate range bounds
  //        guard start > 0 && start <= 536_870_911 && end > 0 && end <= 536_870_911 else {
  //          throw ParserError.invalidFieldNumber(start, location: message.location)
  //        }
  //
  //        // Start must be less than end
  //        guard start < end else {
  //          throw ParserError.custom("Invalid field number range: end must be greater than start")
  //        }
  //
  //        // Check for overlaps with existing reserved numbers
  //        for num in start...end {
  //          guard reservedNumbers.insert(num).inserted else {
  //            throw ParserError.duplicateFieldNumber(num, messageName: message.name)
  //          }
  //        }
  //
  //      case .name:
  //        continue  // Names handled separately
  //      }
  //    }
  //  }

  /// Entry point for field parsing.
  private func parseField() throws -> FieldNode {
    let fieldLocation = currentToken.location
    let leadingComments = currentToken.leadingComments

    var isRepeated = false
    var isOptional = false

    if currentToken.type == .repeated {
      isRepeated = true
      try advanceToken()
    }
    else if currentToken.type == .optional {
      isOptional = true
      try advanceToken()
    }

    let type = try parseType()

    // Validate map cannot be repeated
    if isRepeated {
      if case .map = type {
        throw ParserError.repeatedMapField(currentToken.literal)
      }
    }

    // Parse field name
    let name: String
    if currentToken.type.isAbsolutelyReserved {
      throw ParserError.invalidFieldName(
        "Cannot use reserved keyword '\(currentToken.literal)' as field name"
      )
    }
    else if currentToken.type == .identifier {
      name = try parseIdentifier()
    }
    else {
      // Any other keyword can be used as identifier
      name = currentToken.literal
      try advanceToken()
    }

    try expectToken(.equals)

    // Parse and immediately validate field number
    guard case .intLiteral = currentToken.type,
      let number = Int(currentToken.literal)
    else {
      throw ParserError.unexpectedToken(expected: .intLiteral, got: currentToken)
    }

    try advanceToken()

    var options: [OptionNode] = []
    if currentToken.type == .leftBracket {
      try expectToken(.leftBracket)
      repeat {
        let option = try parseFieldOption()
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

  /// Parses an extend statement.
  private func parseExtend() throws -> ExtendNode {
    try expectToken(.extend)
    let extendLocation = currentToken.location
    let leadingComments = currentToken.leadingComments

    let typeName = try parseQualifiedIdentifier()
    try expectToken(.leftBrace)

    var fields: [FieldNode] = []

    while !check(.rightBrace) {
      if isType(currentToken) {
        // Parse extension field
        let field = try parseField()

        // Extension fields must have explicit field numbers
        if field.number <= 0 {
          throw ParserError.invalidFieldNumber(field.number, location: field.location)
        }

        // Check for valid extension field numbers (ranges 1-536,870,911 except 19000-19999)
        if field.number > 536_870_911 {
          throw ParserError.invalidFieldNumber(field.number, location: field.location)
        }

        if (19000...19999).contains(field.number) {
          throw ParserError.invalidFieldNumber(field.number, location: field.location)
        }

        fields.append(field)
      }
      else {
        throw ParserError.unexpectedToken(expected: .identifier, got: currentToken)
      }
    }

    try expectToken(.rightBrace)

    // Ensure there's at least one field in the extension
    if fields.isEmpty {
      throw ParserError.custom("Extension must contain at least one field")
    }

    return ExtendNode(
      location: extendLocation,
      leadingComments: leadingComments,
      trailingComment: currentToken.trailingComment,
      typeName: typeName,
      fields: fields
    )
  }
}
