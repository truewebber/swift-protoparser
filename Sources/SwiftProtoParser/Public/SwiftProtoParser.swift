import Foundation
import SwiftProtobuf

// MARK: - SwiftProtoParser

/// SwiftProtoParser — A Swift library for parsing Protocol Buffers `.proto` files.
///
/// Public API consists of two static methods: `parseFile` and `parseDirectory`.
public struct SwiftProtoParser {

  private init() {
    // Static API only
  }
}

// MARK: - Public API

extension SwiftProtoParser {

  /// Parse a `.proto` file and all its transitive dependencies.
  ///
  /// Returns a `FileDescriptorSet` containing descriptors for the main file and every
  /// imported file, in topological order (dependencies first, main file last).
  ///
  /// - Parameters:
  ///   - filePath: Path to the main `.proto` file.
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

  /// Parse all `.proto` files in a directory and their transitive dependencies.
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
      let astResult = ProtoParsingPipeline.parse(
        content: resolvedFile.content,
        fileName: resolvedFile.fileName
      )

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

// MARK: - Test Helpers
//
// These methods are internal (not public) and are used exclusively by unit tests
// via `@testable import`. They are thin wrappers over `ProtoParsingPipeline` and
// `DescriptorBuilder`. No production code should call them directly.

extension SwiftProtoParser {

  /// Parse `.proto` content from a string into a `ProtoAST`.
  /// - Note: Test helper — delegates to `ProtoParsingPipeline.parse`.
  static func parseProtoString(_ content: String, fileName: String = "string") -> Result<
    ProtoAST, ProtoParseError
  > {
    return ProtoParsingPipeline.parse(content: content, fileName: fileName)
  }

  /// Read a `.proto` file from disk and parse it into a `ProtoAST`.
  /// - Note: Test helper — delegates to `ProtoParsingPipeline.parseFile(at:)`.
  static func parseProtoFile(_ filePath: String) -> Result<ProtoAST, ProtoParseError> {
    return ProtoParsingPipeline.parseFile(at: filePath)
  }

  /// Resolve imports for `filePath` and parse the main file into a `ProtoAST`.
  /// - Note: Test helper — delegates to `ProtoParsingPipeline.parseFileWithImports`.
  static func parseProtoFileWithImports(
    _ filePath: String,
    importPaths: [String] = [],
    allowMissingImports: Bool = false
  ) -> Result<ProtoAST, ProtoParseError> {
    return ProtoParsingPipeline.parseFileWithImports(
      filePath,
      importPaths: importPaths,
      allowMissingImports: allowMissingImports
    )
  }

  /// Parse all `.proto` files in a directory into an array of `ProtoAST` values.
  /// - Note: Test helper — delegates to `ProtoParsingPipeline.parseDirectory`.
  static func parseProtoDirectory(
    _ directoryPath: String,
    recursive: Bool = false,
    importPaths: [String] = [],
    allowMissingImports: Bool = false
  ) -> Result<[ProtoAST], ProtoParseError> {
    return ProtoParsingPipeline.parseDirectory(
      directoryPath,
      recursive: recursive,
      importPaths: importPaths,
      allowMissingImports: allowMissingImports
    )
  }

  /// Parse a `.proto` file into a `FileDescriptorProto`.
  /// - Note: Test helper.
  static func parseProtoToDescriptors(_ filePath: String) -> Result<
    Google_Protobuf_FileDescriptorProto, ProtoParseError
  > {
    switch ProtoParsingPipeline.parseFile(at: filePath) {
    case .success(let ast):
      let fileName = URL(fileURLWithPath: filePath).lastPathComponent
      return buildSingleDescriptor(from: ast, fileName: fileName)
    case .failure(let error):
      return .failure(error)
    }
  }

  /// Parse `.proto` content from a string into a `FileDescriptorProto`.
  /// - Note: Test helper.
  static func parseProtoStringToDescriptors(
    _ content: String,
    fileName: String = "string.proto"
  ) -> Result<Google_Protobuf_FileDescriptorProto, ProtoParseError> {
    switch ProtoParsingPipeline.parse(content: content, fileName: fileName) {
    case .success(let ast):
      return buildSingleDescriptor(from: ast, fileName: fileName)
    case .failure(let error):
      return .failure(error)
    }
  }

  /// Resolve imports for `filePath` and return a `FileDescriptorProto` for the main file.
  /// - Note: Test helper.
  static func parseProtoFileWithImportsToDescriptors(
    _ filePath: String,
    importPaths: [String] = [],
    allowMissingImports: Bool = false
  ) -> Result<Google_Protobuf_FileDescriptorProto, ProtoParseError> {
    switch ProtoParsingPipeline.parseFileWithImports(
      filePath,
      importPaths: importPaths,
      allowMissingImports: allowMissingImports
    ) {
    case .success(let ast):
      let fileName = URL(fileURLWithPath: filePath).lastPathComponent
      return buildSingleDescriptor(from: ast, fileName: fileName)
    case .failure(let error):
      return .failure(error)
    }
  }

  // MARK: - Private

  private static func buildSingleDescriptor(
    from ast: ProtoAST,
    fileName: String
  ) -> Result<Google_Protobuf_FileDescriptorProto, ProtoParseError> {
    do {
      let descriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: fileName)
      return .success(descriptor)
    }
    catch let descriptorError as DescriptorError {
      return .failure(.descriptorError(descriptorError.localizedDescription))
    }
    catch {
      return .failure(.internalError(message: "DescriptorBuilder failed: \(error.localizedDescription)"))
    }
  }
}
