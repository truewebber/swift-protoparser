import Foundation

/// The SemanticAnalyzer class validates the AST for semantic correctness.
public class SemanticAnalyzer {
	public let ast: ProtoFile
	public var symbolTable = SymbolTable()
	private var errors: [SemanticError] = []
	
	/// Initializes the SemanticAnalyzer with the AST.
	/// - Parameter ast: The AST produced by the parser.
	public init(ast: ProtoFile) {
		self.ast = ast
	}
	
	/// Performs semantic analysis on the AST.
	/// - Throws: `SemanticErrorCollection` if semantic errors are found.
	public func analyze() throws {
		try analyzeSyntax(ast.syntax)
		try analyzePackage(ast.package)
		try analyzeImports(ast.imports)
		try analyzeOptions(ast.options)
		try analyzeDefinitions(ast.definitions)
		
		if !errors.isEmpty {
			throw SemanticErrorCollection(errors: errors)
		}
	}
	
	// MARK: - Analysis Methods
	
	private func analyzeSyntax(_ syntax: Syntax?) throws {
		guard let syntax = syntax else {
			errors.append(SemanticError(
				message: "Missing syntax declaration. 'syntax = \"proto3\";' is required.",
				line: 1,
				column: 1
			))
			return
		}
		if syntax.version != "proto3" {
			errors.append(SemanticError(
				message: "Unsupported syntax version: \(syntax.version). Only 'proto3' is supported.",
				line: syntax.startLine,
				column: syntax.startColumn
			))
		}
	}
	
	private func analyzePackage(_ package: PackageStatement?) throws {
		// Package name validation if needed
	}
	
	private func analyzeImports(_ imports: [ImportStatement]) throws {
		for importStmt in imports {
			// Resolve import paths and handle public/weak modifiers
			// Detect circular dependencies if necessary
		}
	}
	
	private func analyzeOptions(_ options: [ASTOption]) throws {
		for option in options {
			try analyzeOption(option)
		}
	}
	
	private func analyzeOption(_ option: ASTOption) throws {
		// Validate standard and custom options
		// Check option scopes and values
		// For simplicity, we'll assume all options are valid
	}
	
	private func analyzeDefinitions(_ definitions: [TopLevelDefinition]) throws {
		for definition in definitions {
			switch definition {
			case .message(let message):
				try analyzeMessage(message)
			case .enumType(let enumType):
				try analyzeEnum(enumType)
			case .service(let service):
				try analyzeService(service)
			}
		}
	}
	
	private func analyzeMessage(_ message: MessageDeclaration) throws {
		// Check for duplicate message names
		if symbolTable.contains(symbol: message.name) {
			errors.append(SemanticError(
				message: "Duplicate message name: '\(message.name)'.",
				line: message.startLine,
				column: message.startColumn
			))
		} else {
			symbolTable.define(symbol: .message(name: message.name, declaration: message))
		}
		
		symbolTable.enterScope()
		defer { symbolTable.exitScope() }
		
		var fieldNumbers = Set<Int>()
		var fieldNames = Set<String>()
		
		for element in message.body {
			switch element {
			case .field(let field):
				try analyzeField(field, fieldNumbers: &fieldNumbers, fieldNames: &fieldNames)
			case .message(let nestedMessage):
				try analyzeMessage(nestedMessage)
			case .enumType(let enumType):
				try analyzeEnum(enumType)
			case .oneof(let oneof):
				try analyzeOneof(oneof, fieldNumbers: &fieldNumbers, fieldNames: &fieldNames)
			case .option(let option):
				try analyzeOption(option)
			case .reserved(let reserved):
				// Handle reserved fields if necessary
				break
			}
		}
	}
	
	private func analyzeField(_ field: FieldDeclaration, fieldNumbers: inout Set<Int>, fieldNames: inout Set<String>) throws {
		// Check for duplicate field numbers
		if fieldNumbers.contains(field.number) {
			errors.append(SemanticError(
				message: "Duplicate field number \(field.number) in message.",
				line: field.startLine,
				column: field.startColumn
			))
		} else {
			fieldNumbers.insert(field.number)
		}
		
		// Check for duplicate field names
		if fieldNames.contains(field.name) {
			errors.append(SemanticError(
				message: "Duplicate field name '\(field.name)' in message.",
				line: field.startLine,
				column: field.startColumn
			))
		} else {
			fieldNames.insert(field.name)
		}
		
		// Validate field type
		try validateFieldType(field.type, line: field.startLine, column: field.startColumn)
		
		// Validate field options if any
		for option in field.options {
			try analyzeOption(option)
		}
	}
	
	private func analyzeEnum(_ enumType: EnumDeclaration) throws {
		// Check for duplicate enum names
		if symbolTable.contains(symbol: enumType.name) {
			errors.append(SemanticError(
				message: "Duplicate enum name: '\(enumType.name)'.",
				line: enumType.startLine,
				column: enumType.startColumn
			))
		} else {
			symbolTable.define(symbol: .enumType(name: enumType.name, declaration: enumType))
		}
		
		symbolTable.enterScope()
		defer { symbolTable.exitScope() }
		
		var valueNumbers = Set<Int>()
		var valueNames = Set<String>()
		
		for element in enumType.body {
			switch element {
			case .value(let value):
				// Check for duplicate value numbers
				if valueNumbers.contains(value.number) {
					errors.append(SemanticError(
						message: "Duplicate enum value number \(value.number) in enum '\(enumType.name)'.",
						line: value.startLine,
						column: value.startColumn
					))
				} else {
					valueNumbers.insert(value.number)
				}
				
				// Check for duplicate value names
				if valueNames.contains(value.name) {
					errors.append(SemanticError(
						message: "Duplicate enum value name '\(value.name)' in enum '\(enumType.name)'.",
						line: value.startLine,
						column: value.startColumn
					))
				} else {
					valueNames.insert(value.name)
				}
				
				// Validate enum value options if any
				for option in value.options {
					try analyzeOption(option)
				}
			case .option(let option):
				try analyzeOption(option)
			case .reserved(let reserved):
				// Handle reserved values if necessary
				break
			}
		}
		
		// Ensure first enum value has number 0
		if !valueNumbers.contains(0) {
			errors.append(SemanticError(
				message: "The first enum value in '\(enumType.name)' must have the number zero (0).",
				line: enumType.startLine,
				column: enumType.startColumn
			))
		}
	}
	
	private func analyzeService(_ service: ServiceDeclaration) throws {
		// Check for duplicate service names
		if symbolTable.contains(symbol: service.name) {
			errors.append(SemanticError(
				message: "Duplicate service name: '\(service.name)'.",
				line: service.startLine,
				column: service.startColumn
			))
		} else {
			symbolTable.define(symbol: .service(name: service.name, declaration: service))
		}
		
		symbolTable.enterScope()
		defer { symbolTable.exitScope() }
		
		var methodNames = Set<String>()
		
		for element in service.body {
			switch element {
			case .rpc(let rpcMethod):
				// Check for duplicate method names
				if methodNames.contains(rpcMethod.name) {
					errors.append(SemanticError(
						message: "Duplicate method name '\(rpcMethod.name)' in service '\(service.name)'.",
						line: rpcMethod.startLine,
						column: rpcMethod.startColumn
					))
				} else {
					methodNames.insert(rpcMethod.name)
				}
				
				// Validate input and output types
				try validateTypeName(rpcMethod.inputType, line: rpcMethod.startLine, column: rpcMethod.startColumn)
				try validateTypeName(rpcMethod.outputType, line: rpcMethod.startLine, column: rpcMethod.startColumn)
				
				// Validate method options if any
				for option in rpcMethod.options {
					try analyzeOption(option)
				}
			case .option(let option):
				try analyzeOption(option)
			}
		}
	}
	
	private func analyzeOneof(_ oneof: OneofDeclaration, fieldNumbers: inout Set<Int>, fieldNames: inout Set<String>) throws {
		// Check for duplicate oneof names
		if symbolTable.contains(symbol: oneof.name) {
			errors.append(SemanticError(
				message: "Duplicate oneof name: '\(oneof.name)'.",
				line: oneof.startLine,
				column: oneof.startColumn
			))
		} else {
			symbolTable.define(symbol: .oneof(name: oneof.name, declaration: oneof))
		}
		
		var oneofFieldNumbers = Set<Int>()
		var oneofFieldNames = Set<String>()
		
		for field in oneof.fields {
			// Check for duplicate field numbers
			if fieldNumbers.contains(field.number) || oneofFieldNumbers.contains(field.number) {
				errors.append(SemanticError(
					message: "Duplicate field number \(field.number) in oneof '\(oneof.name)'.",
					line: field.startLine,
					column: field.startColumn
				))
			} else {
				fieldNumbers.insert(field.number)
				oneofFieldNumbers.insert(field.number)
			}
			
			// Check for duplicate field names
			if fieldNames.contains(field.name) || oneofFieldNames.contains(field.name) {
				errors.append(SemanticError(
					message: "Duplicate field name '\(field.name)' in oneof '\(oneof.name)'.",
					line: field.startLine,
					column: field.startColumn
				))
			} else {
				fieldNames.insert(field.name)
				oneofFieldNames.insert(field.name)
			}
			
			// Validate field type
			try validateFieldType(field.type, line: field.startLine, column: field.startColumn)
			
			// Validate field options if any
			for option in field.options {
				try analyzeOption(option)
			}
		}
	}
	
	// MARK: - Validation Helpers
	
	private func validateFieldType(_ typeName: String, line: Int, column: Int) throws {
		if isScalarType(typeName) {
			// Valid scalar type
		} else if symbolTable.resolve(name: typeName) != nil {
			// Type exists (message or enum)
		} else {
			errors.append(SemanticError(
				message: "Undefined type '\(typeName)'.",
				line: line,
				column: column
			))
		}
	}
	
	private func validateTypeName(_ typeName: String, line: Int, column: Int) throws {
		if symbolTable.resolve(name: typeName) != nil {
			// Type exists
		} else {
			errors.append(SemanticError(
				message: "Undefined type '\(typeName)'.",
				line: line,
				column: column
			))
		}
	}
	
	private func isScalarType(_ typeName: String) -> Bool {
		let scalarTypes = [
			"double", "float", "int32", "int64", "uint32", "uint64",
			"sint32", "sint64", "fixed32", "fixed64", "sfixed32", "sfixed64",
			"bool", "string", "bytes"
		]
		return scalarTypes.contains(typeName)
	}
}

// MARK: - Symbol Table

public class SymbolTable {
	private var scopes: [Scope] = [Scope()] // Initialize with a global scope

	public init() {}

	public func enterScope() {
		scopes.append(Scope())
	}

	public func exitScope() {
		scopes.removeLast()
	}

	public func define(symbol: Symbol) {
		scopes.last?.symbols[symbol.name] = symbol
	}

	public func contains(symbol name: String) -> Bool {
		for scope in scopes.reversed() {
			if scope.symbols[name] != nil {
				return true
			}
		}
		return false
	}

	public func resolve(name: String) -> Symbol? {
		for scope in scopes.reversed() {
			if let symbol = scope.symbols[name] {
				return symbol
			}
		}
		return nil
	}
}

public class Scope {
	var symbols: [String: Symbol] = [:]
}

public enum Symbol {
	case message(name: String, declaration: MessageDeclaration)
	case enumType(name: String, declaration: EnumDeclaration)
	case service(name: String, declaration: ServiceDeclaration)
	case oneof(name: String, declaration: OneofDeclaration)
	// Add more symbol types as needed

	var name: String {
		switch self {
		case .message(let name, _):
			return name
		case .enumType(let name, _):
			return name
		case .service(let name, _):
			return name
		case .oneof(let name, _):
			return name
		}
	}
}
