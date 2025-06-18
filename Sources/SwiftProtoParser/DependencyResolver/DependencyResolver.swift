import Foundation

/// Main dependency resolver that coordinates the resolution of proto file dependencies
public class DependencyResolver {
  
  // MARK: - Types
  
  /// Configuration options for dependency resolution
  public struct Options {
    /// Whether to allow missing imports (skip them instead of failing)
    public let allowMissingImports: Bool
    
    /// Whether to resolve dependencies recursively
    public let recursive: Bool
    
    /// Whether to validate syntax of all resolved files
    public let validateSyntax: Bool
    
    /// Whether to detect and report circular dependencies
    public let detectCircularDependencies: Bool
    
    /// Maximum depth for recursive resolution (prevents infinite loops)
    public let maxDepth: Int
    
    /// Default options
    public static let `default` = Options(
      allowMissingImports: false,
      recursive: true,
      validateSyntax: true,
      detectCircularDependencies: true,
      maxDepth: 50
    )
    
    /// Initialize options
    public init(
      allowMissingImports: Bool = false,
      recursive: Bool = true,
      validateSyntax: Bool = true,
      detectCircularDependencies: Bool = true,
      maxDepth: Int = 50
    ) {
      self.allowMissingImports = allowMissingImports
      self.recursive = recursive
      self.validateSyntax = validateSyntax
      self.detectCircularDependencies = detectCircularDependencies
      self.maxDepth = maxDepth
    }
  }
  
  /// Result of dependency resolution
  public struct ResolutionResult {
    /// The main file that was resolved
    public let mainFile: ResolvedProtoFile
    
    /// All resolved dependencies
    public let dependencies: [ResolvedProtoFile]
    
    /// All files (main + dependencies) in topological order
    public let allFiles: [ResolvedProtoFile]
    
    /// Any warnings encountered during resolution
    public let warnings: [String]
    
    /// Resolution statistics
    public let stats: ResolutionStats
  }
  
  /// Statistics about the resolution process
  public struct ResolutionStats {
    /// Total number of files resolved
    public let totalFiles: Int
    
    /// Number of direct dependencies
    public let directDependencies: Int
    
    /// Number of transitive dependencies
    public let transitiveDependencies: Int
    
    /// Number of well-known types referenced
    public let wellKnownTypes: Int
    
    /// Resolution time in seconds
    public let resolutionTime: TimeInterval
    
    /// Cache hit rate
    public let cacheHitRate: Double
  }
  
  // MARK: - Properties
  
  /// Import paths to search for proto files
  private let importPaths: [String]
  
  /// File system scanner
  private let scanner: FileSystemScanner
  
  /// Import resolver
  private var importResolver: ImportResolver
  
  /// Resolution options
  private let options: Options
  
  // MARK: - Initialization
  
  /// Initialize the dependency resolver
  /// - Parameters:
  ///   - importPaths: Array of directory paths to search for proto files
  ///   - options: Resolution options
  public init(importPaths: [String] = [], options: Options = .default) {
    self.importPaths = importPaths
    self.options = options
    self.scanner = FileSystemScanner(importPaths: importPaths)
    self.importResolver = ImportResolver(scanner: scanner)
  }
  
  // MARK: - Main Resolution Methods
  
  /// Resolve dependencies for a single proto file
  /// - Parameter filePath: Path to the main proto file
  /// - Returns: Resolution result containing all resolved files
  /// - Throws: ResolverError if resolution fails
  public func resolveDependencies(for filePath: String) throws -> ResolutionResult {
    let startTime = Date()
    
    // Validate import paths
    try scanner.validateImportPaths()
    
    // Load the main file
    let absolutePath = scanner.absolutePath(for: filePath)
    let mainFile = try ResolvedProtoFile.from(
      filePath: absolutePath,
      isMainFile: true
    )
    
    // Validate main file syntax if requested
    if options.validateSyntax {
      try validateFileSyntax(mainFile)
    }
    
    // Resolve dependencies
    var dependencies: [ResolvedProtoFile] = []
    var warnings: [String] = []
    var allResolvedPaths: Set<String> = []
    
    do {
      let dependencyPaths = try resolveDependenciesRecursively(
        from: mainFile,
        depth: 0,
        resolved: &allResolvedPaths
      )
      
      // Load all dependency files
      for path in dependencyPaths {
        // Skip well-known types for now
        if FileSystemScanner.isWellKnownType(path) {
          continue
        }
        
        do {
          let depFile = try ResolvedProtoFile.from(filePath: path)
          dependencies.append(depFile)
          
          // Validate dependency syntax if requested
          if options.validateSyntax {
            try validateFileSyntax(depFile)
          }
        } catch {
          if options.allowMissingImports {
            warnings.append("Could not load dependency: \(path) - \(error)")
          } else {
            throw error
          }
        }
      }
      
    } catch {
      if options.allowMissingImports {
        warnings.append("Some dependencies could not be resolved: \(error)")
      } else {
        throw error
      }
    }
    
    // Check for circular dependencies if requested
    if options.detectCircularDependencies {
      let allFiles = [mainFile] + dependencies
      let cycles = importResolver.detectCircularDependencies(in: allFiles)
      
      if !cycles.isEmpty {
        let cycleDescriptions = cycles.map { $0.joined(separator: " → ") }
        throw ResolverError.circularDependency(cycleDescriptions)
      }
    }
    
    // Sort files in topological order
    let allFiles = try topologicalSort(mainFile: mainFile, dependencies: dependencies)
    
    // Calculate statistics
    let endTime = Date()
    let cacheStats = importResolver.cacheStats
    let stats = ResolutionStats(
      totalFiles: allFiles.count,
      directDependencies: mainFile.imports.count,
      transitiveDependencies: dependencies.count,
      wellKnownTypes: countWellKnownTypes(in: allFiles),
      resolutionTime: endTime.timeIntervalSince(startTime),
      cacheHitRate: cacheStats.size > 0 ? Double(cacheStats.hits) / Double(cacheStats.size) : 0.0
    )
    
    return ResolutionResult(
      mainFile: mainFile,
      dependencies: dependencies,
      allFiles: allFiles,
      warnings: warnings,
      stats: stats
    )
  }
  
  /// Resolve dependencies for multiple proto files
  /// - Parameter filePaths: Array of paths to proto files
  /// - Returns: Array of resolution results
  /// - Throws: ResolverError if any resolution fails
  public func resolveDependencies(for filePaths: [String]) throws -> [ResolutionResult] {
    var results: [ResolutionResult] = []
    
    for filePath in filePaths {
      let result = try resolveDependencies(for: filePath)
      results.append(result)
    }
    
    return results
  }
  
  /// Resolve all proto files in a directory
  /// - Parameters:
  ///   - directoryPath: Path to the directory containing proto files
  ///   - recursive: Whether to search subdirectories
  /// - Returns: Array of resolution results for all proto files
  /// - Throws: ResolverError if directory access fails
  public func resolveDirectory(
    _ directoryPath: String,
    recursive: Bool = false
  ) throws -> [ResolutionResult] {
    let protoFiles: [String]
    
    if recursive {
      protoFiles = try scanner.findAllProtoFilesRecursively(in: directoryPath)
    } else {
      protoFiles = try scanner.findAllProtoFiles(in: directoryPath)
    }
    
    return try resolveDependencies(for: protoFiles)
  }
  
  // MARK: - Private Helper Methods
  
  /// Recursively resolve dependencies from a proto file
  private func resolveDependenciesRecursively(
    from file: ResolvedProtoFile,
    depth: Int,
    resolved: inout Set<String>
  ) throws -> [String] {
    // Check max depth
    guard depth < options.maxDepth else {
      throw ResolverError.circularDependency(["Max depth reached: \(options.maxDepth)"])
    }
    
    // Skip if already resolved
    if resolved.contains(file.filePath) {
      return []
    }
    
    resolved.insert(file.filePath)
    
    if !options.recursive {
      // Just return direct imports
      return try importResolver.resolveImports(from: file)
    }
    
    // Recursively resolve all dependencies
    return try importResolver.resolveImportsRecursively(from: file)
  }
  
  /// Validate proto file syntax
  private func validateFileSyntax(_ file: ResolvedProtoFile) throws {
    // Check for syntax declaration
    guard let syntax = file.syntax else {
      throw ResolverError.missingSyntax(file.filePath)
    }
    
    // Only support proto3 for now
    if syntax != "proto3" {
      throw ResolverError.invalidSyntax(file.filePath, expected: "proto3")
    }
  }
  
  /// Sort files in topological order (dependencies before dependents)
  private func topologicalSort(
    mainFile: ResolvedProtoFile,
    dependencies: [ResolvedProtoFile]
  ) throws -> [ResolvedProtoFile] {
    let allFiles = [mainFile] + dependencies
    var sorted: [ResolvedProtoFile] = []
    var visited: Set<String> = []
    var tempMark: Set<String> = []
    
    func visit(_ file: ResolvedProtoFile) throws {
      let filePath = file.filePath
      
      if tempMark.contains(filePath) {
        // Cycle detected
        throw ResolverError.circularDependency([filePath])
      }
      
      if visited.contains(filePath) {
        return
      }
      
      tempMark.insert(filePath)
      
      // Visit dependencies first
      for importPath in file.imports {
        if let dependency = allFiles.first(where: { 
          $0.importPath == importPath || $0.filePath.hasSuffix(importPath) 
        }) {
          try visit(dependency)
        }
      }
      
      tempMark.remove(filePath)
      visited.insert(filePath)
      sorted.append(file)
    }
    
    // Visit all files
    for file in allFiles {
      if !visited.contains(file.filePath) {
        try visit(file)
      }
    }
    
    return sorted
  }
  
  /// Count well-known types referenced in files
  private func countWellKnownTypes(in files: [ResolvedProtoFile]) -> Int {
    var wellKnownTypes: Set<String> = []
    
    for file in files {
      for importPath in file.imports {
        if FileSystemScanner.isWellKnownType(importPath) {
          wellKnownTypes.insert(importPath)
        }
      }
    }
    
    return wellKnownTypes.count
  }
  
  // MARK: - Utility Methods
  
  /// Clear all internal caches
  public func clearCaches() {
    importResolver.clearCache()
  }
  
  /// Get resolver statistics
  public var stats: (cacheHits: Int, cacheSize: Int) {
    let cacheStats = importResolver.cacheStats
    return (cacheHits: cacheStats.hits, cacheSize: cacheStats.size)
  }
  
  /// Validate that all import paths are accessible
  /// - Throws: ResolverError if any path is invalid
  public func validateImportPaths() throws {
    try scanner.validateImportPaths()
  }
}

// MARK: - Convenience Factory Methods

extension DependencyResolver {
  
  /// Create a resolver with default settings
  /// - Parameter importPaths: Import paths to search
  /// - Returns: Configured dependency resolver
  public static func standard(importPaths: [String]) -> DependencyResolver {
    return DependencyResolver(importPaths: importPaths, options: .default)
  }
  
  /// Create a resolver that allows missing imports
  /// - Parameter importPaths: Import paths to search
  /// - Returns: Configured dependency resolver
  public static func lenient(importPaths: [String]) -> DependencyResolver {
    let options = Options(
      allowMissingImports: true,
      recursive: true,
      validateSyntax: false,
      detectCircularDependencies: false,
      maxDepth: 50
    )
    return DependencyResolver(importPaths: importPaths, options: options)
  }
  
  /// Create a resolver with strict validation
  /// - Parameter importPaths: Import paths to search
  /// - Returns: Configured dependency resolver
  public static func strict(importPaths: [String]) -> DependencyResolver {
    let options = Options(
      allowMissingImports: false,
      recursive: true,
      validateSyntax: true,
      detectCircularDependencies: true,
      maxDepth: 20
    )
    return DependencyResolver(importPaths: importPaths, options: options)
  }
}

// MARK: - CustomStringConvertible

extension DependencyResolver: CustomStringConvertible {
  public var description: String {
    return "DependencyResolver(importPaths: \(importPaths.count), options: \(options))"
  }
}

extension DependencyResolver.Options: CustomStringConvertible {
  public var description: String {
    return "Options(allowMissing: \(allowMissingImports), recursive: \(recursive), validate: \(validateSyntax))"
  }
}
