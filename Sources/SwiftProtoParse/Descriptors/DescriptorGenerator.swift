import Foundation

/// Generates protocol descriptors from the AST and symbol table.
public class DescriptorGenerator {
	private let ast: ProtoFile
	private let symbolTable: SymbolTable
	
	/// Initializes the DescriptorGenerator with the AST and SymbolTable.
	/// - Parameters:
	///   - ast: The AST produced by the parser.
	///   - symbolTable: The symbol table built during semantic analysis.
	public init(ast: ProtoFile, symbolTable: SymbolTable) {
		self.ast = ast
		self.symbolTable = symbolTable
	}
	
	/// Generates and returns a `FileDescriptor`.
	public func generate() -> FileDescriptor {
		var messages = [DescriptorProto]()
		var enums = [EnumDescriptorProto]()
		var services = [ServiceDescriptorProto]()
		
		for definition in ast.definitions {
			switch definition {
			case .message(let message):
				let descriptor = generateMessageDescriptor(message)
				messages.append(descriptor)
			case .enumType(let enumType):
				let descriptor = generateEnumDescriptor(enumType)
				enums.append(descriptor)
			case .service(let service):
				let descriptor = generateServiceDescriptor(service)
				services.append(descriptor)
			}
		}
		
		let fileDescriptor = FileDescriptor(
			syntax: ast.syntax?.version ?? "proto3",
			package: ast.package?.name,
			dependencies: ast.imports.map { $0.path },
			messages: messages,
			enums: enums,
			services: services,
			options: ast.options.map { generateOption($0) }
		)
		
		return fileDescriptor
	}
	
	// Implement methods to generate descriptors for messages, enums, services, fields, etc.
	
	private func generateMessageDescriptor(_ message: MessageDeclaration) -> DescriptorProto {
		var fields = [FieldDescriptorProto]()
		var nestedTypes = [DescriptorProto]()
		var enumTypes = [EnumDescriptorProto]()
		var oneofs = [OneofDescriptorProto]()
		
		for element in message.body {
			switch element {
			case .field(let field):
				let fieldDescriptor = generateFieldDescriptor(field)
				fields.append(fieldDescriptor)
			case .message(let nestedMessage):
				let nestedDescriptor = generateMessageDescriptor(nestedMessage)
				nestedTypes.append(nestedDescriptor)
			case .enumType(let enumType):
				let enumDescriptor = generateEnumDescriptor(enumType)
				enumTypes.append(enumDescriptor)
			case .oneof(let oneof):
				let oneofDescriptor = generateOneofDescriptor(oneof)
				oneofs.append(oneofDescriptor)
			default:
				// Handle other elements as needed
				break
			}
		}
		
		let descriptor = DescriptorProto(
			name: message.name,
			fields: fields,
			nestedTypes: nestedTypes,
			enumTypes: enumTypes,
			oneofs: oneofs,
			options: [] // Add message options if any
		)
		
		return descriptor
	}
	
	private func generateFieldDescriptor(_ field: FieldDeclaration) -> FieldDescriptorProto {
		let label: FieldDescriptorProto.Label = field.label == .repeated ? .repeated : .optional
		let fieldType = mapFieldType(field.type)
		
		let descriptor = FieldDescriptorProto(
			name: field.name,
			number: Int32(field.number),
			label: label,
			type: fieldType,
			typeName: nil, // Set if the type is a message or enum
			options: field.options.map { generateOption($0) }
		)
		
		return descriptor
	}
	
	private func generateEnumDescriptor(_ enumType: EnumDeclaration) -> EnumDescriptorProto {
		var values = [EnumValueDescriptorProto]()
		
		for element in enumType.body {
			if case .value(let enumValue) = element {
				let valueDescriptor = EnumValueDescriptorProto(
					name: enumValue.name,
					number: Int32(enumValue.number),
					options: enumValue.options.map { generateOption($0) }
				)
				values.append(valueDescriptor)
			}
		}
		
		let descriptor = EnumDescriptorProto(
			name: enumType.name,
			values: values,
			options: [] // Add enum options if any
		)
		
		return descriptor
	}
	
	private func generateServiceDescriptor(_ service: ServiceDeclaration) -> ServiceDescriptorProto {
		var methods = [MethodDescriptorProto]()
		
		for element in service.body {
			if case .rpc(let rpcMethod) = element {
				let methodDescriptor = MethodDescriptorProto(
					name: rpcMethod.name,
					inputType: rpcMethod.inputType,
					outputType: rpcMethod.outputType,
					clientStreaming: rpcMethod.isClientStreaming,
					serverStreaming: rpcMethod.isServerStreaming,
					options: rpcMethod.options.map { generateOption($0) }
				)
				methods.append(methodDescriptor)
			}
		}
		
		let descriptor = ServiceDescriptorProto(
			name: service.name,
			methods: methods,
			options: [] // Add service options if any
		)
		
		return descriptor
	}
	
	private func generateOneofDescriptor(_ oneof: OneofDeclaration) -> OneofDescriptorProto {
		let fields = oneof.fields.map { generateFieldDescriptor($0) }
		let descriptor = OneofDescriptorProto(
			name: oneof.name,
			fields: fields,
			options: [] // Add oneof options if any
		)
		return descriptor
	}
	
	private func generateOption(_ option: ASTOption) -> Option {
		let optionValue = mapOptionValue(option.value)
		return Option(name: option.name, value: optionValue)
	}
	
	// Helper methods
	
	private func mapFieldType(_ typeName: String) -> FieldType {
		switch typeName {
		case "int32": return .int32
		case "int64": return .int64
		case "uint32": return .uint32
		case "uint64": return .uint64
		case "sint32": return .sint32
		case "sint64": return .sint64
		case "fixed32": return .fixed32
		case "fixed64": return .fixed64
		case "sfixed32": return .sfixed32
		case "sfixed64": return .sfixed64
		case "float": return .float
		case "double": return .double
		case "bool": return .bool
		case "string": return .string
		case "bytes": return .bytes
		default:
			// Assume it's a message or enum type
			if let _ = symbolTable.resolve(name: typeName) {
				// You may need to differentiate between messages and enums
				return .message(typeName)
			} else {
				// Handle unknown type or throw an error
				return .message(typeName)
			}
		}
	}
	
	private func mapOptionValue(_ value: ASTOptionValue) -> OptionValue {
		switch value {
		case .string(let str):
			return .string(str)
		case .number(let num):
			return .number(num)
		case .boolean(let bool):
			return .boolean(bool)
		case .aggregate(let optionStatements):
			let mappedOptions = optionStatements.map { generateOption($0) }
			return .aggregate(mappedOptions) // Now returns OptionValue.aggregate([Option])
		}
	}
}
