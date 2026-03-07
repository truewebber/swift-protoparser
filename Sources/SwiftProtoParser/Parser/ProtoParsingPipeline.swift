import Foundation

// MARK: - ProtoParsingPipeline

/// Internal utility that executes the Lexer → Parser pipeline.
///
/// This type is the single canonical entry point for parsing within the library.
/// Both the public API (`SwiftProtoParser`) and the Performance module
/// (`IncrementalParser`, `PerformanceBenchmark`) call this type directly, so that
/// no lower layer needs to reference the public facade.
///
/// Dependency order: Layer 2 — depends only on Lexer (Layer 1) and Core (Layer 0).
struct ProtoParsingPipeline {

  private init() {}

  // MARK: - String → AST

  /// Parse `.proto` content from a string into a `ProtoAST`.
  ///
  /// - Parameters:
  ///   - content: Raw `.proto` file content.
  ///   - fileName: Name used in error messages (default: `"string"`).
  /// - Returns: `Result` with the parsed `ProtoAST` or a `ProtoParseError`.
  static func parse(
    content: String,
    fileName: String = "string"
  ) -> Result<ProtoAST, ProtoParseError> {
    let lexer = Lexer(input: content, fileName: fileName)
    let tokenizeResult = lexer.tokenizeForPublicAPI()

    switch tokenizeResult {
    case .success(let tokens):
      let parser = Parser(tokens: tokens)
      let parseResult = parser.parse()

      switch parseResult {
      case .success(let ast):
        return .success(ast)
      case .failure(let parserErrors):
        if let firstError = parserErrors.errors.first {
          return .failure(
            .syntax(firstError.description, in: fileName, at: 1, column: 1)
          )
        }
        return .failure(.internalError(message: "Unknown parser error"))
      }

    case .failure(let error):
      return .failure(error)
    }
  }

  // MARK: - File → AST

  /// Read a `.proto` file from disk and parse it into a `ProtoAST`.
  ///
  /// - Parameter filePath: Absolute or relative path to the `.proto` file.
  /// - Returns: `Result` with the parsed `ProtoAST` or a `ProtoParseError`.
  static func parseFile(at filePath: String) -> Result<ProtoAST, ProtoParseError> {
    do {
      let content = try String(contentsOfFile: filePath, encoding: .utf8)
      let fileName = URL(fileURLWithPath: filePath).lastPathComponent
      return parse(content: content, fileName: fileName)
    }
    catch {
      return .failure(.ioError(underlying: error))
    }
  }

  // MARK: - File + Imports → main-file AST

  /// Resolve import dependencies for `filePath` and parse the **main file** into a `ProtoAST`.
  ///
  /// Import resolution is performed by `DependencyResolver`; only the main file's AST is
  /// returned (imported files are resolved but not included in the result).
  ///
  /// - Parameters:
  ///   - filePath: Path to the main `.proto` file.
  ///   - importPaths: Directories to search when resolving `import` statements.
  ///   - allowMissingImports: When `true`, missing imports are skipped instead of failing.
  /// - Returns: `Result` with the main file's `ProtoAST` or a `ProtoParseError`.
  static func parseFileWithImports(
    _ filePath: String,
    importPaths: [String] = [],
    allowMissingImports: Bool = false
  ) -> Result<ProtoAST, ProtoParseError> {
    do {
      let options = DependencyResolver.Options(
        allowMissingImports: allowMissingImports,
        recursive: true,
        validateSyntax: true,
        detectCircularDependencies: true,
        maxDepth: 50
      )
      let resolver = DependencyResolver(importPaths: importPaths, options: options)
      let resolutionResult = try resolver.resolveDependencies(for: filePath)
      let mainFile = resolutionResult.mainFile
      return parse(content: mainFile.content, fileName: mainFile.fileName)
    }
    catch let resolverError as ResolverError {
      return .failure(
        .dependencyResolutionError(message: resolverError.localizedDescription, importPath: filePath)
      )
    }
    catch {
      return .failure(.ioError(underlying: error))
    }
  }

  // MARK: - Directory → [AST]

  /// Parse all `.proto` files in a directory into an array of `ProtoAST` values.
  ///
  /// - Parameters:
  ///   - directoryPath: Directory to scan for `.proto` files.
  ///   - recursive: Whether to scan subdirectories (default: `false`).
  ///   - importPaths: Additional directories to search for imported files.
  ///   - allowMissingImports: When `true`, missing imports are skipped.
  /// - Returns: `Result` with an array of `ProtoAST` objects or a `ProtoParseError`.
  static func parseDirectory(
    _ directoryPath: String,
    recursive: Bool = false,
    importPaths: [String] = [],
    allowMissingImports: Bool = false
  ) -> Result<[ProtoAST], ProtoParseError> {
    do {
      let allImportPaths = [directoryPath] + importPaths
      let options = DependencyResolver.Options(
        allowMissingImports: allowMissingImports,
        recursive: true,
        validateSyntax: true,
        detectCircularDependencies: true,
        maxDepth: 50
      )
      let resolver = DependencyResolver(importPaths: allImportPaths, options: options)
      let resolutionResults = try resolver.resolveDirectory(directoryPath, recursive: recursive)

      var allASTs: [ProtoAST] = []
      for result in resolutionResults {
        let mainFile = result.mainFile
        let astResult = parse(content: mainFile.content, fileName: mainFile.fileName)
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
      return .failure(
        .dependencyResolutionError(
          message: resolverError.localizedDescription,
          importPath: directoryPath
        )
      )
    }
    catch {
      return .failure(.ioError(underlying: error))
    }
  }
}
