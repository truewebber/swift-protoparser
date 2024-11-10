import Foundation

public class Parser {
	private let lexer: Lexer
	private var currentToken: Token
	private let errorCollector: ErrorCollector?

	public init(lexer: Lexer, errorCollector: ErrorCollector? = nil) {
		self.lexer = lexer
		self.currentToken = lexer.nextToken()
		self.errorCollector = errorCollector
	}

	public func parseProto() throws -> ProtoFile {
		let protoFile = ProtoFile()
		try parseSyntax(protoFile: protoFile)
		while currentToken != .endOfFile {
			try parseTopLevelDefinition(protoFile: protoFile)
		}
		return protoFile
	}

	// MARK: - Parsing Methods

	private func parseSyntax(protoFile: ProtoFile) throws {
		if case .keyword("syntax") = currentToken {
			try expectToken(.symbol("="))
			if case let .stringLiteral(syntaxValue) = currentToken {
				protoFile.syntax = syntaxValue
				advanceToken()
			} else {
				throw throwError("Expected syntax version string")
			}
			try expectToken(.symbol(";"))
		}
	}

	private func parseTopLevelDefinition(protoFile: ProtoFile) throws {
		switch currentToken {
		case .keyword("package"):
			try parsePackage(protoFile: protoFile)
		case .keyword("import"):
			try parseImport(protoFile: protoFile)
		case .keyword("message"):
			let message = try parseMessage()
			protoFile.topLevelDefinitions.append(.message(message))
		case .keyword("enum"):
			let enumType = try parseEnum()
			protoFile.topLevelDefinitions.append(.enumType(enumType))
		case .keyword("service"):
			let service = try parseService()
			protoFile.topLevelDefinitions.append(.service(service))
		case .keyword("option"):
			let option = try parseOption()
			protoFile.topLevelDefinitions.append(.option(option))
		case .symbol(";"):
			advanceToken() // Skip empty statements
		default:
			throw throwError("Unexpected token: \(currentToken)")
		}
	}

	private func parsePackage(protoFile: ProtoFile) throws {
		advanceToken() // Consume 'package'
		if case let .identifier(packageName) = currentToken {
			protoFile.package = packageName
			advanceToken()
		} else {
			throw throwError("Expected package name")
		}
		try expectToken(.symbol(";"))
	}

	private func parseImport(protoFile: ProtoFile) throws {
		advanceToken() // Consume 'import'
		var modifier: ImportStatement.Modifier = .none
		if case let .keyword(modifierKeyword) = currentToken {
			if modifierKeyword == "weak" {
				modifier = .weak
				advanceToken()
			} else if modifierKeyword == "public" {
				modifier = .publicImport
				advanceToken()
			}
		}
		if case let .stringLiteral(path) = currentToken {
			let importStatement = ImportStatement(modifier: modifier, path: path)
			protoFile.imports.append(importStatement)
			advanceToken()
		} else {
			throw throwError("Expected import path string")
		}
		try expectToken(.symbol(";"))
	}

	private func parseMessage() throws -> Message {
		advanceToken() // Consume 'message'
		guard case let .identifier(messageName) = currentToken else {
			throw throwError("Expected message name")
		}
		let message = Message(name: messageName)
		advanceToken()
		try expectToken(.symbol("{"))
		while currentToken != .symbol("}") {
			switch currentToken {
			case .keyword("message"):
				let nestedMessage = try parseMessage()
				message.nestedTypes.append(nestedMessage)
			case .keyword("enum"):
				let enumType = try parseEnum()
				message.enums.append(enumType)
			case .keyword("oneof"):
				let oneof = try parseOneof()
				message.oneofs.append(oneof)
			case .keyword("option"):
				let option = try parseOption()
				message.options.append(option)
			case .identifier, .keyword("repeated"):
				let field = try parseField()
				message.fields.append(field)
			case .symbol(";"):
				advanceToken() // Skip empty statements
			default:
				throw throwError("Unexpected token in message: \(currentToken)")
			}
		}
		try expectToken(.symbol("}"))
		return message
	}

	private func parseEnum() throws -> EnumType {
		advanceToken() // Consume 'enum'
		guard case let .identifier(enumName) = currentToken else {
			throw throwError("Expected enum name")
		}
		let enumType = EnumType(name: enumName)
		advanceToken()
		try expectToken(.symbol("{"))
		while currentToken != .symbol("}") {
			switch currentToken {
			case .identifier:
				let enumValue = try parseEnumValue()
				enumType.values.append(enumValue)
			case .keyword("option"):
				let option = try parseOption()
				enumType.options.append(option)
			case .symbol(";"):
				advanceToken() // Skip empty statements
			default:
				throw throwError("Unexpected token in enum: \(currentToken)")
			}
		}
		try expectToken(.symbol("}"))
		return enumType
	}

	private func parseService() throws -> Service {
		advanceToken() // Consume 'service'
		guard case let .identifier(serviceName) = currentToken else {
			throw throwError("Expected service name")
		}
		let service = Service(name: serviceName)
		advanceToken()
		try expectToken(.symbol("{"))
		while currentToken != .symbol("}") {
			switch currentToken {
			case .keyword("rpc"):
				let method = try parseMethod()
				service.methods.append(method)
			case .keyword("option"):
				let option = try parseOption()
				service.options.append(option)
			case .symbol(";"):
				advanceToken() // Skip empty statements
			default:
				throw throwError("Unexpected token in service: \(currentToken)")
			}
		}
		try expectToken(.symbol("}"))
		return service
	}

	private func parseField() throws -> Field {
		var label: Field.Label?
		if case .keyword("repeated") = currentToken {
			label = .repeated
			advanceToken()
		}
		let type = try parseType()
		guard case let .identifier(fieldName) = currentToken else {
			throw throwError("Expected field name")
		}
		advanceToken()
		try expectToken(.symbol("="))
		guard case let .numericLiteral(numberString) = currentToken, let fieldNumber = Int(numberString) else {
			throw throwError("Expected field number")
		}
		advanceToken()
		try expectToken(.symbol(";"))
		return Field(label: label, type: type, name: fieldName, number: fieldNumber)
	}

	private func parseEnumValue() throws -> EnumValue {
		guard case let .identifier(valueName) = currentToken else {
			throw throwError("Expected enum value name")
		}
		advanceToken()
		try expectToken(.symbol("="))
		guard case let .numericLiteral(numberString) = currentToken, let valueNumber = Int(numberString) else {
			throw throwError("Expected enum value number")
		}
		advanceToken()
		try expectToken(.symbol(";"))
		return EnumValue(name: valueName, number: valueNumber)
	}

	private func parseMethod() throws -> Method {
		advanceToken() // Consume 'rpc'
		guard case let .identifier(methodName) = currentToken else {
			throw throwError("Expected method name")
		}
		advanceToken()
		try expectToken(.symbol("("))
		let inputType = try parseTypeName()
		try expectToken(.symbol(")"))
		try expectToken(.keyword("returns"))
		try expectToken(.symbol("("))
		let outputType = try parseTypeName()
		try expectToken(.symbol(")"))
		try expectToken(.symbol(";"))
		return Method(name: methodName, inputType: inputType, outputType: outputType)
	}

	private func parseOption() throws -> Option {
		advanceToken() // Consume 'option'
		guard case let .identifier(optionName) = currentToken else {
			throw throwError("Expected option name")
		}
		advanceToken()
		try expectToken(.symbol("="))
		let optionValue = try parseConstant()
		try expectToken(.symbol(";"))
		return Option(name: optionName, value: optionValue)
	}

	private func parseOneof() throws -> Oneof {
		advanceToken() // Consume 'oneof'
		guard case let .identifier(oneofName) = currentToken else {
			throw throwError("Expected oneof name")
		}
		let oneof = Oneof(name: oneofName)
		advanceToken()
		try expectToken(.symbol("{"))
		while currentToken != .symbol("}") {
			let field = try parseField()
			oneof.fields.append(field)
		}
		try expectToken(.symbol("}"))
		return oneof
	}

	private func parseType() throws -> FieldType {
		switch currentToken {
		case let .identifier(typeName):
			advanceToken()
			return .basicType(typeName)
		case .keyword("map"):
			return try parseMapType()
		default:
			throw throwError("Expected field type")
		}
	}

	private func parseMapType() throws -> FieldType {
		advanceToken() // Consume 'map'
		try expectToken(.symbol("<"))
		guard case let .identifier(keyType) = currentToken else {
			throw throwError("Expected map key type")
		}
		advanceToken()
		try expectToken(.symbol(","))
		let valueType = try parseType()
		try expectToken(.symbol(">"))
		return .mapType(MapField(keyType: keyType, valueType: valueType))
	}

	private func parseTypeName() throws -> String {
		if case let .identifier(typeName) = currentToken {
			advanceToken()
			return typeName
		} else {
			throw throwError("Expected type name")
		}
	}

	private func parseConstant() throws -> Any {
		switch currentToken {
		case let .stringLiteral(value):
			advanceToken()
			return value
		case let .numericLiteral(value):
			advanceToken()
			return value
		case let .booleanLiteral(value):
			advanceToken()
			return value
		default:
			throw throwError("Expected constant value")
		}
	}

	// MARK: - Utility Methods

	private func expectToken(_ expected: Token) throws {
		if currentToken == expected {
			advanceToken()
		} else {
			throw throwError("Expected token \(expected), found \(currentToken)")
		}
	}

	private func advanceToken() {
		currentToken = lexer.nextToken()
	}

	private func throwError(_ message: String) -> ParserError {
		if let errorCollector = errorCollector {
			// Assume line and column tracking is available
			errorCollector.addError(line: 0, column: 0, message: message)
			return ParserError.parsingFailed
		} else {
			return ParserError.error(message)
		}
	}

	enum ParserError: Error {
		case error(String)
		case parsingFailed
	}
}

