import Foundation
import SwiftProtobuf

// MARK: - SwiftProtoParser

/// SwiftProtoParser - A Swift library for parsing Protocol Buffers .proto files.
///
/// This is the main public API for the library. Currently supports parsing
/// single .proto files without import dependencies.
public struct SwiftProtoParser {

  private init() {
    // Static API only
  }
}

// MARK: - Public API

extension SwiftProtoParser {

  /// Parse a single .proto file from a file path.
  ///
  /// - Parameter filePath: Path to the .proto file
  /// - Returns: Result containing ProtoAST on success, or ProtoParseError on failure.
  ///
  /// Note: This MVP version doesn't resolve imports yet. Use for single-file .proto files.
  public static func parseProtoFile(_ filePath: String) -> Result<ProtoAST, ProtoParseError> {
    do {
      // Read file content
      let content = try String(contentsOfFile: filePath, encoding: .utf8)

      // Parse from string content
      return parseProtoString(content, fileName: filePath)

    }
    catch {
      return .failure(.ioError(underlying: error))
    }
  }

  /// Parse .proto content from a string.
  ///
  /// - Parameters:.
  ///   - content: The .proto file content as a string
  ///   - fileName: Optional file name for error reporting (default: "string").
  /// - Returns: Result containing ProtoAST on success, or ProtoParseError on failure.
  public static func parseProtoString(_ content: String, fileName: String = "string") -> Result<
    ProtoAST, ProtoParseError
  > {
    // Step 1: Tokenize
    let lexer = Lexer(input: content, fileName: fileName)
    let tokenizeResult = lexer.tokenizeForPublicAPI()

    switch tokenizeResult {
    case .success(let tokens):
      // Step 2: Parse
      let parser = Parser(tokens: tokens)
      let parseResult = parser.parse()

      switch parseResult {
      case .success(let ast):
        return .success(ast)
      case .failure(let parserErrors):
        // Convert first parser error to ProtoParseError
        if let firstError = parserErrors.errors.first {
          let protoError = ProtoParseError.syntax(
            firstError.description,
            in: fileName,
            at: 1,  // TODO: extract line from ParserError
            column: 1  // TODO: extract column from ParserError
          )
          return .failure(protoError)
        }
        else {
          return .failure(.internalError(message: "Unknown parser error"))
        }
      }

    case .failure(let error):
      return .failure(error)
    }
  }
}

// MARK: - Descriptor API

extension SwiftProtoParser {

  /// Parse a single .proto file from a file path and return Google Protocol Buffers descriptor.
  ///
  /// - Parameter filePath: Path to the .proto file
  /// - Returns: Result containing Google_Protobuf_FileDescriptorProto on success, or ProtoParseError on failure.
  ///
  /// This method performs the complete pipeline: Lexer → Parser → AST → DescriptorBuilder → FileDescriptorProto
  public static func parseProtoToDescriptors(_ filePath: String) -> Result<Google_Protobuf_FileDescriptorProto, ProtoParseError> {
    do {
      // Read file content
      let content = try String(contentsOfFile: filePath, encoding: .utf8)
      
      // Extract file name from path for descriptor
      let fileName = URL(fileURLWithPath: filePath).lastPathComponent

      // Parse from string content
      return parseProtoStringToDescriptors(content, fileName: fileName)

    }
    catch {
      return .failure(.ioError(underlying: error))
    }
  }

  /// Parse .proto content from a string and return Google Protocol Buffers descriptor.
  ///
  /// - Parameters:
  ///   - content: The .proto file content as a string
  ///   - fileName: File name for descriptor metadata (default: "string.proto")
  /// - Returns: Result containing Google_Protobuf_FileDescriptorProto on success, or ProtoParseError on failure.
  ///
  /// This method performs the complete pipeline: Lexer → Parser → AST → DescriptorBuilder → FileDescriptorProto
  public static func parseProtoStringToDescriptors(_ content: String, fileName: String = "string.proto") -> Result<Google_Protobuf_FileDescriptorProto, ProtoParseError> {
    // Step 1: Parse to AST
    let astResult = parseProtoString(content, fileName: fileName)
    
    switch astResult {
    case .success(let ast):
      // Step 2: Convert AST to FileDescriptorProto using DescriptorBuilder
      do {
        let fileDescriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: fileName)
        return .success(fileDescriptor)
      }
      catch let descriptorError as DescriptorError {
        // Convert DescriptorError to ProtoParseError
        return .failure(.descriptorError(descriptorError))
      }
      catch {
        return .failure(.internalError(message: "DescriptorBuilder failed: \(error.localizedDescription)"))
      }
      
    case .failure(let parseError):
      return .failure(parseError)
    }
  }
}

// MARK: - Convenience Methods

extension SwiftProtoParser {

  /// Parse a .proto file and return the syntax version.
  ///
  /// - Parameter filePath: Path to the .proto file
  /// - Returns: Result containing ProtoVersion on success, or ProtoParseError on failure.
  public static func getProtoVersion(_ filePath: String) -> Result<ProtoVersion, ProtoParseError> {
    return parseProtoFile(filePath).map { ast in
      return ast.syntax
    }
  }

  /// Parse a .proto file and return the package name (if any).
  ///
  /// - Parameter filePath: Path to the .proto file
  /// - Returns: Result containing optional package name on success, or ProtoParseError on failure.
  public static func getPackageName(_ filePath: String) -> Result<String?, ProtoParseError> {
    return parseProtoFile(filePath).map { ast in
      return ast.package
    }
  }

  /// Parse a .proto file and return all message names.
  ///
  /// - Parameter filePath: Path to the .proto file
  /// - Returns: Result containing array of message names on success, or ProtoParseError on failure.
  public static func getMessageNames(_ filePath: String) -> Result<[String], ProtoParseError> {
    return parseProtoFile(filePath).map { ast in
      return ast.messages.map { $0.name }
    }
  }
}

// MARK: - Future API Placeholders

extension SwiftProtoParser {

  // These will be implemented when DependencyResolver is added

  /// Parse a .proto file with import resolution.
  ///
  /// This method resolves all import dependencies and parses the main file.
  /// All dependencies are resolved but only the main file's AST is returned.
  ///
  /// - Parameters:
  ///   - filePath: Path to the main .proto file
  ///   - importPaths: Array of directory paths to search for imported files (default: empty)
  ///   - allowMissingImports: Whether to continue if some imports can't be found (default: false)
  /// - Returns: Result containing ProtoAST of the main file on success, or ProtoParseError on failure.
  public static func parseProtoFileWithImports(
    _ filePath: String,
    importPaths: [String] = [],
    allowMissingImports: Bool = false
  ) -> Result<ProtoAST, ProtoParseError> {
    do {
      // Create DependencyResolver with appropriate options
      let options = DependencyResolver.Options(
        allowMissingImports: allowMissingImports,
        recursive: true,
        validateSyntax: true,
        detectCircularDependencies: true,
        maxDepth: 50
      )
      let resolver = DependencyResolver(importPaths: importPaths, options: options)
      
      // Resolve all dependencies
      let resolutionResult = try resolver.resolveDependencies(for: filePath)
      
      // Parse the main file content to AST
      let mainFile = resolutionResult.mainFile
      return parseProtoString(mainFile.content, fileName: mainFile.fileName)
      
    }
    catch let resolverError as ResolverError {
      return .failure(.dependencyResolutionError(message: resolverError.localizedDescription, importPath: filePath))
    }
    catch {
      return .failure(.ioError(underlying: error))
    }
  }

  /// Parse multiple .proto files in a directory.
  ///
  /// This method finds all .proto files in the specified directory and parses each one
  /// with full dependency resolution.
  ///
  /// - Parameters:
  ///   - directoryPath: Path to the directory containing .proto files
  ///   - recursive: Whether to search subdirectories (default: false)
  ///   - importPaths: Additional import paths to search (default: includes the directory itself)
  ///   - allowMissingImports: Whether to continue if some imports can't be found (default: false)
  /// - Returns: Result containing array of ProtoAST on success, or ProtoParseError on failure.
  public static func parseProtoDirectory(
    _ directoryPath: String,
    recursive: Bool = false,
    importPaths: [String] = [],
    allowMissingImports: Bool = false
  ) -> Result<[ProtoAST], ProtoParseError> {
    do {
      // Include the directory itself in import paths
      let allImportPaths = [directoryPath] + importPaths
      
      // Create DependencyResolver with appropriate options
      let options = DependencyResolver.Options(
        allowMissingImports: allowMissingImports,
        recursive: true,
        validateSyntax: true,
        detectCircularDependencies: true,
        maxDepth: 50
      )
      let resolver = DependencyResolver(importPaths: allImportPaths, options: options)
      
      // Resolve all files in directory
      let resolutionResults = try resolver.resolveDirectory(directoryPath, recursive: recursive)
      
      // Parse each main file to AST
      var allASTs: [ProtoAST] = []
      for result in resolutionResults {
        let mainFile = result.mainFile
        let astResult = parseProtoString(mainFile.content, fileName: mainFile.fileName)
        
        switch astResult {
        case .success(let ast):
          allASTs.append(ast)
        case .failure(let error):
          return .failure(error)
        }
      }
      
      return .success(allASTs)
      
    }
    catch let resolverError as ResolverError {
      return .failure(.dependencyResolutionError(message: resolverError.localizedDescription, importPath: directoryPath))
    }
    catch {
      return .failure(.ioError(underlying: error))
    }
  }
}

// MARK: - Descriptor API with Dependencies

extension SwiftProtoParser {

  /// Parse a .proto file with import resolution and return Google Protocol Buffers descriptors.
  ///
  /// This method resolves all import dependencies, parses the main file, and converts it to
  /// a FileDescriptorProto with complete type information.
  ///
  /// - Parameters:
  ///   - filePath: Path to the main .proto file
  ///   - importPaths: Array of directory paths to search for imported files (default: empty)
  ///   - allowMissingImports: Whether to continue if some imports can't be found (default: false)
  /// - Returns: Result containing Google_Protobuf_FileDescriptorProto on success, or ProtoParseError on failure.
  public static func parseProtoFileWithImportsToDescriptors(
    _ filePath: String,
    importPaths: [String] = [],
    allowMissingImports: Bool = false
  ) -> Result<Google_Protobuf_FileDescriptorProto, ProtoParseError> {
    // First parse with imports to get AST
    let astResult = parseProtoFileWithImports(filePath, importPaths: importPaths, allowMissingImports: allowMissingImports)
    
    switch astResult {
    case .success(let ast):
      // Convert AST to FileDescriptorProto
      do {
        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        let fileDescriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: fileName)
        return .success(fileDescriptor)
      }
      catch let descriptorError as DescriptorError {
        return .failure(.descriptorError(descriptorError))
      }
      catch {
        return .failure(.internalError(message: "DescriptorBuilder failed: \(error.localizedDescription)"))
      }
      
    case .failure(let error):
      return .failure(error)
    }
  }

  /// Parse multiple .proto files in a directory and return Google Protocol Buffers descriptors.
  ///
  /// This method finds all .proto files in the specified directory, parses each one with full
  /// dependency resolution, and converts them to FileDescriptorProto objects.
  ///
  /// - Parameters:
  ///   - directoryPath: Path to the directory containing .proto files
  ///   - recursive: Whether to search subdirectories (default: false)
  ///   - importPaths: Additional import paths to search (default: includes the directory itself)
  ///   - allowMissingImports: Whether to continue if some imports can't be found (default: false)
  /// - Returns: Result containing array of Google_Protobuf_FileDescriptorProto on success, or ProtoParseError on failure.
  public static func parseProtoDirectoryToDescriptors(
    _ directoryPath: String,
    recursive: Bool = false,
    importPaths: [String] = [],
    allowMissingImports: Bool = false
  ) -> Result<[Google_Protobuf_FileDescriptorProto], ProtoParseError> {
    // First parse directory to get ASTs
    let astResults = parseProtoDirectory(directoryPath, recursive: recursive, importPaths: importPaths, allowMissingImports: allowMissingImports)
    
    switch astResults {
    case .success(let asts):
      // Convert each AST to FileDescriptorProto
      var fileDescriptors: [Google_Protobuf_FileDescriptorProto] = []
      
      for (index, ast) in asts.enumerated() {
        do {
          // Generate file name based on index since AST doesn't contain file name
          let fileName = "file_\(index).proto"
          let fileDescriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: fileName)
          fileDescriptors.append(fileDescriptor)
        }
        catch let descriptorError as DescriptorError {
          return .failure(.descriptorError(descriptorError))
        }
        catch {
          return .failure(.internalError(message: "DescriptorBuilder failed: \(error.localizedDescription)"))
        }
      }
      
      return .success(fileDescriptors)
      
    case .failure(let error):
      return .failure(error)
    }
  }
}
