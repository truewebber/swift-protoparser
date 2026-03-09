import SwiftProtobuf
import XCTest

@testable import SwiftProtoParser

// MARK: - WellKnownTypesIntegrationTests

/// Integration tests that parse every well-known protobuf type with SwiftProtoParser
/// and compare the resulting `FileDescriptorProto` against the reference descriptor
/// produced by protoc.
///
/// Reference `.pb` files live in `Tests/TestResources/WellKnownDescriptors/` and are
/// generated via `Scripts/generate_well_known_descriptors.sh`.
///
/// Comparison strategy
/// -------------------
/// Both descriptors are serialised to JSON using SwiftProtobuf's JSONEncoder and the
/// strings are compared directly. Before serialising we clear `source_code_info` (only
/// present when protoc is invoked with `--include_source_info`, which we do not use)
/// and `edition` (an editions-only field not yet supported by SwiftProtoParser).
final class WellKnownTypesIntegrationTests: XCTestCase {

  // MARK: - Well-known proto3 types (no external dependencies)

  func test_any_matchesProtocDescriptor() throws {
    try assertMatches(protoName: "any")
  }

  func test_duration_matchesProtocDescriptor() throws {
    try assertMatches(protoName: "duration")
  }

  func test_empty_matchesProtocDescriptor() throws {
    try assertMatches(protoName: "empty")
  }

  func test_fieldMask_matchesProtocDescriptor() throws {
    try assertMatches(protoName: "field_mask")
  }

  func test_sourceContext_matchesProtocDescriptor() throws {
    try assertMatches(protoName: "source_context")
  }

  func test_timestamp_matchesProtocDescriptor() throws {
    try assertMatches(protoName: "timestamp")
  }

  func test_wrappers_matchesProtocDescriptor() throws {
    try assertMatches(protoName: "wrappers")
  }

  // MARK: - More complex well-known types

  func test_struct_matchesProtocDescriptor() throws {
    try assertMatches(protoName: "struct")
  }

  func test_type_matchesProtocDescriptor() throws {
    try assertMatches(protoName: "type")
  }

  func test_api_matchesProtocDescriptor() throws {
    try assertMatches(protoName: "api")
  }

  // MARK: - descriptor.proto (the hardest one — used as dependency by starlink.proto)

  /// Smoke-test: verifies that SwiftProtoParser can parse google/protobuf/descriptor.proto
  /// without errors and produces a structurally correct descriptor.
  ///
  /// descriptor.proto is the most complex well-known proto: proto2 syntax, extension ranges
  /// with `declaration = {...}` options, `reserved N to max;` in enums, nested messages,
  /// custom options defined by the file itself, and service definitions.
  ///
  /// We do NOT do a full JSON comparison with protoc here because descriptor.proto defines
  /// its own custom field options (retention, targets, edition_defaults, feature_support).
  /// protoc resolves these to typed known fields, whereas SwiftProtoParser stores them as
  /// `uninterpreted_option` — both are valid representations of the same data.
  /// The structural comparison (message names, field numbers, enum values) is what matters.
  func test_descriptor_parsesSuccessfully() throws {
    let protoRelativePath = "google/protobuf/descriptor.proto"
    let protoFullPath = "/usr/local/include/\(protoRelativePath)"

    let result = SwiftProtoParser.parseFile(protoFullPath, importPaths: ["/usr/local/include"])
    guard case .success(let fileSet) = result else {
      if case .failure(let error) = result {
        XCTFail("SwiftProtoParser failed to parse descriptor.proto: \(error)")
      }
      return
    }

    guard let fileProto = fileSet.file.first(where: { $0.name == protoRelativePath }) else {
      XCTFail("FileDescriptorSet does not contain descriptor.proto")
      return
    }

    // Structural checks — message count, key message names, enum count
    XCTAssertEqual(fileProto.package, "google.protobuf")

    let messageNames = fileProto.messageType.map { $0.name }
    XCTAssertTrue(messageNames.contains("FileDescriptorSet"), "FileDescriptorSet missing")
    XCTAssertTrue(messageNames.contains("FileDescriptorProto"), "FileDescriptorProto missing")
    XCTAssertTrue(messageNames.contains("DescriptorProto"), "DescriptorProto missing")
    XCTAssertTrue(messageNames.contains("FieldDescriptorProto"), "FieldDescriptorProto missing")
    XCTAssertTrue(messageNames.contains("EnumDescriptorProto"), "EnumDescriptorProto missing")
    XCTAssertTrue(messageNames.contains("ServiceDescriptorProto"), "ServiceDescriptorProto missing")
    XCTAssertTrue(messageNames.contains("FeatureSet"), "FeatureSet missing")
    XCTAssertTrue(messageNames.contains("UninterpretedOption"), "UninterpretedOption missing")

    let enumNames = fileProto.enumType.map { $0.name }
    XCTAssertTrue(enumNames.contains("Edition"), "Edition enum missing")

    // DescriptorProto should have the expected nested types
    let descriptorProto = fileProto.messageType.first { $0.name == "DescriptorProto" }
    XCTAssertNotNil(descriptorProto)
    let nestedNames = descriptorProto?.nestedType.map { $0.name } ?? []
    XCTAssertTrue(nestedNames.contains("ExtensionRange"), "DescriptorProto.ExtensionRange missing")
    XCTAssertTrue(nestedNames.contains("ReservedRange"), "DescriptorProto.ReservedRange missing")

    // FieldDescriptorProto should have Type and Label enums
    let fieldDescProto = fileProto.messageType.first { $0.name == "FieldDescriptorProto" }
    XCTAssertNotNil(fieldDescProto)
    let fdpEnumNames = fieldDescProto?.enumType.map { $0.name } ?? []
    XCTAssertTrue(fdpEnumNames.contains("Type"), "FieldDescriptorProto.Type missing")
    XCTAssertTrue(fdpEnumNames.contains("Label"), "FieldDescriptorProto.Label missing")

    // FeatureSet should have several enum nested types including FieldPresence
    let featureSet = fileProto.messageType.first { $0.name == "FeatureSet" }
    XCTAssertNotNil(featureSet)
    let featureEnumNames = featureSet?.enumType.map { $0.name } ?? []
    XCTAssertTrue(featureEnumNames.contains("FieldPresence"), "FeatureSet.FieldPresence missing")
    XCTAssertTrue(featureEnumNames.contains("EnumType"), "FeatureSet.EnumType missing")
  }

  // MARK: - Core assertion

  /// Parses `google/protobuf/<protoName>.proto` with SwiftProtoParser and asserts that
  /// its `FileDescriptorProto` is equal (after normalisation) to the one produced by
  /// protoc and stored in `Tests/TestResources/WellKnownDescriptors/<protoName>.pb`.
  private func assertMatches(
    protoName: String,
    file: StaticString = #file,
    line: UInt = #line
  ) throws {
    let protoRelativePath = "google/protobuf/\(protoName).proto"

    // ── 1. Load reference descriptor from TestResources ──────────────────────
    let pbURL = testResourceURL(for: "WellKnownDescriptors/\(protoName).pb")
    guard FileManager.default.fileExists(atPath: pbURL.path) else {
      XCTFail(
        "Reference descriptor not found: \(pbURL.path). Run Scripts/generate_well_known_descriptors.sh",
        file: file,
        line: line
      )
      return
    }
    let pbData = try Data(contentsOf: pbURL)
    let referenceSet = try Google_Protobuf_FileDescriptorSet(serializedBytes: Array(pbData))
    guard let referenceProto = referenceSet.file.first(where: { $0.name == protoRelativePath }) else {
      XCTFail(
        "Reference FileDescriptorSet does not contain \(protoRelativePath)",
        file: file,
        line: line
      )
      return
    }

    // ── 2. Parse with SwiftProtoParser ────────────────────────────────────────
    let protoFullPath = "/usr/local/include/\(protoRelativePath)"
    let result = SwiftProtoParser.parseFile(protoFullPath, importPaths: ["/usr/local/include"])
    guard case .success(let actualSet) = result else {
      if case .failure(let error) = result {
        XCTFail("SwiftProtoParser failed for \(protoRelativePath): \(error)", file: file, line: line)
      }
      return
    }
    guard let actualProto = actualSet.file.first(where: { $0.name == protoRelativePath }) else {
      XCTFail(
        "SwiftProtoParser result does not contain \(protoRelativePath)",
        file: file,
        line: line
      )
      return
    }

    // ── 3. Normalise ──────────────────────────────────────────────────────────
    let normRef = normalise(referenceProto)
    let normActual = normalise(actualProto)

    // ── 4. Serialise to JSON and compare ─────────────────────────────────────
    let refJSON: String
    let actualJSON: String
    do {
      refJSON = try normRef.jsonString()
      actualJSON = try normActual.jsonString()
    }
    catch {
      XCTFail("JSON serialisation failed for \(protoRelativePath): \(error)", file: file, line: line)
      return
    }

    XCTAssertEqual(
      actualJSON,
      refJSON,
      "Descriptor mismatch for \(protoRelativePath).\n"
        + "--- expected (protoc) ---\n\(refJSON)\n"
        + "--- actual (SwiftProtoParser) ---\n\(actualJSON)",
      file: file,
      line: line
    )
  }

  // MARK: - Normalisation

  /// Strips fields that SwiftProtoParser intentionally does not produce so that
  /// the JSON comparison is not polluted by unimplemented-but-irrelevant data.
  private func normalise(_ proto: Google_Protobuf_FileDescriptorProto) -> Google_Protobuf_FileDescriptorProto {
    var p = proto
    // source_code_info is only present with --include_source_info; we never set it.
    p.clearSourceCodeInfo()
    // editions-only field; SwiftProtoParser does not support editions yet.
    p.clearEdition()
    // Recursively normalise nested messages
    p.messageType = p.messageType.map { normaliseMessage($0) }
    return p
  }

  private func normaliseMessage(
    _ proto: Google_Protobuf_DescriptorProto
  ) -> Google_Protobuf_DescriptorProto {
    var p = proto
    // Google_Protobuf_DescriptorProto uses `nestedType` for nested messages
    p.nestedType = p.nestedType.map { normaliseMessage($0) }
    return p
  }

  // MARK: - Helpers

  /// Returns the URL for a file inside `Tests/TestResources/`.
  private func testResourceURL(for relativePath: String) -> URL {
    let thisFile = URL(fileURLWithPath: #file)
    // #file → …/Tests/SwiftProtoParserTests/ProductTests/WellKnownTypesIntegrationTests.swift
    let projectRoot =
      thisFile
      .deletingLastPathComponent()  // ProductTests
      .deletingLastPathComponent()  // SwiftProtoParserTests
      .deletingLastPathComponent()  // Tests
      .deletingLastPathComponent()  // project root
    return projectRoot.appendingPathComponent("Tests/TestResources/\(relativePath)")
  }
}
