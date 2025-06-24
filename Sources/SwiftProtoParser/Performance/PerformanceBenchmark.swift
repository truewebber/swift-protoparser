import Foundation

/// Performance benchmarking system for SwiftProtoParser.
///
/// This system provides:
/// - Comprehensive performance measurement
/// - Comparison with baseline metrics
/// - Memory usage tracking
/// - Parsing speed analysis
/// - Regression detection
/// - Performance reporting
public final class PerformanceBenchmark {

  // MARK: - Configuration

  /// Benchmark configuration settings.
  public struct Configuration {
    /// Number of iterations for each benchmark.
    public let iterations: Int

    /// Warmup iterations before measuring.
    public let warmupIterations: Int

    /// Enable memory tracking.
    public let trackMemory: Bool

    /// Maximum acceptable parsing time per file (seconds).
    public let maxParsingTime: TimeInterval

    /// Maximum acceptable memory usage (bytes).
    public let maxMemoryUsage: Int64

    /// Default configuration.
    public static let `default` = Configuration(
      iterations: 10,
      warmupIterations: 3,
      trackMemory: true,
      maxParsingTime: 1.0,
      maxMemoryUsage: 100 * 1024 * 1024  // 100MB
    )

    /// Quick benchmark configuration.
    public static let quick = Configuration(
      iterations: 3,
      warmupIterations: 1,
      trackMemory: false,
      maxParsingTime: 2.0,
      maxMemoryUsage: 200 * 1024 * 1024  // 200MB
    )

    /// Comprehensive benchmark configuration.
    public static let comprehensive = Configuration(
      iterations: 50,
      warmupIterations: 10,
      trackMemory: true,
      maxParsingTime: 0.5,
      maxMemoryUsage: 50 * 1024 * 1024  // 50MB
    )
  }

  // MARK: - Results

  /// Individual benchmark measurement.
  public struct Measurement {
    public let operation: String
    public let duration: TimeInterval
    public let memoryUsage: Int64
    public let success: Bool
    public let error: ProtoParseError?
    public let timestamp: Date

    public var isWithinLimits: Bool {
      return success && duration <= 1.0 && memoryUsage <= 100 * 1024 * 1024
    }
  }

  /// Benchmark results for a specific operation.
  public struct BenchmarkResult {
    public let operation: String
    public let measurements: [Measurement]
    public let configuration: Configuration

    // Statistical analysis
    public var averageDuration: TimeInterval {
      let successfulMeasurements = measurements.filter { $0.success }
      guard !successfulMeasurements.isEmpty else { return 0 }
      return successfulMeasurements.reduce(0) { $0 + $1.duration } / Double(successfulMeasurements.count)
    }

    public var medianDuration: TimeInterval {
      let successfulDurations = measurements.filter { $0.success }.map { $0.duration }.sorted()
      guard !successfulDurations.isEmpty else { return 0 }
      let count = successfulDurations.count
      return count % 2 == 0
        ? (successfulDurations[count / 2 - 1] + successfulDurations[count / 2]) / 2 : successfulDurations[count / 2]
    }

    public var minDuration: TimeInterval {
      return measurements.filter { $0.success }.map { $0.duration }.min() ?? 0
    }

    public var maxDuration: TimeInterval {
      return measurements.filter { $0.success }.map { $0.duration }.max() ?? 0
    }

    public var standardDeviation: TimeInterval {
      let successfulDurations = measurements.filter { $0.success }.map { $0.duration }
      guard successfulDurations.count > 1 else { return 0 }

      let mean = averageDuration
      let variance =
        successfulDurations.reduce(0) { sum, duration in
          let diff = duration - mean
          return sum + diff * diff
        } / Double(successfulDurations.count - 1)

      return sqrt(variance)
    }

    public var averageMemoryUsage: Int64 {
      let successfulMeasurements = measurements.filter { $0.success }
      guard !successfulMeasurements.isEmpty else { return 0 }
      return successfulMeasurements.reduce(0) { $0 + $1.memoryUsage } / Int64(successfulMeasurements.count)
    }

    public var successRate: Double {
      guard !measurements.isEmpty else { return 0 }
      let successCount = measurements.filter { $0.success }.count
      return Double(successCount) / Double(measurements.count)
    }

    public var isAcceptable: Bool {
      return successRate >= 0.95  // 95% success rate
        && averageDuration <= configuration.maxParsingTime && averageMemoryUsage <= configuration.maxMemoryUsage
    }
  }

  /// Complete benchmark suite results.
  public struct BenchmarkSuite {
    public let name: String
    public let results: [BenchmarkResult]
    public let startTime: Date
    public let endTime: Date
    public let configuration: Configuration

    public var totalDuration: TimeInterval {
      return endTime.timeIntervalSince(startTime)
    }

    public var overallSuccessRate: Double {
      let totalMeasurements = results.flatMap { $0.measurements }
      guard !totalMeasurements.isEmpty else { return 0 }
      let successCount = totalMeasurements.filter { $0.success }.count
      return Double(successCount) / Double(totalMeasurements.count)
    }

    public var allBenchmarksAcceptable: Bool {
      return results.allSatisfy { $0.isAcceptable }
    }
  }

  // MARK: - Properties

  private let configuration: Configuration
  private let cache: PerformanceCache?
  private let incrementalParser: IncrementalParser?

  // MARK: - Initialization

  /// Initialize performance benchmark.
  /// - Parameters:
  ///   - configuration: Benchmark configuration.
  ///   - cache: Optional performance cache for testing.
  ///   - incrementalParser: Optional incremental parser for testing.
  public init(
    configuration: Configuration = .default,
    cache: PerformanceCache? = nil,
    incrementalParser: IncrementalParser? = nil
  ) {
    self.configuration = configuration
    self.cache = cache
    self.incrementalParser = incrementalParser
  }

  // MARK: - Benchmarking

  /// Benchmark parsing a single proto file.
  /// - Parameter filePath: Path to the proto file.
  /// - Returns: Benchmark result.
  public func benchmarkSingleFile(_ filePath: String) -> BenchmarkResult {
    let operation = "parseProtoFile(\(URL(fileURLWithPath: filePath).lastPathComponent))"
    var measurements: [Measurement] = []

    // Warmup
    for _ in 0..<configuration.warmupIterations {
      _ = measureOperation {
        SwiftProtoParser.parseProtoFile(filePath)
      }
    }

    // Actual measurements
    for _ in 0..<configuration.iterations {
      let measurement = measureOperation {
        SwiftProtoParser.parseProtoFile(filePath)
      }
      measurements.append(
        Measurement(
          operation: operation,
          duration: measurement.duration,
          memoryUsage: measurement.memoryUsage,
          success: measurement.success,
          error: measurement.error,
          timestamp: Date()
        )
      )
    }

    return BenchmarkResult(
      operation: operation,
      measurements: measurements,
      configuration: configuration
    )
  }

  /// Benchmark parsing proto content from string.
  /// - Parameters:
  ///   - content: Proto file content.
  ///   - name: Name for the benchmark.
  /// - Returns: Benchmark result.
  public func benchmarkStringParsing(_ content: String, name: String = "parseProtoString") -> BenchmarkResult {
    let operation = "\(name)(\(content.count) chars)"
    var measurements: [Measurement] = []

    // Warmup iterations
    for _ in 0..<configuration.warmupIterations {
      _ = measureOperation {
        SwiftProtoParser.parseProtoString(content)
      }
    }

    // Actual measurements
    for _ in 0..<configuration.iterations {
      let measurement = measureOperation {
        SwiftProtoParser.parseProtoString(content)
      }
      measurements.append(
        Measurement(
          operation: operation,
          duration: measurement.duration,
          memoryUsage: measurement.memoryUsage,
          success: measurement.success,
          error: measurement.error,
          timestamp: Date()
        )
      )
    }

    return BenchmarkResult(
      operation: operation,
      measurements: measurements,
      configuration: configuration
    )
  }

  // MARK: - Multi-File Benchmarks

  /// Benchmark parsing multiple files with dependencies.
  /// - Parameters:
  ///   - filePath: Main proto file path.
  ///   - importPaths: Import paths for dependencies.
  /// - Returns: Benchmark result.
  public func benchmarkWithDependencies(_ filePath: String, importPaths: [String] = []) -> BenchmarkResult {
    let operation = "parseProtoFileWithImports(\(URL(fileURLWithPath: filePath).lastPathComponent))"
    var measurements: [Measurement] = []

    // Warmup iterations
    for _ in 0..<configuration.warmupIterations {
      _ = measureOperation {
        SwiftProtoParser.parseProtoFileWithImports(filePath, importPaths: importPaths)
      }
    }

    // Actual measurements
    for _ in 0..<configuration.iterations {
      let measurement = measureOperation {
        SwiftProtoParser.parseProtoFileWithImports(filePath, importPaths: importPaths)
      }
      measurements.append(
        Measurement(
          operation: operation,
          duration: measurement.duration,
          memoryUsage: measurement.memoryUsage,
          success: measurement.success,
          error: measurement.error,
          timestamp: Date()
        )
      )
    }

    return BenchmarkResult(
      operation: operation,
      measurements: measurements,
      configuration: configuration
    )
  }

  /// Benchmark parsing directory of proto files.
  /// - Parameters:
  ///   - directoryPath: Directory containing proto files.
  ///   - recursive: Whether to scan subdirectories.
  /// - Returns: Benchmark result.
  public func benchmarkDirectory(_ directoryPath: String, recursive: Bool = false) -> BenchmarkResult {
    let operation = "parseProtoDirectory(\(URL(fileURLWithPath: directoryPath).lastPathComponent))"
    var measurements: [Measurement] = []

    // Warmup iterations
    for _ in 0..<configuration.warmupIterations {
      _ = measureOperation {
        SwiftProtoParser.parseProtoDirectory(directoryPath, recursive: recursive)
      }
    }

    // Actual measurements
    for _ in 0..<configuration.iterations {
      let measurement = measureOperation {
        SwiftProtoParser.parseProtoDirectory(directoryPath, recursive: recursive)
      }
      measurements.append(
        Measurement(
          operation: operation,
          duration: measurement.duration,
          memoryUsage: measurement.memoryUsage,
          success: measurement.success,
          error: measurement.error,
          timestamp: Date()
        )
      )
    }

    return BenchmarkResult(
      operation: operation,
      measurements: measurements,
      configuration: configuration
    )
  }

  // MARK: - Descriptor Benchmarks

  /// Benchmark AST to descriptor conversion.
  /// - Parameter filePath: Path to the proto file.
  /// - Returns: Benchmark result.
  public func benchmarkDescriptorGeneration(_ filePath: String) -> BenchmarkResult {
    let operation = "parseProtoToDescriptors(\(URL(fileURLWithPath: filePath).lastPathComponent))"
    var measurements: [Measurement] = []

    // Warmup iterations
    for _ in 0..<configuration.warmupIterations {
      _ = measureOperation {
        SwiftProtoParser.parseProtoToDescriptors(filePath)
      }
    }

    // Actual measurements
    for _ in 0..<configuration.iterations {
      let measurement = measureOperation {
        SwiftProtoParser.parseProtoToDescriptors(filePath)
      }
      measurements.append(
        Measurement(
          operation: operation,
          duration: measurement.duration,
          memoryUsage: measurement.memoryUsage,
          success: measurement.success,
          error: measurement.error,
          timestamp: Date()
        )
      )
    }

    return BenchmarkResult(
      operation: operation,
      measurements: measurements,
      configuration: configuration
    )
  }

  // MARK: - Cache Performance Benchmarks

  /// Benchmark cache effectiveness.
  /// - Parameter filePath: Path to the proto file.
  /// - Returns: Benchmark result comparing cached vs non-cached performance.
  public func benchmarkCacheEffectiveness(_ filePath: String) -> BenchmarkResult {
    guard let cache = self.cache else {
      return BenchmarkResult(
        operation: "benchmarkCacheEffectiveness (no cache)",
        measurements: [],
        configuration: configuration
      )
    }

    let operation = "cacheEffectiveness(\(URL(fileURLWithPath: filePath).lastPathComponent))"
    var measurements: [Measurement] = []

    // Clear cache first
    cache.clearAll()

    for iteration in 0..<configuration.iterations {
      let measurement: (duration: TimeInterval, memoryUsage: Int64, success: Bool, error: ProtoParseError?)

      if iteration == 0 {
        // First iteration - cache miss expected
        measurement = measureOperation {
          SwiftProtoParser.parseProtoFile(filePath)
        }
      }
      else {
        // Subsequent iterations - cache hit expected
        measurement = measureOperation {
          SwiftProtoParser.parseProtoFile(filePath)
        }
      }

      measurements.append(
        Measurement(
          operation: operation,
          duration: measurement.duration,
          memoryUsage: measurement.memoryUsage,
          success: measurement.success,
          error: measurement.error,
          timestamp: Date()
        )
      )
    }

    return BenchmarkResult(
      operation: operation,
      measurements: measurements,
      configuration: configuration
    )
  }

  // MARK: - Comprehensive Benchmark Suites

  /// Run comprehensive benchmark suite on test files.
  /// - Parameter testFilesDirectory: Directory containing test proto files.
  /// - Returns: Complete benchmark suite results.
  public func runComprehensiveSuite(_ testFilesDirectory: String) -> BenchmarkSuite {
    let startTime = Date()
    var results: [BenchmarkResult] = []

    do {
      // Find all proto files in test directory
      let protoFiles = try findProtoFiles(in: testFilesDirectory)

      // Single file benchmarks
      for filePath in protoFiles.prefix(5) {  // Limit to first 5 files for performance
        results.append(benchmarkSingleFile(filePath))
        results.append(benchmarkDescriptorGeneration(filePath))

        if cache != nil {
          results.append(benchmarkCacheEffectiveness(filePath))
        }
      }

      // Multi-file benchmarks
      if let firstFile = protoFiles.first {
        results.append(benchmarkWithDependencies(firstFile, importPaths: [testFilesDirectory]))
      }

      // Directory benchmark
      results.append(benchmarkDirectory(testFilesDirectory))

    }
    catch {
      // Add error measurement
      results.append(
        BenchmarkResult(
          operation: "comprehensiveSuite (error)",
          measurements: [
            Measurement(
              operation: "findProtoFiles",
              duration: 0,
              memoryUsage: 0,
              success: false,
              error: .ioError(underlying: error),
              timestamp: Date()
            )
          ],
          configuration: configuration
        )
      )
    }

    return BenchmarkSuite(
      name: "ComprehensiveSuite",
      results: results,
      startTime: startTime,
      endTime: Date(),
      configuration: configuration
    )
  }

  // MARK: - Performance Regression Detection

  /// Compare benchmark results with baseline.
  /// - Parameters:
  ///   - current: Current benchmark results.
  ///   - baseline: Baseline benchmark results.
  /// - Returns: Performance comparison analysis.
  public func compareWithBaseline(_ current: BenchmarkSuite, baseline: BenchmarkSuite) -> PerformanceComparison {
    var regressions: [String] = []
    var improvements: [String] = []

    for currentResult in current.results {
      if let baselineResult = baseline.results.first(where: { $0.operation == currentResult.operation }) {
        let performanceRatio = currentResult.averageDuration / baselineResult.averageDuration

        if performanceRatio > 1.1 {  // More than 10% slower
          regressions.append(
            "\(currentResult.operation): \(String(format: "%.1f", (performanceRatio - 1) * 100))% slower"
          )
        }
        else if performanceRatio < 0.9 {  // More than 10% faster
          improvements.append(
            "\(currentResult.operation): \(String(format: "%.1f", (1 - performanceRatio) * 100))% faster"
          )
        }
      }
    }

    return PerformanceComparison(
      current: current,
      baseline: baseline,
      regressions: regressions,
      improvements: improvements
    )
  }

  // MARK: - Private Implementation

  private func measureOperation<T>(_ operation: () -> Result<T, ProtoParseError>) -> (
    duration: TimeInterval, memoryUsage: Int64, success: Bool, error: ProtoParseError?
  ) {
    let startTime = Date()
    let startMemory = configuration.trackMemory ? getCurrentMemoryUsage() : 0

    let result = operation()

    let duration = Date().timeIntervalSince(startTime)
    let endMemory = configuration.trackMemory ? getCurrentMemoryUsage() : 0
    let memoryUsage = max(0, endMemory - startMemory)

    switch result {
    case .success:
      return (duration: duration, memoryUsage: memoryUsage, success: true, error: nil)
    case .failure(let error):
      return (duration: duration, memoryUsage: memoryUsage, success: false, error: error)
    }
  }

  private func findProtoFiles(in directory: String) throws -> [String] {
    let fileManager = FileManager.default
    let url = URL(fileURLWithPath: directory)

    guard
      let enumerator = fileManager.enumerator(
        at: url,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsSubdirectoryDescendants]
      )
    else {
      throw ProtoParseError.ioError(
        underlying: NSError(
          domain: "PerformanceBenchmark",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Failed to enumerate directory"]
        )
      )
    }

    var protoFiles: [String] = []
    for case let fileURL as URL in enumerator where fileURL.pathExtension == "proto" {
      protoFiles.append(fileURL.path)
    }

    return protoFiles.sorted()
  }

  private func getCurrentMemoryUsage() -> Int64 {
    #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
      }
    }

    if kerr == KERN_SUCCESS {
      return Int64(info.resident_size)
    }

    return 0
    #elseif os(Linux)
    // Use /proc/self/status on Linux
    do {
      let statusContent = try String(contentsOfFile: "/proc/self/status", encoding: .utf8)
      let lines = statusContent.components(separatedBy: .newlines)
      
      for line in lines {
        if line.hasPrefix("VmRSS:") {
          let components = line.components(separatedBy: .whitespaces).compactMap(Int.init)
          if let memoryKB = components.first {
            return Int64(memoryKB * 1024) // Convert KB to bytes
          }
        }
      }
    } catch {
      // Fallback if /proc/self/status is not available
    }
    return 0
    #else
    // Fallback for other platforms
    return 0
    #endif
  }
}

// MARK: - Performance Comparison

/// Performance comparison between current and baseline results.
public struct PerformanceComparison {
  public let current: PerformanceBenchmark.BenchmarkSuite
  public let baseline: PerformanceBenchmark.BenchmarkSuite
  public let regressions: [String]
  public let improvements: [String]

  public var hasRegressions: Bool {
    return !regressions.isEmpty
  }

  public var hasImprovements: Bool {
    return !improvements.isEmpty
  }

  public var overallPerformanceRatio: Double {
    let currentAverage = current.results.reduce(0) { $0 + $1.averageDuration } / Double(current.results.count)
    let baselineAverage = baseline.results.reduce(0) { $0 + $1.averageDuration } / Double(baseline.results.count)

    return baselineAverage > 0 ? currentAverage / baselineAverage : 1.0
  }
}
