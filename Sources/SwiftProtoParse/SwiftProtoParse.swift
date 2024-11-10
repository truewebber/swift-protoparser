import Foundation

// Import the necessary modules from the library
// Assuming the modules are in the same package or accessible
// If modules are in different files, ensure they are part of the same module or import them appropriately

// Note: Replace 'ModuleName' with the actual module name if needed
// import ModuleName

/// The main class for the SwiftProtoParse library.
public class SwiftProtoParse {
	
	/// Parses the given .proto file content and returns a `FileDescriptor`.
	///
	/// - Parameter protoContent: The content of the .proto file as a `String`.
	/// - Throws: An error if parsing fails at any stage (lexical, syntactic, semantic).
	/// - Returns: A `FileDescriptor` representing the parsed .proto file.
	public static func parse(protoContent: String) throws -> FileDescriptor {
		// Lexical Analysis
		let lexer = Lexer(input: protoContent)
		let tokens: [Token]
		do {
			tokens = try lexer.tokenize()
		} catch let error as ParseError {
			// Handle lexical errors
			throw error
		}
		
		// Syntax Parsing
		let parser = Parser(tokens: tokens)
		let ast: ProtoFile
		do {
			ast = try parser.parse()
		} catch let error as ParseError {
			// Handle syntax errors
			throw error
		}
		
		// Semantic Analysis
		let analyzer = SemanticAnalyzer(ast: ast)
		do {
			try analyzer.analyze()
		} catch let error as SemanticErrorCollection {
			// Handle semantic errors
			throw error
		}
		
		// Descriptor Generation
		let generator = DescriptorGenerator(ast: ast, symbolTable: analyzer.symbolTable)
		let fileDescriptor = generator.generate()
		
		return fileDescriptor
	}
}
