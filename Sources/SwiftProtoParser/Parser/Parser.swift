import Foundation

/// Wrapper for multiple parser errors to conform to Error protocol.
public struct ParserErrors: Error {
  public let errors: [ParserError]

  public init(_ errors: [ParserError]) {
    self.errors = errors
  }
}

/// Recursive descent parser for Protocol Buffers source code.
///
/// This parser takes a stream of tokens from the lexer and constructs.
/// an Abstract Syntax Tree (AST) representing the structure of the .proto file.
public final class Parser {

  // MARK: - Private Properties

  /// The parser state managing token stream and errors.
  private var state: ParserState

  // MARK: - Initialization

  /// Creates a new parser with the given tokens.
  ///
  /// - Parameter tokens: The array of tokens to parse.
  public init(tokens: [Token]) {
    self.state = ParserState(tokens: tokens)
  }

  // MARK: - Public Methods

  /// Parses the tokens into a Protocol Buffers AST.
  ///
  /// - Returns: A `Result` containing either the parsed AST or parser errors.
  public func parse() -> Result<ProtoAST, ParserErrors> {
    do {
      let ast = try parseProtoFile()

      if state.errors.isEmpty {
        // Resolve enum field types (convert .message to .enumType where appropriate)
        let resolver = EnumFieldTypeResolver(ast: ast)
        let resolvedAST = resolver.resolveFieldTypes()

        return .success(resolvedAST)
      }
      else {
        return .failure(ParserErrors(state.errors))
      }
    }
    catch {
      // Add any uncaught errors
      if let parserError = error as? ParserError {
        state.addError(parserError)
      }
      else {
        state.addError(.internalError("Unexpected error: \(error)"))
      }
      return .failure(ParserErrors(state.errors))
    }
  }

  // MARK: - Private Parsing Methods

  /// Parses a complete .proto file.
  private func parseProtoFile() throws -> ProtoAST {
    var syntax: ProtoVersion = .proto3  // Default
    var package: String?
    var imports: [String] = []
    var options: [OptionNode] = []
    var messages: [MessageNode] = []
    var enums: [EnumNode] = []
    var services: [ServiceNode] = []
    var extends: [ExtendNode] = []

    // Skip initial whitespace and comments
    skipIgnorableTokens()

    // Parse syntax declaration (required)
    syntax = try parseSyntaxDeclaration()

    // Parse top-level elements
    while !state.isAtEnd {
      let beforeIndex = state.currentIndex
      skipIgnorableTokens()

      guard let token = state.currentToken else { break }

      switch token.type {
      case .keyword(let keyword):
        switch keyword {
        case .package:
          if package != nil {
            state.addError(.duplicateElement("package", at: token.position))
          }
          else {
            package = try parsePackageDeclaration()
          }

        case .import:
          let importPath = try parseImportDeclaration()
          imports.append(importPath)

        case .option:
          let option = try parseOptionDeclaration()
          options.append(option)

        case .message:
          let message = try parseMessageDeclaration()
          messages.append(message)

        case .enum:
          let enumDecl = try parseEnumDeclaration()
          enums.append(enumDecl)

        case .service:
          let service = try parseServiceDeclaration()
          services.append(service)

        case .extend:
          let extend = try parseExtendDeclaration()
          extends.append(extend)

        default:
          state.addError(.unexpectedToken(token, expected: "top-level declaration"))
          state.advance()
          state.synchronize()
        }

      case .eof:
        break

      default:
        state.addError(.unexpectedToken(token, expected: "top-level declaration"))
        state.synchronize()
      }

      // Safety check to prevent infinite loop
      if state.currentIndex == beforeIndex {
        state.advance()  // Force advance to break potential infinite loop
      }
    }

    return ProtoAST(
      syntax: syntax,
      package: package,
      imports: imports,
      options: options,
      messages: messages,
      enums: enums,
      services: services,
      extends: extends
    )
  }

  /// Parses the syntax declaration: syntax = "proto3";.
  private func parseSyntaxDeclaration() throws -> ProtoVersion {
    _ = state.expectKeyword(.syntax)
    skipIgnorableTokens()
    _ = state.expectSymbol("=")
    skipIgnorableTokens()

    guard let token = state.currentToken,
      case .stringLiteral(let syntaxString) = token.type
    else {
      state.addError(
        .unexpectedToken(
          state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
          expected: "syntax string"
        )
      )
      return .proto3
    }

    state.advance()
    skipIgnorableTokens()
    _ = state.expectSymbol(";")

    // Handle proto2 gracefully - convert to proto3 silently
    if syntaxString == "proto2" {
      // Note: We could log a warning here in a real implementation
      return .proto3
    }

    guard let version = ProtoVersion(rawValue: syntaxString) else {
      state.addError(
        .invalidSyntax(
          "Unsupported syntax: \(syntaxString), defaulting to proto3",
          line: token.position.line,
          column: token.position.column
        )
      )
      return .proto3
    }

    return version
  }

  /// Parses a package declaration: package com.example;.
  private func parsePackageDeclaration() throws -> String {
    _ = state.expectKeyword(.package)
    skipIgnorableTokens()

    var packageComponents: [String] = []

    // Parse dotted package name
    repeat {
      // Accept both identifiers and keywords as package components
      let component: String
      if let identifier = state.identifierName {
        component = identifier
      }
      else if let token = state.currentToken,
        case .keyword(let keyword) = token.type
      {
        component = keyword.rawValue
      }
      else {
        state.addError(
          .unexpectedToken(
            state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
            expected: "package identifier"
          )
        )
        return ""
      }

      packageComponents.append(component)
      state.advance()
      skipIgnorableTokens()

      if state.checkSymbol(".") {
        state.advance()  // consume "."
        skipIgnorableTokens()
      }
      else {
        break
      }
    } while !state.isAtEnd

    _ = state.expectSymbol(";")

    return packageComponents.joined(separator: ".")
  }

  /// Parses an import declaration: import "path/to/file.proto";.
  private func parseImportDeclaration() throws -> String {
    _ = state.expectKeyword(.import)
    skipIgnorableTokens()

    // Handle optional "public" or "weak" modifiers
    if state.checkKeyword(.public) || state.checkKeyword(.weak) {
      state.advance()  // Skip modifier for now
      skipIgnorableTokens()
    }

    guard let importPath = state.stringLiteralValue else {
      state.addError(
        .unexpectedToken(
          state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
          expected: "import path string"
        )
      )
      return ""
    }

    state.advance()
    skipIgnorableTokens()
    _ = state.expectSymbol(";")

    return importPath
  }

  /// Parses an option declaration: option java_package = "com.example";.
  private func parseOptionDeclaration() throws -> OptionNode {
    _ = state.expectKeyword(.option)
    skipIgnorableTokens()

    // Parse option name (can be custom option in parentheses)
    let isCustom: Bool
    let optionName: String

    if state.checkSymbol("(") {
      isCustom = true
      state.advance()  // consume "("
      skipIgnorableTokens()

      guard let customName = state.identifierName else {
        state.addError(
          .unexpectedToken(
            state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
            expected: "custom option name"
          )
        )
        return OptionNode(name: "", value: .string(""))
      }

      optionName = customName
      state.advance()
      skipIgnorableTokens()
      _ = state.expectSymbol(")")
    }
    else {
      isCustom = false
      guard let name = state.identifierName else {
        state.addError(
          .unexpectedToken(
            state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
            expected: "option name"
          )
        )
        return OptionNode(name: "", value: .string(""))
      }

      optionName = name
      state.advance()
    }

    skipIgnorableTokens()
    _ = state.expectSymbol("=")
    skipIgnorableTokens()

    // Parse option value
    let value = try parseOptionValue()

    skipIgnorableTokens()
    _ = state.expectSymbol(";")

    return OptionNode(name: optionName, value: value, isCustom: isCustom)
  }

  /// Parses an option value (string, number, boolean, or identifier).
  private func parseOptionValue() throws -> OptionValue {
    guard let token = state.currentToken else {
      state.addError(.unexpectedEndOfInput(expected: "option value"))
      return .string("")
    }

    let value: OptionValue

    switch token.type {
    case .stringLiteral(let str):
      value = .string(str)

    case .integerLiteral(let int):
      value = .number(Double(int))

    case .floatLiteral(let float):
      value = .number(float)

    case .boolLiteral(let bool):
      value = .boolean(bool)

    case .identifier(let id):
      value = .identifier(id)

    default:
      state.addError(.unexpectedToken(token, expected: "option value"))
      return .string("")
    }

    state.advance()
    return value
  }

  /// Parses a message declaration.
  private func parseMessageDeclaration() throws -> MessageNode {
    _ = state.expectKeyword(.message)
    skipIgnorableTokens()

    guard let messageName = state.identifierName else {
      state.addError(
        .unexpectedToken(
          state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
          expected: "message name"
        )
      )
      return MessageNode(name: "")
    }

    state.advance()
    skipIgnorableTokens()
    _ = state.expectSymbol("{")

    var fields: [FieldNode] = []
    var nestedMessages: [MessageNode] = []
    var nestedEnums: [EnumNode] = []
    var oneofGroups: [OneofNode] = []
    var options: [OptionNode] = []
    var reservedNumbers: [Int32] = []
    var reservedNames: [String] = []

    // Parse message body
    while !state.isAtEnd {
      skipIgnorableTokens()

      if state.checkSymbol("}") {
        break
      }

      guard let token = state.currentToken else { break }

      switch token.type {
      case .keyword(let keyword):
        switch keyword {
        case .message:
          let nestedMessage = try parseMessageDeclaration()
          nestedMessages.append(nestedMessage)

        case .enum:
          let nestedEnum = try parseEnumDeclaration()
          nestedEnums.append(nestedEnum)

        case .oneof:
          let oneof = try parseOneofDeclaration()
          oneofGroups.append(oneof)

        case .option:
          let option = try parseOptionDeclaration()
          options.append(option)

        case .reserved:
          let (numbers, names) = try parseReservedDeclaration()
          reservedNumbers.append(contentsOf: numbers)
          reservedNames.append(contentsOf: names)

        case .repeated, .optional:
          let field = try parseFieldDeclaration()
          fields.append(field)

        case .map:
          // Map field type
          let field = try parseFieldDeclaration()
          fields.append(field)

        default:
          // Other keywords are not valid message elements
          state.addError(.unexpectedToken(token, expected: "message element"))
          state.advance()
          state.synchronize()
        }

      case .identifier:
        // Regular field
        let field = try parseFieldDeclaration()
        fields.append(field)

      default:
        state.addError(.unexpectedToken(token, expected: "message element"))
        state.synchronize()
      }
    }

    _ = state.expectSymbol("}")

    return MessageNode(
      name: messageName,
      fields: fields,
      nestedMessages: nestedMessages,
      nestedEnums: nestedEnums,
      oneofGroups: oneofGroups,
      options: options,
      reservedNumbers: reservedNumbers,
      reservedNames: reservedNames
    )
  }

  /// Parses a field declaration.
  private func parseFieldDeclaration() throws -> FieldNode {
    // Parse optional field label
    var label: FieldLabel = .singular

    if state.checkKeyword(.repeated) {
      label = .repeated
      state.advance()
      skipIgnorableTokens()
    }
    else if state.checkKeyword(.optional) {
      label = .optional
      state.advance()
      skipIgnorableTokens()
    }

    // Parse field type
    let fieldType = try parseFieldType()
    skipIgnorableTokens()

    // Parse field name (allow keywords as field names in certain contexts)
    let fieldName: String
    if let identifier = state.identifierName {
      fieldName = identifier
    }
    else if let token = state.currentToken,
      case .keyword(let keyword) = token.type,
      isAllowedAsFieldName(keyword)
    {
      // Allow certain keywords as field names (protobuf allows this)
      fieldName = keyword.rawValue
    }
    else {
      state.addError(
        .unexpectedToken(
          state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
          expected: "field name"
        )
      )
      return FieldNode(name: "", type: .string, number: 1)
    }

    state.advance()
    skipIgnorableTokens()
    _ = state.expectSymbol("=")
    skipIgnorableTokens()

    // Parse field number
    guard let fieldNumberInt = state.integerLiteralValue else {
      state.addError(
        .unexpectedToken(
          state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
          expected: "field number"
        )
      )
      return FieldNode(name: fieldName, type: fieldType, number: 1)
    }

    let fieldNumber = Int32(fieldNumberInt)
    state.advance()
    skipIgnorableTokens()

    // Parse optional field options
    var options: [OptionNode] = []
    if state.checkSymbol("[") {
      options = try parseFieldOptions()
      skipIgnorableTokens()
    }

    _ = state.expectSymbol(";")

    // Validate field number
    if fieldNumber <= 0 || fieldNumber > 536_870_911 {
      state.addError(.fieldNumberOutOfRange(fieldNumber, at: state.currentPosition))
    }
    else if (19000...19999).contains(fieldNumber) {
      state.addError(.reservedFieldNumber(fieldNumber, at: state.currentPosition))
    }

    return FieldNode(
      name: fieldName,
      type: fieldType,
      number: fieldNumber,
      label: label,
      options: options
    )
  }

  /// Parses a field type (scalar, message, enum, qualified type, or map).
  private func parseFieldType() throws -> FieldType {
    guard let token = state.currentToken else {
      state.addError(.unexpectedEndOfInput(expected: "field type"))
      return .string
    }

    switch token.type {
    case .keyword(let keyword):
      // Handle map type
      if keyword == .map {
        return try parseMapType()
      }

      // Other keywords are not valid field types
      state.addError(.unexpectedToken(token, expected: "field type"))
      state.advance()
      return .string

    case .identifier(let typeName):
      // Check if this identifier is actually a scalar type
      switch typeName {
      case "double":
        state.advance()
        return .double
      case "float":
        state.advance()
        return .float
      case "int32":
        state.advance()
        return .int32
      case "int64":
        state.advance()
        return .int64
      case "uint32":
        state.advance()
        return .uint32
      case "uint64":
        state.advance()
        return .uint64
      case "sint32":
        state.advance()
        return .sint32
      case "sint64":
        state.advance()
        return .sint64
      case "fixed32":
        state.advance()
        return .fixed32
      case "fixed64":
        state.advance()
        return .fixed64
      case "sfixed32":
        state.advance()
        return .sfixed32
      case "sfixed64":
        state.advance()
        return .sfixed64
      case "bool":
        state.advance()
        return .bool
      case "string":
        state.advance()
        return .string
      case "bytes":
        state.advance()
        return .bytes
      default:
        // Not a scalar type - could be message/enum or qualified type
        return try parseQualifiedTypeName(firstPart: typeName)
      }

    default:
      state.addError(.unexpectedToken(token, expected: "field type"))
      state.advance()
      return .string
    }
  }

  /// Parses a qualified type name like 'Message' or 'google.protobuf.Timestamp'.
  private func parseQualifiedTypeName(firstPart: String) throws -> FieldType {
    state.advance()  // consume first identifier

    var qualifiedName = firstPart

    // Check if this is a qualified name (contains dots)
    while state.checkSymbol(".") {
      state.advance()  // consume "."
      skipIgnorableTokens()

      guard let nextPart = state.identifierName else {
        state.addError(
          .unexpectedToken(
            state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
            expected: "qualified type name part"
          )
        )

        // CRITICAL FIX: Proper synchronization after qualified type parsing error
        // We need to backtrack to a stable state. If we encountered an unexpected token
        // while parsing a qualified type, it's likely that we hit a keyword that starts
        // a new message element (like 'message', 'enum', etc.)
        // Don't consume the token - let the outer parser handle it
        break
      }

      qualifiedName += "." + nextPart
      state.advance()  // consume next identifier
    }

    // If it contains dots, it's a qualified type, otherwise a simple message type
    if qualifiedName.contains(".") {
      return .qualifiedType(qualifiedName)
    }
    else {
      return .message(qualifiedName)
    }
  }

  /// Parses a map field type: map<key_type, value_type>.
  private func parseMapType() throws -> FieldType {
    _ = state.expectKeyword(.map)
    skipIgnorableTokens()
    _ = state.expectSymbol("<")
    skipIgnorableTokens()

    let keyType = try parseFieldType()
    skipIgnorableTokens()
    _ = state.expectSymbol(",")
    skipIgnorableTokens()
    let valueType = try parseFieldType()
    skipIgnorableTokens()

    _ = state.expectSymbol(">")

    return .map(key: keyType, value: valueType)
  }

  /// Parses field options: [option1 = value1, option2 = value2].
  private func parseFieldOptions() throws -> [OptionNode] {
    _ = state.expectSymbol("[")
    skipIgnorableTokens()

    var options: [OptionNode] = []

    repeat {
      skipIgnorableTokens()

      // Parse option name
      let isCustom: Bool
      let optionName: String

      if state.checkSymbol("(") {
        isCustom = true
        state.advance()  // consume "("
        skipIgnorableTokens()

        guard let customName = state.identifierName else {
          state.addError(
            .unexpectedToken(
              state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
              expected: "custom option name"
            )
          )
          break
        }

        optionName = customName
        state.advance()
        skipIgnorableTokens()
        _ = state.expectSymbol(")")
      }
      else {
        isCustom = false
        guard let name = state.identifierName else {
          state.addError(
            .unexpectedToken(
              state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
              expected: "option name"
            )
          )
          break
        }

        optionName = name
        state.advance()
      }

      skipIgnorableTokens()
      _ = state.expectSymbol("=")
      skipIgnorableTokens()
      let value = try parseOptionValue()

      options.append(OptionNode(name: optionName, value: value, isCustom: isCustom))

      skipIgnorableTokens()
      if state.checkSymbol(",") {
        state.advance()  // consume ","
        skipIgnorableTokens()
      }
      else {
        break
      }
    } while !state.isAtEnd

    skipIgnorableTokens()
    _ = state.expectSymbol("]")

    return options
  }

  /// Parses an enum declaration.
  private func parseEnumDeclaration() throws -> EnumNode {
    _ = state.expectKeyword(.enum)
    skipIgnorableTokens()

    guard let enumName = state.identifierName else {
      state.addError(
        .unexpectedToken(
          state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
          expected: "enum name"
        )
      )
      return EnumNode(name: "")
    }

    state.advance()
    skipIgnorableTokens()
    _ = state.expectSymbol("{")

    var values: [EnumValueNode] = []
    var options: [OptionNode] = []

    // Parse enum body
    while !state.isAtEnd {
      skipIgnorableTokens()

      // Check for end of enum after skipping ignorable tokens
      if state.checkSymbol("}") {
        break
      }

      guard let token = state.currentToken else {
        break
      }

      switch token.type {
      case .keyword(.option):
        let option = try parseOptionDeclaration()
        options.append(option)

      case .identifier:
        let enumValue = try parseEnumValue()
        values.append(enumValue)

      default:
        state.addError(.unexpectedToken(token, expected: "enum element"))
        state.advance()
        state.synchronize()
      }
    }

    _ = state.expectSymbol("}")

    // Validate that enum has a zero value (required in proto3)
    if !values.contains(where: { $0.number == 0 }) {
      state.addError(.missingEnumZeroValue(enumName, at: state.currentPosition))
    }

    return EnumNode(name: enumName, values: values, options: options)
  }

  /// Parses an enum value: VALUE_NAME = number [options];.
  private func parseEnumValue() throws -> EnumValueNode {
    guard let valueName = state.identifierName else {
      state.addError(
        .unexpectedToken(
          state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
          expected: "enum value name"
        )
      )
      return EnumValueNode(name: "", number: 0)
    }

    state.advance()
    skipIgnorableTokens()
    _ = state.expectSymbol("=")
    skipIgnorableTokens()

    guard let valueNumberInt = state.integerLiteralValue else {
      state.addError(
        .unexpectedToken(
          state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
          expected: "enum value number"
        )
      )
      return EnumValueNode(name: valueName, number: 0)
    }

    let valueNumber = Int32(valueNumberInt)
    state.advance()
    skipIgnorableTokens()

    // Parse optional options
    var options: [OptionNode] = []
    if state.checkSymbol("[") {
      options = try parseFieldOptions()
      skipIgnorableTokens()
    }

    _ = state.expectSymbol(";")

    return EnumValueNode(name: valueName, number: valueNumber, options: options)
  }

  /// Parses a oneof declaration.
  private func parseOneofDeclaration() throws -> OneofNode {
    _ = state.expectKeyword(.oneof)
    skipIgnorableTokens()

    guard let oneofName = state.identifierName else {
      state.addError(
        .unexpectedToken(
          state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
          expected: "oneof name"
        )
      )
      return OneofNode(name: "")
    }

    state.advance()
    skipIgnorableTokens()
    _ = state.expectSymbol("{")

    var fields: [FieldNode] = []
    var options: [OptionNode] = []

    // Parse oneof body
    while !state.isAtEnd {
      skipIgnorableTokens()

      // Check for end of oneof after skipping ignorable tokens
      if state.checkSymbol("}") {
        break
      }

      guard let token = state.currentToken else {
        break
      }

      switch token.type {
      case .keyword(let keyword):
        switch keyword {
        case .option:
          let option = try parseOptionDeclaration()
          options.append(option)

        case .map:
          // Map field in oneof - need to parse as oneof field
          let field = try parseOneofField()
          fields.append(field)

        default:
          // Other keywords are not valid oneof elements
          state.addError(.unexpectedToken(token, expected: "oneof element"))
          state.advance()
          state.synchronize()
        }

      case .identifier:
        // Message/enum type field in oneof OR scalar type (since scalar types are identifiers, not keywords)
        let field = try parseOneofField()
        fields.append(field)

      default:
        state.addError(.unexpectedToken(token, expected: "oneof element"))
        state.advance()
        state.synchronize()
      }
    }

    skipIgnorableTokens()
    _ = state.expectSymbol("}")

    return OneofNode(name: oneofName, fields: fields, options: options)
  }

  /// Parses a field within a oneof declaration (no field label allowed).
  private func parseOneofField() throws -> FieldNode {
    // In oneof, field label is always singular (no repeated/optional allowed)
    let label: FieldLabel = .singular

    // Parse field type
    let fieldType = try parseFieldType()
    skipIgnorableTokens()

    // Parse field name (allow keywords as field names in certain contexts)
    let fieldName: String
    if let identifier = state.identifierName {
      fieldName = identifier
    }
    else if let token = state.currentToken,
      case .keyword(let keyword) = token.type,
      isAllowedAsFieldName(keyword)
    {
      // Allow certain keywords as field names (protobuf allows this)
      fieldName = keyword.rawValue
    }
    else {
      state.addError(
        .unexpectedToken(
          state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
          expected: "field name"
        )
      )
      return FieldNode(name: "", type: .string, number: 1)
    }

    state.advance()
    skipIgnorableTokens()
    _ = state.expectSymbol("=")
    skipIgnorableTokens()

    // Parse field number
    guard let fieldNumberInt = state.integerLiteralValue else {
      state.addError(
        .unexpectedToken(
          state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
          expected: "field number"
        )
      )
      return FieldNode(name: fieldName, type: fieldType, number: 1)
    }

    let fieldNumber = Int32(fieldNumberInt)
    state.advance()
    skipIgnorableTokens()

    // Parse optional field options
    var options: [OptionNode] = []
    if state.checkSymbol("[") {
      options = try parseFieldOptions()
      skipIgnorableTokens()
    }

    _ = state.expectSymbol(";")

    // Validate field number
    if fieldNumber <= 0 || fieldNumber > 536_870_911 {
      state.addError(.fieldNumberOutOfRange(fieldNumber, at: state.currentPosition))
    }
    else if (19000...19999).contains(fieldNumber) {
      state.addError(.reservedFieldNumber(fieldNumber, at: state.currentPosition))
    }

    return FieldNode(
      name: fieldName,
      type: fieldType,
      number: fieldNumber,
      label: label,
      options: options
    )
  }

  /// Parses a reserved declaration: reserved 1, 2, 3 to 5, "field1", "field2";.
  private func parseReservedDeclaration() throws -> ([Int32], [String]) {
    _ = state.expectKeyword(.reserved)
    skipIgnorableTokens()

    var numbers: [Int32] = []
    var names: [String] = []

    repeat {
      skipIgnorableTokens()
      if let stringValue = state.stringLiteralValue {
        // Reserved field name
        names.append(stringValue)
        state.advance()
        skipIgnorableTokens()
      }
      else if let intValue = state.integerLiteralValue {
        // Reserved field number or range
        let startNumber = Int32(intValue)
        state.advance()
        skipIgnorableTokens()

        if state.checkIdentifier() && state.identifierName == "to" {
          // Range: start to end
          state.advance()  // consume "to"
          skipIgnorableTokens()

          guard let endValue = state.integerLiteralValue else {
            state.addError(
              .unexpectedToken(
                state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
                expected: "end range number"
              )
            )
            break
          }

          let endNumber = Int32(endValue)
          state.advance()
          skipIgnorableTokens()

          // Add all numbers in range
          if startNumber <= endNumber {
            for num in startNumber...endNumber {
              numbers.append(num)
            }
          }
          else {
            state.addError(
              .unexpectedToken(
                state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
                expected: "valid range (start <= end)"
              )
            )
          }
        }
        else {
          // Single number
          numbers.append(startNumber)
        }
      }
      else {
        state.addError(
          .unexpectedToken(
            state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
            expected: "reserved number or name"
          )
        )
        break
      }

      if state.checkSymbol(",") {
        state.advance()  // consume ","
        skipIgnorableTokens()
      }
      else {
        break
      }
    } while !state.isAtEnd

    _ = state.expectSymbol(";")

    return (numbers, names)
  }

  /// Parses a service declaration.
  private func parseServiceDeclaration() throws -> ServiceNode {
    _ = state.expectKeyword(.service)
    skipIgnorableTokens()

    guard let serviceName = state.identifierName else {
      state.addError(
        .unexpectedToken(
          state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
          expected: "service name"
        )
      )
      return ServiceNode(name: "")
    }

    state.advance()
    skipIgnorableTokens()
    _ = state.expectSymbol("{")

    var methods: [RPCMethodNode] = []
    var options: [OptionNode] = []

    // Parse service body
    while !state.isAtEnd {
      skipIgnorableTokens()

      // Check for end of service after skipping ignorable tokens
      if state.checkSymbol("}") {
        break
      }

      guard let token = state.currentToken else { break }

      switch token.type {
      case .keyword(.option):
        let option = try parseOptionDeclaration()
        options.append(option)

      case .keyword(.rpc):
        let method = try parseRPCMethod()
        methods.append(method)

      default:
        state.addError(.unexpectedToken(token, expected: "service element"))
        state.advance()
        state.synchronize()
      }
    }

    _ = state.expectSymbol("}")

    return ServiceNode(name: serviceName, methods: methods, options: options)
  }

  /// Parses an RPC method: rpc MethodName(RequestType) returns (ResponseType);.
  private func parseRPCMethod() throws -> RPCMethodNode {
    _ = state.expectKeyword(.rpc)
    skipIgnorableTokens()

    guard let methodName = state.identifierName else {
      state.addError(
        .unexpectedToken(
          state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
          expected: "RPC method name"
        )
      )
      return RPCMethodNode(name: "", inputType: "", outputType: "")
    }

    state.advance()
    skipIgnorableTokens()
    _ = state.expectSymbol("(")
    skipIgnorableTokens()

    // Parse input type (with optional "stream" modifier)
    let inputStreaming = state.checkKeyword(.stream)
    if inputStreaming {
      state.advance()
      skipIgnorableTokens()
    }

    // Parse input type - support qualified types like google.protobuf.Empty
    let inputType: String
    if let firstPart = state.identifierName {
      // Use qualified type parsing logic to support google.protobuf.Empty
      let fieldType = try parseQualifiedTypeName(firstPart: firstPart)
      switch fieldType {
      case .message(let typeName), .enumType(let typeName), .qualifiedType(let typeName):
        inputType = typeName
      default:
        state.addError(
          .unexpectedToken(
            state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
            expected: "RPC input type"
          )
        )
        return RPCMethodNode(name: methodName, inputType: "", outputType: "")
      }
    }
    else {
      state.addError(
        .unexpectedToken(
          state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
          expected: "RPC input type"
        )
      )
      return RPCMethodNode(name: methodName, inputType: "", outputType: "")
    }
    skipIgnorableTokens()
    _ = state.expectSymbol(")")
    skipIgnorableTokens()
    _ = state.expectKeyword(.returns)
    skipIgnorableTokens()
    _ = state.expectSymbol("(")
    skipIgnorableTokens()

    // Parse output type (with optional "stream" modifier)
    let outputStreaming = state.checkKeyword(.stream)
    if outputStreaming {
      state.advance()
      skipIgnorableTokens()
    }

    // Parse output type - support qualified types like google.protobuf.Empty
    let outputType: String
    if let firstPart = state.identifierName {
      // Use qualified type parsing logic to support google.protobuf.Empty
      let fieldType = try parseQualifiedTypeName(firstPart: firstPart)
      switch fieldType {
      case .message(let typeName), .enumType(let typeName), .qualifiedType(let typeName):
        outputType = typeName
      default:
        state.addError(
          .unexpectedToken(
            state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
            expected: "RPC output type"
          )
        )
        return RPCMethodNode(name: methodName, inputType: inputType, outputType: "")
      }
    }
    else {
      state.addError(
        .unexpectedToken(
          state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
          expected: "RPC output type"
        )
      )
      return RPCMethodNode(name: methodName, inputType: inputType, outputType: "")
    }
    skipIgnorableTokens()
    _ = state.expectSymbol(")")
    skipIgnorableTokens()

    // Parse optional method options
    var options: [OptionNode] = []
    if state.checkSymbol("{") {
      state.advance()  // consume "{"

      while !state.isAtEnd {
        skipIgnorableTokens()

        if state.checkSymbol("}") {
          break
        }

        if state.checkKeyword(.option) {
          let option = try parseOptionDeclaration()
          options.append(option)
        }
        else {
          state.addError(
            .unexpectedToken(
              state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
              expected: "option or '}'"
            )
          )
          state.advance()
          state.synchronize()
          break
        }
      }

      _ = state.expectSymbol("}")
    }
    else {
      _ = state.expectSymbol(";")
    }

    return RPCMethodNode(
      name: methodName,
      inputType: inputType,
      outputType: outputType,
      inputStreaming: inputStreaming,
      outputStreaming: outputStreaming,
      options: options
    )
  }

  /// Parses an extend declaration for custom options (proto3 only).
  /// extend google.protobuf.FileOptions { optional string my_option = 50001; }.
  private func parseExtendDeclaration() throws -> ExtendNode {
    let position = state.currentPosition
    _ = state.expectKeyword(.extend)
    skipIgnorableTokens()

    // Parse extended type name (must be qualified, like google.protobuf.FileOptions)
    var extendedTypeComponents: [String] = []

    // Parse the qualified type name (e.g., google.protobuf.FileOptions)
    repeat {
      guard let component = state.identifierName else {
        state.addError(
          .unexpectedToken(
            state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
            expected: "extended type name"
          )
        )
        return ExtendNode(extendedType: "", position: position)
      }

      extendedTypeComponents.append(component)
      state.advance()
      skipIgnorableTokens()

      if state.checkSymbol(".") {
        state.advance()  // consume "."
        skipIgnorableTokens()
      }
      else {
        break
      }
    } while !state.isAtEnd

    let extendedType = extendedTypeComponents.joined(separator: ".")

    // Validate that this is a valid proto3 extend target
    if !extendedType.hasPrefix("google.protobuf.") {
      state.addError(
        .invalidExtendTarget(
          "extend statements in proto3 are only allowed for google.protobuf.* types for custom options, got: \(extendedType)",
          line: position.line,
          column: position.column
        )
      )
    }

    skipIgnorableTokens()
    _ = state.expectSymbol("{")

    var fields: [FieldNode] = []
    var options: [OptionNode] = []

    // Parse extend body - only custom option fields are allowed
    while !state.isAtEnd {
      skipIgnorableTokens()

      if state.checkSymbol("}") {
        break
      }

      guard let token = state.currentToken else { break }

      switch token.type {
      case .keyword(let keyword):
        switch keyword {
        case .option:
          let option = try parseOptionDeclaration()
          options.append(option)

        case .optional:
          // Custom option fields in extend statements
          let field = try parseFieldDeclaration()
          fields.append(field)

        default:
          state.addError(.unexpectedToken(token, expected: "optional field or option"))
          state.advance()
          state.synchronize()
        }

      case .identifier:
        // Regular field type (should have optional modifier for custom options)
        state.addError(
          .missingFieldLabel(
            "Custom option fields in extend statements should have 'optional' label",
            line: token.position.line,
            column: token.position.column
          )
        )
        // Try to parse anyway for error recovery
        let field = try parseFieldDeclaration()
        fields.append(field)

      default:
        state.addError(.unexpectedToken(token, expected: "extend element"))
        state.synchronize()
      }
    }

    _ = state.expectSymbol("}")

    return ExtendNode(
      extendedType: extendedType,
      fields: fields,
      options: options,
      position: position
    )
  }

  // MARK: - Helper Methods

  /// Skips whitespace, comments, and newlines.
  private func skipIgnorableTokens() {
    while let token = state.currentToken, token.isIgnorable {
      let beforeIndex = state.currentIndex
      state.advance()
      // Safety check to prevent infinite loop
      if state.currentIndex == beforeIndex {
        break
      }
    }
  }

  /// Checks if a keyword can be used as a field name.
  ///
  /// In Protocol Buffers, most keywords are allowed as field names.
  /// Only a very small set of keywords are truly reserved.
  private func isAllowedAsFieldName(_ keyword: ProtoKeyword) -> Bool {
    switch keyword {
    // Very few keywords are actually prohibited as field names in protobuf
    // Most keywords like "message", "service", "enum" etc. can be used as field names
    case .syntax, .package, .import:
      return false
    // All other keywords (including message, enum, service, etc.) can be field names
    default:
      return true
    }
  }
}

// MARK: - Parser + Static Methods

extension Parser {

  /// Convenience method to parse tokens directly.
  ///
  /// - Parameter tokens: The tokens to parse.
  /// - Returns: A `Result` containing either the parsed AST or parser errors.
  public static func parse(tokens: [Token]) -> Result<ProtoAST, ParserErrors> {
    let parser = Parser(tokens: tokens)
    return parser.parse()
  }
}
