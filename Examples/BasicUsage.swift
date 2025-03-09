import Foundation
import SwiftProtoParser
import SwiftProtobuf

/// This example demonstrates basic usage of the SwiftProtoParser library.
/// It shows how to parse a proto file and access the generated descriptor.

// MARK: - Basic Parsing

/// Parse a proto file and print its contents.
func parseProtoFile() {
  // Create a parser with default configuration
  let parser = ProtoParser()

  do {
    // Parse a proto file
    let descriptor = try parser.parseFile("path/to/your.proto")

    // Print basic information about the file
    print("File: \(descriptor.name)")
    print("Package: \(descriptor.package)")
    print("Syntax: \(descriptor.syntax)")

    // Print messages
    print("\nMessages:")
    for message in descriptor.messageType {
      printMessage(message, indent: 2)
    }

    // Print enums
    print("\nEnums:")
    for enumType in descriptor.enumType {
      printEnum(enumType, indent: 2)
    }

    // Print services
    print("\nServices:")
    for service in descriptor.service {
      printService(service, indent: 2)
    }
  }
  catch {
    print("Error parsing proto file: \(error)")
  }
}

// MARK: - Custom Configuration

/// Parse a proto file with custom configuration.
func parseWithCustomConfiguration() {
  // Create a configuration using the builder pattern
  let config = Configuration.builder()
    .addImportPath("path/to/imports")
    .withSourceInfo(true)
    .withServices(true)
    .build()

  // Create a parser with the custom configuration
  let parser = ProtoParser(configuration: config)

  do {
    // Parse a proto file
    let descriptor = try parser.parseFile("path/to/your.proto")

    // Use the descriptor...
    print("Successfully parsed with custom configuration")
  }
  catch {
    print("Error parsing proto file: \(error)")
  }
}

// MARK: - Parsing from String

/// Parse proto content from a string.
func parseFromString() {
  let protoContent = """
    syntax = "proto3";

    package example;

    message Person {
      string name = 1;
      int32 id = 2;
      bool active = 3;
    }
    """

  let parser = ProtoParser()

  do {
    // Parse proto content from a string
    let descriptor = try parser.parseContent(protoContent, filePath: "example.proto")

    // Use the descriptor...
    print("Successfully parsed from string")
  }
  catch {
    print("Error parsing proto content: \(error)")
  }
}

// MARK: - Helper Functions

/// Print a message descriptor.
func printMessage(_ message: Google_Protobuf_DescriptorProto, indent: Int) {
  let indentation = String(repeating: " ", count: indent)
  print("\(indentation)Message: \(message.name)")

  // Print fields
  for field in message.field {
    print("\(indentation)  Field: \(field.name) (\(field.number))")
  }

  // Print nested messages
  for nestedMessage in message.nestedType {
    printMessage(nestedMessage, indent: indent + 4)
  }

  // Print nested enums
  for nestedEnum in message.enumType {
    printEnum(nestedEnum, indent: indent + 4)
  }
}

/// Print an enum descriptor.
func printEnum(_ enumType: Google_Protobuf_EnumDescriptorProto, indent: Int) {
  let indentation = String(repeating: " ", count: indent)
  print("\(indentation)Enum: \(enumType.name)")

  // Print enum values
  for value in enumType.value {
    print("\(indentation)  Value: \(value.name) = \(value.number)")
  }
}

/// Print a service descriptor.
func printService(_ service: Google_Protobuf_ServiceDescriptorProto, indent: Int) {
  let indentation = String(repeating: " ", count: indent)
  print("\(indentation)Service: \(service.name)")

  // Print methods
  for method in service.method {
    print("\(indentation)  Method: \(method.name)")
    print("\(indentation)    Input: \(method.inputType)")
    print("\(indentation)    Output: \(method.outputType)")
    print("\(indentation)    Client Streaming: \(method.clientStreaming)")
    print("\(indentation)    Server Streaming: \(method.serverStreaming)")
  }
}

// MARK: - Main

// Uncomment one of these to run the example
// parseProtoFile()
// parseWithCustomConfiguration()
// parseFromString()
