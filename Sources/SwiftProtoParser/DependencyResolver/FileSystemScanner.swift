import Foundation

/// Handles scanning the file system for proto files.
public struct FileSystemScanner {

  // MARK: - Properties

  /// The import paths to search for proto files.
  private let importPaths: [String]

  /// FileManager instance for file operations.
  private let fileManager: FileManager

  // MARK: - Initialization

  /// Initialize the scanner with import paths.
  /// - Parameter importPaths: Array of directory paths to search for proto files.
  public init(importPaths: [String] = []) {
    self.importPaths = importPaths
    self.fileManager = FileManager.default
  }

  // MARK: - File Resolution

  /// Find a proto file by import path.
  /// - Parameter importPath: The import path (e.g., "google/protobuf/timestamp.proto")
  /// - Returns: Absolute path to the file if found.
  /// - Throws: ResolverError if file not found or access issues.
  public func findProtoFile(_ importPath: String) throws -> String {
    // Validate import path
    guard !importPath.isEmpty else {
      throw ResolverError.invalidImportPath(importPath)
    }

    // Clean up the import path
    let cleanPath = importPath.trimmingCharacters(in: .whitespacesAndNewlines)

    // Search in import paths
    for searchPath in importPaths {
      let fullPath = (searchPath as NSString).appendingPathComponent(cleanPath)

      if fileManager.fileExists(atPath: fullPath) {
        return fullPath
      }
    }

    // If not found, try relative to current directory as last resort
    let relativePath = (fileManager.currentDirectoryPath as NSString).appendingPathComponent(cleanPath)
    if fileManager.fileExists(atPath: relativePath) {
      return relativePath
    }

    // File not found anywhere
    throw ResolverError.importNotFound(importPath, searchPaths: importPaths)
  }

  /// Find all proto files in a directory.
  /// - Parameter directoryPath: Path to the directory to scan.
  /// - Returns: Array of absolute paths to proto files.
  /// - Throws: ResolverError if directory access issues.
  public func findAllProtoFiles(in directoryPath: String) throws -> [String] {
    // Check if directory exists
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: directoryPath, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      throw ResolverError.directoryNotFound(directoryPath)
    }

    // Get directory contents
    let contents: [String]
    do {
      contents = try fileManager.contentsOfDirectory(atPath: directoryPath)
    }
    catch {
      throw ResolverError.ioError(directoryPath, underlying: error.localizedDescription)
    }

    // Filter proto files and return absolute paths
    let protoFiles =
      contents
      .filter { $0.hasSuffix(".proto") }
      .map { (directoryPath as NSString).appendingPathComponent($0) }

    return protoFiles
  }

  /// Recursively find all proto files in a directory tree.
  /// - Parameter directoryPath: Path to the root directory to scan.
  /// - Returns: Array of absolute paths to proto files.
  /// - Throws: ResolverError if directory access issues.
  public func findAllProtoFilesRecursively(in directoryPath: String) throws -> [String] {
    var protoFiles: [String] = []

    // Use FileManager's directory enumerator for recursive search
    guard let enumerator = fileManager.enumerator(atPath: directoryPath) else {
      throw ResolverError.directoryNotFound(directoryPath)
    }

    while let item = enumerator.nextObject() as? String {
      if item.hasSuffix(".proto") {
        let fullPath = (directoryPath as NSString).appendingPathComponent(item)
        protoFiles.append(fullPath)
      }
    }

    return protoFiles
  }

  // MARK: - Path Utilities

  /// Convert a relative path to absolute path.
  /// - Parameter path: The path to convert.
  /// - Returns: Absolute path.
  public func absolutePath(for path: String) -> String {
    if (path as NSString).isAbsolutePath {
      return path
    }

    return (fileManager.currentDirectoryPath as NSString).appendingPathComponent(path)
  }

  /// Check if a path is accessible.
  /// - Parameter path: The path to check.
  /// - Returns: True if the path exists and is accessible.
  public func isAccessible(_ path: String) -> Bool {
    return fileManager.fileExists(atPath: path)
  }

  /// Check if a path is a directory.
  /// - Parameter path: The path to check.
  /// - Returns: True if the path is a directory.
  public func isDirectory(_ path: String) -> Bool {
    var isDirectory: ObjCBool = false
    return fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
  }

  /// Validate that all import paths are accessible directories.
  /// - Throws: ResolverError if any import path is invalid.
  public func validateImportPaths() throws {
    for importPath in importPaths {
      guard isAccessible(importPath) else {
        throw ResolverError.directoryNotFound(importPath)
      }

      guard isDirectory(importPath) else {
        throw ResolverError.invalidImportPathWithReason(importPath, reason: "not a directory")
      }
    }
  }

  // MARK: - Well-Known Types Support

  /// Check if an import path refers to a well-known type.
  /// - Parameter importPath: The import path to check.
  /// - Returns: True if this is a Google well-known type.
  public static func isWellKnownType(_ importPath: String) -> Bool {
    let wellKnownPrefixes = [
      "google/protobuf/",
      "google/type/",
      "google/api/",
    ]

    return wellKnownPrefixes.contains { importPath.hasPrefix($0) }
  }

  /// Get the list of well-known type imports.
  /// - Returns: Array of well-known import paths.
  public static func wellKnownTypes() -> [String] {
    return [
      "google/protobuf/any.proto",
      "google/protobuf/api.proto",
      "google/protobuf/duration.proto",
      "google/protobuf/empty.proto",
      "google/protobuf/field_mask.proto",
      "google/protobuf/source_context.proto",
      "google/protobuf/struct.proto",
      "google/protobuf/timestamp.proto",
      "google/protobuf/type.proto",
      "google/protobuf/wrappers.proto",
    ]
  }
}

// MARK: - CustomStringConvertible

extension FileSystemScanner: CustomStringConvertible {
  public var description: String {
    return "FileSystemScanner(importPaths: \(importPaths))"
  }
}
