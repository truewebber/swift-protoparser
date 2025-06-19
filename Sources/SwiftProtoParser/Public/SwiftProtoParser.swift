import Foundation

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

  /// Parse a .proto file with import resolution (Future).
  ///
  /// - Note: This will be implemented when DependencyResolver module is added.
  public static func parseProtoFileWithImports(
    _ filePath: String,
    importPaths: [String] = []
  ) -> Result<ProtoAST, ProtoParseError> {
    // TODO: Implement when DependencyResolver is ready
    return .failure(.internalError(message: "Import resolution not yet implemented"))
  }

  /// Parse multiple .proto files in a directory (Future).
  ///
  /// - Note: This will be implemented when DependencyResolver module is added.
  public static func parseProtoDirectory(
    _ directoryPath: String,
    mainFile: String? = nil
  ) -> Result<[ProtoAST], ProtoParseError> {
    // TODO: Implement when DependencyResolver is ready
    return .failure(.internalError(message: "Directory parsing not yet implemented"))
  }
}
