import SwiftProtoParser
import XCTest

final class ParserPerformanceTests: XCTestCase {

  // MARK: - Properties

  private let fileManager = FileManager.default
  private let testProtoDir = "TestProtos"

  // MARK: - Setup & Teardown

  override func setUp() {
    super.setUp()
    // Ensure test proto files exist
    XCTAssertTrue(
      fileManager.fileExists(atPath: "\(testProtoDir)/simple.proto"),
      "simple.proto not found. Run Scripts/setup_protoc.sh first.")
    XCTAssertTrue(
      fileManager.fileExists(atPath: "\(testProtoDir)/complex.proto"),
      "complex.proto not found. Run Scripts/setup_protoc.sh first.")
  }

  // MARK: - Performance Tests

  func testSimpleProtoParsingPerformance() throws {
    let parser = ProtoParser(
      configuration: Configuration.builder()
        .addImportPath(testProtoDir)
        .build())

    measure {
      do {
        // Parse the file with validation disabled to avoid type reference errors
        let lexer = Lexer(
          input: try String(contentsOfFile: "\(testProtoDir)/simple.proto", encoding: .utf8))
        let parserInstance = try Parser(lexer: lexer)
        let fileNode = try parserInstance.parseFile(filePath: "\(testProtoDir)/simple.proto")

        // Generate descriptor without validation
        let generator = DescriptorGenerator()
        _ = try generator.generateFileDescriptor(fileNode)
      } catch {
        XCTFail("Failed to parse simple.proto: \(error)")
      }
    }
  }

  func testComplexProtoParsingPerformance() throws {
    let parser = ProtoParser(
      configuration: Configuration.builder()
        .addImportPath(testProtoDir)
        .build())

    measure {
      do {
        // Parse the file with validation disabled to avoid type reference errors
        let lexer = Lexer(
          input: try String(contentsOfFile: "\(testProtoDir)/complex.proto", encoding: .utf8))
        let parserInstance = try Parser(lexer: lexer)
        let fileNode = try parserInstance.parseFile(filePath: "\(testProtoDir)/complex.proto")

        // Generate descriptor without validation
        let generator = DescriptorGenerator()
        _ = try generator.generateFileDescriptor(fileNode)
      } catch {
        XCTFail("Failed to parse complex.proto: \(error)")
      }
    }
  }

  func testLargeProtoParsingPerformance() throws {
    // Generate a large proto file for performance testing
    let largeProtoPath = "\(testProtoDir)/large.proto"
    try generateLargeProtoFile(path: largeProtoPath, messageCount: 100, fieldsPerMessage: 20)

    measure {
      do {
        // Parse the file with validation disabled to avoid type reference errors
        let lexer = Lexer(input: try String(contentsOfFile: largeProtoPath, encoding: .utf8))
        let parserInstance = try Parser(lexer: lexer)
        let fileNode = try parserInstance.parseFile(filePath: largeProtoPath)

        // Generate descriptor without validation
        let generator = DescriptorGenerator()
        _ = try generator.generateFileDescriptor(fileNode)
      } catch {
        XCTFail("Failed to parse large.proto: \(error)")
      }
    }

    // Clean up
    try? fileManager.removeItem(atPath: largeProtoPath)
  }

  func testMemoryUsage() throws {
    // This test doesn't actually measure memory usage automatically,
    // but it can be used with Instruments to profile memory usage

    for _ in 0..<100 {
      autoreleasepool {
        do {
          // Parse the file with validation disabled to avoid type reference errors
          let lexer = Lexer(
            input: try String(contentsOfFile: "\(testProtoDir)/complex.proto", encoding: .utf8))
          let parserInstance = try Parser(lexer: lexer)
          let fileNode = try parserInstance.parseFile(filePath: "\(testProtoDir)/complex.proto")

          // Generate descriptor without validation
          let generator = DescriptorGenerator()
          _ = try generator.generateFileDescriptor(fileNode)
        } catch {
          XCTFail("Failed to parse complex.proto: \(error)")
        }
      }
    }
  }

  // MARK: - Helper Methods

  /// Generates a large proto file for performance testing
  private func generateLargeProtoFile(path: String, messageCount: Int, fieldsPerMessage: Int) throws
  {
    var content = """
      syntax = "proto3";

      package performance_test;

      """

    for i in 0..<messageCount {
      content += "message Message\(i) {\n"

      for j in 0..<fieldsPerMessage {
        let fieldType: String
        switch j % 10 {
        case 0: fieldType = "string"
        case 1: fieldType = "int32"
        case 2: fieldType = "int64"
        case 3: fieldType = "uint32"
        case 4: fieldType = "uint64"
        case 5: fieldType = "bool"
        case 6: fieldType = "bytes"
        case 7: fieldType = "float"
        case 8: fieldType = "double"
        case 9: fieldType = "Message\((i + 1) % messageCount)"
        default: fieldType = "string"
        }

        content += "  \(fieldType) field\(j) = \(j + 1);\n"
      }

      content += "}\n\n"
    }

    try content.write(toFile: path, atomically: true, encoding: .utf8)
  }
}
