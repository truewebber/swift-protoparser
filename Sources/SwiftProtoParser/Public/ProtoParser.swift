import Foundation
import SwiftProtobuf

/// Main proto parser interface
public final class ProtoParser {
  /// Configuration for the parser
  private let configuration: Configuration

  /// Symbol table for type resolution
  private let symbolTable: SymbolTable

  /// Import resolver for handling imports
  private let importResolver: ImportResolver

  /// Initialize a new proto parser
  /// - Parameter configuration: Parser configuration
  public init(configuration: Configuration = Configuration()) {
    self.configuration = configuration
    self.symbolTable = SymbolTable()

    let fileProvider = DefaultFileProvider(importPaths: configuration.importPaths)

    // Changed the closure to return FileNode instead of descriptor
    self.importResolver = ImportResolver(fileProvider: fileProvider) { path, content in
      // Create lexer and parser for the imported content
      let lexer = Lexer(input: content)
      let parser = try Parser(lexer: lexer)
      // Return FileNode with the file path
      return try parser.parseFile(filePath: path)
    }
  }

  /// Parse a proto file
  /// - Parameter path: Path to the file
  /// - Returns: File descriptor proto
  /// - Throws: ProtoParserError if parsing fails
  public func parseFile(_ path: String) throws -> Google_Protobuf_FileDescriptorProto {
    let fileProvider = DefaultFileProvider(importPaths: configuration.importPaths)
    guard let content = try? fileProvider.readFile(path) else {
      throw ProtoParserError.fileNotFound(path)
    }

    return try parseContent(content, filePath: path)
  }

  /// Parse proto content
  /// - Parameters:
  ///   - content: The proto content to parse
  ///   - filePath: Optional file path for error reporting
  /// - Returns: File descriptor proto
  /// - Throws: ParserError if parsing fails
  public func parseContent(_ content: String, filePath: String? = nil) throws
    -> Google_Protobuf_FileDescriptorProto
  {
    // Create lexer
    let lexer = Lexer(input: content)

    // Create parser
    let parser = try Parser(lexer: lexer)

    // Parse file
    let fileNode = try parser.parseFile(filePath: filePath)

    // Process imports and collect imported types
    let importedTypes = try processImports(fileNode)

    // Validate file
    let validator = ValidatorV2()
    validator.setImportedTypes(importedTypes)
    try validator.validate(fileNode)

    // Generate descriptors
    let generator = DescriptorGenerator()
    var fileDescriptor = try generator.generateFileDescriptor(fileNode)

    // Generate source info if needed
    if configuration.generateSourceInfo {
      let sourceInfoGenerator = SourceInfoGenerator()
      fileDescriptor.sourceCodeInfo = sourceInfoGenerator.generateSourceInfo(fileNode)
    }

    return fileDescriptor
  }

  /// Parse multiple proto files
  /// - Parameter paths: Array of file paths
  /// - Returns: Array of file descriptor protos
  /// - Throws: ParserError if parsing fails
  public func parseFiles(_ paths: [String]) throws -> [Google_Protobuf_FileDescriptorProto] {
    return try paths.map { try parseFile($0) }
  }

  /// Clear all internal state
  public func clear() {
    symbolTable.clear()
    importResolver.clearCache()
  }

  // MARK: - Private Methods

  /// Process imports in a file node
  /// - Parameter fileNode: The file node to process imports for
  /// - Returns: Dictionary of imported types
  /// - Throws: Error if import resolution fails
  private func processImports(_ fileNode: FileNode) throws -> [String: String] {
    // Get all imported types
    var importedTypes: [String: String] = [:]
    var processedImports = Set<String>()

    // Process imports recursively
    try processImportsRecursively(
      fileNode, importedTypes: &importedTypes, processedImports: &processedImports)

    return importedTypes
  }

  /// Recursively process imports in a file node and its imported files
  /// - Parameters:
  ///   - fileNode: The file node to process imports for
  ///   - importedTypes: Dictionary to collect imported types
  ///   - processedImports: Set of already processed import paths to avoid cycles
  /// - Throws: Error if import resolution fails
  private func processImportsRecursively(
    _ fileNode: FileNode, importedTypes: inout [String: String], processedImports: inout Set<String>
  ) throws {
    // For each import, collect the types from the imported file
    for import_ in fileNode.imports {
      // Skip if we've already processed this import
      if processedImports.contains(import_.path) {
        continue
      }

      // Mark this import as processed
      processedImports.insert(import_.path)

      // Resolve the import
      let importedFile = try importResolver.resolveImport(import_.path)

      // Add all defined types from this imported file
      for type in importedFile.allDefinedTypes {
        let fullName = type.fullName(inPackage: importedFile.package)
        importedTypes[fullName] = import_.path
      }

      // Recursively process imports in the imported file
      try processImportsRecursively(
        importedFile, importedTypes: &importedTypes, processedImports: &processedImports)
    }
  }
}

/// Public error type for parser errors
public enum ProtoParserError: Error, CustomStringConvertible {
  case fileNotFound(String)
  case lexerError(LexerError)
  case parserError(ParserError)  // Using the ParserError directly
  case validationError(ValidationError)
  case importError(ImportError)
  case descriptorError(DescriptorGeneratorError)
  case custom(String)

  public var description: String {
    switch self {
    case .fileNotFound(let path):
      return "File not found: \(path)"
    case .lexerError(let error):
      return "Lexer error: \(error)"
    case .parserError(let error):
      return "Parser error: \(error)"
    case .validationError(let error):
      return "Validation error: \(error)"
    case .importError(let error):
      return "Import error: \(error)"
    case .descriptorError(let error):
      return "Descriptor generation error: \(error)"
    case .custom(let message):
      return message
    }
  }
}

/// Extension to wrap internal errors into public ProtoParserError
extension ProtoParserError {
  static func wrap(_ error: Error) -> ProtoParserError {
    switch error {
    case let error as LexerError:
      return .lexerError(error)
    case let error as ParserError:
      return .parserError(error)
    case let error as ValidationError:
      return .validationError(error)
    case let error as ImportError:
      return .importError(error)
    case let error as DescriptorGeneratorError:
      return .descriptorError(error)
    case let error as ProtoParserError:
      return error
    default:
      return .custom(error.localizedDescription)
    }
  }
}

/// Extension to provide convenience parsing methods
extension ProtoParser {
  /// Parse proto content and return as a string
  /// - Parameter content: The proto content to parse
  /// - Returns: String representation of the file descriptor
  /// - Throws: ParserError if parsing fails
  public func parseContentToString(_ content: String) throws -> String {
    let descriptor = try parseContent(content)
    return descriptor.textFormatString()
  }

  /// Parse file and return as a string
  /// - Parameter path: Path to the file
  /// - Returns: String representation of the file descriptor
  /// - Throws: ParserError if parsing fails
  public func parseFileToString(_ path: String) throws -> String {
    let descriptor = try parseFile(path)
    return descriptor.textFormatString()
  }
}
