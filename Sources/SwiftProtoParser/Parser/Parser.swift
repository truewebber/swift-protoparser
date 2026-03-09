import Foundation

/// Wrapper for multiple parser errors to conform to Error protocol.
struct ParserErrors: Error {
  let errors: [ParserError]

  init(_ errors: [ParserError]) {
    self.errors = errors
  }
}

/// Recursive descent parser for Protocol Buffers source code.
///
/// This parser takes a stream of tokens from the lexer and constructs.
/// an Abstract Syntax Tree (AST) representing the structure of the .proto file.
final class Parser {

  // MARK: - Private Properties

  /// The parser state managing token stream and errors.
  private var state: ParserState

  // MARK: - Initialization

  /// Creates a new parser with the given tokens.
  ///
  /// - Parameter tokens: The array of tokens to parse.
  init(tokens: [Token]) {
    self.state = ParserState(tokens: tokens)
  }

  // MARK: - Public Methods

  /// Parses the tokens into a Protocol Buffers AST.
  ///
  /// - Returns: A `Result` containing either the parsed AST or parser errors.
  func parse() -> Result<ProtoAST, ParserErrors> {
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
    var syntax: ProtoVersion = .default
    var package: String?
    var imports: [ImportNode] = []
    var options: [OptionNode] = []
    var messages: [MessageNode] = []
    var enums: [EnumNode] = []
    var services: [ServiceNode] = []
    var extends: [ExtendNode] = []

    // Skip initial whitespace and comments
    skipIgnorableTokens()

    // Parse optional syntax declaration.
    // Per protoc 33.5 behaviour: missing syntax → proto2 (no error, no warning).
    if let token = state.currentToken, case .keyword(let kw) = token.type, kw == .syntax {
      syntax = try parseSyntaxDeclaration()
    }

    // Make the resolved version available to all downstream parsing methods.
    state.protoVersion = syntax

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
            state.currentPackage = package
          }

        case .import:
          let importNode = try parseImportDeclaration()
          imports.append(importNode)

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

  /// Parses the syntax declaration: `syntax = "proto2";` or `syntax = "proto3";`.
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
      return .default
    }

    state.advance()
    skipIgnorableTokens()
    _ = state.expectSymbol(";")

    guard let version = ProtoVersion(rawValue: syntaxString) else {
      state.addError(
        .invalidSyntax(
          "Unrecognized syntax identifier \"\(syntaxString)\".  This parser only recognizes \"proto2\" and \"proto3\".",
          line: token.position.line,
          column: token.position.column
        )
      )
      return .default
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

  /// Parses an import declaration: import ["public"|"weak"] "path/to/file.proto";.
  private func parseImportDeclaration() throws -> ImportNode {
    _ = state.expectKeyword(.import)
    skipIgnorableTokens()

    var modifier: ImportModifier = .none
    if state.checkKeyword(.public) {
      modifier = .public
      state.advance()
      skipIgnorableTokens()
    }
    else if state.checkKeyword(.weak) {
      modifier = .weak
      state.advance()
      skipIgnorableTokens()
    }

    guard let importPath = state.stringLiteralValue else {
      state.addError(
        .unexpectedToken(
          state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
          expected: "import path string"
        )
      )
      return ImportNode(path: "", modifier: modifier)
    }

    state.advance()
    skipIgnorableTokens()
    _ = state.expectSymbol(";")

    return ImportNode(path: importPath, modifier: modifier)
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

      guard let firstPart = state.identifierName else {
        state.addError(
          .unexpectedToken(
            state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
            expected: "custom option name"
          )
        )
        return OptionNode(name: "", value: .string(""))
      }

      state.advance()
      var nameParts = [firstPart]

      // Parse fullIdent: ident { "." ident }
      while state.checkSymbol(".") {
        state.advance()  // consume "."
        skipIgnorableTokens()
        guard let nextPart = state.identifierName else {
          state.addError(
            .unexpectedToken(
              state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
              expected: "identifier after '.' in option name"
            )
          )
          return OptionNode(name: "", value: .string(""))
        }
        nameParts.append(nextPart)
        state.advance()
      }

      optionName = nameParts.joined(separator: ".")
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

  /// Parses an option value (string, number, boolean, identifier, or message literal).
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

    case .keyword(let kw):
      // Keywords can appear as enum value identifiers (e.g. SPEED, RETENTION_RUNTIME)
      value = .identifier(kw.rawValue)

    case .symbol("{"):
      // Message literal: { field: value, ... } — consume the whole block.
      value = .identifier(consumeBalancedBlock(open: "{", close: "}"))
      return value

    case .symbol("["):
      // Array literal: [ value, ... ] — consume the whole block.
      value = .identifier(consumeBalancedBlock(open: "[", close: "]"))
      return value

    case .symbol("-"):
      // Negative number
      state.advance()
      skipIgnorableTokens()
      guard let next = state.currentToken else {
        state.addError(.unexpectedEndOfInput(expected: "number after '-'"))
        return .number(0)
      }
      switch next.type {
      case .integerLiteral(let int):
        state.advance()
        return .number(-Double(int))
      case .floatLiteral(let float):
        state.advance()
        return .number(-float)
      default:
        state.addError(.unexpectedToken(next, expected: "number after '-'"))
        return .number(0)
      }

    default:
      state.addError(.unexpectedToken(token, expected: "option value"))
      return .string("")
    }

    state.advance()
    return value
  }

  /// Consumes a balanced block starting with `open` up to the matching `close` and
  /// returns the raw text content (for message-literal and array-literal option values).
  private func consumeBalancedBlock(open: Character, close: Character) -> String {
    var depth = 0
    var text = ""
    while !state.isAtEnd {
      guard let token = state.currentToken else { break }
      if case .symbol(let ch) = token.type {
        if ch == open {
          depth += 1
          text.append(ch)
          state.advance()
          continue
        }
        if ch == close {
          depth -= 1
          text.append(ch)
          state.advance()
          if depth == 0 { break }
          continue
        }
      }
      if case .whitespace = token.type {
        state.advance()
        continue
      }
      if case .newline = token.type {
        state.advance()
        continue
      }
      text.append(contentsOf: token.type.description)
      state.advance()
    }
    return text
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
    var extensionRanges: [ExtensionRangeNode] = []
    var nestedExtends: [ExtendNode] = []
    var groupFields: [GroupFieldNode] = []

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

        case .extensions:
          if state.protoVersion == .proto3 {
            let position = token.position
            state.addError(
              .extensionRangeInProto3(line: position.line, column: position.column)
            )
            state.advance()
            state.synchronize()
          }
          else {
            let ranges = try parseExtensionRanges()
            extensionRanges.append(contentsOf: ranges)
          }

        case .extend:
          let nestedExtend = try parseExtendDeclaration()
          nestedExtends.append(nestedExtend)

        case .repeated, .optional, .required:
          if state.peekNextNonIgnorableToken?.isKeyword(.group) == true {
            let groupField = try parseGroupField(label: keyword)
            groupFields.append(groupField)
          }
          else {
            let field = try parseFieldDeclaration()
            fields.append(field)
          }

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
    if state.checkSymbol(";") { state.advance() }

    return MessageNode(
      name: messageName,
      fields: fields,
      nestedMessages: nestedMessages,
      nestedEnums: nestedEnums,
      oneofGroups: oneofGroups,
      options: options,
      reservedNumbers: reservedNumbers,
      reservedNames: reservedNames,
      extensionRanges: extensionRanges,
      nestedExtends: nestedExtends,
      groupFields: groupFields
    )
  }

  /// Parses a group field declaration: `label group Name = number { ... }`.
  ///
  /// Must only be called when the current token is a field label keyword (optional/required/repeated)
  /// and the next non-ignorable token is the `group` keyword.
  private func parseGroupField(label keyword: ProtoKeyword) throws -> GroupFieldNode {
    let labelPosition = state.currentPosition

    if state.protoVersion == .proto3 {
      state.addError(.groupInProto3(line: labelPosition.line, column: labelPosition.column))
      state.advance()
      state.synchronize()
      return GroupFieldNode(label: .optional, groupName: "", fieldNumber: 0, body: MessageNode(name: ""))
    }

    let label: FieldLabel
    switch keyword {
    case .repeated:
      label = .repeated
    case .required:
      label = .required
    default:
      label = .optional
    }
    state.advance()
    skipIgnorableTokens()

    _ = state.expectKeyword(.group)
    skipIgnorableTokens()

    guard let groupName = state.identifierName else {
      state.addError(
        .unexpectedToken(
          state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
          expected: "group name"
        )
      )
      return GroupFieldNode(label: label, groupName: "", fieldNumber: 0, body: MessageNode(name: ""))
    }
    state.advance()
    skipIgnorableTokens()

    _ = state.expectSymbol("=")
    skipIgnorableTokens()

    guard let fieldNumberInt = state.integerLiteralValue else {
      state.addError(
        .unexpectedToken(
          state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
          expected: "field number"
        )
      )
      return GroupFieldNode(label: label, groupName: groupName, fieldNumber: 0, body: MessageNode(name: groupName))
    }
    let fieldNumber = Int32(fieldNumberInt)
    state.advance()
    skipIgnorableTokens()

    _ = state.expectSymbol("{")

    var bodyFields: [FieldNode] = []
    var bodyNestedMessages: [MessageNode] = []
    var bodyNestedEnums: [EnumNode] = []
    var bodyOneofGroups: [OneofNode] = []
    var bodyOptions: [OptionNode] = []
    var bodyReservedNumbers: [Int32] = []
    var bodyReservedNames: [String] = []
    var bodyExtensionRanges: [ExtensionRangeNode] = []
    var bodyNestedExtends: [ExtendNode] = []
    var bodyGroupFields: [GroupFieldNode] = []

    while !state.isAtEnd {
      skipIgnorableTokens()
      if state.checkSymbol("}") { break }
      guard let token = state.currentToken else { break }

      switch token.type {
      case .keyword(let kw):
        switch kw {
        case .message:
          let nested = try parseMessageDeclaration()
          bodyNestedMessages.append(nested)

        case .enum:
          let nested = try parseEnumDeclaration()
          bodyNestedEnums.append(nested)

        case .oneof:
          let oneof = try parseOneofDeclaration()
          bodyOneofGroups.append(oneof)

        case .option:
          let option = try parseOptionDeclaration()
          bodyOptions.append(option)

        case .reserved:
          let (numbers, names) = try parseReservedDeclaration()
          bodyReservedNumbers.append(contentsOf: numbers)
          bodyReservedNames.append(contentsOf: names)

        case .extensions:
          if state.protoVersion == .proto3 {
            let position = token.position
            state.addError(.extensionRangeInProto3(line: position.line, column: position.column))
            state.advance()
            state.synchronize()
          }
          else {
            let ranges = try parseExtensionRanges()
            bodyExtensionRanges.append(contentsOf: ranges)
          }

        case .extend:
          let nested = try parseExtendDeclaration()
          bodyNestedExtends.append(nested)

        case .repeated, .optional, .required:
          if state.peekNextNonIgnorableToken?.isKeyword(.group) == true {
            let nested = try parseGroupField(label: kw)
            bodyGroupFields.append(nested)
          }
          else {
            let field = try parseFieldDeclaration()
            bodyFields.append(field)
          }

        case .map:
          let field = try parseFieldDeclaration()
          bodyFields.append(field)

        default:
          state.addError(.unexpectedToken(token, expected: "group body element"))
          state.advance()
          state.synchronize()
        }

      case .identifier:
        let field = try parseFieldDeclaration()
        bodyFields.append(field)

      default:
        state.addError(.unexpectedToken(token, expected: "group body element"))
        state.synchronize()
      }
    }

    _ = state.expectSymbol("}")
    if state.checkSymbol(";") { state.advance() }

    let body = MessageNode(
      name: groupName,
      fields: bodyFields,
      nestedMessages: bodyNestedMessages,
      nestedEnums: bodyNestedEnums,
      oneofGroups: bodyOneofGroups,
      options: bodyOptions,
      reservedNumbers: bodyReservedNumbers,
      reservedNames: bodyReservedNames,
      extensionRanges: bodyExtensionRanges,
      nestedExtends: bodyNestedExtends,
      groupFields: bodyGroupFields
    )

    return GroupFieldNode(label: label, groupName: groupName, fieldNumber: fieldNumber, body: body)
  }

  /// Parses a field declaration.
  private func parseFieldDeclaration() throws -> FieldNode {
    // Parse optional field label
    var label: FieldLabel = .singular
    var labelParsed = false

    if state.checkKeyword(.repeated) {
      label = .repeated
      labelParsed = true
      state.advance()
      skipIgnorableTokens()
    }
    else if state.checkKeyword(.optional) {
      label = .optional
      labelParsed = true
      state.advance()
      skipIgnorableTokens()
    }
    else if state.checkKeyword(.required) {
      let position = state.currentPosition
      if state.protoVersion == .proto3 {
        state.addError(
          .invalidSyntax(
            "Required fields are not allowed in proto3.",
            line: position.line,
            column: position.column
          )
        )
      }
      label = .required
      labelParsed = true
      state.advance()
      skipIgnorableTokens()
    }

    // In proto2, every regular field must carry an explicit label.
    // Map fields are exempt (they use no label in both versions).
    if !labelParsed && state.protoVersion == .proto2 && !state.checkKeyword(.map) {
      let position = state.currentPosition
      state.addError(
        .missingFieldLabel(
          "Expected \"required\", \"optional\", or \"repeated\".",
          line: position.line,
          column: position.column
        )
      )
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

        guard let firstPart = state.identifierName else {
          state.addError(
            .unexpectedToken(
              state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
              expected: "custom option name"
            )
          )
          break
        }

        state.advance()
        var nameParts = [firstPart]

        // Parse fullIdent: ident { "." ident }
        while state.checkSymbol(".") {
          state.advance()  // consume "."
          skipIgnorableTokens()
          guard let nextPart = state.identifierName else {
            state.addError(
              .unexpectedToken(
                state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
                expected: "identifier after '.' in option name"
              )
            )
            break
          }
          nameParts.append(nextPart)
          state.advance()
        }

        optionName = nameParts.joined(separator: ".")
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
    if state.checkSymbol(";") { state.advance() }

    // Zero-value is only required in proto3; proto2 and no-syntax allow any starting value.
    if state.protoVersion == .proto3 && !values.contains(where: { $0.number == 0 }) {
      state.addError(.missingEnumZeroValue(enumName, at: state.currentPosition))
    }

    // Duplicate numeric values require option allow_alias = true.
    let hasAllowAlias = options.contains { $0.name == "allow_alias" && $0.value == .boolean(true) }
    if !hasAllowAlias {
      validateEnumNoDuplicateValues(values, enumName: enumName)
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

  /// Checks that no two enum values share the same number.
  ///
  /// Reports the first duplicate found using the exact protoc error format:
  /// `"<fqn>" uses the same enum value as "<fqn>". If this is intended, set
  /// 'option allow_alias = true;' to the enum definition. The next available
  /// enum value is N.`
  private func validateEnumNoDuplicateValues(_ values: [EnumValueNode], enumName: String) {
    var seenNumbers: [Int32: String] = [:]
    for value in values {
      if let originalName = seenNumbers[value.number] {
        let pkg = state.currentPackage
        let fqnDuplicate = pkg.map { "\($0).\(value.name)" } ?? value.name
        let fqnOriginal = pkg.map { "\($0).\(originalName)" } ?? originalName
        let maxValue = values.map { $0.number }.max() ?? 0
        let nextValue = Int(maxValue) + 1
        let message =
          "\"\(fqnDuplicate)\" uses the same enum value as \"\(fqnOriginal)\". "
          + "If this is intended, set 'option allow_alias = true;' to the enum definition. "
          + "The next available enum value is \(nextValue)."
        state.addError(
          .duplicateEnumValue(message, line: state.currentPosition.line, column: state.currentPosition.column)
        )
        return
      }
      seenNumbers[value.number] = value.name
    }
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

        case .required, .optional, .repeated:
          // Labels are forbidden inside oneof in both proto2 and proto3
          state.addError(.labeledFieldInOneof(line: token.position.line, column: token.position.column))
          state.advance()
          skipIgnorableTokens()
          // Continue parsing the field so further errors can still be reported
          if !state.isAtEnd && !state.checkSymbol("}") {
            let field = try parseOneofField()
            fields.append(field)
          }

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
    if state.checkSymbol(";") { state.advance() }

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

  /// The exclusive upper bound used when `max` appears in an extension range.
  ///
  /// Matches protoc behaviour: `extensions N to max` → `extensionRange {start: N, end: 536870912}`.
  private static let extensionRangeMax: Int32 = 536_870_912

  /// Parses one or more comma-separated extension ranges after the `extensions` keyword.
  ///
  /// Grammar: `extensions N to M [, N to M]* ;`
  /// where `M` may be `max`. End values are stored **exclusive** (M + 1 / 536870912 for max).
  private func parseExtensionRanges() throws -> [ExtensionRangeNode] {
    _ = state.expectKeyword(.extensions)
    skipIgnorableTokens()

    var ranges: [ExtensionRangeNode] = []

    repeat {
      skipIgnorableTokens()

      guard let startValue = state.integerLiteralValue else {
        state.addError(
          .unexpectedToken(
            state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
            expected: "extension range start number"
          )
        )
        break
      }

      let start = Int32(startValue)
      state.advance()
      skipIgnorableTokens()

      let exclusiveEnd: Int32
      if state.checkIdentifier() && state.identifierName == "to" {
        state.advance()  // consume "to"
        skipIgnorableTokens()

        if state.checkIdentifier() && state.identifierName == "max" {
          exclusiveEnd = Parser.extensionRangeMax
          state.advance()
        }
        else if let endValue = state.integerLiteralValue {
          exclusiveEnd = Int32(endValue) + 1
          state.advance()
        }
        else {
          state.addError(
            .unexpectedToken(
              state.currentToken ?? Token(type: .eof, position: Token.Position(line: 0, column: 0)),
              expected: "extension range end number or 'max'"
            )
          )
          break
        }
      }
      else {
        // Single extension number: `extensions N;` — equivalent to `extensions N to N`
        exclusiveEnd = start + 1
      }

      ranges.append(ExtensionRangeNode(start: start, end: exclusiveEnd))
      skipIgnorableTokens()

      if state.checkSymbol(",") {
        state.advance()  // consume ","
        skipIgnorableTokens()
      }
      else {
        break
      }
    } while !state.isAtEnd

    _ = state.expectSymbol(";")

    return ranges
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
    if state.checkSymbol(";") { state.advance() }

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
      if state.checkSymbol(";") { state.advance() }
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

    // Handle optional leading dot (explicit fully-qualified reference like .google.protobuf.X)
    let hasLeadingDot = state.checkSymbol(".")
    if hasLeadingDot {
      state.advance()  // consume leading "."
      skipIgnorableTokens()
    }

    // Parse the qualified type name (e.g., google.protobuf.FileOptions or FileOptions)
    var extendedTypeComponents: [String] = []
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

    let baseName = extendedTypeComponents.joined(separator: ".")
    let extendedType = hasLeadingDot ? ".\(baseName)" : baseName

    // Compute the FQN and determine the validation mode upfront.
    // Error emission for "does not declare N as extension number" is deferred
    // until after parsing the body so we can include the actual field number.
    enum ExtendProto3Validation {
      case valid
      case noExtensionRanges(displayName: String)
      case optionsOnly
    }

    let proto3Validation: ExtendProto3Validation
    if state.protoVersion == .proto3 {
      let fqn: String
      if extendedType.hasPrefix(".") {
        fqn = extendedType
      }
      else if !extendedType.contains("."), let pkg = state.currentPackage, !pkg.isEmpty {
        fqn = ".\(pkg).\(extendedType)"
      }
      else {
        fqn = ".\(extendedType)"
      }

      if fqn.hasPrefix(".google.protobuf.") {
        proto3Validation = .valid
      }
      else if !extendedType.contains(".") {
        // Simple local name: proto3 messages have no extension ranges.
        // Defer error with per-field number (matches protoc exact message).
        let pkg = state.currentPackage
        let displayName = pkg.map { "\($0).\(extendedType)" } ?? extendedType
        proto3Validation = .noExtensionRanges(displayName: displayName)
      }
      else {
        // Qualified name — likely a proto2 import target with extension ranges.
        proto3Validation = .optionsOnly
      }
    }
    else {
      proto3Validation = .valid
    }

    skipIgnorableTokens()
    _ = state.expectSymbol("{")

    var fields: [FieldNode] = []
    var options: [OptionNode] = []

    // Parse extend body
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

        case .optional, .repeated, .required:
          let field = try parseFieldDeclaration()
          fields.append(field)

        default:
          state.addError(.unexpectedToken(token, expected: "field or option"))
          state.advance()
          state.synchronize()
        }

      case .identifier:
        // Field declared without an explicit label — valid proto3 singular field
        let field = try parseFieldDeclaration()
        fields.append(field)

      default:
        state.addError(.unexpectedToken(token, expected: "extend element"))
        state.synchronize()
      }
    }

    _ = state.expectSymbol("}")
    if state.checkSymbol(";") { state.advance() }

    // Emit deferred proto3 validation errors now that field numbers are known.
    switch proto3Validation {
    case .valid:
      break
    case .noExtensionRanges(let displayName):
      if fields.isEmpty {
        state.addError(
          .invalidExtendTarget(
            "\"\(displayName)\" does not declare any extension numbers.",
            line: position.line,
            column: position.column
          )
        )
      }
      else {
        for field in fields {
          state.addError(
            .invalidExtendTarget(
              "\"\(displayName)\" does not declare \(field.number) as an extension number.",
              line: position.line,
              column: position.column
            )
          )
        }
      }
    case .optionsOnly:
      state.addError(
        .invalidExtendTarget(
          "Extensions in proto3 are only allowed for defining options.",
          line: position.line,
          column: position.column
        )
      )
    }

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
    // In protobuf, all keywords are valid as field names; the language is
    // not reserved-word restricted at the identifier level.
    return true
  }
}

// MARK: - Parser + Static Methods

extension Parser {

  /// Convenience method to parse tokens directly.
  ///
  /// - Parameter tokens: The tokens to parse.
  /// - Returns: A `Result` containing either the parsed AST or parser errors.
  static func parse(tokens: [Token]) -> Result<ProtoAST, ParserErrors> {
    let parser = Parser(tokens: tokens)
    return parser.parse()
  }
}
