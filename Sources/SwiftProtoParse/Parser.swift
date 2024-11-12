import Foundation
import SwiftProtobuf

/// Error type representing a parsing error.
struct ParserError: Error, CustomStringConvertible {
	let message: String
	let line: Int
	let column: Int

	var description: String {
		return "[Line \(line), Column \(column)] Parser Error: \(message)"
	}
}

/// Class responsible for parsing tokens into a FileDescriptorProto.
class Parser {
	private let tokens: [Token]
	private var current: Int = 0

	/// Initializes the parser with the list of tokens.
	/// - Parameter tokens: The tokens generated by the lexer.
	init(tokens: [Token]) {
		self.tokens = tokens
	}

	/// Parses the tokens and returns a FileDescriptorProto.
	/// - Returns: A FileDescriptorProto representing the parsed .proto file.
	/// - Throws: `ParserError` if a syntax error is encountered.
	func parse() throws -> Google_Protobuf_FileDescriptorProto {
		var fileDescriptor = Google_Protobuf_FileDescriptorProto()
		try parseSyntax(into: &fileDescriptor)
		try parsePackage(into: &fileDescriptor)
		try parseImports(into: &fileDescriptor)
		try parseTopLevelDeclarations(into: &fileDescriptor)
		return fileDescriptor
	}

	// MARK: - Parsing Methods

	/// Parses the syntax declaration.
	private func parseSyntax(into fileDescriptor: inout Google_Protobuf_FileDescriptorProto) throws {
		if matchKeyword("syntax") {
			try consumeSymbol("=")
			let syntaxToken = try consumeStringLiteral()
			guard syntaxToken.lexeme == "\"proto3\"" || syntaxToken.lexeme == "'proto3'" else {
				throw error("Unsupported syntax version: \(syntaxToken.lexeme)")
			}
			fileDescriptor.syntax = "proto3"
			try consumeSymbol(";")
		} else {
			throw error("Missing syntax declaration")
		}
	}

	/// Parses the package declaration.
	private func parsePackage(into fileDescriptor: inout Google_Protobuf_FileDescriptorProto) throws {
		if matchKeyword("package") {
			let packageName = try parseFullIdentifier()
			fileDescriptor.package = packageName
			try consumeSymbol(";")
		}
	}

	/// Parses import statements.
	private func parseImports(into fileDescriptor: inout Google_Protobuf_FileDescriptorProto) throws {
		while matchKeyword("import") {
			// Initialize import modifiers
			var importModifier: String? = nil

			if matchKeyword("public") {
				importModifier = "public"
			} else if matchKeyword("weak") {
				importModifier = "weak"
			}

			let importPathToken = try consumeStringLiteral()
			let importPath = importPathToken.lexeme.trimmingCharacters(in: ["\"", "'"])
			fileDescriptor.dependency.append(importPath)

			// Note: Since FileDescriptorProto does not store import modifiers,
			// we may need to handle them separately if necessary.
			// For now, we can store them in a custom data structure if needed.
			// Alternatively, you can ignore them if they are not required.

			try consumeSymbol(";")
		}
	}

	/// Parses top-level declarations (messages, enums, services, extensions, options).
	private func parseTopLevelDeclarations(into fileDescriptor: inout Google_Protobuf_FileDescriptorProto) throws {
		while !isAtEnd() {
			if matchKeyword("option") {
				let option = try parseOption()
				// No need to check if fileDescriptor.options is nil
				fileDescriptor.options.uninterpretedOption.append(option)
				try consumeSymbol(";")
			} else if matchKeyword("message") {
				let message = try parseMessage()
				fileDescriptor.messageType.append(message)
			} else if matchKeyword("enum") {
				let enumType = try parseEnum()
				fileDescriptor.enumType.append(enumType)
			} else if matchKeyword("service") {
				let service = try parseService()
				fileDescriptor.service.append(service)
			} else if matchKeyword("extend") {
				let extensions = try parseExtensions()
				fileDescriptor.extension.append(contentsOf: extensions)
			} else if matchSymbol(";") {
				advance()
			} else {
				throw error("Unexpected token '\(peek().lexeme)'")
			}
		}
	}


	// MARK: - Parsing Declarations

	/// Parses a message declaration.
	private func parseMessage() throws -> Google_Protobuf_DescriptorProto {
		let messageNameToken = try consumeIdentifier()
		var messageDescriptor = Google_Protobuf_DescriptorProto()
		messageDescriptor.name = messageNameToken.lexeme

		try consumeSymbol("{")

		while !checkSymbol("}") && !isAtEnd() {
			if matchKeyword("option") {
				let option = try parseOption()
//				if messageDescriptor.options == nil {
//					messageDescriptor.options = Google_Protobuf_MessageOptions()
//				}
				messageDescriptor.options.uninterpretedOption.append(option)
				try consumeSymbol(";")
			} else if matchKeyword("message") {
				let nestedMessage = try parseMessage()
				messageDescriptor.nestedType.append(nestedMessage)
			} else if matchKeyword("enum") {
				let nestedEnum = try parseEnum()
				messageDescriptor.enumType.append(nestedEnum)
			} else if matchKeyword("oneof") {
				let oneof = try parseOneof()
				messageDescriptor.oneofDecl.append(oneof.declaration)
				messageDescriptor.field.append(contentsOf: oneof.fields)
			} else if matchKeyword("map") {
				let field = try parseMapField()
				messageDescriptor.field.append(field)
			} else if matchKeyword("reserved") {
				let reservedRanges = try parseReserved()
				messageDescriptor.reservedRange.append(contentsOf: reservedRanges.ranges)
				messageDescriptor.reservedName.append(contentsOf: reservedRanges.names)
				try consumeSymbol(";")
			} else if matchKeyword("extend") {
				let extensions = try parseExtensions()
				messageDescriptor.extension.append(contentsOf: extensions)
			} else if matchKeyword("extensions") {
				let extensionRanges = try parseExtensionRanges()
				messageDescriptor.extensionRange.append(contentsOf: extensionRanges)
				try consumeSymbol(";")
			} else if matchKeyword("option") {
				let option = try parseOption()
//				if messageDescriptor.options == nil {
//					messageDescriptor.options = Google_Protobuf_MessageOptions()
//				}
				messageDescriptor.options.uninterpretedOption.append(option)
				try consumeSymbol(";")
			} else if checkIdentifier() || checkKeyword("repeated") {
				let field = try parseField()
				messageDescriptor.field.append(field)
			} else if matchSymbol(";") {
				advance()
			} else {
				throw error("Unexpected token '\(peek().lexeme)' in message '\(messageDescriptor.name)'")
			}
		}

		try consumeSymbol("}")

		return messageDescriptor
	}

	/// Parses an enum declaration.
	private func parseEnum() throws -> Google_Protobuf_EnumDescriptorProto {
		let enumNameToken = try consumeIdentifier()
		var enumDescriptor = Google_Protobuf_EnumDescriptorProto()
		enumDescriptor.name = enumNameToken.lexeme

		try consumeSymbol("{")

		while !checkSymbol("}") && !isAtEnd() {
			if matchKeyword("option") {
				let option = try parseOption()
//				if enumDescriptor.options == nil {
//					enumDescriptor.options = Google_Protobuf_EnumOptions()
//				}
				enumDescriptor.options.uninterpretedOption.append(option)
				try consumeSymbol(";")
			} else if matchKeyword("reserved") {
				let reservedRanges = try parseReserved()
				enumDescriptor.reservedRange.append(contentsOf: reservedRanges.ranges.map { range in
					var enumRange = Google_Protobuf_EnumDescriptorProto.EnumReservedRange()
					enumRange.start = range.start
					enumRange.end = range.end
					return enumRange
				})
				enumDescriptor.reservedName.append(contentsOf: reservedRanges.names)
				try consumeSymbol(";")
			} else if checkIdentifier() {
				let enumValue = try parseEnumValue()
				enumDescriptor.value.append(enumValue)
			} else if matchSymbol(";") {
				advance()
			} else {
				throw error("Unexpected token '\(peek().lexeme)' in enum '\(enumDescriptor.name)'")
			}
		}

		try consumeSymbol("}")

		return enumDescriptor
	}

	/// Parses a service declaration.
	private func parseService() throws -> Google_Protobuf_ServiceDescriptorProto {
		let serviceNameToken = try consumeIdentifier()
		var serviceDescriptor = Google_Protobuf_ServiceDescriptorProto()
		serviceDescriptor.name = serviceNameToken.lexeme

		try consumeSymbol("{")

		while !checkSymbol("}") && !isAtEnd() {
			if matchKeyword("option") {
				let option = try parseOption()
//				if serviceDescriptor.options == nil {
//					serviceDescriptor.options = Google_Protobuf_ServiceOptions()
//				}
				serviceDescriptor.options.uninterpretedOption.append(option)
				try consumeSymbol(";")
			} else if matchKeyword("rpc") {
				let method = try parseRPCMethod()
				serviceDescriptor.method.append(method)
			} else if matchSymbol(";") {
				advance()
			} else {
				throw error("Unexpected token '\(peek().lexeme)' in service '\(serviceDescriptor.name)'")
			}
		}

		try consumeSymbol("}")

		return serviceDescriptor
	}

	/// Parses extensions.
	private func parseExtensions() throws -> [Google_Protobuf_FieldDescriptorProto] {
		let extendeeType = try parseFullIdentifier()
		try consumeSymbol("{")

		var extensions = [Google_Protobuf_FieldDescriptorProto]()

		while !checkSymbol("}") && !isAtEnd() {
			if checkIdentifier() || checkKeyword("repeated") {
				let field = try parseField(isExtension: true, extendeeType: extendeeType)
				extensions.append(field)
			} else if matchSymbol(";") {
				advance()
			} else {
				throw error("Unexpected token '\(peek().lexeme)' in extensions for '\(extendeeType)'")
			}
		}

		try consumeSymbol("}")

		return extensions
	}

	// MARK: - Parsing Elements

	/// Parses a field declaration.
	private func parseField(isExtension: Bool = false, extendeeType: String = "") throws -> Google_Protobuf_FieldDescriptorProto {
		var label: Google_Protobuf_FieldDescriptorProto.Label = .optional

		if matchKeyword("repeated") {
			label = .repeated
		}

		let typeToken = try consumeType()
		let fieldType = try resolveType(from: typeToken)

		let fieldNameToken = try consumeIdentifier()
		try consumeSymbol("=")
		let fieldNumberToken = try consumeIntegerLiteral()
		guard let fieldNumber = Int32(fieldNumberToken.lexeme) else {
			throw error("Invalid field number '\(fieldNumberToken.lexeme)'")
		}

		var fieldDescriptor = Google_Protobuf_FieldDescriptorProto()
		fieldDescriptor.name = fieldNameToken.lexeme
		fieldDescriptor.number = fieldNumber
		fieldDescriptor.label = label
		fieldDescriptor.type = fieldType.type
		fieldDescriptor.typeName = fieldType.typeName

		if isExtension {
			fieldDescriptor.extendee = ".\(extendeeType)"
		}

		if matchSymbol("[") {
			let options = try parseFieldOptions()
			fieldDescriptor.options = options
			try consumeSymbol("]")
		}

		try consumeSymbol(";")

		return fieldDescriptor
	}

	/// Parses a map field declaration.
	private func parseMapField() throws -> Google_Protobuf_FieldDescriptorProto {
		try consumeSymbol("<")
		let keyTypeToken = try consumeType()
		let keyType = try resolveMapKeyType(from: keyTypeToken)
		try consumeSymbol(",")
		let valueTypeToken = try consumeType()
		let valueType = try resolveType(from: valueTypeToken)
		try consumeSymbol(">")

		let fieldNameToken = try consumeIdentifier()
		try consumeSymbol("=")
		let fieldNumberToken = try consumeIntegerLiteral()
		guard let fieldNumber = Int32(fieldNumberToken.lexeme) else {
			throw error("Invalid field number '\(fieldNumberToken.lexeme)'")
		}

		var fieldDescriptor = Google_Protobuf_FieldDescriptorProto()
		fieldDescriptor.name = fieldNameToken.lexeme
		fieldDescriptor.number = fieldNumber
		fieldDescriptor.label = .repeated
		fieldDescriptor.type = .message
		fieldDescriptor.typeName = ".\(fieldNameForMapEntry(fieldName: fieldDescriptor.name))"

		// Create the MapEntry message type
		var mapEntryDescriptor = Google_Protobuf_DescriptorProto()
		mapEntryDescriptor.name = fieldNameForMapEntry(fieldName: fieldDescriptor.name)
		mapEntryDescriptor.options = Google_Protobuf_MessageOptions()
		mapEntryDescriptor.options.mapEntry = true

		// Key field
		var keyField = Google_Protobuf_FieldDescriptorProto()
		keyField.name = "key"
		keyField.number = 1
		keyField.label = .optional
		keyField.type = keyType.type
		keyField.typeName = keyType.typeName

		// Value field
		var valueField = Google_Protobuf_FieldDescriptorProto()
		valueField.name = "value"
		valueField.number = 2
		valueField.label = .optional
		valueField.type = valueType.type
		valueField.typeName = valueType.typeName

		mapEntryDescriptor.field = [keyField, valueField]

		// Add the MapEntry message to the current message's nested types
		if var parentMessage = getCurrentMessageDescriptor() {
			parentMessage.nestedType.append(mapEntryDescriptor)
			updateCurrentMessageDescriptor(with: parentMessage)
		} else {
			throw error("Map fields must be defined within a message")
		}

		if matchSymbol("[") {
			let options = try parseFieldOptions()
			fieldDescriptor.options = options
			try consumeSymbol("]")
		}

		try consumeSymbol(";")

		return fieldDescriptor
	}

	/// Parses a oneof declaration.
	private func parseOneof() throws -> (declaration: Google_Protobuf_OneofDescriptorProto, fields: [Google_Protobuf_FieldDescriptorProto]) {
		let oneofNameToken = try consumeIdentifier()
		var oneofDescriptor = Google_Protobuf_OneofDescriptorProto()
		oneofDescriptor.name = oneofNameToken.lexeme

		try consumeSymbol("{")

		var fields = [Google_Protobuf_FieldDescriptorProto]()

		while !checkSymbol("}") && !isAtEnd() {
			if checkIdentifier() || checkKeyword("repeated") {
				var field = try parseField()
				field.oneofIndex = Int32(getCurrentOneofIndex())
				fields.append(field)
			} else if matchSymbol(";") {
				advance()
			} else {
				throw error("Unexpected token '\(peek().lexeme)' in oneof '\(oneofDescriptor.name)'")
			}
		}

		try consumeSymbol("}")

		return (declaration: oneofDescriptor, fields: fields)
	}

	/// Parses a reserved statement.
	private func parseReserved() throws -> (ranges: [Google_Protobuf_DescriptorProto.ReservedRange], names: [String]) {
		var ranges = [Google_Protobuf_DescriptorProto.ReservedRange]()
		var names = [String]()

		repeat {
			if checkNumericLiteral() {
				let start = try parseIntValue()
				var end = start
				if matchKeyword("to") {
					if matchKeyword("max") {
						end = Int32.max
					} else {
						end = try parseIntValue()
					}
				}
				var range = Google_Protobuf_DescriptorProto.ReservedRange()
				range.start = start
				range.end = end
				ranges.append(range)
			} else if checkStringLiteral() {
				let nameToken = try consumeStringLiteral()
				names.append(nameToken.lexeme.trimmingCharacters(in: ["\"", "'"]))
			} else {
				throw error("Expected field number or name in reserved statement")
			}
		} while matchSymbol(",")

		return (ranges: ranges, names: names)
	}

	/// Parses an option statement.
	private func parseOption() throws -> Google_Protobuf_UninterpretedOption {
		var option = Google_Protobuf_UninterpretedOption()
		var nameParts = [Google_Protobuf_UninterpretedOption.NamePart]()

		if matchSymbol("(") {
			let name = try parseFullIdentifier()
			nameParts.append(makeNamePart(name: name, isExtension: true))
			try consumeSymbol(")")
		} else {
			let name = try consumeIdentifier()
			nameParts.append(makeNamePart(name: name.lexeme, isExtension: false))
		}

		while matchSymbol(".") {
			let name = try consumeIdentifier()
			nameParts.append(makeNamePart(name: name.lexeme, isExtension: false))
		}

		try consumeSymbol("=")

		let constant = try parseConstant()

		option.name = nameParts

		if let stringValue = constant.stringValue {
			option.stringValue = stringValue
		} else if let positiveIntValue = constant.positiveIntValue {
			option.positiveIntValue = positiveIntValue
		} else if let negativeIntValue = constant.negativeIntValue {
			option.negativeIntValue = negativeIntValue
		} else if let doubleValue = constant.doubleValue {
			option.doubleValue = doubleValue
		} else if let identifierValue = constant.identifierValue {
			option.identifierValue = identifierValue
		} else {
			throw error("Invalid constant value for option")
		}

		return option
	}


	/// Parses a field's options (inside square brackets).
	private func parseFieldOptions() throws -> Google_Protobuf_FieldOptions {
		var options = Google_Protobuf_FieldOptions()
		repeat {
			let option = try parseOption()
			options.uninterpretedOption.append(option)
		} while matchSymbol(",")

		return options
	}

	/// Parses an enum value.
	private func parseEnumValue() throws -> Google_Protobuf_EnumValueDescriptorProto {
		let nameToken = try consumeIdentifier()
		try consumeSymbol("=")
		let numberToken = try consumeIntegerLiteral()
		guard let number = Int32(numberToken.lexeme) else {
			throw error("Invalid enum value number '\(numberToken.lexeme)'")
		}

		var enumValueDescriptor = Google_Protobuf_EnumValueDescriptorProto()
		enumValueDescriptor.name = nameToken.lexeme
		enumValueDescriptor.number = number

		if matchSymbol("[") {
			// Parse enum value options
			let options = try parseEnumValueOptions()
			enumValueDescriptor.options = options
			try consumeSymbol("]")
		}

		try consumeSymbol(";")

		return enumValueDescriptor
	}

	/// Parses enum value options.
	private func parseEnumValueOptions() throws -> Google_Protobuf_EnumValueOptions {
		var options = Google_Protobuf_EnumValueOptions()
		repeat {
			let option = try parseOption()
			options.uninterpretedOption.append(option)
		} while matchSymbol(",")

		return options
	}

	/// Parses a RPC method.
	private func parseRPCMethod() throws -> Google_Protobuf_MethodDescriptorProto {
		let methodNameToken = try consumeIdentifier()
		var methodDescriptor = Google_Protobuf_MethodDescriptorProto()
		methodDescriptor.name = methodNameToken.lexeme

		try consumeSymbol("(")
		let clientStreaming = matchKeyword("stream")
		let inputType = try parseFullIdentifier()
		methodDescriptor.clientStreaming = clientStreaming
		methodDescriptor.inputType = ".\(inputType)"
		try consumeSymbol(")")

		try consumeKeyword("returns")

		try consumeSymbol("(")
		let serverStreaming = matchKeyword("stream")
		let outputType = try parseFullIdentifier()
		methodDescriptor.serverStreaming = serverStreaming
		methodDescriptor.outputType = ".\(outputType)"
		try consumeSymbol(")")

		if matchSymbol("{") {
			while !checkSymbol("}") && !isAtEnd() {
				if matchKeyword("option") {
					let option = try parseOption()
//					if methodDescriptor.options == nil {
//						methodDescriptor.options = Google_Protobuf_MethodOptions()
//					}
					methodDescriptor.options.uninterpretedOption.append(option)
					try consumeSymbol(";")
				} else if matchSymbol(";") {
					advance()
				} else {
					throw error("Unexpected token '\(peek().lexeme)' in method '\(methodDescriptor.name)'")
				}
			}
			try consumeSymbol("}")
		} else {
			try consumeSymbol(";")
		}

		return methodDescriptor
	}

	/// Parses extension ranges.
	private func parseExtensionRanges() throws -> [Google_Protobuf_DescriptorProto.ExtensionRange] {
		var ranges = [Google_Protobuf_DescriptorProto.ExtensionRange]()

		repeat {
			let start = try parseIntValue()
			var end = start
			if matchKeyword("to") {
				if matchKeyword("max") {
					end = Int32.max
				} else {
					end = try parseIntValue()
				}
			}
			var range = Google_Protobuf_DescriptorProto.ExtensionRange()
			range.start = start
			range.end = end
			ranges.append(range)
		} while matchSymbol(",")

		return ranges
	}

	/// Consumes an integer literal token.
	private func consumeIntegerLiteral() throws -> Token {
		if checkNumericLiteral() {
			let token = advance()
			// Verify that the token represents an integer and not a floating-point number.
			if let _ = Int64(token.lexeme) {
				return token
			} else {
				throw error("Expected integer literal, found '\(token.lexeme)'")
			}
		} else {
			throw error("Expected integer literal, found '\(peek().lexeme)'")
		}
	}
		
//	/// Checks if the next token is a numeric literal.
//	private func checkNumericLiteral() -> Bool {
//		if isAtEnd() {
//			return false
//		}
//		if case .numericLiteral(_) = peek().type {
//			return true
//		}
//		return false
//	}
//
//	// Implement other helper methods if not already implemented...
//
//	/// Advances to the next token and returns the previous token.
//	@discardableResult
//	private func advance() -> Token {
//		if !isAtEnd() {
//			current += 1
//		}
//		return previous()
//	}
//
//	/// Peeks at the current token without advancing.
//	private func peek() -> Token {
//		if isAtEnd() {
//			return tokens.last!
//		}
//		return tokens[current]
//	}
//
//	/// Returns the previous token.
//	private func previous() -> Token {
//		return tokens[current - 1]
//	}
//
//	/// Checks if we've reached the end of the tokens.
//	private func isAtEnd() -> Bool {
//		return current >= tokens.count
//	}
//
//	/// Creates and returns a ParserError with the given message.
//	private func error(_ message: String) -> ParserError {
//		let token = peek()
//		return ParserError(message: message, line: token.line, column: token.column)
//	}

	// MARK: - Parsing Helpers

	/// Parses a constant value.
	private func parseConstant() throws -> (stringValue: Data?, positiveIntValue: UInt64?, negativeIntValue: Int64?, doubleValue: Double?, identifierValue: String?) {
		if checkStringLiteral() {
			let token = try consumeStringLiteral()
			let data = token.lexeme.trimmingCharacters(in: ["\"", "'"]).data(using: .utf8) ?? Data()
			return (stringValue: data, positiveIntValue: nil, negativeIntValue: nil, doubleValue: nil, identifierValue: nil)
		} else if checkNumericLiteral() {
			let token = try consumeNumericLiteral()
			if let intValue = Int64(token.lexeme) {
				if intValue >= 0 {
					return (stringValue: nil, positiveIntValue: UInt64(intValue), negativeIntValue: nil, doubleValue: nil, identifierValue: nil)
				} else {
					return (stringValue: nil, positiveIntValue: nil, negativeIntValue: intValue, doubleValue: nil, identifierValue: nil)
				}
			} else if let doubleValue = Double(token.lexeme) {
				return (stringValue: nil, positiveIntValue: nil, negativeIntValue: nil, doubleValue: doubleValue, identifierValue: nil)
			} else {
				throw error("Invalid numeric literal '\(token.lexeme)'")
			}
		} else if checkKeyword("true") || checkKeyword("false") {
			let token = advance()
			return (stringValue: nil, positiveIntValue: nil, negativeIntValue: nil, doubleValue: nil, identifierValue: token.lexeme)
		} else if checkIdentifier() {
			let token = try consumeIdentifier()
			return (stringValue: nil, positiveIntValue: nil, negativeIntValue: nil, doubleValue: nil, identifierValue: token.lexeme)
		} else {
			throw error("Expected a constant value")
		}
	}

	/// Parses a full identifier, including package prefixes.
	private func parseFullIdentifier() throws -> String {
		var identifier = ""
		repeat {
			let token = try consumeIdentifier()
			identifier += token.lexeme
		} while matchSymbol(".") && { identifier += "."; return true }()

		return identifier
	}

	/// Resolves the type from a token.
	private func resolveType(from token: Token) throws -> (type: Google_Protobuf_FieldDescriptorProto.TypeEnum, typeName: String) {
		switch token.lexeme {
		case "double":
			return (.double, "")
		case "float":
			return (.float, "")
		case "int32":
			return (.int32, "")
		case "int64":
			return (.int64, "")
		case "uint32":
			return (.uint32, "")
		case "uint64":
			return (.uint64, "")
		case "sint32":
			return (.sint32, "")
		case "sint64":
			return (.sint64, "")
		case "fixed32":
			return (.fixed32, "")
		case "fixed64":
			return (.fixed64, "")
		case "sfixed32":
			return (.sfixed32, "")
		case "sfixed64":
			return (.sfixed64, "")
		case "bool":
			return (.bool, "")
		case "string":
			return (.string, "")
		case "bytes":
			return (.bytes, "")
		default:
			// User-defined type (message or enum)
			return (.message, ".\(token.lexeme)")
		}
	}

	/// Resolves the map key type from a token.
	private func resolveMapKeyType(from token: Token) throws -> (type: Google_Protobuf_FieldDescriptorProto.TypeEnum, typeName: String) {
		switch token.lexeme {
		case "int32":
			return (.int32, "")
		case "int64":
			return (.int64, "")
		case "uint32":
			return (.uint32, "")
		case "uint64":
			return (.uint64, "")
		case "sint32":
			return (.sint32, "")
		case "sint64":
			return (.sint64, "")
		case "fixed32":
			return (.fixed32, "")
		case "fixed64":
			return (.fixed64, "")
		case "sfixed32":
			return (.sfixed32, "")
		case "sfixed64":
			return (.sfixed64, "")
		case "bool":
			return (.bool, "")
		case "string":
			return (.string, "")
		default:
			throw error("Invalid map key type '\(token.lexeme)'")
		}
	}

	// MARK: - Token Consumption Methods

	/// Consumes an identifier token.
	private func consumeIdentifier() throws -> Token {
		if checkIdentifier() {
			return advance()
		} else {
			throw error("Expected identifier, found '\(peek().lexeme)'")
		}
	}

	/// Consumes a string literal token.
	private func consumeStringLiteral() throws -> Token {
		if checkStringLiteral() {
			return advance()
		} else {
			throw error("Expected string literal, found '\(peek().lexeme)'")
		}
	}

	/// Consumes a numeric literal token.
	private func consumeNumericLiteral() throws -> Token {
		if checkNumericLiteral() {
			return advance()
		} else {
			throw error("Expected numeric literal, found '\(peek().lexeme)'")
		}
	}

	/// Consumes an integer literal and returns its value.
	private func parseIntValue() throws -> Int32 {
		let token = try consumeNumericLiteral()
		guard let value = Int32(token.lexeme) else {
			throw error("Invalid integer literal '\(token.lexeme)'")
		}
		return value
	}

	/// Consumes a type token (identifier or keyword).
	private func consumeType() throws -> Token {
		if checkIdentifier() || checkKeywordType() {
			return advance()
		} else {
			throw error("Expected type, found '\(peek().lexeme)'")
		}
	}

	/// Consumes a specific symbol.
	private func consumeSymbol(_ symbol: String) throws {
		if matchSymbol(symbol) {
			advance()
		} else {
			throw error("Expected symbol '\(symbol)', found '\(peek().lexeme)'")
		}
	}

	/// Consumes a specific keyword.
	private func consumeKeyword(_ keyword: String) throws {
		if matchKeyword(keyword) {
			advance()
		} else {
			throw error("Expected keyword '\(keyword)', found '\(peek().lexeme)'")
		}
	}

	// MARK: - Matching Methods

	/// Checks if the next token is a specific keyword.
	private func matchKeyword(_ keyword: String) -> Bool {
		if checkKeyword(keyword) {
			return true
		}
		return false
	}

	/// Checks if the next token is a specific symbol.
	private func matchSymbol(_ symbol: String) -> Bool {
		if checkSymbol(symbol) {
			return true
		}
		return false
	}

	// MARK: - Checking Methods

	/// Checks if the next token is an identifier.
	private func checkIdentifier() -> Bool {
		if isAtEnd() {
			return false
		}
		if case .identifier(_) = peek().type {
			return true
		}
		return false
	}

	/// Checks if the next token is a string literal.
	private func checkStringLiteral() -> Bool {
		if isAtEnd() {
			return false
		}
		if case .stringLiteral(_) = peek().type {
			return true
		}
		return false
	}

	/// Checks if the next token is a numeric literal.
	private func checkNumericLiteral() -> Bool {
		if isAtEnd() {
			return false
		}
		if case .numericLiteral(_) = peek().type {
			return true
		}
		return false
	}

	/// Checks if the next token is a specific keyword.
	private func checkKeyword(_ keyword: String) -> Bool {
		if isAtEnd() {
			return false
		}
		if case .keyword(let kw) = peek().type {
			return kw == keyword
		}
		return false
	}

	/// Checks if the next token is a type keyword.
	private func checkKeywordType() -> Bool {
		if isAtEnd() {
			return false
		}
		if case .keyword(let kw) = peek().type {
			let typeKeywords: Set<String> = [
				"double", "float", "int32", "int64", "uint32", "uint64", "sint32",
				"sint64", "fixed32", "fixed64", "sfixed32", "sfixed64", "bool", "string", "bytes"
			]
			return typeKeywords.contains(kw)
		}
		return false
	}

	/// Checks if the next token is a specific symbol.
	private func checkSymbol(_ symbol: String) -> Bool {
		if isAtEnd() {
			return false
		}
		if case .symbol(let sym) = peek().type {
			return sym == symbol
		}
		return false
	}

	// MARK: - Helper Methods

	/// Advances to the next token.
	@discardableResult
	private func advance() -> Token {
		if !isAtEnd() {
			current += 1
		}
		return previous()
	}

	/// Peeks at the current token.
	private func peek() -> Token {
		if isAtEnd() {
			return tokens.last!
		}
		return tokens[current]
	}

	/// Gets the previous token.
	private func previous() -> Token {
		return tokens[current - 1]
	}

	/// Checks if we have reached the end of the token list.
	private func isAtEnd() -> Bool {
		return current >= tokens.count
	}

	/// Throws a ParserError with the given message.
	private func error(_ message: String) -> ParserError {
		let token = peek()
		return ParserError(message: message, line: token.line, column: token.column)
	}

	/// Creates a NamePart for an option name.
	private func makeNamePart(name: String, isExtension: Bool) -> Google_Protobuf_UninterpretedOption.NamePart {
		var namePart = Google_Protobuf_UninterpretedOption.NamePart()
		namePart.namePart = name
		namePart.isExtension = isExtension
		return namePart
	}

	/// Generates a name for a map entry message.
	private func fieldNameForMapEntry(fieldName: String) -> String {
		return "\(fieldName)Entry"
	}

	/// Gets the current message descriptor for nested types.
	private func getCurrentMessageDescriptor() -> Google_Protobuf_DescriptorProto? {
		// Implementation depends on how you manage the message context stack.
		// For simplicity, you can maintain a stack of message descriptors.
		return messageContextStack.last
	}

	/// Updates the current message descriptor with changes.
	private func updateCurrentMessageDescriptor(with message: Google_Protobuf_DescriptorProto) {
		// Update the message in the context stack.
		if !messageContextStack.isEmpty {
			messageContextStack[messageContextStack.count - 1] = message
		}
	}

	/// Gets the current oneof index in the message.
	private func getCurrentOneofIndex() -> Int {
		// Return the index of the current oneof declaration.
		if let message = getCurrentMessageDescriptor() {
			return message.oneofDecl.count - 1
		}
		return 0
	}

	// MARK: - Context Stack

	/// Stack to keep track of nested message contexts.
	private var messageContextStack: [Google_Protobuf_DescriptorProto] = []

	/// Pushes a message descriptor onto the context stack.
	private func pushMessageContext(_ message: Google_Protobuf_DescriptorProto) {
		messageContextStack.append(message)
	}

	/// Pops a message descriptor from the context stack.
	private func popMessageContext() {
		_ = messageContextStack.popLast()
	}
}