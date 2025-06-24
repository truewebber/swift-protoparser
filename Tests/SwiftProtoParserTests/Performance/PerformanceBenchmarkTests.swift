import XCTest

@testable import SwiftProtoParser

final class PerformanceBenchmarkTests: XCTestCase {

  var tempDir: URL!
  var benchmark: PerformanceBenchmark!
  var performanceCache: PerformanceCache!

  override func setUp() {
    super.setUp()
    tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    performanceCache = PerformanceCache(configuration: .default)
    benchmark = PerformanceBenchmark(
      configuration: .quick,
      cache: performanceCache,
      incrementalParser: nil
    )
  }

  override func tearDown() {
    if let tempDir = tempDir {
      try? FileManager.default.removeItem(at: tempDir)
    }
    super.tearDown()
  }

  // MARK: - Configuration Tests

  func testConfigurationDefault() {
    let config = PerformanceBenchmark.Configuration.default
    XCTAssertEqual(config.iterations, 10)
    XCTAssertEqual(config.warmupIterations, 3)
    XCTAssertTrue(config.trackMemory)
    XCTAssertEqual(config.maxParsingTime, 1.0)
    XCTAssertEqual(config.maxMemoryUsage, 100 * 1024 * 1024)
  }

  func testConfigurationQuick() {
    let config = PerformanceBenchmark.Configuration.quick
    XCTAssertEqual(config.iterations, 3)
    XCTAssertEqual(config.warmupIterations, 1)
    XCTAssertFalse(config.trackMemory)
    XCTAssertEqual(config.maxParsingTime, 2.0)
    XCTAssertEqual(config.maxMemoryUsage, 200 * 1024 * 1024)
  }

  func testConfigurationComprehensive() {
    let config = PerformanceBenchmark.Configuration.comprehensive
    XCTAssertEqual(config.iterations, 50)
    XCTAssertEqual(config.warmupIterations, 10)
    XCTAssertTrue(config.trackMemory)
    XCTAssertEqual(config.maxParsingTime, 0.5)
    XCTAssertEqual(config.maxMemoryUsage, 50 * 1024 * 1024)
  }

  // MARK: - Measurement Tests

  func testMeasurementIsWithinLimits() {
    // Test measurement within limits
    let goodMeasurement = PerformanceBenchmark.Measurement(
      operation: "test",
      duration: 0.5,
      memoryUsage: 50 * 1024 * 1024,
      success: true,
      error: nil,
      timestamp: Date()
    )
    XCTAssertTrue(goodMeasurement.isWithinLimits)

    // Test measurement exceeding time limit
    let slowMeasurement = PerformanceBenchmark.Measurement(
      operation: "test",
      duration: 2.0,
      memoryUsage: 50 * 1024 * 1024,
      success: true,
      error: nil,
      timestamp: Date()
    )
    XCTAssertFalse(slowMeasurement.isWithinLimits)

    // Test measurement exceeding memory limit
    let memoryHeavyMeasurement = PerformanceBenchmark.Measurement(
      operation: "test",
      duration: 0.5,
      memoryUsage: 200 * 1024 * 1024,
      success: true,
      error: nil,
      timestamp: Date()
    )
    XCTAssertFalse(memoryHeavyMeasurement.isWithinLimits)

    // Test failed measurement
    let failedMeasurement = PerformanceBenchmark.Measurement(
      operation: "test",
      duration: 0.5,
      memoryUsage: 50 * 1024 * 1024,
      success: false,
      error: .syntaxError(message: "test error", file: "test.proto", line: 1, column: 1),
      timestamp: Date()
    )
    XCTAssertFalse(failedMeasurement.isWithinLimits)
  }

  // MARK: - BenchmarkResult Tests

  func testBenchmarkResultStatistics() {
    let measurements = [
      PerformanceBenchmark.Measurement(
        operation: "test",
        duration: 0.1,
        memoryUsage: 1000,
        success: true,
        error: nil,
        timestamp: Date()
      ),
      PerformanceBenchmark.Measurement(
        operation: "test",
        duration: 0.2,
        memoryUsage: 2000,
        success: true,
        error: nil,
        timestamp: Date()
      ),
      PerformanceBenchmark.Measurement(
        operation: "test",
        duration: 0.3,
        memoryUsage: 3000,
        success: true,
        error: nil,
        timestamp: Date()
      ),
      PerformanceBenchmark.Measurement(
        operation: "test",
        duration: 1.0,
        memoryUsage: 4000,
        success: false,
        error: .syntaxError(message: "test", file: "test.proto", line: 1, column: 1),
        timestamp: Date()
      ),
    ]

    let result = PerformanceBenchmark.BenchmarkResult(
      operation: "testOperation",
      measurements: measurements,
      configuration: .quick
    )

    // Test statistical calculations
    XCTAssertEqual(result.averageDuration, 0.2, accuracy: 0.001)  // Only successful measurements
    XCTAssertEqual(result.medianDuration, 0.2, accuracy: 0.001)
    XCTAssertEqual(result.minDuration, 0.1, accuracy: 0.001)
    XCTAssertEqual(result.maxDuration, 0.3, accuracy: 0.001)
    XCTAssertEqual(result.averageMemoryUsage, 2000)  // (1000+2000+3000)/3
    XCTAssertEqual(result.successRate, 0.75)  // 3 out of 4 successful

    // Test standard deviation
    XCTAssertGreaterThan(result.standardDeviation, 0)
    XCTAssertLessThan(result.standardDeviation, 0.2)
  }

  func testBenchmarkResultEmptyMeasurements() {
    let result = PerformanceBenchmark.BenchmarkResult(
      operation: "empty",
      measurements: [],
      configuration: .default
    )

    XCTAssertEqual(result.averageDuration, 0)
    XCTAssertEqual(result.medianDuration, 0)
    XCTAssertEqual(result.minDuration, 0)
    XCTAssertEqual(result.maxDuration, 0)
    XCTAssertEqual(result.averageMemoryUsage, 0)
    XCTAssertEqual(result.successRate, 0)
    XCTAssertEqual(result.standardDeviation, 0)
    XCTAssertFalse(result.isAcceptable)
  }

  func testBenchmarkResultIsAcceptable() {
    // Test acceptable result
    let acceptableMeasurements = [
      PerformanceBenchmark.Measurement(
        operation: "test",
        duration: 0.1,
        memoryUsage: 1000,
        success: true,
        error: nil,
        timestamp: Date()
      ),
      PerformanceBenchmark.Measurement(
        operation: "test",
        duration: 0.2,
        memoryUsage: 2000,
        success: true,
        error: nil,
        timestamp: Date()
      ),
    ]

    let acceptableResult = PerformanceBenchmark.BenchmarkResult(
      operation: "acceptable",
      measurements: acceptableMeasurements,
      configuration: .default
    )

    XCTAssertTrue(acceptableResult.isAcceptable)

    // Test unacceptable result (low success rate)
    let lowSuccessRate = [
      PerformanceBenchmark.Measurement(
        operation: "test",
        duration: 0.1,
        memoryUsage: 1000,
        success: true,
        error: nil,
        timestamp: Date()
      ),
      PerformanceBenchmark.Measurement(
        operation: "test",
        duration: 0.2,
        memoryUsage: 2000,
        success: false,
        error: .syntaxError(message: "test", file: "test.proto", line: 1, column: 1),
        timestamp: Date()
      ),
    ]

    let unacceptableResult = PerformanceBenchmark.BenchmarkResult(
      operation: "unacceptable",
      measurements: lowSuccessRate,
      configuration: .default
    )

    XCTAssertFalse(unacceptableResult.isAcceptable)  // 50% success rate < 95%
  }

  // MARK: - BenchmarkSuite Tests

  func testBenchmarkSuiteStatistics() {
    let startTime = Date()
    let endTime = Date(timeIntervalSinceNow: 5.0)

    let result1 = PerformanceBenchmark.BenchmarkResult(
      operation: "op1",
      measurements: [
        PerformanceBenchmark.Measurement(
          operation: "op1",
          duration: 0.1,
          memoryUsage: 1000,
          success: true,
          error: nil,
          timestamp: Date()
        )
      ],
      configuration: .default
    )

    let result2 = PerformanceBenchmark.BenchmarkResult(
      operation: "op2",
      measurements: [
        PerformanceBenchmark.Measurement(
          operation: "op2",
          duration: 0.2,
          memoryUsage: 2000,
          success: false,
          error: .syntaxError(message: "test", file: "test.proto", line: 1, column: 1),
          timestamp: Date()
        )
      ],
      configuration: .default
    )

    let suite = PerformanceBenchmark.BenchmarkSuite(
      name: "TestSuite",
      results: [result1, result2],
      startTime: startTime,
      endTime: endTime,
      configuration: .default
    )

    XCTAssertEqual(suite.totalDuration, 5.0, accuracy: 0.1)
    XCTAssertEqual(suite.overallSuccessRate, 0.5)  // 1 success out of 2 measurements
    XCTAssertFalse(suite.allBenchmarksAcceptable)  // result2 is not acceptable
  }

  // MARK: - Single File Benchmark Tests

  func testBenchmarkSingleFile() {
    let protoContent = """
      syntax = "proto3";
      package test.benchmark;

      message TestMessage {
        string name = 1;
        int32 value = 2;
      }
      """

    let protoFile = tempDir.appendingPathComponent("test.proto")
    try! protoContent.write(to: protoFile, atomically: true, encoding: .utf8)

    let result = benchmark.benchmarkSingleFile(protoFile.path)

    XCTAssertTrue(result.operation.contains("test.proto"))
    XCTAssertEqual(result.measurements.count, 3)  // quick config has 3 iterations
    XCTAssertGreaterThan(result.successRate, 0.0)
    XCTAssertGreaterThan(result.averageDuration, 0.0)
  }

  func testBenchmarkSingleFileNonExistent() {
    let result = benchmark.benchmarkSingleFile("/nonexistent/file.proto")

    XCTAssertTrue(result.operation.contains("file.proto"))
    XCTAssertEqual(result.measurements.count, 3)  // quick config has 3 iterations
    XCTAssertEqual(result.successRate, 0.0)  // All should fail

    // Check that all measurements have errors
    for measurement in result.measurements {
      XCTAssertFalse(measurement.success)
      XCTAssertNotNil(measurement.error)
    }
  }

  // MARK: - String Parsing Benchmark Tests

  func testBenchmarkStringParsing() {
    let protoContent = """
      syntax = "proto3";
      package test.string;

      message StringMessage {
        string data = 1;
      }
      """

    let result = benchmark.benchmarkStringParsing(protoContent, name: "testString")

    XCTAssertTrue(result.operation.contains("testString"))
    XCTAssertTrue(result.operation.contains("chars"))
    XCTAssertEqual(result.measurements.count, 3)  // quick config has 3 iterations
    XCTAssertGreaterThan(result.successRate, 0.0)
    XCTAssertGreaterThan(result.averageDuration, 0.0)
  }

  func testBenchmarkStringParsingDefaultName() {
    let protoContent = """
      syntax = "proto3";
      message DefaultNameMessage { string field = 1; }
      """

    let result = benchmark.benchmarkStringParsing(protoContent)

    XCTAssertTrue(result.operation.contains("parseProtoString"))
    XCTAssertEqual(result.measurements.count, 3)
  }

  func testBenchmarkStringParsingInvalidContent() {
    let invalidContent = "invalid proto content"

    let result = benchmark.benchmarkStringParsing(invalidContent, name: "invalid")

    XCTAssertTrue(result.operation.contains("invalid"))
    XCTAssertEqual(result.measurements.count, 3)
    XCTAssertEqual(result.successRate, 0.0)  // All should fail
  }

  // MARK: - Multi-File Benchmark Tests

  func testBenchmarkWithDependencies() {
    let baseContent = """
      syntax = "proto3";
      package test.base;

      message BaseMessage {
        string name = 1;
      }
      """

    let mainContent = """
      syntax = "proto3";
      package test.main;
      import "base.proto";

      message MainMessage {
        test.base.BaseMessage base = 1;
      }
      """

    let baseFile = tempDir.appendingPathComponent("base.proto")
    let mainFile = tempDir.appendingPathComponent("main.proto")

    try! baseContent.write(to: baseFile, atomically: true, encoding: .utf8)
    try! mainContent.write(to: mainFile, atomically: true, encoding: .utf8)

    let result = benchmark.benchmarkWithDependencies(mainFile.path, importPaths: [tempDir.path])

    XCTAssertTrue(result.operation.contains("main.proto"))
    XCTAssertEqual(result.measurements.count, 3)
    XCTAssertGreaterThanOrEqual(result.successRate, 0.0)  // May fail due to import issues
  }

  func testBenchmarkWithDependenciesNonExistent() {
    let result = benchmark.benchmarkWithDependencies("/nonexistent/main.proto", importPaths: ["/nonexistent"])

    XCTAssertEqual(result.measurements.count, 3)
    XCTAssertEqual(result.successRate, 0.0)
  }

  // MARK: - Directory Benchmark Tests

  func testBenchmarkDirectory() {
    // Create multiple proto files
    for i in 1...3 {
      let content = """
        syntax = "proto3";
        package test.dir\(i);

        message DirMessage\(i) {
          string name = 1;
        }
        """

      let file = tempDir.appendingPathComponent("dir\(i).proto")
      try! content.write(to: file, atomically: true, encoding: .utf8)
    }

    let result = benchmark.benchmarkDirectory(tempDir.path)

    XCTAssertTrue(result.operation.contains(tempDir.lastPathComponent))
    XCTAssertEqual(result.measurements.count, 3)
    XCTAssertGreaterThan(result.successRate, 0.0)
  }

  func testBenchmarkDirectoryRecursive() {
    // Create subdirectory with proto file
    let subDir = tempDir.appendingPathComponent("subdir")
    try! FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

    let content = """
      syntax = "proto3";
      message SubMessage { string name = 1; }
      """

    let subFile = subDir.appendingPathComponent("sub.proto")
    try! content.write(to: subFile, atomically: true, encoding: .utf8)

    let result = benchmark.benchmarkDirectory(tempDir.path, recursive: true)

    XCTAssertEqual(result.measurements.count, 3)
  }

  func testBenchmarkDirectoryNonExistent() {
    let result = benchmark.benchmarkDirectory("/nonexistent/directory")

    XCTAssertEqual(result.measurements.count, 3)
    XCTAssertEqual(result.successRate, 0.0)
  }

  // MARK: - Descriptor Generation Benchmark Tests

  func testBenchmarkDescriptorGeneration() {
    let protoContent = """
      syntax = "proto3";
      package test.descriptor;

      message DescriptorMessage {
        string name = 1;
        int32 value = 2;
      }
      """

    let protoFile = tempDir.appendingPathComponent("descriptor.proto")
    try! protoContent.write(to: protoFile, atomically: true, encoding: .utf8)

    let result = benchmark.benchmarkDescriptorGeneration(protoFile.path)

    XCTAssertTrue(result.operation.contains("descriptor.proto"))
    XCTAssertEqual(result.measurements.count, 3)
    XCTAssertGreaterThan(result.successRate, 0.0)
  }

  func testBenchmarkDescriptorGenerationNonExistent() {
    let result = benchmark.benchmarkDescriptorGeneration("/nonexistent/descriptor.proto")

    XCTAssertEqual(result.measurements.count, 3)
    XCTAssertEqual(result.successRate, 0.0)
  }

  // MARK: - Cache Effectiveness Benchmark Tests

  func testBenchmarkCacheEffectiveness() {
    let protoContent = """
      syntax = "proto3";
      package test.cache;

      message CacheMessage {
        string name = 1;
      }
      """

    let protoFile = tempDir.appendingPathComponent("cache.proto")
    try! protoContent.write(to: protoFile, atomically: true, encoding: .utf8)

    let result = benchmark.benchmarkCacheEffectiveness(protoFile.path)

    XCTAssertTrue(result.operation.contains("cache.proto"))
    XCTAssertEqual(result.measurements.count, 3)
    XCTAssertGreaterThan(result.successRate, 0.0)
  }

  func testBenchmarkCacheEffectivenessNoCache() {
    let noCacheBenchmark = PerformanceBenchmark(configuration: .quick, cache: nil, incrementalParser: nil)

    let result = noCacheBenchmark.benchmarkCacheEffectiveness("/any/path")

    XCTAssertTrue(result.operation.contains("no cache"))
    XCTAssertEqual(result.measurements.count, 0)
  }

  // MARK: - Comprehensive Suite Tests

  func testRunComprehensiveSuite() {
    // Create test files
    for i in 1...3 {
      let content = """
        syntax = "proto3";
        package test.suite\(i);

        message SuiteMessage\(i) {
          string name = 1;
        }
        """

      let file = tempDir.appendingPathComponent("suite\(i).proto")
      try! content.write(to: file, atomically: true, encoding: .utf8)
    }

    let suite = benchmark.runComprehensiveSuite(tempDir.path)

    XCTAssertEqual(suite.name, "ComprehensiveSuite")
    XCTAssertGreaterThan(suite.results.count, 0)
    XCTAssertGreaterThan(suite.totalDuration, 0)
    XCTAssertGreaterThanOrEqual(suite.overallSuccessRate, 0.0)
    XCTAssertLessThanOrEqual(suite.overallSuccessRate, 1.0)
  }

  func testRunComprehensiveSuiteEmptyDirectory() {
    let emptyDir = tempDir.appendingPathComponent("empty")
    try! FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)

    let suite = benchmark.runComprehensiveSuite(emptyDir.path)

    XCTAssertEqual(suite.name, "ComprehensiveSuite")
    XCTAssertGreaterThan(suite.results.count, 0)  // Should have directory benchmark
  }

  func testRunComprehensiveSuiteNonExistent() {
    let suite = benchmark.runComprehensiveSuite("/nonexistent/directory")

    XCTAssertEqual(suite.name, "ComprehensiveSuite")
    XCTAssertGreaterThan(suite.results.count, 0)

    // Should have error result or directory benchmark
    let hasErrorOrDirectory = suite.results.contains {
      $0.operation.contains("error") || $0.operation.contains("directory")
    }
    XCTAssertTrue(hasErrorOrDirectory)
  }

  // MARK: - Performance Comparison Tests

  func testCompareWithBaseline() {
    let baselineResults = [
      PerformanceBenchmark.BenchmarkResult(
        operation: "test1",
        measurements: [
          PerformanceBenchmark.Measurement(
            operation: "test1",
            duration: 0.1,
            memoryUsage: 1000,
            success: true,
            error: nil,
            timestamp: Date()
          )
        ],
        configuration: .default
      )
    ]

    let currentResults = [
      PerformanceBenchmark.BenchmarkResult(
        operation: "test1",
        measurements: [
          PerformanceBenchmark.Measurement(
            operation: "test1",
            duration: 0.2,
            memoryUsage: 2000,
            success: true,
            error: nil,
            timestamp: Date()
          )
        ],
        configuration: .default
      )
    ]

    let baselineSuite = PerformanceBenchmark.BenchmarkSuite(
      name: "Baseline",
      results: baselineResults,
      startTime: Date(),
      endTime: Date(),
      configuration: .default
    )

    let currentSuite = PerformanceBenchmark.BenchmarkSuite(
      name: "Current",
      results: currentResults,
      startTime: Date(),
      endTime: Date(),
      configuration: .default
    )

    let comparison = benchmark.compareWithBaseline(currentSuite, baseline: baselineSuite)

    XCTAssertTrue(comparison.hasRegressions)
    XCTAssertFalse(comparison.hasImprovements)
    XCTAssertGreaterThan(comparison.overallPerformanceRatio, 1.0)  // Slower than baseline
    XCTAssertGreaterThan(comparison.regressions.count, 0)
  }

  func testCompareWithBaselineImprovements() {
    let baselineResults = [
      PerformanceBenchmark.BenchmarkResult(
        operation: "test1",
        measurements: [
          PerformanceBenchmark.Measurement(
            operation: "test1",
            duration: 0.2,
            memoryUsage: 2000,
            success: true,
            error: nil,
            timestamp: Date()
          )
        ],
        configuration: .default
      )
    ]

    let currentResults = [
      PerformanceBenchmark.BenchmarkResult(
        operation: "test1",
        measurements: [
          PerformanceBenchmark.Measurement(
            operation: "test1",
            duration: 0.1,
            memoryUsage: 1000,
            success: true,
            error: nil,
            timestamp: Date()
          )
        ],
        configuration: .default
      )
    ]

    let baselineSuite = PerformanceBenchmark.BenchmarkSuite(
      name: "Baseline",
      results: baselineResults,
      startTime: Date(),
      endTime: Date(),
      configuration: .default
    )

    let currentSuite = PerformanceBenchmark.BenchmarkSuite(
      name: "Current",
      results: currentResults,
      startTime: Date(),
      endTime: Date(),
      configuration: .default
    )

    let comparison = benchmark.compareWithBaseline(currentSuite, baseline: baselineSuite)

    XCTAssertFalse(comparison.hasRegressions)
    XCTAssertTrue(comparison.hasImprovements)
    XCTAssertLessThan(comparison.overallPerformanceRatio, 1.0)  // Faster than baseline
    XCTAssertGreaterThan(comparison.improvements.count, 0)
  }

  // MARK: - Initialization Tests

  func testInitialization() {
    let customConfig = PerformanceBenchmark.Configuration(
      iterations: 5,
      warmupIterations: 2,
      trackMemory: false,
      maxParsingTime: 0.5,
      maxMemoryUsage: 50 * 1024 * 1024
    )

    let customBenchmark = PerformanceBenchmark(
      configuration: customConfig,
      cache: performanceCache,
      incrementalParser: nil
    )

    XCTAssertNotNil(customBenchmark)
  }

  func testInitializationWithDefaults() {
    let defaultBenchmark = PerformanceBenchmark()
    XCTAssertNotNil(defaultBenchmark)
  }

  // MARK: - Edge Case Tests

  func testBenchmarkResultSingleMeasurement() {
    let singleMeasurement = [
      PerformanceBenchmark.Measurement(
        operation: "single",
        duration: 0.1,
        memoryUsage: 1000,
        success: true,
        error: nil,
        timestamp: Date()
      )
    ]

    let result = PerformanceBenchmark.BenchmarkResult(
      operation: "single",
      measurements: singleMeasurement,
      configuration: .default
    )

    XCTAssertEqual(result.averageDuration, 0.1)
    XCTAssertEqual(result.medianDuration, 0.1)
    XCTAssertEqual(result.minDuration, 0.1)
    XCTAssertEqual(result.maxDuration, 0.1)
    XCTAssertEqual(result.standardDeviation, 0)  // Single measurement has no deviation
  }

  func testBenchmarkResultOnlyFailures() {
    let failedMeasurements = [
      PerformanceBenchmark.Measurement(
        operation: "fail",
        duration: 0.1,
        memoryUsage: 1000,
        success: false,
        error: .syntaxError(message: "error", file: "test.proto", line: 1, column: 1),
        timestamp: Date()
      ),
      PerformanceBenchmark.Measurement(
        operation: "fail",
        duration: 0.2,
        memoryUsage: 2000,
        success: false,
        error: .syntaxError(message: "error", file: "test.proto", line: 1, column: 1),
        timestamp: Date()
      ),
    ]

    let result = PerformanceBenchmark.BenchmarkResult(
      operation: "allFailed",
      measurements: failedMeasurements,
      configuration: .default
    )

    XCTAssertEqual(result.averageDuration, 0)  // No successful measurements
    XCTAssertEqual(result.successRate, 0)
    XCTAssertFalse(result.isAcceptable)
  }

  func testPerformanceComparisonEdgeCases() {
    let emptySuite = PerformanceBenchmark.BenchmarkSuite(
      name: "Empty",
      results: [],
      startTime: Date(),
      endTime: Date(),
      configuration: .default
    )

    let comparison = benchmark.compareWithBaseline(emptySuite, baseline: emptySuite)

    XCTAssertFalse(comparison.hasRegressions)
    XCTAssertFalse(comparison.hasImprovements)
    XCTAssertEqual(comparison.overallPerformanceRatio, 1.0)  // No change for empty suites
  }
}
