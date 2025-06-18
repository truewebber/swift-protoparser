import Foundation

/// Resolves import statements from proto files
public struct ImportResolver {
  
  // MARK: - Properties
  
  /// File system scanner for finding proto files
  private let scanner: FileSystemScanner
  
  /// Cache for resolved imports to avoid duplicate work
  private var resolvedCache: [String: String] = [:]
  
  /// Set of files currently being resolved (for circular dependency detection)
  private var resolutionStack: Set<String> = []
  
  // MARK: - Initialization
  
  /// Initialize the import resolver
  /// - Parameter scanner: File system scanner to use for finding files
  public init(scanner: FileSystemScanner) {
    self.scanner = scanner
  }
  
  /// Initialize with import paths
  /// - Parameter importPaths: Array of directory paths to search for proto files
  public init(importPaths: [String]) {
    self.scanner = FileSystemScanner(importPaths: importPaths)
  }
  
  // MARK: - Import Resolution
  
  /// Resolve a single import statement
  /// - Parameters:
  ///   - importPath: The import path to resolve
  ///   - fromFile: The file that contains this import (for relative resolution)
  /// - Returns: Absolute path to the imported file
  /// - Throws: ResolverError if import cannot be resolved
  public mutating func resolveImport(
    _ importPath: String,
    fromFile: String
  ) throws -> String {
    // Check cache first
    let cacheKey = "\(importPath):\(fromFile)"
    if let cached = resolvedCache[cacheKey] {
      return cached
    }
    
    // Check for circular dependency
    if resolutionStack.contains(importPath) {
      let cycle = Array(resolutionStack) + [importPath]
      throw ResolverError.circularDependency(cycle)
    }
    
    // Add to resolution stack
    resolutionStack.insert(importPath)
    defer { resolutionStack.remove(importPath) }
    
    // Try to resolve the import
    let resolvedPath: String
    
    // Check if it's a well-known type (skip resolution for now)
    if FileSystemScanner.isWellKnownType(importPath) {
      resolvedPath = importPath // Will be handled specially later
    } else {
      // Try to find the file
      resolvedPath = try scanner.findProtoFile(importPath)
    }
    
    // Cache the result
    resolvedCache[cacheKey] = resolvedPath
    
    return resolvedPath
  }
  
  /// Resolve all imports from a proto file
  /// - Parameter file: The resolved proto file containing imports
  /// - Returns: Array of resolved import paths
  /// - Throws: ResolverError if any import cannot be resolved
  public mutating func resolveImports(from file: ResolvedProtoFile) throws -> [String] {
    var resolvedImports: [String] = []
    
    for importPath in file.imports {
      let resolved = try resolveImport(importPath, fromFile: file.filePath)
      resolvedImports.append(resolved)
    }
    
    return resolvedImports
  }
  
  /// Resolve all imports recursively from a proto file
  /// - Parameter file: The resolved proto file to start from
  /// - Returns: Array of all resolved import paths (including transitive dependencies)
  /// - Throws: ResolverError if any import cannot be resolved
  public mutating func resolveImportsRecursively(from file: ResolvedProtoFile) throws -> [String] {
    var allImports: Set<String> = []
    var toProcess: [String] = []
    
    // Start with direct imports
    let directImports = try resolveImports(from: file)
    toProcess.append(contentsOf: directImports)
    
    // Process imports recursively
    while !toProcess.isEmpty {
      let currentImport = toProcess.removeFirst()
      
      // Skip if already processed
      if allImports.contains(currentImport) {
        continue
      }
      
      allImports.insert(currentImport)
      
      // Skip well-known types for now
      if FileSystemScanner.isWellKnownType(currentImport) {
        continue
      }
      
      // Load the imported file and get its imports
      do {
        let importedFile = try ResolvedProtoFile.from(filePath: currentImport)
        let nestedImports = try resolveImports(from: importedFile)
        toProcess.append(contentsOf: nestedImports)
      } catch {
        // If we can't read the imported file, that's an error
        throw ResolverError.ioError(currentImport, underlying: error.localizedDescription)
      }
    }
    
    return Array(allImports)
  }
  
  // MARK: - Validation
  
  /// Validate that all imports in a file can be resolved
  /// - Parameter file: The proto file to validate
  /// - Returns: Array of validation errors (empty if all valid)
  public mutating func validateImports(in file: ResolvedProtoFile) -> [ResolverError] {
    var errors: [ResolverError] = []
    
    for importPath in file.imports {
      do {
        _ = try resolveImport(importPath, fromFile: file.filePath)
      } catch let error as ResolverError {
        errors.append(error)
      } catch {
        errors.append(ResolverError.ioError(importPath, underlying: error.localizedDescription))
      }
    }
    
    return errors
  }
  
  /// Check for circular dependencies in a set of files
  /// - Parameter files: Array of proto files to check
  /// - Returns: Array of detected circular dependency chains
  public func detectCircularDependencies(in files: [ResolvedProtoFile]) -> [[String]] {
    var cycles: [[String]] = []
    var visited: Set<String> = []
    var recursionStack: Set<String> = []
    
    for file in files {
      if !visited.contains(file.filePath) {
        detectCycles(
          from: file.filePath,
          files: files,
          visited: &visited,
          recursionStack: &recursionStack,
          cycles: &cycles
        )
      }
    }
    
    return cycles
  }
  
  /// Helper method for cycle detection using DFS
  private func detectCycles(
    from filePath: String,
    files: [ResolvedProtoFile],
    visited: inout Set<String>,
    recursionStack: inout Set<String>,
    cycles: inout [[String]]
  ) {
    visited.insert(filePath)
    recursionStack.insert(filePath)
    
    // Find the file in our list
    guard let currentFile = files.first(where: { $0.filePath == filePath }) else {
      return
    }
    
    // Check all imports
    for importPath in currentFile.imports {
      // Skip well-known types
      if FileSystemScanner.isWellKnownType(importPath) {
        continue
      }
      
      // Try to find the imported file
      if let importedFile = files.first(where: { $0.importPath == importPath || $0.filePath.hasSuffix(importPath) }) {
        let importedFilePath = importedFile.filePath
        
        if recursionStack.contains(importedFilePath) {
          // Found a cycle
          let cycleStart = Array(recursionStack).firstIndex(of: importedFilePath) ?? 0
          let cycle = Array(Array(recursionStack)[cycleStart...]) + [importedFilePath]
          cycles.append(cycle)
        } else if !visited.contains(importedFilePath) {
          detectCycles(
            from: importedFilePath,
            files: files,
            visited: &visited,
            recursionStack: &recursionStack,
            cycles: &cycles
          )
        }
      }
    }
    
    recursionStack.remove(filePath)
  }
  
  // MARK: - Cache Management
  
  /// Clear the resolution cache
  public mutating func clearCache() {
    resolvedCache.removeAll()
  }
  
  /// Get cache statistics
  /// - Returns: Tuple of (cache hits, cache size)
  public var cacheStats: (hits: Int, size: Int) {
    return (hits: resolvedCache.count, size: resolvedCache.count)
  }
  
  // MARK: - Well-Known Types Handling
  
  /// Check if an import is a well-known type that should be skipped
  /// - Parameter importPath: The import path to check
  /// - Returns: True if this is a well-known type
  public static func isWellKnownType(_ importPath: String) -> Bool {
    return FileSystemScanner.isWellKnownType(importPath)
  }
  
  /// Get information about a well-known type
  /// - Parameter importPath: The well-known type import path
  /// - Returns: Description of the well-known type, or nil if not well-known
  public static func wellKnownTypeInfo(_ importPath: String) -> String? {
    let wellKnownTypes = [
      "google/protobuf/any.proto": "Protocol buffer Any type",
      "google/protobuf/api.proto": "Protocol buffer API definitions",
      "google/protobuf/duration.proto": "Protocol buffer Duration type",
      "google/protobuf/empty.proto": "Protocol buffer Empty type",
      "google/protobuf/field_mask.proto": "Protocol buffer FieldMask type",
      "google/protobuf/source_context.proto": "Protocol buffer SourceContext type",
      "google/protobuf/struct.proto": "Protocol buffer Struct types",
      "google/protobuf/timestamp.proto": "Protocol buffer Timestamp type",
      "google/protobuf/type.proto": "Protocol buffer Type definitions",
      "google/protobuf/wrappers.proto": "Protocol buffer wrapper types"
    ]
    
    return wellKnownTypes[importPath]
  }
}

// MARK: - CustomStringConvertible

extension ImportResolver: CustomStringConvertible {
  public var description: String {
    return "ImportResolver(cache: \(resolvedCache.count) entries, scanner: \(scanner))"
  }
}
