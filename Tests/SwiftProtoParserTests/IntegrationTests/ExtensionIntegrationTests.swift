import SwiftProtobuf
import XCTest

@testable import SwiftProtoParser

final class ExtensionIntegrationTests: XCTestCase {

  func testExtensionIntegration() throws {
    // Create a test proto file with extensions
    let protoContent = """
      syntax = "proto3";

      package test;

      message Foo {
        int32 a = 1;
      }

      extend Foo {
        string bar = 2;
        int32 baz = 3;
      }
      """

    // Parse the proto file
    let lexer = Lexer(input: protoContent)
    let parser = try Parser(lexer: lexer)
    let file = try parser.parseFile(filePath: "test.proto")

    // Generate descriptor
    let generator = DescriptorGenerator()
    let descriptor = try generator.generateFileDescriptor(file)

    // Verify extensions
    XCTAssertEqual(descriptor.extension.count, 2)

    // Find the Foo extensions
    let fooExtensions = descriptor.extension.filter { $0.extendee.hasSuffix(".test.Foo") }
    XCTAssertEqual(fooExtensions.count, 2)

    // Verify bar extension
    let barExtension = fooExtensions.first { $0.name == "bar" }
    XCTAssertNotNil(barExtension)
    XCTAssertEqual(barExtension?.number, 2)
    XCTAssertEqual(barExtension?.type, .string)

    // Verify baz extension
    let bazExtension = fooExtensions.first { $0.name == "baz" }
    XCTAssertNotNil(bazExtension)
    XCTAssertEqual(bazExtension?.number, 3)
    XCTAssertEqual(bazExtension?.type, .int32)
  }
}
