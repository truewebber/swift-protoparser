import XCTest
@testable import SwiftProtoParser

final class PerformanceCacheTests: XCTestCase {

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

  // MARK: - Configuration Tests

  func testDefaultConfiguration() {
    let config = PerformanceCache.Configuration.default
    XCTAssertEqual(config.maxASTEntries, 1000)
    XCTAssertEqual(config.maxDescriptorEntries, 500)
    XCTAssertEqual(config.maxDependencyEntries, 200)
    XCTAssertEqual(config.maxMemoryUsage, 100 * 1024 * 1024)
    XCTAssertEqual(config.timeToLive, 3600)
    XCTAssertTrue(config.enableMonitoring)
  }

  func testHighPerformanceConfiguration() {
    let config = PerformanceCache.Configuration.highPerformance
    XCTAssertEqual(config.maxASTEntries, 5000)
    XCTAssertEqual(config.maxDescriptorEntries, 2500)
    XCTAssertEqual(config.maxDependencyEntries, 1000)
    XCTAssertEqual(config.maxMemoryUsage, 500 * 1024 * 1024)
    XCTAssertEqual(config.timeToLive, 7200)
    XCTAssertTrue(config.enableMonitoring)
  }

  func testMemoryConstrainedConfiguration() {
    let config = PerformanceCache.Configuration.memoryConstrained
    XCTAssertEqual(config.maxASTEntries, 100)
    XCTAssertEqual(config.maxDescriptorEntries, 50)
    XCTAssertEqual(config.maxDependencyEntries, 25)
    XCTAssertEqual(config.maxMemoryUsage, 10 * 1024 * 1024)
    XCTAssertEqual(config.timeToLive, 1800)
    XCTAssertFalse(config.enableMonitoring)
  }

  // MARK: - AST Caching Tests

  func testASTCaching() {
    let protoContent = """
      syntax = "proto3";
      package test;
      
      message TestMessage {
        string name = 1;
        int32 value = 2;
      }
      """
    
    let ast = createTestAST()
    let filePath = "/test/file.proto"
    let contentHash = PerformanceCache.contentHash(for: protoContent)
    let fileSize: Int64 = 1024
    let parseTime: TimeInterval = 0.05
    
    // Cache AST
    cache.cacheAST(ast, for: filePath, contentHash: contentHash, fileSize: fileSize, parseTime: parseTime)
    
    // Retrieve cached AST
    let cachedAST = cache.getCachedAST(for: filePath, contentHash: contentHash)
    XCTAssertNotNil(cachedAST)
    XCTAssertEqual(cachedAST?.package, ast.package)
    XCTAssertEqual(cachedAST?.syntax, ast.syntax)
    XCTAssertEqual(cachedAST?.messages.count, ast.messages.count)
  }

  func testASTCacheMiss() {
    let filePath = "/test/file.proto"
    let contentHash = "nonexistent_hash"
    
    let cachedAST = cache.getCachedAST(for: filePath, contentHash: contentHash)
    XCTAssertNil(cachedAST)
  }

  func testASTCacheInvalidation() {
    let ast = createTestAST()
    let filePath = "/test/file.proto"
    let oldContentHash = "old_hash"
    let newContentHash = "new_hash"
    let fileSize: Int64 = 1024
    let parseTime: TimeInterval = 0.05
    
    // Cache with old hash
    cache.cacheAST(ast, for: filePath, contentHash: oldContentHash, fileSize: fileSize, parseTime: parseTime)
    
    // Try to retrieve with new hash (should miss)
    let cachedAST = cache.getCachedAST(for: filePath, contentHash: newContentHash)
    XCTAssertNil(cachedAST)
    
    // Should still be able to retrieve with old hash
    let oldCachedAST = cache.getCachedAST(for: filePath, contentHash: oldContentHash)
    XCTAssertNotNil(oldCachedAST)
  }

  // MARK: - Statistics Tests

  func testInitialStatistics() {
    let stats = cache.getStatistics()
    XCTAssertEqual(stats.astCacheHits, 0)
    XCTAssertEqual(stats.astCacheMisses, 0)
    XCTAssertEqual(stats.descriptorCacheHits, 0)
    XCTAssertEqual(stats.descriptorCacheMisses, 0)
    XCTAssertEqual(stats.dependencyCacheHits, 0)
    XCTAssertEqual(stats.dependencyCacheMisses, 0)
    XCTAssertEqual(stats.evictionCount, 0)
    XCTAssertEqual(stats.astHitRate, 0.0)
  }

  func testCacheHitStatistics() {
    let ast = createTestAST()
    let filePath = "/test/file.proto"
    let contentHash = "test_hash"
    let fileSize: Int64 = 1024
    let parseTime: TimeInterval = 0.05
    
    // Cache AST
    cache.cacheAST(ast, for: filePath, contentHash: contentHash, fileSize: fileSize, parseTime: parseTime)
    
    // First retrieval (hit)
    _ = cache.getCachedAST(for: filePath, contentHash: contentHash)
    
    // Second retrieval (another hit)
    _ = cache.getCachedAST(for: filePath, contentHash: contentHash)
    
    let stats = cache.getStatistics()
    XCTAssertEqual(stats.astCacheHits, 2)
    XCTAssertEqual(stats.astCacheMisses, 0)
    XCTAssertEqual(stats.astHitRate, 1.0)
  }

  func testCacheMissStatistics() {
    // Try to retrieve non-existent entry
    _ = cache.getCachedAST(for: "/nonexistent", contentHash: "nonexistent")
    
    let stats = cache.getStatistics()
    XCTAssertEqual(stats.astCacheHits, 0)
    XCTAssertEqual(stats.astCacheMisses, 1)
    XCTAssertEqual(stats.astHitRate, 0.0)
  }

  func testMixedCacheStatistics() {
    let ast = createTestAST()
    let filePath = "/test/file.proto"
    let contentHash = "test_hash"
    let fileSize: Int64 = 1024
    let parseTime: TimeInterval = 0.05
    
    // Cache AST
    cache.cacheAST(ast, for: filePath, contentHash: contentHash, fileSize: fileSize, parseTime: parseTime)
    
    // One hit
    _ = cache.getCachedAST(for: filePath, contentHash: contentHash)
    
    // Two misses
    _ = cache.getCachedAST(for: "/nonexistent1", contentHash: "nonexistent1")
    _ = cache.getCachedAST(for: "/nonexistent2", contentHash: "nonexistent2")
    
    let stats = cache.getStatistics()
    XCTAssertEqual(stats.astCacheHits, 1)
    XCTAssertEqual(stats.astCacheMisses, 2)
    XCTAssertEqual(stats.astHitRate, 1.0 / 3.0, accuracy: 0.01)
  }

  // MARK: - Cache Management Tests

  func testClearAll() {
    let ast = createTestAST()
    let filePath = "/test/file.proto"
    let contentHash = "test_hash"
    let fileSize: Int64 = 1024
    let parseTime: TimeInterval = 0.05
    
    // Cache AST
    cache.cacheAST(ast, for: filePath, contentHash: contentHash, fileSize: fileSize, parseTime: parseTime)
    
    // Verify it's cached
    let cachedAST = cache.getCachedAST(for: filePath, contentHash: contentHash)
    XCTAssertNotNil(cachedAST)
    
    // Clear cache
    cache.clearAll()
    
    // Verify it's gone
    let clearedAST = cache.getCachedAST(for: filePath, contentHash: contentHash)
    XCTAssertNil(clearedAST)
    
    // After clearAll(), statistics should be reset, but the check above adds 1 miss
    let stats = cache.getStatistics()
    XCTAssertEqual(stats.astCacheHits, 0)
    XCTAssertEqual(stats.astCacheMisses, 1) // The miss from checking cleared cache
  }

  // MARK: - Content Hashing Tests

  func testContentHashing() {
    let content1 = "syntax = \"proto3\"; message Test { string name = 1; }"
    let content2 = "syntax = \"proto3\"; message Test { string name = 1; }"
    let content3 = "syntax = \"proto3\"; message Test { string value = 1; }"
    
    let hash1 = PerformanceCache.contentHash(for: content1)
    let hash2 = PerformanceCache.contentHash(for: content2)
    let hash3 = PerformanceCache.contentHash(for: content3)
    
    // Same content should produce same hash
    XCTAssertEqual(hash1, hash2)
    
    // Different content should produce different hash
    XCTAssertNotEqual(hash1, hash3)
    
    // Hashes should be non-empty
    XCTAssertFalse(hash1.isEmpty)
    XCTAssertFalse(hash3.isEmpty)
  }

  func testEmptyContentHashing() {
    let emptyHash = PerformanceCache.contentHash(for: "")
    XCTAssertFalse(emptyHash.isEmpty)
  }

  // MARK: - Performance Tests

  func testCachePerformance() {
    let ast = createTestAST()
    let contentHash = "test_hash"
    let fileSize: Int64 = 1024
    let parseTime: TimeInterval = 0.05
    
    // Measure caching performance
    measure {
      for i in 0..<1000 {
        let filePath = "/test/file_\(i).proto"
        cache.cacheAST(ast, for: filePath, contentHash: "\(contentHash)_\(i)", fileSize: fileSize, parseTime: parseTime)
      }
    }
  }

  func testCacheRetrievalPerformance() {
    let ast = createTestAST()
    let contentHash = "test_hash"
    let fileSize: Int64 = 1024
    let parseTime: TimeInterval = 0.05
    
    // Cache many entries
    for i in 0..<1000 {
      let filePath = "/test/file_\(i).proto"
      cache.cacheAST(ast, for: filePath, contentHash: "\(contentHash)_\(i)", fileSize: fileSize, parseTime: parseTime)
    }
    
    // Measure retrieval performance
    measure {
      for i in 0..<1000 {
        let filePath = "/test/file_\(i).proto"
        _ = cache.getCachedAST(for: filePath, contentHash: "\(contentHash)_\(i)")
      }
    }
  }

  // MARK: - Helper Methods

  private func createTestAST() -> ProtoAST {
    return ProtoAST(
      syntax: .proto3,
      package: "test",
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
}
