import Foundation

/// The Parser class parses tokens into an AST representing the .proto file structure.
public class Parser {
	private let tokens: [Token]
	private var current: Int = 0
	private var errors: [SyntaxError] = []
	
	/// Initializes the Parser with a list of tokens.
	/// - Parameter tokens: An array of tokens produced by the lexer.
	public init(tokens: [Token]) {
		self.tokens = tokens
	}

	/// Parses the tokens and returns a ProtoFile AST node.
	public func parse() throws -> ProtoFile {
		let startToken = peek()
		let syntax = try parseSyntax()
		let imports = try parseImports()
		let package = try parsePackage()
		let options = try parseOptions()
		let definitions = try parseTopLevelDefinitions()
		return ProtoFile(
			syntax: syntax,
			imports: imports,
			package: package,
			options: options,
			definitions: definitions,
			startLine: startToken.line,
			startColumn: startToken.column
		)
	}

	// MARK: - Parsing Methods

	/// Parses the syntax declaration.
	private func parseSyntax() throws -> Syntax? {
		if matchKeyword("syntax") {
			let syntaxToken = previous()
			try consumeSymbol("=")
			let versionToken = try consumeStringLiteral()
			try consumeSymbol(";")
			
			let version = unquote(versionToken.lexeme)
			if version != "proto3" {
				throw SyntaxError(
					message: "Unsupported syntax version: \(version). Only 'proto3' is supported.",
					line: versionToken.line,
					column: versionToken.column
				)
			}
			
			return Syntax(
				version: version,
				startLine: syntaxToken.line,
				startColumn: syntaxToken.column
			)
		}
		return nil
	}

	/// Parses import statements.
	private func parseImports() throws -> [ImportStatement] {
		var imports = [ImportStatement]()
		while matchKeyword("import") {
			let importToken = previous()
			var modifier: ImportStatement.Modifier = .none
			if matchKeyword("public") {
				modifier = .publicImport
			} else if matchKeyword("weak") {
				modifier = .weak
			}
			let pathToken = try consumeStringLiteral()
			try consumeSymbol(";")
			let path = unquote(pathToken.lexeme)
			let importStatement = ImportStatement(
				modifier: modifier,
				path: path,
				startLine: importToken.line,
				startColumn: importToken.column
			)
			imports.append(importStatement)
		}
		return imports
	}

	/// Parses the package declaration.
	private func parsePackage() throws -> PackageStatement? {
		if matchKeyword("package") {
			let packageToken = previous()
			let nameToken = try consumeFullIdentifier()
			try consumeSymbol(";")
			return PackageStatement(
				name: nameToken.lexeme,
				startLine: packageToken.line,
				startColumn: packageToken.column
			)
		}
		return nil
	}

	/// Parses option statements.
	private func parseOptions() throws -> [ASTOption] {
		var options = [ASTOption]()
		while matchKeyword("option") {
			let option = try parseOptionStatement()
			options.append(option)
		}
		return options
	}

	/// Parses top-level definitions (messages, enums, services, etc.).
	private func parseTopLevelDefinitions() throws -> [TopLevelDefinition] {
		var definitions = [TopLevelDefinition]()
		while !isAtEnd() {
			if matchKeyword("message") {
				let message = try parseMessage()
				definitions.append(.message(message))
			} else if matchKeyword("enum") {
				let enumType = try parseEnum()
				definitions.append(.enumType(enumType))
			} else if matchKeyword("service") {
				let service = try parseService()
				definitions.append(.service(service))
			} else if matchSymbol(";") {
				// Ignore empty statements
				advance()
			} else {
				throw SyntaxError(
					message: "Unexpected token '\(peek().lexeme)'",
					line: peek().line,
					column: peek().column
				)
			}
		}
		return definitions
	}

	// Implementations of parseMessage(), parseEnum(), parseService(), parseOptionStatement(), etc., go here.
	// For brevity, I'll provide implementations for parseOptionStatement(), parseMessage(), and parseEnum().

	/// Parses an option statement.
	private func parseOptionStatement() throws -> ASTOption {
		let optionToken = previous()
		let nameToken = try parseOptionName()
		try consumeSymbol("=")
		let value = try parseConstant()
		try consumeSymbol(";")
		return ASTOption(
			name: nameToken.lexeme,
			value: value,
			startLine: optionToken.line,
			startColumn: optionToken.column
		)
	}

	/// Parses a message declaration.
	private func parseMessage() throws -> MessageDeclaration {
		let messageToken = previous()
		let nameToken = try consumeIdentifier()
		try consumeSymbol("{")
		var body = [MessageElement]()
		while !checkSymbol("}") && !isAtEnd() {
			if matchKeyword("option") {
				let option = try parseOptionStatement()
				body.append(.option(option))
			} else if matchKeyword("message") {
				let nestedMessage = try parseMessage()
				body.append(.message(nestedMessage))
			} else if matchKeyword("enum") {
				let enumType = try parseEnum()
				body.append(.enumType(enumType))
			} else if matchKeyword("oneof") {
				let oneof = try parseOneof()
				body.append(.oneof(oneof))
			} else if matchKeyword("reserved") {
				let reserved = try parseReserved()
				body.append(.reserved(reserved))
			} else if matchKeyword("repeated") || checkIdentifier() {
				let field = try parseField()
				body.append(.field(field))
			} else if matchSymbol(";") {
				advance()
			} else {
				throw SyntaxError(
					message: "Unexpected token '\(peek().lexeme)' in message body",
					line: peek().line,
					column: peek().column
				)
			}
		}
		try consumeSymbol("}")
		return MessageDeclaration(
			name: nameToken.lexeme,
			body: body,
			startLine: messageToken.line,
			startColumn: messageToken.column
		)
	}

	/// Parses an enum declaration.
	private func parseEnum() throws -> EnumDeclaration {
		let enumToken = previous()
		let nameToken = try consumeIdentifier()
		try consumeSymbol("{")
		var body = [EnumElement]()
		while !checkSymbol("}") && !isAtEnd() {
			if matchKeyword("option") {
				let option = try parseOptionStatement()
				body.append(.option(option))
			} else if matchKeyword("reserved") {
				let reserved = try parseReserved()
				body.append(.reserved(reserved))
			} else if checkIdentifier() {
				let value = try parseEnumValue()
				body.append(.value(value))
			} else if matchSymbol(";") {
				advance()
			} else {
				throw SyntaxError(
					message: "Unexpected token '\(peek().lexeme)' in enum body",
					line: peek().line,
					column: peek().column
				)
			}
		}
		try consumeSymbol("}")
		return EnumDeclaration(
			name: nameToken.lexeme,
			body: body,
			startLine: enumToken.line,
			startColumn: enumToken.column
		)
	}

	/// Parses a service declaration.
	private func parseService() throws -> ServiceDeclaration {
		let serviceToken = previous()
		let nameToken = try consumeIdentifier()
		try consumeSymbol("{")
		var body = [ServiceElement]()
		while !checkSymbol("}") && !isAtEnd() {
			if matchKeyword("option") {
				let option = try parseOptionStatement()
				body.append(.option(option))
			} else if matchKeyword("rpc") {
				let rpcMethod = try parseRPCMethod()
				body.append(.rpc(rpcMethod))
			} else if matchSymbol(";") {
				advance()
			} else {
				throw SyntaxError(
					message: "Unexpected token '\(peek().lexeme)' in service body",
					line: peek().line,
					column: peek().column
				)
			}
		}
		try consumeSymbol("}")
		return ServiceDeclaration(
			name: nameToken.lexeme,
			body: body,
			startLine: serviceToken.line,
			startColumn: serviceToken.column
		)
	}

	// MARK: - Helper Parsing Methods

	/// Parses an option name, handling both simple and custom options.
	private func parseOptionName() throws -> Token {
		if matchSymbol("(") {
			var fullName = "("
			while !checkSymbol(")") && !isAtEnd() {
				let token = advance()
				fullName += token.lexeme
			}
			try consumeSymbol(")")
			fullName += ")"
			return Token(
				type: .identifier(fullName),
				lexeme: fullName,
				line: previous().line,
				column: previous().column
			)
		} else {
			return try consumeFullIdentifier()
		}
	}

	/// Parses a constant value used in options.
	private func parseConstant() throws -> ASTOptionValue {
		let token = peek()
		switch token.type {
		case .stringLiteral(let str):
			advance()
			return .string(unquote(str))
		case .numericLiteral(let num):
			advance()
			return .number(num)
		case .booleanLiteral(let bool):
			advance()
			return .boolean(bool)
		case .identifier(_):
			// Handle enum values or identifiers
			let identifierToken = advance()
			return .string(identifierToken.lexeme)
		case .symbol("{"):
			return try parseAggregateOptionValue()
		default:
			throw SyntaxError(
				message: "Invalid constant value '\(token.lexeme)'",
				line: token.line,
				column: token.column
			)
		}
	}

	/// Parses an aggregate option value.
	private func parseAggregateOptionValue() throws -> ASTOptionValue {
		try consumeSymbol("{")
		var options = [ASTOption]()
		while !checkSymbol("}") && !isAtEnd() {
			let nameToken = try parseOptionName()
			try consumeSymbol(":")
			let value = try parseConstant()
			let option = ASTOption(
				name: nameToken.lexeme,
				value: value,
				startLine: nameToken.line,
				startColumn: nameToken.column
			)
			options.append(option)
			if checkSymbol(",") {
				advance()
			}
		}
		try consumeSymbol("}")
		return .aggregate(options)
	}

	/// Parses a field declaration.
	private func parseField() throws -> FieldDeclaration {
		let label: FieldLabel
		if matchKeyword("repeated") {
			label = .repeated
		} else {
			label = .optional
		}
		let typeToken = try consumeType()
		let nameToken = try consumeIdentifier()
		try consumeSymbol("=")
		let numberToken = try consumeIntegerLiteral()
		var options = [ASTOption]()
		if matchSymbol("[") {
			options = try parseFieldOptions()
		}
		try consumeSymbol(";")
		return FieldDeclaration(
			label: label,
			type: typeToken.lexeme,
			name: nameToken.lexeme,
			number: Int(numberToken.lexeme)!,
			options: options,
			startLine: typeToken.line,
			startColumn: typeToken.column
		)
	}

	/// Parses field options within square brackets.
	private func parseFieldOptions() throws -> [ASTOption] {
		var options = [ASTOption]()
		repeat {
			let option = try parseOptionStatement()
			options.append(option)
		} while matchSymbol(",")
		try consumeSymbol("]")
		return options
	}

	/// Parses a oneof declaration.
	private func parseOneof() throws -> OneofDeclaration {
		let oneofToken = previous()
		let nameToken = try consumeIdentifier()
		try consumeSymbol("{")
		var fields = [FieldDeclaration]()
		while !checkSymbol("}") && !isAtEnd() {
			if matchSymbol(";") {
				advance()
			} else {
				let field = try parseOneofField()
				fields.append(field)
			}
		}
		try consumeSymbol("}")
		return OneofDeclaration(
			name: nameToken.lexeme,
			fields: fields,
			startLine: oneofToken.line,
			startColumn: oneofToken.column
		)
	}

	/// Parses a field within a oneof declaration.
	private func parseOneofField() throws -> FieldDeclaration {
		let typeToken = try consumeType()
		let nameToken = try consumeIdentifier()
		try consumeSymbol("=")
		let numberToken = try consumeIntegerLiteral()
		var options = [ASTOption]()
		if matchSymbol("[") {
			options = try parseFieldOptions()
		}
		try consumeSymbol(";")
		return FieldDeclaration(
			label: .optional,
			type: typeToken.lexeme,
			name: nameToken.lexeme,
			number: Int(numberToken.lexeme)!,
			options: options,
			startLine: typeToken.line,
			startColumn: typeToken.column
		)
	}

	/// Parses a reserved statement.
	private func parseReserved() throws -> ReservedStatement {
		let reservedToken = previous()
		var numbers = [ReservedRange]()
		var names = [String]()
		
		repeat {
			if checkStringLiteral() {
				let nameToken = try consumeStringLiteral()
				names.append(unquote(nameToken.lexeme))
			} else {
				let startToken = try consumeIntegerLiteral()
				var end: Int?
				if matchSymbol("to") {
					if matchKeyword("max") {
						end = nil
					} else {
						let endToken = try consumeIntegerLiteral()
						end = Int(endToken.lexeme)
					}
				} else {
					end = Int(startToken.lexeme)
				}
				let range = ReservedRange(start: Int(startToken.lexeme)!, end: end)
				numbers.append(range)
			}
		} while matchSymbol(",")
		
		try consumeSymbol(";")
		return ReservedStatement(
			numbers: numbers,
			names: names,
			startLine: reservedToken.line,
			startColumn: reservedToken.column
		)
	}

	/// Parses an enum value.
	private func parseEnumValue() throws -> EnumValue {
		let nameToken = try consumeIdentifier()
		try consumeSymbol("=")
		let numberToken = try consumeIntegerLiteral()
		var options = [ASTOption]()
		if matchSymbol("[") {
			options = try parseFieldOptions()
		}
		try consumeSymbol(";")
		return EnumValue(
			name: nameToken.lexeme,
			number: Int(numberToken.lexeme)!,
			options: options,
			startLine: nameToken.line,
			startColumn: nameToken.column
		)
	}

	/// Parses an RPC method within a service.
	private func parseRPCMethod() throws -> RPCMethod {
		let rpcToken = previous()
		let nameToken = try consumeIdentifier()
		try consumeSymbol("(")
		let clientStreaming = matchKeyword("stream")
		let inputTypeToken = try consumeType()
		try consumeSymbol(")")
		try consumeKeyword("returns")
		try consumeSymbol("(")
		let serverStreaming = matchKeyword("stream")
		let outputTypeToken = try consumeType()
		try consumeSymbol(")")
		var options = [ASTOption]()
		if matchSymbol("{") {
			while !checkSymbol("}") && !isAtEnd() {
				if matchKeyword("option") {
					let option = try parseOptionStatement()
					options.append(option)
				} else if matchSymbol(";") {
					advance()
				} else {
					throw SyntaxError(
						message: "Unexpected token '\(peek().lexeme)' in RPC method options",
						line: peek().line,
						column: peek().column
					)
				}
			}
			try consumeSymbol("}")
		} else {
			try consumeSymbol(";")
		}
		return RPCMethod(
			name: nameToken.lexeme,
			inputType: inputTypeToken.lexeme,
			outputType: outputTypeToken.lexeme,
			isClientStreaming: clientStreaming,
			isServerStreaming: serverStreaming,
			options: options,
			startLine: rpcToken.line,
			startColumn: rpcToken.column
		)
	}

	// MARK: - Token Consumption Methods

	/// Consumes a type token (built-in or user-defined).
	private func consumeType() throws -> Token {
		if checkIdentifier() {
			return advance()
		} else {
			throw SyntaxError(
				message: "Expected type but found '\(peek().lexeme)'",
				line: peek().line,
				column: peek().column
			)
		}
	}

	/// Consumes a full identifier (can include dots for package prefixes).
	private func consumeFullIdentifier() throws -> Token {
		var lexeme = ""
		let startToken = peek()
		while checkIdentifier() || checkSymbol(".") {
			lexeme += peek().lexeme
			advance()
		}
		if lexeme.isEmpty {
			throw SyntaxError(
				message: "Expected identifier but found '\(peek().lexeme)'",
				line: peek().line,
				column: peek().column
			)
		}
		return Token(
			type: .identifier(lexeme),
			lexeme: lexeme,
			line: startToken.line,
			column: startToken.column
		)
	}

	/// Consumes an integer literal.
	private func consumeIntegerLiteral() throws -> Token {
		if case .numericLiteral(let numStr) = peek().type, Int(numStr) != nil {
			return advance()
		} else {
			throw SyntaxError(
				message: "Expected integer literal but found '\(peek().lexeme)'",
				line: peek().line,
				column: peek().column
			)
		}
	}

	/// Consumes a string literal.
	private func consumeStringLiteral() throws -> Token {
		if case .stringLiteral(_) = peek().type {
			return advance()
		} else {
			throw SyntaxError(
				message: "Expected string literal but found '\(peek().lexeme)'",
				line: peek().line,
				column: peek().column
			)
		}
	}

	/// Consumes an identifier.
	private func consumeIdentifier() throws -> Token {
		if checkIdentifier() {
			return advance()
		} else {
			throw SyntaxError(
				message: "Expected identifier but found '\(peek().lexeme)'",
				line: peek().line,
				column: peek().column
			)
		}
	}

	/// Consumes a specific keyword.
	private func consumeKeyword(_ keyword: String) throws {
		if checkKeyword(keyword) {
			advance()
		} else {
			throw SyntaxError(
				message: "Expected keyword '\(keyword)' but found '\(peek().lexeme)'",
				line: peek().line,
				column: peek().column
			)
		}
	}

	/// Consumes a specific symbol.
	private func consumeSymbol(_ symbol: String) throws {
		if checkSymbol(symbol) {
			advance()
		} else {
			throw SyntaxError(
				message: "Expected symbol '\(symbol)' but found '\(peek().lexeme)'",
				line: peek().line,
				column: peek().column
			)
		}
	}

	// MARK: - Token Matching Methods
	
	/// Checks if the current token is a keyword and matches the given keyword.
	private func matchKeyword(_ keyword: String) -> Bool {
		if checkKeyword(keyword) {
			advance()
			return true
		}
		return false
	}

	/// Checks if the current token is a symbol and matches the given symbol.
	private func matchSymbol(_ symbol: String) -> Bool {
		if checkSymbol(symbol) {
			advance()
			return true
		}
		return false
	}
	
	// MARK: - Token Checking Methods
	
	private func checkKeyword(_ keyword: String) -> Bool {
		if isAtEnd() { return false }
		if case let .keyword(lexeme) = peek().type {
			return lexeme == keyword
		}
		return false
	}
	
	private func checkSymbol(_ symbol: String) -> Bool {
		if isAtEnd() { return false }
		if case let .symbol(lexeme) = peek().type {
			return lexeme == symbol
		}
		return false
	}
	
	private func checkIdentifier() -> Bool {
		if isAtEnd() { return false }
		if case .identifier(_) = peek().type {
			return true
		}
		return false
	}
	
	private func checkStringLiteral() -> Bool {
		if isAtEnd() { return false }
		if case .stringLiteral(_) = peek().type {
			return true
		}
		return false
	}
	
	// MARK: - Token Management Methods
	
	private func advance() -> Token {
		if !isAtEnd() {
			current += 1
		}
		return previous()
	}
	
	private func peek() -> Token {
		return tokens[current]
	}
	
	private func previous() -> Token {
		return tokens[current - 1]
	}
	
	private func isAtEnd() -> Bool {
		return peek().type == .eof
	}
	
	private func unquote(_ string: String) -> String {
		var result = string
		if result.hasPrefix("\"") || result.hasPrefix("'") {
			result.removeFirst()
		}
		if result.hasSuffix("\"") || result.hasSuffix("'") {
			result.removeLast()
		}
		return result
	}
}

