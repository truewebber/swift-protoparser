import Foundation
import SwiftProtoParser

/// Simple benchmark tool to compare the performance of the original and component-based validator implementations
/// Usage: swift run -c release BenchmarkTool --validator [original|component]

// Create test files for benchmarking
func createTestFiles() -> [FileNode] {
  var files: [FileNode] = []
  
  // Simple file
  let simpleFile = FileNode(
    location: SourceLocation(line: 1, column: 1),
    leadingComments: [],
    syntax: "proto3",
    package: "test.simple",
    imports: [],
    options: [],
    definitions: []
  )
  files.append(simpleFile)
  
  // File with enums
  let enumNode = EnumNode(
    location: SourceLocation(line: 2, column: 1),
    leadingComments: [],
    trailingComment: nil,
    name: "TestEnum",
    values: [
      EnumValueNode(
        location: SourceLocation(line: 3, column: 3),
        leadingComments: [],
        trailingComment: nil,
        name: "ZERO",
        number: 0,
        options: []
      ),
      EnumValueNode(
        location: SourceLocation(line: 4, column: 3),
        leadingComments: [],
        trailingComment: nil,
        name: "ONE",
        number: 1,
        options: []
      )
    ],
    options: []
  )
  
  let enumFile = FileNode(
    location: SourceLocation(line: 1, column: 1),
    leadingComments: [],
    syntax: "proto3",
    package: "test.enums",
    imports: [],
    options: [],
    definitions: [enumNode]
  )
  files.append(enumFile)
  
  // File with messages
  let messageNode = MessageNode(
    location: SourceLocation(line: 2, column: 1),
    leadingComments: [],
    trailingComment: nil,
    name: "TestMessage",
    fields: [
      FieldNode(
        location: SourceLocation(line: 3, column: 3),
        leadingComments: [],
        trailingComment: nil,
        name: "field1",
        type: .scalar(.string),
        number: 1,
        isRepeated: false,
        isOptional: false,
        oneof: nil,
        options: []
      ),
      FieldNode(
        location: SourceLocation(line: 4, column: 3),
        leadingComments: [],
        trailingComment: nil,
        name: "field2",
        type: .scalar(.int32),
        number: 2,
        isRepeated: false,
        isOptional: false,
        oneof: nil,
        options: []
      )
    ],
    oneofs: [],
    options: []
  )
  
  let messageFile = FileNode(
    location: SourceLocation(line: 1, column: 1),
    leadingComments: [],
    syntax: "proto3",
    package: "test.messages",
    imports: [],
    options: [],
    definitions: [messageNode]
  )
  files.append(messageFile)
  
  return files
}

// Main function
func main() {
  print("Benchmark Tool")
  print("==============")
  print("This tool would benchmark the performance of the original and component-based validators")
  print("However, it requires access to internal Validator class which is not accessible from this tool")
  
  // Create test files to demonstrate they can be created correctly
  let files = createTestFiles()
  print("Successfully created \(files.count) test files")
}

main() 