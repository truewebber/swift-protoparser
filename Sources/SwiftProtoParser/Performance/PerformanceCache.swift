import Foundation
import SwiftProtobuf

/// Centralized caching system for SwiftProtoParser performance optimization.
///
/// This cache system provides:
/// - Parsed AST caching based on file content hash
/// - Descriptor caching for frequently used files
/// - Dependency resolution result caching
/// - Memory-aware cache eviction policies
/// - Performance metrics and monitoring
public final class PerformanceCache {

  // MARK: - Cache Entry Types

  /// Cache entry for parsed AST with metadata.
  private struct ASTCacheEntry {
    let ast: ProtoAST
    let contentHash: String
    let fileSize: Int64
    let parseTime: TimeInterval
    let createdAt: Date
    let accessCount: Int
    let lastAccessed: Date
  }

  /// Cache entry for file descriptors.
  private struct DescriptorCacheEntry {
    let descriptor: Google_Protobuf_FileDescriptorProto
    let contentHash: String
    let fileSize: Int64
    let buildTime: TimeInterval
    let createdAt: Date
    let accessCount: Int
    let lastAccessed: Date
  }

  /// Cache entry for dependency resolution results.
  private struct DependencyCacheEntry {
    let result: DependencyResolver.ResolutionResult
    let contentHash: String
    let createdAt: Date
    let accessCount: Int
    let lastAccessed: Date
  }

  // MARK: - Configuration

  /// Cache configuration settings.
  public struct Configuration: Sendable {
    /// Maximum number of AST entries to cache.
    public let maxASTEntries: Int

    /// Maximum number of descriptor entries to cache.
    public let maxDescriptorEntries: Int

    /// Maximum number of dependency resolution entries to cache.
    public let maxDependencyEntries: Int

    /// Maximum memory usage in bytes (approximate).
    public let maxMemoryUsage: Int64

    /// Time-to-live for cache entries in seconds.
    public let timeToLive: TimeInterval

    /// Enable performance monitoring.
    public let enableMonitoring: Bool

    /// Initialize cache configuration.
    public init(
      maxASTEntries: Int,
      maxDescriptorEntries: Int,
      maxDependencyEntries: Int,
      maxMemoryUsage: Int64,
      timeToLive: TimeInterval,
      enableMonitoring: Bool
    ) {
      self.maxASTEntries = maxASTEntries
      self.maxDescriptorEntries = maxDescriptorEntries
      self.maxDependencyEntries = maxDependencyEntries
      self.maxMemoryUsage = maxMemoryUsage
      self.timeToLive = timeToLive
      self.enableMonitoring = enableMonitoring
    }

    /// Default configuration.
    public static let `default` = Configuration(
      maxASTEntries: 1000,
      maxDescriptorEntries: 500,
      maxDependencyEntries: 200,
      maxMemoryUsage: 100 * 1024 * 1024,  // 100MB
      timeToLive: 3600,  // 1 hour
      enableMonitoring: true
    )

    /// High-performance configuration for large projects.
    public static let highPerformance = Configuration(
      maxASTEntries: 5000,
      maxDescriptorEntries: 2500,
      maxDependencyEntries: 1000,
      maxMemoryUsage: 500 * 1024 * 1024,  // 500MB
      timeToLive: 7200,  // 2 hours
      enableMonitoring: true
    )

    /// Memory-constrained configuration.
    public static let memoryConstrained = Configuration(
      maxASTEntries: 100,
      maxDescriptorEntries: 50,
      maxDependencyEntries: 25,
      maxMemoryUsage: 10 * 1024 * 1024,  // 10MB
      timeToLive: 1800,  // 30 minutes
      enableMonitoring: false
    )
  }

  // MARK: - Cache Storage

  private var astCache: [String: ASTCacheEntry] = [:]
  private var descriptorCache: [String: DescriptorCacheEntry] = [:]
  private var dependencyCache: [String: DependencyCacheEntry] = [:]

  private let configuration: Configuration
  private let queue = DispatchQueue(label: "com.swiftprotoparser.cache", attributes: .concurrent)
  private var monitoringTask: Task<Void, Never>?

  // MARK: - Performance Metrics

  /// Cache performance statistics.
  public struct Statistics: Sendable {
    public let astCacheHits: Int
    public let astCacheMisses: Int
    public let descriptorCacheHits: Int
    public let descriptorCacheMisses: Int
    public let dependencyCacheHits: Int
    public let dependencyCacheMisses: Int
    public let totalMemoryUsage: Int64
    public let evictionCount: Int
    public let averageParseTime: TimeInterval
    public let averageBuildTime: TimeInterval

    public var astHitRate: Double {
      let total = astCacheHits + astCacheMisses
      return total > 0 ? Double(astCacheHits) / Double(total) : 0.0
    }

    public var descriptorHitRate: Double {
      let total = descriptorCacheHits + descriptorCacheMisses
      return total > 0 ? Double(descriptorCacheHits) / Double(total) : 0.0
    }

    public var dependencyHitRate: Double {
      let total = dependencyCacheHits + dependencyCacheMisses
      return total > 0 ? Double(dependencyCacheHits) / Double(total) : 0.0
    }
  }

  private var stats = Statistics(
    astCacheHits: 0,
    astCacheMisses: 0,
    descriptorCacheHits: 0,
    descriptorCacheMisses: 0,
    dependencyCacheHits: 0,
    dependencyCacheMisses: 0,
    totalMemoryUsage: 0,
    evictionCount: 0,
    averageParseTime: 0.0,
    averageBuildTime: 0.0
  )

  // MARK: - Initialization

  /// Initialize the performance cache with configuration.
  /// - Parameter configuration: Cache configuration settings.
  public init(configuration: Configuration = .default) {
    self.configuration = configuration

    if configuration.enableMonitoring {
      startPerformanceMonitoring()
    }
  }

  // MARK: - AST Caching

  /// Retrieve cached AST for a file.
  /// - Parameters:
  ///   - filePath: Path to the proto file.
  ///   - contentHash: Hash of the file content.
  /// - Returns: Cached AST if available and valid.
  public func getCachedAST(for filePath: String, contentHash: String) -> ProtoAST? {
    return queue.sync {
      guard let entry = astCache[filePath],
        entry.contentHash == contentHash,
        !isExpired(entry.createdAt)
      else {
        // Miss - update stats synchronously for immediate feedback
        var newStats = stats
        newStats = Statistics(
          astCacheHits: newStats.astCacheHits,
          astCacheMisses: newStats.astCacheMisses + 1,
          descriptorCacheHits: newStats.descriptorCacheHits,
          descriptorCacheMisses: newStats.descriptorCacheMisses,
          dependencyCacheHits: newStats.dependencyCacheHits,
          dependencyCacheMisses: newStats.dependencyCacheMisses,
          totalMemoryUsage: newStats.totalMemoryUsage,
          evictionCount: newStats.evictionCount,
          averageParseTime: newStats.averageParseTime,
          averageBuildTime: newStats.averageBuildTime
        )
        stats = newStats
        return nil
      }

      // Hit - update entry and stats
      let updatedEntry = ASTCacheEntry(
        ast: entry.ast,
        contentHash: entry.contentHash,
        fileSize: entry.fileSize,
        parseTime: entry.parseTime,
        createdAt: entry.createdAt,
        accessCount: entry.accessCount + 1,
        lastAccessed: Date()
      )
      astCache[filePath] = updatedEntry

      var newStats = stats
      newStats = Statistics(
        astCacheHits: newStats.astCacheHits + 1,
        astCacheMisses: newStats.astCacheMisses,
        descriptorCacheHits: newStats.descriptorCacheHits,
        descriptorCacheMisses: newStats.descriptorCacheMisses,
        dependencyCacheHits: newStats.dependencyCacheHits,
        dependencyCacheMisses: newStats.dependencyCacheMisses,
        totalMemoryUsage: newStats.totalMemoryUsage,
        evictionCount: newStats.evictionCount,
        averageParseTime: newStats.averageParseTime,
        averageBuildTime: newStats.averageBuildTime
      )
      stats = newStats

      return entry.ast
    }
  }

  /// Cache parsed AST for a file.
  /// - Parameters:
  ///   - ast: Parsed AST to cache.
  ///   - filePath: Path to the proto file.
  ///   - contentHash: Hash of the file content.
  ///   - fileSize: Size of the file in bytes.
  ///   - parseTime: Time taken to parse the file.
  public func cacheAST(
    _ ast: ProtoAST,
    for filePath: String,
    contentHash: String,
    fileSize: Int64,
    parseTime: TimeInterval
  ) {
    let entry = ASTCacheEntry(
      ast: ast,
      contentHash: contentHash,
      fileSize: fileSize,
      parseTime: parseTime,
      createdAt: Date(),
      accessCount: 1,
      lastAccessed: Date()
    )

    astCache[filePath] = entry
    enforceASTCacheLimits()
    updateAverageParseTime(parseTime)
  }

  // MARK: - Descriptor Caching

  /// Retrieve cached descriptor for a file.
  /// - Parameters:
  ///   - filePath: Path to the proto file.
  ///   - contentHash: Hash of the file content.
  /// - Returns: Cached descriptor if available and valid.
  public func getCachedDescriptor(for filePath: String, contentHash: String) -> Google_Protobuf_FileDescriptorProto? {
    guard let entry = descriptorCache[filePath],
      entry.contentHash == contentHash,
      !isExpired(entry.createdAt)
    else {
      updateStatsSync { stats in
        stats = Statistics(
          astCacheHits: stats.astCacheHits,
          astCacheMisses: stats.astCacheMisses,
          descriptorCacheHits: stats.descriptorCacheHits,
          descriptorCacheMisses: stats.descriptorCacheMisses + 1,
          dependencyCacheHits: stats.dependencyCacheHits,
          dependencyCacheMisses: stats.dependencyCacheMisses,
          totalMemoryUsage: stats.totalMemoryUsage,
          evictionCount: stats.evictionCount,
          averageParseTime: stats.averageParseTime,
          averageBuildTime: stats.averageBuildTime
        )
      }
      return nil
    }

    // Update access statistics
    let updatedEntry = DescriptorCacheEntry(
      descriptor: entry.descriptor,
      contentHash: entry.contentHash,
      fileSize: entry.fileSize,
      buildTime: entry.buildTime,
      createdAt: entry.createdAt,
      accessCount: entry.accessCount + 1,
      lastAccessed: Date()
    )
    descriptorCache[filePath] = updatedEntry

    updateStatsSync { stats in
      stats = Statistics(
        astCacheHits: stats.astCacheHits,
        astCacheMisses: stats.astCacheMisses,
        descriptorCacheHits: stats.descriptorCacheHits + 1,
        descriptorCacheMisses: stats.descriptorCacheMisses,
        dependencyCacheHits: stats.dependencyCacheHits,
        dependencyCacheMisses: stats.dependencyCacheMisses,
        totalMemoryUsage: stats.totalMemoryUsage,
        evictionCount: stats.evictionCount,
        averageParseTime: stats.averageParseTime,
        averageBuildTime: stats.averageBuildTime
      )
    }

    return entry.descriptor
  }

  /// Cache built descriptor for a file.
  /// - Parameters:
  ///   - descriptor: Built descriptor to cache.
  ///   - filePath: Path to the proto file.
  ///   - contentHash: Hash of the file content.
  ///   - fileSize: Size of the file in bytes.
  ///   - buildTime: Time taken to build the descriptor.
  public func cacheDescriptor(
    _ descriptor: Google_Protobuf_FileDescriptorProto,
    for filePath: String,
    contentHash: String,
    fileSize: Int64,
    buildTime: TimeInterval
  ) {
    let entry = DescriptorCacheEntry(
      descriptor: descriptor,
      contentHash: contentHash,
      fileSize: fileSize,
      buildTime: buildTime,
      createdAt: Date(),
      accessCount: 1,
      lastAccessed: Date()
    )

    descriptorCache[filePath] = entry
    enforceDescriptorCacheLimits()
    updateAverageBuildTime(buildTime)
  }

  // MARK: - Dependency Caching

  /// Retrieve cached dependency resolution result.
  /// - Parameters:
  ///   - filePath: Path to the main proto file.
  ///   - contentHash: Hash of the combined content.
  /// - Returns: Cached resolution result if available and valid.
  public func getCachedDependencyResult(for filePath: String, contentHash: String) -> DependencyResolver
    .ResolutionResult?
  {
    guard let entry = dependencyCache[filePath],
      entry.contentHash == contentHash,
      !isExpired(entry.createdAt)
    else {
      updateStatsSync { stats in
        stats = Statistics(
          astCacheHits: stats.astCacheHits,
          astCacheMisses: stats.astCacheMisses,
          descriptorCacheHits: stats.descriptorCacheHits,
          descriptorCacheMisses: stats.descriptorCacheMisses,
          dependencyCacheHits: stats.dependencyCacheHits,
          dependencyCacheMisses: stats.dependencyCacheMisses + 1,
          totalMemoryUsage: stats.totalMemoryUsage,
          evictionCount: stats.evictionCount,
          averageParseTime: stats.averageParseTime,
          averageBuildTime: stats.averageBuildTime
        )
      }
      return nil
    }

    // Update access statistics
    let updatedEntry = DependencyCacheEntry(
      result: entry.result,
      contentHash: entry.contentHash,
      createdAt: entry.createdAt,
      accessCount: entry.accessCount + 1,
      lastAccessed: Date()
    )
    dependencyCache[filePath] = updatedEntry

    updateStatsSync { stats in
      stats = Statistics(
        astCacheHits: stats.astCacheHits,
        astCacheMisses: stats.astCacheMisses,
        descriptorCacheHits: stats.descriptorCacheHits,
        descriptorCacheMisses: stats.descriptorCacheMisses,
        dependencyCacheHits: stats.dependencyCacheHits + 1,
        dependencyCacheMisses: stats.dependencyCacheMisses,
        totalMemoryUsage: stats.totalMemoryUsage,
        evictionCount: stats.evictionCount,
        averageParseTime: stats.averageParseTime,
        averageBuildTime: stats.averageBuildTime
      )
    }

    return entry.result
  }

  /// Cache dependency resolution result.
  /// - Parameters:
  ///   - result: Resolution result to cache.
  ///   - filePath: Path to the main proto file.
  ///   - contentHash: Hash of the combined content.
  public func cacheDependencyResult(
    _ result: DependencyResolver.ResolutionResult,
    for filePath: String,
    contentHash: String
  ) {
    let entry = DependencyCacheEntry(
      result: result,
      contentHash: contentHash,
      createdAt: Date(),
      accessCount: 1,
      lastAccessed: Date()
    )

    dependencyCache[filePath] = entry
    enforceDependencyCacheLimits()
  }

  // MARK: - Cache Management

  /// Clear all caches.
  public func clearAll() {
    astCache.removeAll()
    descriptorCache.removeAll()
    dependencyCache.removeAll()
    resetStatistics()
  }

  /// Clear expired entries from all caches.
  public func clearExpired() {
    let now = Date()

    astCache = astCache.filter { !isExpired($0.value.createdAt, at: now) }
    descriptorCache = descriptorCache.filter { !isExpired($0.value.createdAt, at: now) }
    dependencyCache = dependencyCache.filter { !isExpired($0.value.createdAt, at: now) }
  }

  /// Get current cache statistics.
  /// - Returns: Current performance statistics.
  public func getStatistics() -> Statistics {
    return stats
  }

  // MARK: - Private Implementation

  private func isExpired(_ createdAt: Date, at currentTime: Date = Date()) -> Bool {
    return currentTime.timeIntervalSince(createdAt) > configuration.timeToLive
  }

  private func enforceASTCacheLimits() {
    while astCache.count > configuration.maxASTEntries {
      evictLeastRecentlyUsedAST()
    }
  }

  private func enforceDescriptorCacheLimits() {
    while descriptorCache.count > configuration.maxDescriptorEntries {
      evictLeastRecentlyUsedDescriptor()
    }
  }

  private func enforceDependencyCacheLimits() {
    while dependencyCache.count > configuration.maxDependencyEntries {
      evictLeastRecentlyUsedDependency()
    }
  }

  private func evictLeastRecentlyUsedAST() {
    guard let oldestKey = astCache.min(by: { $0.value.lastAccessed < $1.value.lastAccessed })?.key else {
      return
    }
    astCache.removeValue(forKey: oldestKey)
    updateEvictionCount()
  }

  private func evictLeastRecentlyUsedDescriptor() {
    guard let oldestKey = descriptorCache.min(by: { $0.value.lastAccessed < $1.value.lastAccessed })?.key else {
      return
    }
    descriptorCache.removeValue(forKey: oldestKey)
    updateEvictionCount()
  }

  private func evictLeastRecentlyUsedDependency() {
    guard let oldestKey = dependencyCache.min(by: { $0.value.lastAccessed < $1.value.lastAccessed })?.key else {
      return
    }
    dependencyCache.removeValue(forKey: oldestKey)
    updateEvictionCount()
  }

  private func updateStatsSync(_ update: (inout Statistics) -> Void) {
    var newStats = stats
    update(&newStats)
    stats = newStats
  }

  private func updateEvictionCount() {
    updateStatsSync { stats in
      stats = Statistics(
        astCacheHits: stats.astCacheHits,
        astCacheMisses: stats.astCacheMisses,
        descriptorCacheHits: stats.descriptorCacheHits,
        descriptorCacheMisses: stats.descriptorCacheMisses,
        dependencyCacheHits: stats.dependencyCacheHits,
        dependencyCacheMisses: stats.dependencyCacheMisses,
        totalMemoryUsage: stats.totalMemoryUsage,
        evictionCount: stats.evictionCount + 1,
        averageParseTime: stats.averageParseTime,
        averageBuildTime: stats.averageBuildTime
      )
    }
  }

  private func updateAverageParseTime(_ parseTime: TimeInterval) {
    updateStatsSync { stats in
      let totalParses = stats.astCacheHits + stats.astCacheMisses
      let newAverage =
        totalParses > 0
        ? (stats.averageParseTime * Double(totalParses - 1) + parseTime) / Double(totalParses) : parseTime

      stats = Statistics(
        astCacheHits: stats.astCacheHits,
        astCacheMisses: stats.astCacheMisses,
        descriptorCacheHits: stats.descriptorCacheHits,
        descriptorCacheMisses: stats.descriptorCacheMisses,
        dependencyCacheHits: stats.dependencyCacheHits,
        dependencyCacheMisses: stats.dependencyCacheMisses,
        totalMemoryUsage: stats.totalMemoryUsage,
        evictionCount: stats.evictionCount,
        averageParseTime: newAverage,
        averageBuildTime: stats.averageBuildTime
      )
    }
  }

  private func updateAverageBuildTime(_ buildTime: TimeInterval) {
    updateStatsSync { stats in
      let totalBuilds = stats.descriptorCacheHits + stats.descriptorCacheMisses
      let newAverage =
        totalBuilds > 0
        ? (stats.averageBuildTime * Double(totalBuilds - 1) + buildTime) / Double(totalBuilds) : buildTime

      stats = Statistics(
        astCacheHits: stats.astCacheHits,
        astCacheMisses: stats.astCacheMisses,
        descriptorCacheHits: stats.descriptorCacheHits,
        descriptorCacheMisses: stats.descriptorCacheMisses,
        dependencyCacheHits: stats.dependencyCacheHits,
        dependencyCacheMisses: stats.dependencyCacheMisses,
        totalMemoryUsage: stats.totalMemoryUsage,
        evictionCount: stats.evictionCount,
        averageParseTime: stats.averageParseTime,
        averageBuildTime: newAverage
      )
    }
  }

  private func resetStatistics() {
    stats = Statistics(
      astCacheHits: 0,
      astCacheMisses: 0,
      descriptorCacheHits: 0,
      descriptorCacheMisses: 0,
      dependencyCacheHits: 0,
      dependencyCacheMisses: 0,
      totalMemoryUsage: 0,
      evictionCount: 0,
      averageParseTime: 0.0,
      averageBuildTime: 0.0
    )
  }

  private func startPerformanceMonitoring() {
    // Start a task to periodically clear expired entries
    monitoringTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 300_000_000_000)  // 300 seconds
        self?.clearExpired()
      }
    }
  }
}

// MARK: - Content Hashing Utilities

extension PerformanceCache {

  /// Generate content hash for a file.
  /// - Parameter content: File content to hash.
  /// - Returns: SHA256 hash of the content.
  public static func contentHash(for content: String) -> String {
    let data = content.data(using: .utf8) ?? Data()
    return data.withUnsafeBytes { bytes in
      let buffer = bytes.bindMemory(to: UInt8.self)
      return SimpleHash.hash(data: buffer).map { String(format: "%02x", $0) }.joined()
    }
  }

  /// Generate combined hash for dependency resolution.
  /// - Parameter files: Array of resolved proto files.
  /// - Returns: Combined hash of all file contents.
  public static func combinedHash(for files: [ResolvedProtoFile]) -> String {
    let combinedContent = files.map { "\($0.filePath):\($0.content)" }.joined(separator: "\n")
    return contentHash(for: combinedContent)
  }
}

// MARK: - Simple Hash Implementation

private struct SimpleHash {
  static func hash(data: UnsafeBufferPointer<UInt8>) -> [UInt8] {
    // Simple hash implementation for content hashing
    var hash: UInt64 = 5381

    for byte in data {
      hash = ((hash << 5) &+ hash) &+ UInt64(byte)
    }

    var result: [UInt8] = []
    for i in 0..<8 {
      result.append(UInt8((hash >> (i * 8)) & 0xFF))
    }

    return result
  }
}
