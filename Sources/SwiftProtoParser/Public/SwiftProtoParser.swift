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

  /// Parse a .proto file and all its transitive dependencies.
  ///
  /// Returns a `FileDescriptorSet` containing descriptors for the main file and every
  /// imported file, in topological order (dependencies first, main file last).
  ///
  /// - Parameters:
  ///   - filePath: Path to the main .proto file.
  ///   - importPaths: Directories to search when resolving `import` statements (default: empty).
  /// - Returns: `Result` containing a `Google_Protobuf_FileDescriptorSet` on success,
  ///            or a `ProtoParseError` on failure.
  public static func parseFile(
    _ filePath: String,
    importPaths: [String] = []
  ) -> Result<Google_Protobuf_FileDescriptorSet, ProtoParseError> {
    let options = DependencyResolver.Options(
      allowMissingImports: false,
      recursive: true,
      validateSyntax: true,
      detectCircularDependencies: true,
      maxDepth: 50
    )
    let resolver = DependencyResolver(importPaths: importPaths, options: options)

    do {
      let resolutionResult = try resolver.resolveDependencies(for: filePath)
      return buildDescriptorSet(from: resolutionResult.allFiles)
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

  /// Parse all .proto files in a directory and their transitive dependencies.
  ///
  /// Returns a `FileDescriptorSet` containing deduplicated descriptors for every file
  /// found in the directory (and optionally subdirectories) plus all their imports.
  ///
  /// - Parameters:
  ///   - directoryPath: Path to the directory containing `.proto` files.
  ///   - recursive: Whether to scan subdirectories (default: `false`).
  ///   - importPaths: Additional directories to search when resolving `import` statements.
  ///                  The `directoryPath` itself is always included automatically.
  /// - Returns: `Result` containing a `Google_Protobuf_FileDescriptorSet` on success,
  ///            or a `ProtoParseError` on failure.
  public static func parseDirectory(
    _ directoryPath: String,
    recursive: Bool = false,
    importPaths: [String] = []
  ) -> Result<Google_Protobuf_FileDescriptorSet, ProtoParseError> {
    let allImportPaths = [directoryPath] + importPaths
    let options = DependencyResolver.Options(
      allowMissingImports: false,
      recursive: true,
      validateSyntax: true,
      detectCircularDependencies: true,
      maxDepth: 50
    )
    let resolver = DependencyResolver(importPaths: allImportPaths, options: options)

    do {
      let resolutionResults = try resolver.resolveDirectory(directoryPath, recursive: recursive)

      // Collect all files across all resolutions, deduplicated by absolute path.
      var seen: Set<String> = []
      var allFiles: [ResolvedProtoFile] = []
      for result in resolutionResults {
        for file in result.allFiles where !seen.contains(file.filePath) {
          seen.insert(file.filePath)
          allFiles.append(file)
        }
      }

      return buildDescriptorSet(from: allFiles)
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

  // MARK: - Private helpers

  private static func buildDescriptorSet(
    from files: [ResolvedProtoFile]
  ) -> Result<Google_Protobuf_FileDescriptorSet, ProtoParseError> {
    var fileDescriptors: [Google_Protobuf_FileDescriptorProto] = []

    for resolvedFile in files {
      let astResult = parseProtoString(resolvedFile.content, fileName: resolvedFile.fileName)

      switch astResult {
      case .success(let ast):
        do {
          let descriptor = try DescriptorBuilder.buildFileDescriptor(
            from: ast,
            fileName: resolvedFile.fileName
          )
          fileDescriptors.append(descriptor)
        }
        catch let descriptorError as DescriptorError {
          return .failure(.descriptorError(descriptorError.localizedDescription))
        }
        catch {
          return .failure(
            .internalError(
              message:
                "DescriptorBuilder failed for \(resolvedFile.fileName): \(error.localizedDescription)"
            )
          )
        }
      case .failure(let error):
        return .failure(error)
      }
    }

    var set = Google_Protobuf_FileDescriptorSet()
    set.file = fileDescriptors
    return .success(set)
  }
}

// MARK: - Legacy API (internal)

extension SwiftProtoParser {

  /// Parse a single .proto file from a file path.
  ///
  /// - Parameter filePath: Path to the .proto file
  /// - Returns: Result containing ProtoAST on success, or ProtoParseError on failure.
  ///
  /// Note: This MVP version doesn't resolve imports yet. Use for single-file .proto files.
  static func parseProtoFile(_ filePath: String) -> Result<ProtoAST, ProtoParseError> {
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
  static func parseProtoString(_ content: String, fileName: String = "string") -> Result<
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
  static func parseProtoToDescriptors(_ filePath: String) -> Result<
    Google_Protobuf_FileDescriptorProto, ProtoParseError
  > {
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
  static func parseProtoStringToDescriptors(_ content: String, fileName: String = "string.proto") -> Result<
    Google_Protobuf_FileDescriptorProto, ProtoParseError
  > {
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
        return .failure(.descriptorError(descriptorError.localizedDescription))
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
  static func getProtoVersion(_ filePath: String) -> Result<ProtoVersion, ProtoParseError> {
    return parseProtoFile(filePath).map { ast in
      return ast.syntax
    }
  }

  /// Parse a .proto file and return the package name (if any).
  ///
  /// - Parameter filePath: Path to the .proto file
  /// - Returns: Result containing optional package name on success, or ProtoParseError on failure.
  static func getPackageName(_ filePath: String) -> Result<String?, ProtoParseError> {
    return parseProtoFile(filePath).map { ast in
      return ast.package
    }
  }

  /// Parse a .proto file and return all message names.
  ///
  /// - Parameter filePath: Path to the .proto file
  /// - Returns: Result containing array of message names on success, or ProtoParseError on failure.
  static func getMessageNames(_ filePath: String) -> Result<[String], ProtoParseError> {
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
  static func parseProtoFileWithImports(
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
  static func parseProtoDirectory(
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
      return .failure(
        .dependencyResolutionError(message: resolverError.localizedDescription, importPath: directoryPath)
      )
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
  static func parseProtoFileWithImportsToDescriptors(
    _ filePath: String,
    importPaths: [String] = [],
    allowMissingImports: Bool = false
  ) -> Result<Google_Protobuf_FileDescriptorProto, ProtoParseError> {
    // First parse with imports to get AST
    let astResult = parseProtoFileWithImports(
      filePath,
      importPaths: importPaths,
      allowMissingImports: allowMissingImports
    )

    switch astResult {
    case .success(let ast):
      // Convert AST to FileDescriptorProto
      do {
        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        let fileDescriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: fileName)
        return .success(fileDescriptor)
      }
      catch let descriptorError as DescriptorError {
        return .failure(.descriptorError(descriptorError.localizedDescription))
      }
      catch {
        return .failure(.internalError(message: "DescriptorBuilder failed: \(error.localizedDescription)"))
      }

    case .failure(let error):
      return .failure(error)
    }
  }

  /// Parse a .proto file with import resolution and return Google Protocol Buffers descriptors
  /// for ALL files: the main file and all transitive dependencies.
  ///
  /// Returns descriptors in topological order: dependencies first, main file last.
  /// This is useful when message types from imported files need to be resolved.
  ///
  /// - Parameters:
  ///   - filePath: Path to the main .proto file
  ///   - importPaths: Array of directory paths to search for imported files (default: empty)
  ///   - allowMissingImports: Whether to continue if some imports can't be found (default: false)
  /// - Returns: Result containing array of Google_Protobuf_FileDescriptorProto on success,
  ///            where the last element is always the main file's descriptor.
  static func parseProtoFileWithImportsToAllDescriptors(
    _ filePath: String,
    importPaths: [String] = [],
    allowMissingImports: Bool = false
  ) -> Result<[Google_Protobuf_FileDescriptorProto], ProtoParseError> {
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

      var fileDescriptors: [Google_Protobuf_FileDescriptorProto] = []

      for resolvedFile in resolutionResult.allFiles {
        let astResult = parseProtoString(resolvedFile.content, fileName: resolvedFile.fileName)

        switch astResult {
        case .success(let ast):
          do {
            let descriptor = try DescriptorBuilder.buildFileDescriptor(
              from: ast,
              fileName: resolvedFile.fileName
            )
            fileDescriptors.append(descriptor)
          }
          catch let descriptorError as DescriptorError {
            if !allowMissingImports {
              return .failure(.descriptorError(descriptorError.localizedDescription))
            }
          }
          catch {
            if !allowMissingImports {
              return .failure(
                .internalError(
                  message:
                    "DescriptorBuilder failed for \(resolvedFile.fileName): \(error.localizedDescription)"
                )
              )
            }
          }

        case .failure(let error):
          if !allowMissingImports {
            return .failure(error)
          }
        }
      }

      return .success(fileDescriptors)

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
  static func parseProtoDirectoryToDescriptors(
    _ directoryPath: String,
    recursive: Bool = false,
    importPaths: [String] = [],
    allowMissingImports: Bool = false
  ) -> Result<[Google_Protobuf_FileDescriptorProto], ProtoParseError> {
    // First parse directory to get ASTs
    let astResults = parseProtoDirectory(
      directoryPath,
      recursive: recursive,
      importPaths: importPaths,
      allowMissingImports: allowMissingImports
    )

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
          return .failure(.descriptorError(descriptorError.localizedDescription))
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

// MARK: - Performance & Caching API

extension SwiftProtoParser {

  /// Shared performance cache instance for optimized parsing.
  static let sharedCache = PerformanceCache(configuration: .default)

  /// Shared incremental parser instance for large projects.
  static let sharedIncrementalParser = IncrementalParser(
    configuration: .default,
    cache: sharedCache
  )

  /// Parse a .proto file with performance caching enabled.
  ///
  /// This method uses content-based caching to avoid re-parsing unchanged files.
  /// Ideal for development workflows where files are parsed repeatedly.
  ///
  /// - Parameters:
  ///   - filePath: Path to the .proto file
  ///   - enableCaching: Whether to use performance caching (default: true)
  /// - Returns: Result containing ProtoAST on success, or ProtoParseError on failure.
  static func parseProtoFileWithCaching(
    _ filePath: String,
    enableCaching: Bool = true
  ) -> Result<ProtoAST, ProtoParseError> {

    guard enableCaching else {
      return parseProtoFile(filePath)
    }

    do {
      let content = try String(contentsOfFile: filePath, encoding: .utf8)
      let contentHash = PerformanceCache.contentHash(for: content)

      // Check cache first
      if let cachedAST = sharedCache.getCachedAST(for: filePath, contentHash: contentHash) {
        return .success(cachedAST)
      }

      // Parse and cache result
      let startTime = Date()
      let result = parseProtoString(content, fileName: filePath)
      let parseTime = Date().timeIntervalSince(startTime)

      if case .success(let ast) = result {
        let fileSize = try getFileSize(filePath)
        sharedCache.cacheAST(ast, for: filePath, contentHash: contentHash, fileSize: fileSize, parseTime: parseTime)
      }

      return result

    }
    catch {
      return .failure(.ioError(underlying: error))
    }
  }

  /// Parse a directory incrementally, only re-parsing changed files.
  ///
  /// This method detects file changes and only parses modified files and their dependents.
  /// Significantly faster for large projects with frequent changes.
  ///
  /// - Parameters:
  ///   - directoryPath: Path to the directory containing .proto files
  ///   - recursive: Whether to scan subdirectories (default: false)
  ///   - importPaths: Additional import paths to search (default: includes the directory itself)
  /// - Returns: Result containing array of ProtoAST for all files, or ProtoParseError on failure.
  static func parseProtoDirectoryIncremental(
    _ directoryPath: String,
    recursive: Bool = false,
    importPaths: [String] = []
  ) -> Result<[ProtoAST], ProtoParseError> {

    do {
      // Detect changes
      let changeSet = try sharedIncrementalParser.detectChanges(in: directoryPath, recursive: recursive)

      if !changeSet.hasChanges {
        // No changes - return cached results if available
        // For now, fall back to regular parsing
        return parseProtoDirectory(directoryPath, recursive: recursive, importPaths: importPaths)
      }

      // Parse incrementally
      let allImportPaths = [directoryPath] + importPaths
      let results = try sharedIncrementalParser.parseIncremental(
        changeSet: changeSet,
        importPaths: allImportPaths
      )

      // Extract successful ASTs
      var asts: [ProtoAST] = []
      for (_, result) in results {
        switch result {
        case .success(let ast):
          asts.append(ast)
        case .failure(let error):
          return .failure(error)
        }
      }

      return .success(asts)

    }
    catch {
      // Fall back to regular parsing on incremental parsing errors
      return parseProtoDirectory(directoryPath, recursive: recursive, importPaths: importPaths)
    }
  }

  /// Parse a large .proto file using streaming for memory efficiency.
  ///
  /// This method is optimized for very large proto files (>50MB) that might cause
  /// memory issues with regular parsing.
  ///
  /// - Parameters:
  ///   - filePath: Path to the large .proto file
  ///   - importPaths: Import paths for dependency resolution (default: empty)
  /// - Returns: Result containing ProtoAST on success, or ProtoParseError on failure.
  static func parseProtoFileStreaming(
    _ filePath: String,
    importPaths: [String] = []
  ) -> Result<ProtoAST, ProtoParseError> {

    do {
      return try sharedIncrementalParser.parseStreamingFile(filePath, importPaths: importPaths)
    }
    catch {
      return .failure(.ioError(underlying: error))
    }
  }

  /// Get performance statistics for the shared cache.
  ///
  /// - Returns: Current cache performance statistics.
  static func getCacheStatistics() -> PerformanceCache.Statistics {
    return sharedCache.getStatistics()
  }

  /// Get incremental parsing statistics.
  ///
  /// - Returns: Current incremental parsing statistics.
  static func getIncrementalStatistics() -> IncrementalParser.Statistics {
    return sharedIncrementalParser.getStatistics()
  }

  /// Clear all performance caches.
  ///
  /// Use this to free memory or reset performance tracking.
  static func clearPerformanceCaches() {
    sharedCache.clearAll()
    sharedIncrementalParser.reset()
  }

  /// Benchmark parsing performance for a file or directory.
  ///
  /// This method runs comprehensive performance tests and returns detailed metrics.
  /// Useful for performance optimization and regression testing.
  ///
  /// - Parameters:
  ///   - path: Path to file or directory to benchmark
  ///   - configuration: Benchmark configuration (default: .default)
  /// - Returns: Benchmark results with detailed performance metrics.
  static func benchmarkPerformance(
    _ path: String,
    configuration: PerformanceBenchmark.Configuration = .default
  ) -> PerformanceBenchmark.BenchmarkResult {

    let benchmark = PerformanceBenchmark(
      configuration: configuration,
      cache: sharedCache,
      incrementalParser: sharedIncrementalParser
    )

    // Determine if path is file or directory
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
      return PerformanceBenchmark.BenchmarkResult(
        operation: "benchmark(\(path)) - not found",
        measurements: [],
        configuration: configuration
      )
    }

    if isDirectory.boolValue {
      return benchmark.benchmarkDirectory(path)
    }
    else {
      return benchmark.benchmarkSingleFile(path)
    }
  }

  // MARK: - Private Helpers

  private static func getFileSize(_ filePath: String) throws -> Int64 {
    let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
    return attributes[.size] as? Int64 ?? 0
  }
}
