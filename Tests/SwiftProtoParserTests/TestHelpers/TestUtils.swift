import XCTest

@testable import SwiftProtoParser

/// Utility functions and extensions for testing.
enum TestUtils {

  /// Creates a temporary file with the given content
  /// - Parameters:.
  ///   - content: The content to write to the file.
  ///   - fileExtension: The file extension (default: "proto").
  /// - Returns: The URL of the temporary file.
  static func createTemporaryFile(
    with content: String,
    fileExtension: String = "proto"
  ) throws
    -> URL
  {
    let temporaryDirectory = FileManager.default.temporaryDirectory
    let fileName = UUID().uuidString
    let fileURL = temporaryDirectory.appendingPathComponent(fileName).appendingPathExtension(
      fileExtension
    )

    try content.write(to: fileURL, atomically: true, encoding: .utf8)

    return fileURL
  }

  /// Deletes a file at the given URL.
  /// - Parameter url: The URL of the file to delete.
  static func deleteFile(at url: URL) throws {
    try FileManager.default.removeItem(at: url)
  }

  /// Creates a lexer for the given input
  /// - Parameter input: The input string to tokenize.
  /// - Returns: A lexer instance.
  static func createLexer(for input: String) -> Lexer {
    return Lexer(input: input)
  }

  /// Creates a parser for the given input
  /// - Parameter input: The input string to parse.
  /// - Returns: A parser instance.
  static func createParser(for input: String) throws -> Parser {
    let lexer = createLexer(for: input)
    return try Parser(lexer: lexer)
  }

  /// Creates a default configuration for testing.
  /// - Returns: A configuration instance.
  static func createDefaultConfiguration() -> Configuration {
    return Configuration.builder().build()
  }

  /// Creates a proto parser with default configuration.
  /// - Returns: A proto parser instance.
  static func createDefaultProtoParser() -> ProtoParser {
    return ProtoParser(configuration: createDefaultConfiguration())
  }

  /// Asserts that a function throws a specific error type.
  /// - Parameters:.
  ///   - expectedError: The expected error type.
  ///   - expression: The expression that should throw.
  ///   - message: The assertion message.
  ///   - file: The file where the assertion is made.
  ///   - line: The line where the assertion is made.
  static func assertThrows<T: Error, R>(
    _ expectedError: T.Type,
    _ expression: @autoclosure () throws -> R,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertThrowsError(try expression(), message(), file: file, line: line) { error in
      XCTAssertTrue(
        error is T,
        "Expected error of type \(T.self), but got \(type(of: error))",
        file: file,
        line: line
      )
    }
  }

  /// Asserts that a function throws a specific error.
  /// - Parameters:.
  ///   - expectedError: The expected error.
  ///   - expression: The expression that should throw.
  ///   - message: The assertion message.
  ///   - file: The file where the assertion is made.
  ///   - line: The line where the assertion is made.
  static func assertThrows<T: Error & Equatable, R>(
    _ expectedError: T,
    _ expression: @autoclosure () throws -> R,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertThrowsError(try expression(), message(), file: file, line: line) { error in
      guard let typedError = error as? T else {
        XCTFail(
          "Expected error of type \(T.self), but got \(type(of: error))",
          file: file,
          line: line
        )
        return
      }

      XCTAssertEqual(
        typedError,
        expectedError,
        "Expected error \(expectedError), but got \(typedError)",
        file: file,
        line: line
      )
    }
  }
}

/// Extension to create test proto files.
extension String {
  /// A simple valid proto file.
  static let simpleProtoFile = """
    syntax = "proto3";

    package test;

    message TestMessage {
      string name = 1;
      int32 id = 2;
    }
    """

  /// A proto file with all basic elements.
  static let completeProtoFile = """
    syntax = "proto3";

    package test;

    import "google/protobuf/descriptor.proto";

    option java_package = "com.example.test";

    message TestMessage {
      string name = 1;
      int32 id = 2;
      bool active = 3;
      
      enum Status {
        UNKNOWN = 0;
        ACTIVE = 1;
        INACTIVE = 2;
      }
      
      Status status = 4;
      
      message NestedMessage {
        string value = 1;
      }
      
      NestedMessage nested = 5;
      
      oneof test_oneof {
        string oneof_string = 6;
        int32 oneof_int = 7;
      }
      
      map<string, string> metadata = 8;
      
      reserved 9, 10, 15 to 20;
      reserved "foo", "bar";
    }

    enum TestEnum {
      UNKNOWN = 0;
      VALUE1 = 1;
      VALUE2 = 2;
    }

    service TestService {
      rpc GetTest(TestMessage) returns (TestMessage);
      rpc StreamTests(TestMessage) returns (stream TestMessage);
      rpc StreamBoth(stream TestMessage) returns (stream TestMessage);
    }
    """

  /// A proto file with custom options.
  static let customOptionsProtoFile = """
    syntax = "proto3";

    package test;

    import "google/protobuf/descriptor.proto";

    extend google.protobuf.FileOptions {
      string my_file_option = 50000;
    }

    extend google.protobuf.MessageOptions {
      int32 my_message_option = 50001;
    }

    extend google.protobuf.FieldOptions {
      bool my_field_option = 50002;
    }

    option (my_file_option) = "Hello, world!";

    message TestMessage {
      option (my_message_option) = 42;
      
      string name = 1 [(my_field_option) = true];
    }
    """

  /// A proto file with extensions.
  static let extensionsProtoFile = """
    syntax = "proto3";

    package test;

    message TestMessage {
      string name = 1;
      int32 id = 2;
    }

    extend TestMessage {
      string extra_info = 3;
      bool is_valid = 4;
    }
    """

  /// A proto file with invalid syntax.
  static let invalidSyntaxProtoFile = """
    syntax = "proto3"

    package test

    message TestMessage {
      string name = 1
      int32 id = 2
    }
    """

  /// A proto file with invalid field numbers.
  static let invalidFieldNumbersProtoFile = """
    syntax = "proto3";

    package test;

    message TestMessage {
      string name = 0;
      int32 id = 19000;
    }
    """

  /// A proto file with duplicate field numbers.
  static let duplicateFieldNumbersProtoFile = """
    syntax = "proto3";

    package test;

    message TestMessage {
      string name = 1;
      int32 id = 1;
    }
    """

  /// A proto file with invalid enum values.
  static let invalidEnumValuesProtoFile = """
    syntax = "proto3";

    package test;

    enum TestEnum {
      UNKNOWN = 1;
      VALUE1 = 2;
    }
    """

  /// A proto file with circular imports.
  static let circularImportProtoFile1 = """
    syntax = "proto3";

    package test1;

    import "test2.proto";

    message Test1 {
      Test2 test2 = 1;
    }
    """

  static let circularImportProtoFile2 = """
    syntax = "proto3";

    package test2;

    import "test1.proto";

    message Test2 {
      Test1 test1 = 1;
    }
    """
}
