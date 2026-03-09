import Foundation
import XCTest

@testable import SwiftProtoParser

// MARK: - DescriptorProtoIntegrationTests

/// Integration test: parse the official google/protobuf/descriptor.proto end-to-end
/// using the public SwiftProtoParser.parseFile API and assert the output matches
/// known protoc semantics.
final class DescriptorProtoIntegrationTests: XCTestCase {

  // MARK: - Helpers

  private func descriptorProtoPath() -> String {
    let thisFileURL = URL(fileURLWithPath: #file)
    let projectDirectory =
      thisFileURL
      .deletingLastPathComponent()  // Integration
      .deletingLastPathComponent()  // SwiftProtoParserTests
      .deletingLastPathComponent()  // Tests
      .deletingLastPathComponent()  // project root
    return
      projectDirectory
      .appendingPathComponent("Tests/Fixtures/proto2/google/protobuf/descriptor.proto")
      .path
  }

  // MARK: - Tests

  func test_parseDescriptorProto_succeeds() {
    let result = SwiftProtoParser.parseFile(descriptorProtoPath())
    if case .failure(let error) = result {
      XCTFail("Expected successful parse of descriptor.proto; got error: \(error)")
    }
  }

  func test_parseDescriptorProto_fileDescriptorSyntaxIsEmpty() {
    guard case .success(let set) = SwiftProtoParser.parseFile(descriptorProtoPath()),
      let fd = set.file.first
    else {
      XCTFail("Parse failed or produced no file descriptors")
      return
    }
    XCTAssertEqual(
      fd.syntax,
      "",
      "Proto2 FileDescriptorProto.syntax must be empty string (protoc convention)"
    )
  }

  func test_parseDescriptorProto_packageIsGoogleProtobuf() {
    guard case .success(let set) = SwiftProtoParser.parseFile(descriptorProtoPath()),
      let fd = set.file.first
    else {
      XCTFail("Parse failed")
      return
    }
    XCTAssertEqual(fd.package, "google.protobuf")
  }

  func test_parseDescriptorProto_containsExpectedTopLevelMessages() {
    guard case .success(let set) = SwiftProtoParser.parseFile(descriptorProtoPath()),
      let fd = set.file.first
    else {
      XCTFail("Parse failed")
      return
    }
    let names = Set(fd.messageType.map { $0.name })
    XCTAssertTrue(names.contains("DescriptorProto"), "Missing DescriptorProto")
    XCTAssertTrue(names.contains("FieldDescriptorProto"), "Missing FieldDescriptorProto")
    XCTAssertTrue(names.contains("FileOptions"), "Missing FileOptions")
    XCTAssertTrue(names.contains("MessageOptions"), "Missing MessageOptions")
    XCTAssertTrue(names.contains("FileDescriptorProto"), "Missing FileDescriptorProto")
    XCTAssertTrue(names.contains("EnumDescriptorProto"), "Missing EnumDescriptorProto")
  }

  func test_parseDescriptorProto_atLeastOneMessageHasExtensionRanges() {
    guard case .success(let set) = SwiftProtoParser.parseFile(descriptorProtoPath()),
      let fd = set.file.first
    else {
      XCTFail("Parse failed")
      return
    }
    let hasRanges = fd.messageType.contains { !$0.extensionRange.isEmpty }
    XCTAssertTrue(
      hasRanges,
      "At least one message (e.g. FileOptions, MessageOptions) must have extensionRanges"
    )
  }

  func test_parseDescriptorProto_fileOptionsMessageHasExtensionRange1000ToMax() {
    guard case .success(let set) = SwiftProtoParser.parseFile(descriptorProtoPath()),
      let fd = set.file.first,
      let fileOptions = fd.messageType.first(where: { $0.name == "FileOptions" })
    else {
      XCTFail("Parse failed or FileOptions not found")
      return
    }
    XCTAssertFalse(fileOptions.extensionRange.isEmpty, "FileOptions must have extension ranges")
    let hasRange1000 = fileOptions.extensionRange.contains { $0.start == 1000 }
    XCTAssertTrue(hasRange1000, "FileOptions must have extension range starting at 1000")
  }

  func test_parseDescriptorProto_publicAndWeakDependenciesAreEmpty() {
    guard case .success(let set) = SwiftProtoParser.parseFile(descriptorProtoPath()),
      let fd = set.file.first
    else {
      XCTFail("Parse failed")
      return
    }
    XCTAssertTrue(fd.publicDependency.isEmpty, "descriptor.proto has no public imports")
    XCTAssertTrue(fd.weakDependency.isEmpty, "descriptor.proto has no weak imports")
  }

  func test_parseDescriptorProto_dependenciesAreEmpty() {
    guard case .success(let set) = SwiftProtoParser.parseFile(descriptorProtoPath()),
      let fd = set.file.first
    else {
      XCTFail("Parse failed")
      return
    }
    XCTAssertTrue(fd.dependency.isEmpty, "descriptor.proto has no imports")
  }

  func test_parseDescriptorProto_fileDescriptorSetContainsExactlyOneFile() {
    guard case .success(let set) = SwiftProtoParser.parseFile(descriptorProtoPath()) else {
      XCTFail("Parse failed")
      return
    }
    XCTAssertEqual(
      set.file.count,
      1,
      "Parsing a self-contained file must produce exactly 1 FileDescriptorProto"
    )
  }

  func test_parseDescriptorProto_fieldDescriptorProtoHasNestedEnums() {
    guard case .success(let set) = SwiftProtoParser.parseFile(descriptorProtoPath()),
      let fd = set.file.first,
      let fieldMsg = fd.messageType.first(where: { $0.name == "FieldDescriptorProto" })
    else {
      XCTFail("Parse failed or FieldDescriptorProto not found")
      return
    }
    let enumNames = Set(fieldMsg.enumType.map { $0.name })
    XCTAssertTrue(enumNames.contains("Type"), "FieldDescriptorProto must have nested enum Type")
    XCTAssertTrue(enumNames.contains("Label"), "FieldDescriptorProto must have nested enum Label")
  }
}
