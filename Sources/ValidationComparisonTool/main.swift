import Foundation
import SwiftProtoParser

/// Validation comparison tool to ensure that both validator implementations produce the same results
/// This tool validates a set of test files with both implementations and compares the results

// Create test files for validation comparison
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
  
  // Invalid syntax version
  let invalidSyntaxFile = FileNode(
    location: SourceLocation(line: 1, column: 1),
    leadingComments: [],
    syntax: "proto2",
    package: "test.invalid.syntax",
    imports: [],
    options: [],
    definitions: []
  )
  files.append(invalidSyntaxFile)
  
  // Invalid enum (first value not zero)
  let invalidEnumNode = EnumNode(
    location: SourceLocation(line: 2, column: 1),
    leadingComments: [],
    trailingComment: nil,
    name: "InvalidEnum",
    values: [
      EnumValueNode(
        location: SourceLocation(line: 3, column: 3),
        leadingComments: [],
        trailingComment: nil,
        name: "ONE",
        number: 1,  // Should be 0
        options: []
      )
    ],
    options: []
  )
  
  let invalidEnumFile = FileNode(
    location: SourceLocation(line: 1, column: 1),
    leadingComments: [],
    syntax: "proto3",
    package: "test.invalid.enum",
    imports: [],
    options: [],
    definitions: [invalidEnumNode]
  )
  files.append(invalidEnumFile)
  
  // Invalid message (duplicate field number)
  let invalidMessageNode = MessageNode(
    location: SourceLocation(line: 2, column: 1),
    leadingComments: [],
    trailingComment: nil,
    name: "InvalidMessage",
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
        number: 1,  // Duplicate field number
        isRepeated: false,
        isOptional: false,
        oneof: nil,
        options: []
      )
    ],
    oneofs: [],
    options: []
  )
  
  let invalidMessageFile = FileNode(
    location: SourceLocation(line: 1, column: 1),
    leadingComments: [],
    syntax: "proto3",
    package: "test.invalid.message",
    imports: [],
    options: [],
    definitions: [invalidMessageNode]
  )
  files.append(invalidMessageFile)
  
  return files
}

// Compare validation results between original and component-based validators
func compareValidationResults() {
  print("This function would compare validation results between the original and component-based validators")
  print("However, it requires access to internal Validator class which is not accessible from this tool")
}

// Main function
func main() {
  print("Validation Comparison Tool")
  print("=========================")
  print("This tool would compare validation results between the original and component-based validators")
  print("However, it requires access to internal Validator class which is not accessible from this tool")
}

main() 