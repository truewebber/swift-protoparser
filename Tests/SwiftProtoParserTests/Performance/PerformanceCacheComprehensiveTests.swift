import SwiftProtobuf
import XCTest

@testable import SwiftProtoParser

final class PerformanceCacheComprehensiveTests: XCTestCase {

  var cache: PerformanceCache!

  override func setUp() {
    super.setUp()
    cache = PerformanceCache(configuration: .default)
  }

  override func tearDown() {
    cache.clearAll()
    cache = nil
    super.tearDown()
  }

  // MARK: - Descriptor Caching Tests

  func testDescriptorCaching() throws {
    let descriptor = try createTestDescriptor()
    let filePath = "/test/descriptor.proto"
    let contentHash = "descriptor_hash"
    let fileSize: Int64 = 2048
    let buildTime: TimeInterval = 0.1

    // Cache descriptor
    cache.cacheDescriptor(descriptor, for: filePath, contentHash: contentHash, fileSize: fileSize, buildTime: buildTime)

    // Retrieve cached descriptor
    let cachedDescriptor = cache.getCachedDescriptor(for: filePath, contentHash: contentHash)
    XCTAssertNotNil(cachedDescriptor)
    XCTAssertEqual(cachedDescriptor?.name, descriptor.name)
    XCTAssertEqual(cachedDescriptor?.syntax, descriptor.syntax)
  }

  func testDescriptorCacheMiss() {
    let filePath = "/test/descriptor.proto"
    let contentHash = "nonexistent_hash"

    let cachedDescriptor = cache.getCachedDescriptor(for: filePath, contentHash: contentHash)
    XCTAssertNil(cachedDescriptor)
  }

  func testDescriptorCacheInvalidation() throws {
    let descriptor = try createTestDescriptor()
    let filePath = "/test/descriptor.proto"
    let oldContentHash = "old_descriptor_hash"
    let newContentHash = "new_descriptor_hash"
    let fileSize: Int64 = 2048
    let buildTime: TimeInterval = 0.1

    // Cache with old hash
    cache.cacheDescriptor(
      descriptor,
      for: filePath,
      contentHash: oldContentHash,
      fileSize: fileSize,
      buildTime: buildTime
    )

    // Try to retrieve with new hash (should miss)
    let cachedDescriptor = cache.getCachedDescriptor(for: filePath, contentHash: newContentHash)
    XCTAssertNil(cachedDescriptor)

    // Should still be able to retrieve with old hash
    let oldCachedDescriptor = cache.getCachedDescriptor(for: filePath, contentHash: oldContentHash)
    XCTAssertNotNil(oldCachedDescriptor)
  }

  func testDescriptorStatistics() throws {
    let descriptor = try createTestDescriptor()
    let filePath = "/test/descriptor.proto"
    let contentHash = "descriptor_hash"
    let fileSize: Int64 = 2048
    let buildTime: TimeInterval = 0.1

    // Cache descriptor
    cache.cacheDescriptor(descriptor, for: filePath, contentHash: contentHash, fileSize: fileSize, buildTime: buildTime)

    // First retrieval (hit)
    _ = cache.getCachedDescriptor(for: filePath, contentHash: contentHash)

    // Second retrieval (another hit)
    _ = cache.getCachedDescriptor(for: filePath, contentHash: contentHash)

    // One miss
    _ = cache.getCachedDescriptor(for: "/nonexistent", contentHash: "nonexistent")

    let stats = cache.getStatistics()
    XCTAssertEqual(stats.descriptorCacheHits, 2)
    XCTAssertEqual(stats.descriptorCacheMisses, 1)
    XCTAssertEqual(stats.descriptorHitRate, 2.0 / 3.0, accuracy: 0.01)
  }

  // MARK: - Dependency Caching Tests

  func testDependencyCaching() throws {
    let result = try createTestDependencyResult()
    let filePath = "/test/main.proto"
    let contentHash = "dependency_hash"

    // Cache dependency result
    cache.cacheDependencyResult(result, for: filePath, contentHash: contentHash)

    // Retrieve cached result
    let cachedResult = cache.getCachedDependencyResult(for: filePath, contentHash: contentHash)
    XCTAssertNotNil(cachedResult)
    XCTAssertEqual(cachedResult?.mainFile.filePath, result.mainFile.filePath)
    XCTAssertEqual(cachedResult?.dependencies.count, result.dependencies.count)
  }

  func testDependencyCacheMiss() {
    let filePath = "/test/main.proto"
    let contentHash = "nonexistent_hash"

    let cachedResult = cache.getCachedDependencyResult(for: filePath, contentHash: contentHash)
    XCTAssertNil(cachedResult)
  }

  func testDependencyStatistics() throws {
    let result = try createTestDependencyResult()
    let filePath = "/test/main.proto"
    let contentHash = "dependency_hash"

    // Cache dependency result
    cache.cacheDependencyResult(result, for: filePath, contentHash: contentHash)

    // First retrieval (hit)
    _ = cache.getCachedDependencyResult(for: filePath, contentHash: contentHash)

    // One miss
    _ = cache.getCachedDependencyResult(for: "/nonexistent", contentHash: "nonexistent")

    let stats = cache.getStatistics()
    XCTAssertEqual(stats.dependencyCacheHits, 1)
    XCTAssertEqual(stats.dependencyCacheMisses, 1)
    XCTAssertEqual(stats.dependencyHitRate, 0.5, accuracy: 0.01)
  }

  // MARK: - Cache Expiration Tests

  func testCacheExpiration() {
    // Create cache with very short TTL
    let shortTTLConfig = PerformanceCache.Configuration(
      maxASTEntries: 10,
      maxDescriptorEntries: 10,
      maxDependencyEntries: 10,
      maxMemoryUsage: 1024 * 1024,
      timeToLive: 0.1,  // 100ms
      enableMonitoring: false
    )
    let shortTTLCache = PerformanceCache(configuration: shortTTLConfig)

    let ast = createTestAST()
    let filePath = "/test/expiring.proto"
    let contentHash = "expiring_hash"
    let fileSize: Int64 = 1024
    let parseTime: TimeInterval = 0.05

    // Cache AST
    shortTTLCache.cacheAST(ast, for: filePath, contentHash: contentHash, fileSize: fileSize, parseTime: parseTime)

    // Should be able to retrieve immediately
    let cachedAST1 = shortTTLCache.getCachedAST(for: filePath, contentHash: contentHash)
    XCTAssertNotNil(cachedAST1)

    // Wait for expiration
    Thread.sleep(forTimeInterval: 0.2)

    // Should be expired now
    let cachedAST2 = shortTTLCache.getCachedAST(for: filePath, contentHash: contentHash)
    XCTAssertNil(cachedAST2)

    shortTTLCache.clearAll()
  }

  func testClearExpired() {
    // Create cache with short TTL
    let shortTTLConfig = PerformanceCache.Configuration(
      maxASTEntries: 10,
      maxDescriptorEntries: 10,
      maxDependencyEntries: 10,
      maxMemoryUsage: 1024 * 1024,
      timeToLive: 0.1,  // 100ms
      enableMonitoring: false
    )
    let shortTTLCache = PerformanceCache(configuration: shortTTLConfig)

    let ast = createTestAST()
    let filePath1 = "/test/expire1.proto"
    let filePath2 = "/test/expire2.proto"
    let contentHash = "expiring_hash"
    let fileSize: Int64 = 1024
    let parseTime: TimeInterval = 0.05

    // Cache two ASTs
    shortTTLCache.cacheAST(ast, for: filePath1, contentHash: contentHash, fileSize: fileSize, parseTime: parseTime)
    shortTTLCache.cacheAST(ast, for: filePath2, contentHash: contentHash, fileSize: fileSize, parseTime: parseTime)

    // Both should be retrievable
    XCTAssertNotNil(shortTTLCache.getCachedAST(for: filePath1, contentHash: contentHash))
    XCTAssertNotNil(shortTTLCache.getCachedAST(for: filePath2, contentHash: contentHash))

    // Wait for expiration
    Thread.sleep(forTimeInterval: 0.2)

    // Clear expired entries
    shortTTLCache.clearExpired()

    // Both should be gone now
    XCTAssertNil(shortTTLCache.getCachedAST(for: filePath1, contentHash: contentHash))
    XCTAssertNil(shortTTLCache.getCachedAST(for: filePath2, contentHash: contentHash))

    shortTTLCache.clearAll()
  }

  // MARK: - Cache Eviction (LRU) Tests

  func testASTCacheEviction() {
    // Create cache with very small limits
    let smallConfig = PerformanceCache.Configuration(
      maxASTEntries: 2,
      maxDescriptorEntries: 10,
      maxDependencyEntries: 10,
      maxMemoryUsage: 1024 * 1024,
      timeToLive: 3600,
      enableMonitoring: false
    )
    let smallCache = PerformanceCache(configuration: smallConfig)

    let ast = createTestAST()
    let fileSize: Int64 = 1024
    let parseTime: TimeInterval = 0.05

    // Cache 3 ASTs (should trigger eviction)
    smallCache.cacheAST(ast, for: "/test/file1.proto", contentHash: "hash1", fileSize: fileSize, parseTime: parseTime)
    smallCache.cacheAST(ast, for: "/test/file2.proto", contentHash: "hash2", fileSize: fileSize, parseTime: parseTime)
    smallCache.cacheAST(ast, for: "/test/file3.proto", contentHash: "hash3", fileSize: fileSize, parseTime: parseTime)

    // First file should be evicted (LRU)
    XCTAssertNil(smallCache.getCachedAST(for: "/test/file1.proto", contentHash: "hash1"))
    XCTAssertNotNil(smallCache.getCachedAST(for: "/test/file2.proto", contentHash: "hash2"))
    XCTAssertNotNil(smallCache.getCachedAST(for: "/test/file3.proto", contentHash: "hash3"))

    // Check eviction count in statistics
    let stats = smallCache.getStatistics()
    XCTAssertGreaterThan(stats.evictionCount, 0)

    smallCache.clearAll()
  }

  func testDescriptorCacheEviction() throws {
    // Create cache with very small limits
    let smallConfig = PerformanceCache.Configuration(
      maxASTEntries: 10,
      maxDescriptorEntries: 2,
      maxDependencyEntries: 10,
      maxMemoryUsage: 1024 * 1024,
      timeToLive: 3600,
      enableMonitoring: false
    )
    let smallCache = PerformanceCache(configuration: smallConfig)

    let descriptor = try createTestDescriptor()
    let fileSize: Int64 = 2048
    let buildTime: TimeInterval = 0.1

    // Cache 3 descriptors (should trigger eviction)
    smallCache.cacheDescriptor(
      descriptor,
      for: "/test/desc1.proto",
      contentHash: "hash1",
      fileSize: fileSize,
      buildTime: buildTime
    )
    smallCache.cacheDescriptor(
      descriptor,
      for: "/test/desc2.proto",
      contentHash: "hash2",
      fileSize: fileSize,
      buildTime: buildTime
    )
    smallCache.cacheDescriptor(
      descriptor,
      for: "/test/desc3.proto",
      contentHash: "hash3",
      fileSize: fileSize,
      buildTime: buildTime
    )

    // First descriptor should be evicted (LRU)
    XCTAssertNil(smallCache.getCachedDescriptor(for: "/test/desc1.proto", contentHash: "hash1"))
    XCTAssertNotNil(smallCache.getCachedDescriptor(for: "/test/desc2.proto", contentHash: "hash2"))
    XCTAssertNotNil(smallCache.getCachedDescriptor(for: "/test/desc3.proto", contentHash: "hash3"))

    smallCache.clearAll()
  }

  func testDependencyCacheEviction() throws {
    // Create cache with very small limits
    let smallConfig = PerformanceCache.Configuration(
      maxASTEntries: 10,
      maxDescriptorEntries: 10,
      maxDependencyEntries: 2,
      maxMemoryUsage: 1024 * 1024,
      timeToLive: 3600,
      enableMonitoring: false
    )
    let smallCache = PerformanceCache(configuration: smallConfig)

    let result = try createTestDependencyResult()

    // Cache 3 dependency results (should trigger eviction)
    smallCache.cacheDependencyResult(result, for: "/test/dep1.proto", contentHash: "hash1")
    smallCache.cacheDependencyResult(result, for: "/test/dep2.proto", contentHash: "hash2")
    smallCache.cacheDependencyResult(result, for: "/test/dep3.proto", contentHash: "hash3")

    // First dependency should be evicted (LRU)
    XCTAssertNil(smallCache.getCachedDependencyResult(for: "/test/dep1.proto", contentHash: "hash1"))
    XCTAssertNotNil(smallCache.getCachedDependencyResult(for: "/test/dep2.proto", contentHash: "hash2"))
    XCTAssertNotNil(smallCache.getCachedDependencyResult(for: "/test/dep3.proto", contentHash: "hash3"))

    smallCache.clearAll()
  }

  // MARK: - Access Count and LRU Behavior Tests

  func testLRUBehavior() {
    // Create cache with small limit to test LRU
    let smallConfig = PerformanceCache.Configuration(
      maxASTEntries: 3,
      maxDescriptorEntries: 10,
      maxDependencyEntries: 10,
      maxMemoryUsage: 1024 * 1024,
      timeToLive: 3600,
      enableMonitoring: false
    )
    let smallCache = PerformanceCache(configuration: smallConfig)

    let ast = createTestAST()
    let fileSize: Int64 = 1024
    let parseTime: TimeInterval = 0.05

    // Cache 3 ASTs
    smallCache.cacheAST(ast, for: "/test/file1.proto", contentHash: "hash1", fileSize: fileSize, parseTime: parseTime)
    smallCache.cacheAST(ast, for: "/test/file2.proto", contentHash: "hash2", fileSize: fileSize, parseTime: parseTime)
    smallCache.cacheAST(ast, for: "/test/file3.proto", contentHash: "hash3", fileSize: fileSize, parseTime: parseTime)

    // Access file1 to make it recently used
    _ = smallCache.getCachedAST(for: "/test/file1.proto", contentHash: "hash1")

    // Add 4th file (should evict file2, not file1)
    smallCache.cacheAST(ast, for: "/test/file4.proto", contentHash: "hash4", fileSize: fileSize, parseTime: parseTime)

    // file1 should still be there (recently accessed)
    XCTAssertNotNil(smallCache.getCachedAST(for: "/test/file1.proto", contentHash: "hash1"))
    // file2 should be evicted (least recently used)
    XCTAssertNil(smallCache.getCachedAST(for: "/test/file2.proto", contentHash: "hash2"))
    // file3 and file4 should be there
    XCTAssertNotNil(smallCache.getCachedAST(for: "/test/file3.proto", contentHash: "hash3"))
    XCTAssertNotNil(smallCache.getCachedAST(for: "/test/file4.proto", contentHash: "hash4"))

    smallCache.clearAll()
  }

  // MARK: - Combined Hash Tests

  func testCombinedHash() throws {
    let file1 = try createTestResolvedProtoFile(
      path: "/test/file1.proto",
      content: "syntax = \"proto3\"; message Test1 {}"
    )
    let file2 = try createTestResolvedProtoFile(
      path: "/test/file2.proto",
      content: "syntax = \"proto3\"; message Test2 {}"
    )
    let file3 = try createTestResolvedProtoFile(
      path: "/test/file3.proto",
      content: "syntax = \"proto3\"; message Test3 {}"
    )

    let hash1 = PerformanceCache.combinedHash(for: [file1, file2])
    let hash2 = PerformanceCache.combinedHash(for: [file1, file2])
    let hash3 = PerformanceCache.combinedHash(for: [file1, file3])

    // Same files should produce same hash
    XCTAssertEqual(hash1, hash2)

    // Different files should produce different hash
    XCTAssertNotEqual(hash1, hash3)

    // Hash should not be empty
    XCTAssertFalse(hash1.isEmpty)
  }

  func testCombinedHashEmpty() {
    let emptyHash = PerformanceCache.combinedHash(for: [])
    XCTAssertFalse(emptyHash.isEmpty)
  }

  func testCombinedHashOrder() throws {
    let file1 = try createTestResolvedProtoFile(
      path: "/test/file1.proto",
      content: "syntax = \"proto3\"; message Test1 {}"
    )
    let file2 = try createTestResolvedProtoFile(
      path: "/test/file2.proto",
      content: "syntax = \"proto3\"; message Test2 {}"
    )

    let hash1 = PerformanceCache.combinedHash(for: [file1, file2])
    let hash2 = PerformanceCache.combinedHash(for: [file2, file1])

    // Order should matter
    XCTAssertNotEqual(hash1, hash2)
  }

  // MARK: - Configuration Tests

  func testMemoryConstrainedConfiguration() {
    let config = PerformanceCache.Configuration.memoryConstrained
    XCTAssertEqual(config.maxASTEntries, 100)
    XCTAssertEqual(config.maxDescriptorEntries, 50)
    XCTAssertEqual(config.maxDependencyEntries, 25)
    XCTAssertEqual(config.maxMemoryUsage, 10 * 1024 * 1024)
    XCTAssertEqual(config.timeToLive, 1800)
    XCTAssertFalse(config.enableMonitoring)
  }

  func testCustomConfiguration() {
    let customConfig = PerformanceCache.Configuration(
      maxASTEntries: 123,
      maxDescriptorEntries: 456,
      maxDependencyEntries: 789,
      maxMemoryUsage: 987_654_321,
      timeToLive: 1234,
      enableMonitoring: true
    )

    let customCache = PerformanceCache(configuration: customConfig)
    XCTAssertNotNil(customCache)

    customCache.clearAll()
  }

  // MARK: - Average Time Calculations Tests

  func testAverageParseTimeCalculation() {
    let ast = createTestAST()
    let filePath = "/test/parse_time.proto"
    let contentHash = "parse_time_hash"
    let fileSize: Int64 = 1024

    // Cache ASTs with different parse times
    cache.cacheAST(ast, for: "\(filePath)1", contentHash: "\(contentHash)1", fileSize: fileSize, parseTime: 0.1)
    cache.cacheAST(ast, for: "\(filePath)2", contentHash: "\(contentHash)2", fileSize: fileSize, parseTime: 0.2)
    cache.cacheAST(ast, for: "\(filePath)3", contentHash: "\(contentHash)3", fileSize: fileSize, parseTime: 0.3)

    // Access to trigger statistics update
    _ = cache.getCachedAST(for: "\(filePath)1", contentHash: "\(contentHash)1")
    _ = cache.getCachedAST(for: "\(filePath)2", contentHash: "\(contentHash)2")
    _ = cache.getCachedAST(for: "\(filePath)3", contentHash: "\(contentHash)3")

    let stats = cache.getStatistics()
    XCTAssertGreaterThan(stats.averageParseTime, 0.0)
    XCTAssertLessThan(stats.averageParseTime, 1.0)
  }

  func testAverageBuildTimeCalculation() throws {
    let descriptor = try createTestDescriptor()
    let filePath = "/test/build_time.proto"
    let contentHash = "build_time_hash"
    let fileSize: Int64 = 2048

    // Cache descriptors with different build times
    cache.cacheDescriptor(
      descriptor,
      for: "\(filePath)1",
      contentHash: "\(contentHash)1",
      fileSize: fileSize,
      buildTime: 0.05
    )
    cache.cacheDescriptor(
      descriptor,
      for: "\(filePath)2",
      contentHash: "\(contentHash)2",
      fileSize: fileSize,
      buildTime: 0.10
    )
    cache.cacheDescriptor(
      descriptor,
      for: "\(filePath)3",
      contentHash: "\(contentHash)3",
      fileSize: fileSize,
      buildTime: 0.15
    )

    // Access to trigger statistics update
    _ = cache.getCachedDescriptor(for: "\(filePath)1", contentHash: "\(contentHash)1")
    _ = cache.getCachedDescriptor(for: "\(filePath)2", contentHash: "\(contentHash)2")
    _ = cache.getCachedDescriptor(for: "\(filePath)3", contentHash: "\(contentHash)3")

    let stats = cache.getStatistics()
    XCTAssertGreaterThan(stats.averageBuildTime, 0.0)
    XCTAssertLessThan(stats.averageBuildTime, 1.0)
  }

  // MARK: - Performance Monitoring Tests

  func testPerformanceMonitoringEnabled() {
    let monitoringConfig = PerformanceCache.Configuration(
      maxASTEntries: 10,
      maxDescriptorEntries: 10,
      maxDependencyEntries: 10,
      maxMemoryUsage: 1024 * 1024,
      timeToLive: 3600,
      enableMonitoring: true
    )

    let monitoringCache = PerformanceCache(configuration: monitoringConfig)
    XCTAssertNotNil(monitoringCache)

    monitoringCache.clearAll()
  }

  func testPerformanceMonitoringDisabled() {
    let noMonitoringConfig = PerformanceCache.Configuration(
      maxASTEntries: 10,
      maxDescriptorEntries: 10,
      maxDependencyEntries: 10,
      maxMemoryUsage: 1024 * 1024,
      timeToLive: 3600,
      enableMonitoring: false
    )

    let noMonitoringCache = PerformanceCache(configuration: noMonitoringConfig)
    XCTAssertNotNil(noMonitoringCache)

    noMonitoringCache.clearAll()
  }

  // MARK: - Comprehensive Statistics Tests

  func testComprehensiveStatistics() throws {
    let ast = createTestAST()
    let descriptor = try createTestDescriptor()
    let dependencyResult = try createTestDependencyResult()

    // Cache various items
    cache.cacheAST(ast, for: "/test/ast.proto", contentHash: "ast_hash", fileSize: 1024, parseTime: 0.05)
    cache.cacheDescriptor(descriptor, for: "/test/desc.proto", contentHash: "desc_hash", fileSize: 2048, buildTime: 0.1)
    cache.cacheDependencyResult(dependencyResult, for: "/test/dep.proto", contentHash: "dep_hash")

    // Make some hits and misses
    _ = cache.getCachedAST(for: "/test/ast.proto", contentHash: "ast_hash")  // hit
    _ = cache.getCachedAST(for: "/test/missing.proto", contentHash: "missing")  // miss

    _ = cache.getCachedDescriptor(for: "/test/desc.proto", contentHash: "desc_hash")  // hit
    _ = cache.getCachedDescriptor(for: "/test/missing.proto", contentHash: "missing")  // miss

    _ = cache.getCachedDependencyResult(for: "/test/dep.proto", contentHash: "dep_hash")  // hit
    _ = cache.getCachedDependencyResult(for: "/test/missing.proto", contentHash: "missing")  // miss

    let stats = cache.getStatistics()

    // Verify all hit rates
    XCTAssertEqual(stats.astCacheHits, 1)
    XCTAssertEqual(stats.astCacheMisses, 1)
    XCTAssertEqual(stats.astHitRate, 0.5, accuracy: 0.01)

    XCTAssertEqual(stats.descriptorCacheHits, 1)
    XCTAssertEqual(stats.descriptorCacheMisses, 1)
    XCTAssertEqual(stats.descriptorHitRate, 0.5, accuracy: 0.01)

    XCTAssertEqual(stats.dependencyCacheHits, 1)
    XCTAssertEqual(stats.dependencyCacheMisses, 1)
    XCTAssertEqual(stats.dependencyHitRate, 0.5, accuracy: 0.01)

    XCTAssertGreaterThan(stats.averageParseTime, 0.0)
    XCTAssertGreaterThan(stats.averageBuildTime, 0.0)
  }

  func testStatisticsAfterClearAll() {
    let ast = createTestAST()

    // Cache and access some items
    cache.cacheAST(ast, for: "/test/clear.proto", contentHash: "clear_hash", fileSize: 1024, parseTime: 0.05)
    _ = cache.getCachedAST(for: "/test/clear.proto", contentHash: "clear_hash")

    // Verify stats are not zero
    let statsBefore = cache.getStatistics()
    XCTAssertGreaterThan(statsBefore.astCacheHits, 0)

    // Clear all
    cache.clearAll()

    // Stats should be reset
    let statsAfter = cache.getStatistics()
    XCTAssertEqual(statsAfter.astCacheHits, 0)
    XCTAssertEqual(statsAfter.astCacheMisses, 0)
    XCTAssertEqual(statsAfter.descriptorCacheHits, 0)
    XCTAssertEqual(statsAfter.descriptorCacheMisses, 0)
    XCTAssertEqual(statsAfter.dependencyCacheHits, 0)
    XCTAssertEqual(statsAfter.dependencyCacheMisses, 0)
    XCTAssertEqual(statsAfter.evictionCount, 0)
    XCTAssertEqual(statsAfter.averageParseTime, 0.0)
    XCTAssertEqual(statsAfter.averageBuildTime, 0.0)
  }

  // MARK: - Edge Cases and Error Handling Tests

  func testCacheWithEmptyFilePath() {
    let ast = createTestAST()
    let contentHash = "empty_path_hash"
    let fileSize: Int64 = 1024
    let parseTime: TimeInterval = 0.05

    // Cache with empty file path
    cache.cacheAST(ast, for: "", contentHash: contentHash, fileSize: fileSize, parseTime: parseTime)

    // Should be able to retrieve
    let cachedAST = cache.getCachedAST(for: "", contentHash: contentHash)
    XCTAssertNotNil(cachedAST)
  }

  func testCacheWithEmptyContentHash() {
    let ast = createTestAST()
    let filePath = "/test/empty_hash.proto"
    let fileSize: Int64 = 1024
    let parseTime: TimeInterval = 0.05

    // Cache with empty content hash
    cache.cacheAST(ast, for: filePath, contentHash: "", fileSize: fileSize, parseTime: parseTime)

    // Should be able to retrieve with empty hash
    let cachedAST = cache.getCachedAST(for: filePath, contentHash: "")
    XCTAssertNotNil(cachedAST)

    // Should miss with non-empty hash
    let missedAST = cache.getCachedAST(for: filePath, contentHash: "non_empty")
    XCTAssertNil(missedAST)
  }

  func testContentHashConsistency() {
    let content1 = "syntax = \"proto3\"; package test; message TestMessage { string name = 1; }"
    let content2 = "syntax = \"proto3\"; package test; message TestMessage { string name = 1; }"
    let content3 = "syntax = \"proto3\"; package test; message DifferentMessage { string name = 1; }"

    let hash1a = PerformanceCache.contentHash(for: content1)
    let hash1b = PerformanceCache.contentHash(for: content1)
    let hash2 = PerformanceCache.contentHash(for: content2)
    let hash3 = PerformanceCache.contentHash(for: content3)

    // Same content should always produce same hash
    XCTAssertEqual(hash1a, hash1b)
    XCTAssertEqual(hash1a, hash2)

    // Different content should produce different hash
    XCTAssertNotEqual(hash1a, hash3)

    // Hashes should be consistent across calls
    let hash1c = PerformanceCache.contentHash(for: content1)
    XCTAssertEqual(hash1a, hash1c)
  }

  // MARK: - Helper Methods

  private func createTestAST() -> ProtoAST {
    return ProtoAST(
      syntax: .proto3,
      package: "test.cache",
      imports: [],
      options: [],
      messages: [
        MessageNode(
          name: "TestMessage",
          fields: [
            FieldNode(
              name: "name",
              type: .string,
              number: 1,
              label: .optional,
              options: []
            )
          ],
          nestedMessages: [],
          nestedEnums: [],
          options: []
        )
      ],
      enums: [],
      services: []
    )
  }

  private func createTestDescriptor() throws -> Google_Protobuf_FileDescriptorProto {
    let ast = createTestAST()
    return try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
  }

  private func createTestDependencyResult() throws -> DependencyResolver.ResolutionResult {
    let mainFile = try createTestResolvedProtoFile(
      path: "/test/main.proto",
      content: "syntax = \"proto3\"; package test; message Main {}"
    )

    let depFile = try createTestResolvedProtoFile(
      path: "/test/dep.proto",
      content: "syntax = \"proto3\"; package test; message Dependency {}"
    )

    let stats = DependencyResolver.ResolutionStats(
      totalFiles: 2,
      directDependencies: 1,
      transitiveDependencies: 1,
      wellKnownTypes: 0,
      resolutionTime: 0.1,
      cacheHitRate: 0.0
    )

    return DependencyResolver.ResolutionResult(
      mainFile: mainFile,
      dependencies: [depFile],
      allFiles: [mainFile, depFile],
      warnings: [],
      stats: stats
    )
  }

  private func createTestResolvedProtoFile(path: String, content: String) throws -> ResolvedProtoFile {
    let fileManager = FileManager.default
    let attributes = try fileManager.attributesOfItem(atPath: #file)
    let modificationTime = attributes[.modificationDate] as? Date ?? Date()
    let fileSize = attributes[.size] as? Int64 ?? 1024

    return ResolvedProtoFile(
      filePath: path,
      importPath: path,
      content: content,
      imports: [],
      syntax: "proto3",
      packageName: "test",
      modificationTime: modificationTime,
      fileSize: fileSize,
      isMainFile: false
    )
  }
}
