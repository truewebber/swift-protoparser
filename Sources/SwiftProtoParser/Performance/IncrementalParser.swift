import Foundation

/// Incremental parsing system for large Protocol Buffers projects.
///
/// This system provides:
/// - Change detection for proto files
/// - Selective re-parsing of modified files
/// - Dependency graph management
/// - Batch processing optimization
/// - Memory-efficient streaming for large files
public final class IncrementalParser {

  // MARK: - File Change Tracking

  /// File metadata for change detection.
  private struct FileMetadata {
    let filePath: String
    let lastModified: Date
    let fileSize: Int64
    let contentHash: String
    let dependencies: Set<String>
    let dependents: Set<String>
  }

  /// Change detection result.
  public struct ChangeSet {
    /// Files that have been modified.
    public let modifiedFiles: Set<String>
    
    /// Files that need re-parsing due to dependency changes.
    public let affectedFiles: Set<String>
    
    /// Files that were added.
    public let addedFiles: Set<String>
    
    /// Files that were removed.
    public let removedFiles: Set<String>
    
    /// Total number of files affected.
    public var totalAffected: Int {
      return modifiedFiles.count + affectedFiles.count + addedFiles.count
    }
    
    /// Whether any changes were detected.
    public var hasChanges: Bool {
      return !modifiedFiles.isEmpty || !affectedFiles.isEmpty || !addedFiles.isEmpty || !removedFiles.isEmpty
    }
  }

  // MARK: - Configuration

  /// Configuration for incremental parsing.
  public struct Configuration {
    /// Maximum file size for in-memory processing (bytes).
    public let maxInMemorySize: Int64
    
    /// Chunk size for streaming large files (bytes).
    public let streamingChunkSize: Int
    
    /// Maximum number of files to process in parallel.
    public let maxParallelFiles: Int
    
    /// Enable change detection optimization.
    public let enableChangeDetection: Bool
    
    /// Cache parsed results for incremental updates.
    public let enableResultCaching: Bool
    
    /// Default configuration.
    public static let `default` = Configuration(
      maxInMemorySize: 50 * 1024 * 1024, // 50MB
      streamingChunkSize: 64 * 1024, // 64KB
      maxParallelFiles: 4,
      enableChangeDetection: true,
      enableResultCaching: true
    )
    
    /// High-performance configuration for large projects.
    public static let highPerformance = Configuration(
      maxInMemorySize: 200 * 1024 * 1024, // 200MB
      streamingChunkSize: 256 * 1024, // 256KB
      maxParallelFiles: 8,
      enableChangeDetection: true,
      enableResultCaching: true
    )
    
    /// Memory-constrained configuration.
    public static let memoryConstrained = Configuration(
      maxInMemorySize: 10 * 1024 * 1024, // 10MB
      streamingChunkSize: 16 * 1024, // 16KB
      maxParallelFiles: 2,
      enableChangeDetection: true,
      enableResultCaching: false
    )
  }

  // MARK: - Properties

  private let configuration: Configuration
  private let cache: PerformanceCache
  private var fileMetadata: [String: FileMetadata] = [:]
  private let queue = DispatchQueue(label: "com.swiftprotoparser.incremental", attributes: .concurrent)
  private let fileManager = FileManager.default

  // MARK: - Statistics

  /// Incremental parsing statistics.
  public struct Statistics {
    public let totalFilesTracked: Int
    public let filesProcessedIncrementally: Int
    public let filesProcessedFromScratch: Int
    public let totalParsingTime: TimeInterval
    public let incrementalSavings: TimeInterval
    public let memoryPeakUsage: Int64
    
    public var incrementalEfficiency: Double {
      let total = filesProcessedIncrementally + filesProcessedFromScratch
      return total > 0 ? Double(filesProcessedIncrementally) / Double(total) : 0.0
    }
  }
  
  private var stats = Statistics(
    totalFilesTracked: 0,
    filesProcessedIncrementally: 0,
    filesProcessedFromScratch: 0,
    totalParsingTime: 0.0,
    incrementalSavings: 0.0,
    memoryPeakUsage: 0
  )

  // MARK: - Initialization

  /// Initialize incremental parser.
  /// - Parameters:
  ///   - configuration: Incremental parsing configuration.
  ///   - cache: Performance cache for result caching.
  public init(configuration: Configuration = .default, cache: PerformanceCache) {
    self.configuration = configuration
    self.cache = cache
  }

  // MARK: - Change Detection

  /// Detect changes in a directory of proto files.
  /// - Parameters:
  ///   - directoryPath: Path to the directory to scan.
  ///   - recursive: Whether to scan subdirectories.
  /// - Returns: Change set describing what files have changed.
  /// - Throws: ProtoParseError if directory scanning fails.
  public func detectChanges(in directoryPath: String, recursive: Bool = false) throws -> ChangeSet {
    let startTime = Date()
    
    // Scan directory for current proto files
    let currentFiles = try scanProtoFiles(in: directoryPath, recursive: recursive)
    let previousFiles = Set(fileMetadata.keys)
    
    // Determine added and removed files
    let addedFiles = currentFiles.subtracting(previousFiles)
    let removedFiles = previousFiles.subtracting(currentFiles)
    let commonFiles = currentFiles.intersection(previousFiles)
    
    // Check for modifications in common files
    var modifiedFiles: Set<String> = []
    var affectedFiles: Set<String> = []
    
    for filePath in commonFiles {
      if try hasFileChanged(filePath) {
        modifiedFiles.insert(filePath)
        
        // Add dependent files to affected set
        if let metadata = fileMetadata[filePath] {
          affectedFiles.formUnion(metadata.dependents)
        }
      }
    }
    
    // Update statistics
    updateStats { stats in
      stats = Statistics(
        totalFilesTracked: currentFiles.count,
        filesProcessedIncrementally: stats.filesProcessedIncrementally,
        filesProcessedFromScratch: stats.filesProcessedFromScratch,
        totalParsingTime: stats.totalParsingTime + Date().timeIntervalSince(startTime),
        incrementalSavings: stats.incrementalSavings,
        memoryPeakUsage: stats.memoryPeakUsage
      )
    }
    
    return ChangeSet(
      modifiedFiles: modifiedFiles,
      affectedFiles: affectedFiles,
      addedFiles: addedFiles,
      removedFiles: removedFiles
    )
  }

  /// Parse proto files incrementally based on detected changes.
  /// - Parameters:
  ///   - changeSet: Change set from detectChanges.
  ///   - importPaths: Import paths for dependency resolution.
  /// - Returns: Results for all affected files.
  /// - Throws: ProtoParseError if parsing fails.
  public func parseIncremental(
    changeSet: ChangeSet,
    importPaths: [String] = []
  ) throws -> [String: Result<ProtoAST, ProtoParseError>] {
    
    let startTime = Date()
    var results: [String: Result<ProtoAST, ProtoParseError>] = [:]
    
    // Remove deleted files from metadata
    for removedFile in changeSet.removedFiles {
      fileMetadata.removeValue(forKey: removedFile)
    }
    
    // Files that need processing
    let filesToProcess = changeSet.modifiedFiles
      .union(changeSet.affectedFiles)
      .union(changeSet.addedFiles)
    
    if filesToProcess.isEmpty {
      return results
    }
    
    // Process files in parallel batches
    let filesArray = Array(filesToProcess)
    let batches = filesArray.chunked(into: configuration.maxParallelFiles)
    
    for batch in batches {
      try processBatch(batch, importPaths: importPaths, results: &results)
    }
    
    // Update statistics
    let processingTime = Date().timeIntervalSince(startTime)
    updateStats { stats in
      stats = Statistics(
        totalFilesTracked: stats.totalFilesTracked,
        filesProcessedIncrementally: stats.filesProcessedIncrementally + filesToProcess.count,
        filesProcessedFromScratch: stats.filesProcessedFromScratch,
        totalParsingTime: stats.totalParsingTime + processingTime,
        incrementalSavings: stats.incrementalSavings,
        memoryPeakUsage: max(stats.memoryPeakUsage, self.getCurrentMemoryUsage())
      )
    }
    
    return results
  }

  /// Parse a large proto file using streaming.
  /// - Parameters:
  ///   - filePath: Path to the large proto file.
  ///   - importPaths: Import paths for dependency resolution.
  /// - Returns: Parsed AST result.
  /// - Throws: ProtoParseError if parsing fails.
  public func parseStreamingFile(
    _ filePath: String,
    importPaths: [String] = []
  ) throws -> Result<ProtoAST, ProtoParseError> {
    
    let fileSize = try getFileSize(filePath)
    
    if fileSize <= configuration.maxInMemorySize {
      // Use regular in-memory parsing
      return SwiftProtoParser.parseProtoFile(filePath)
    }
    
    // Use streaming approach for large files
    return try parseFileInChunks(filePath, importPaths: importPaths)
  }

  // MARK: - Statistics and Monitoring

  /// Get current incremental parsing statistics.
  /// - Returns: Current statistics.
  public func getStatistics() -> Statistics {
    return queue.sync { stats }
  }

  /// Clear all tracking metadata and statistics.
  public func reset() {
    queue.async(flags: .barrier) {
      self.fileMetadata.removeAll()
      self.resetStatistics()
    }
  }

  // MARK: - Private Implementation

  private func scanProtoFiles(in directoryPath: String, recursive: Bool) throws -> Set<String> {
    var protoFiles: Set<String> = []
    
    if recursive {
      // Use recursive enumeration
      let url = URL(fileURLWithPath: directoryPath)
      guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
        throw ProtoParseError.ioError(underlying: NSError(domain: "IncrementalParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to enumerate directory"]))
      }
      
      for case let fileURL as URL in enumerator {
        if fileURL.pathExtension == "proto" {
          protoFiles.insert(fileURL.path)
        }
      }
    } else {
      // Use simple directory contents for non-recursive
      let contents = try fileManager.contentsOfDirectory(atPath: directoryPath)
      for fileName in contents {
        if fileName.hasSuffix(".proto") {
          let fullPath = (directoryPath as NSString).appendingPathComponent(fileName)
          protoFiles.insert(fullPath)
        }
      }
    }
    
    return protoFiles
  }

  private func hasFileChanged(_ filePath: String) throws -> Bool {
    guard let existingMetadata = fileMetadata[filePath] else {
      // New file, needs processing
      return true
    }
    
    let attributes = try fileManager.attributesOfItem(atPath: filePath)
    guard let modificationDate = attributes[.modificationDate] as? Date,
          let fileSize = attributes[.size] as? Int64 else {
      throw ProtoParseError.ioError(underlying: NSError(domain: "IncrementalParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get file attributes"]))
    }
    
    // Quick check: modification date or size changed
    if modificationDate != existingMetadata.lastModified || fileSize != existingMetadata.fileSize {
      return true
    }
    
    // Deep check: content hash changed (only if quick check passes)
    let content = try String(contentsOfFile: filePath, encoding: .utf8)
    let contentHash = PerformanceCache.contentHash(for: content)
    
    return contentHash != existingMetadata.contentHash
  }

  private func processBatch(
    _ batch: [String],
    importPaths: [String],
    results: inout [String: Result<ProtoAST, ProtoParseError>]
  ) throws {
    
    let group = DispatchGroup()
    var batchResults: [String: Result<ProtoAST, ProtoParseError>] = [:]
    let resultsQueue = DispatchQueue(label: "results", attributes: .concurrent)
    
    for filePath in batch {
      group.enter()
      
      queue.async {
        let result = self.parseFileWithCaching(filePath, importPaths: importPaths)
        
        resultsQueue.async(flags: .barrier) {
          batchResults[filePath] = result
          group.leave()  // Move group.leave() here to ensure it happens after the result is stored
        }
      }
    }
    
    group.wait()
    
    // Merge batch results into main results
    for (key, value) in batchResults {
      results[key] = value
    }
  }

  private func parseFileWithCaching(
    _ filePath: String,
    importPaths: [String]
  ) -> Result<ProtoAST, ProtoParseError> {
    
    do {
      let content = try String(contentsOfFile: filePath, encoding: .utf8)
      let contentHash = PerformanceCache.contentHash(for: content)
      
      // Check cache first
      if configuration.enableResultCaching,
         let cachedAST = cache.getCachedAST(for: filePath, contentHash: contentHash) {
        return .success(cachedAST)
      }
      
      // Parse file
      let startTime = Date()
      let result = SwiftProtoParser.parseProtoFileWithImports(filePath, importPaths: importPaths)
      let parseTime = Date().timeIntervalSince(startTime)
      
      // Update metadata and cache result
      switch result {
      case .success(let ast):
        updateFileMetadata(filePath, content: content, contentHash: contentHash)
        
        if configuration.enableResultCaching {
          let fileSize = try getFileSize(filePath)
          cache.cacheAST(ast, for: filePath, contentHash: contentHash, fileSize: fileSize, parseTime: parseTime)
        }
        
        return .success(ast)
        
      case .failure(let error):
        return .failure(error)
      }
      
    } catch {
      return .failure(.ioError(underlying: error))
    }
  }

  private func parseFileInChunks(
    _ filePath: String,
    importPaths: [String]
  ) throws -> Result<ProtoAST, ProtoParseError> {
    
    // For very large files, we need to be more careful
    // This is a simplified implementation - in practice, you might need
    // more sophisticated streaming parsing
    
    let fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: filePath))
    defer { fileHandle.closeFile() }
    
    var content = ""
    var offset: UInt64 = 0
    
    while true {
      let chunk = fileHandle.readData(ofLength: configuration.streamingChunkSize)
      if chunk.isEmpty { break }
      
      if let chunkString = String(data: chunk, encoding: .utf8) {
        content += chunkString
      }
      
      offset += UInt64(chunk.count)
      
      // Check memory usage and break if needed
      if getCurrentMemoryUsage() > configuration.maxInMemorySize {
        throw ProtoParseError.performanceLimitExceeded(
          message: "File too large for streaming parser",
          limit: "maxInMemorySize: \(configuration.maxInMemorySize)"
        )
      }
    }
    
    // Parse the complete content
    return SwiftProtoParser.parseProtoString(content, fileName: filePath)
  }

  private func updateFileMetadata(_ filePath: String, content: String, contentHash: String) {
    do {
      let attributes = try fileManager.attributesOfItem(atPath: filePath)
      guard let modificationDate = attributes[.modificationDate] as? Date,
            let fileSize = attributes[.size] as? Int64 else {
        return
      }
      
      // Extract dependencies from content (simplified)
      let dependencies = extractDependencies(from: content)
      
      let metadata = FileMetadata(
        filePath: filePath,
        lastModified: modificationDate,
        fileSize: fileSize,
        contentHash: contentHash,
        dependencies: dependencies,
        dependents: Set() // Will be populated when building dependency graph
      )
      
      // Synchronize access to fileMetadata dictionary
      queue.async(flags: .barrier) {
        self.fileMetadata[filePath] = metadata
      }
      
    } catch {
      // Failed to update metadata, continue without it
    }
  }

  private func extractDependencies(from content: String) -> Set<String> {
    var dependencies: Set<String> = []
    
    // Simple regex to find import statements
    let importPattern = #"import\s+"([^"]+)""#
    let regex = try? NSRegularExpression(pattern: importPattern, options: [])
    let range = NSRange(content.startIndex..<content.endIndex, in: content)
    
    regex?.enumerateMatches(in: content, options: [], range: range) { match, _, _ in
      if let match = match,
         let range = Range(match.range(at: 1), in: content) {
        dependencies.insert(String(content[range]))
      }
    }
    
    return dependencies
  }

  private func getFileSize(_ filePath: String) throws -> Int64 {
    let attributes = try fileManager.attributesOfItem(atPath: filePath)
    return attributes[.size] as? Int64 ?? 0
  }

  private func getCurrentMemoryUsage() -> Int64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
      }
    }
    
    if kerr == KERN_SUCCESS {
      return Int64(info.resident_size)
    }
    
    return 0
  }

  private func updateStats(_ update: @escaping (inout Statistics) -> Void) {
    queue.async(flags: .barrier) {
      var newStats = self.stats
      update(&newStats)
      self.stats = newStats
    }
  }

  private func resetStatistics() {
    stats = Statistics(
      totalFilesTracked: 0,
      filesProcessedIncrementally: 0,
      filesProcessedFromScratch: 0,
      totalParsingTime: 0.0,
      incrementalSavings: 0.0,
      memoryPeakUsage: 0
    )
  }
}

// MARK: - Array Extension for Chunking

private extension Array {
  func chunked(into size: Int) -> [[Element]] {
    return stride(from: 0, to: count, by: size).map {
      Array(self[$0..<Swift.min($0 + size, count)])
    }
  }
}
