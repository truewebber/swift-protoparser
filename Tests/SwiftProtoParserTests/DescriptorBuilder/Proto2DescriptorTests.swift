import XCTest

@testable import SwiftProtoParser

// MARK: - Proto2DescriptorTests

/// Tests for proto2/proto3 descriptor generation.
///
/// - AC-4: extension ranges in `DescriptorProto.extensionRange`
/// - AC-5 (first bullet): top-level `extend` blocks populate `FileDescriptorProto.extension`
final class Proto2DescriptorTests: XCTestCase {

  // MARK: - AC-4: Extension ranges in DescriptorProto

  func test_build_proto2MessageWithSingleExtensionRange_populatesExtensionRange() throws {
    let messageNode = MessageNode(
      name: "Extendable",
      fields: [],
      extensionRanges: [ExtensionRangeNode(start: 100, end: 200)]
    )

    let descriptor = try MessageDescriptorBuilder.build(from: messageNode)

    XCTAssertEqual(descriptor.extensionRange.count, 1)
    XCTAssertEqual(descriptor.extensionRange[0].start, 100)
    XCTAssertEqual(descriptor.extensionRange[0].end, 200)
  }

  func test_build_proto2MessageWithMultipleExtensionRanges_populatesAll() throws {
    let messageNode = MessageNode(
      name: "Extendable",
      fields: [],
      extensionRanges: [
        ExtensionRangeNode(start: 100, end: 200),
        ExtensionRangeNode(start: 300, end: 400),
        ExtensionRangeNode(start: 500, end: 536_870_912),
      ]
    )

    let descriptor = try MessageDescriptorBuilder.build(from: messageNode)

    XCTAssertEqual(descriptor.extensionRange.count, 3)
    XCTAssertEqual(descriptor.extensionRange[0].start, 100)
    XCTAssertEqual(descriptor.extensionRange[0].end, 200)
    XCTAssertEqual(descriptor.extensionRange[1].start, 300)
    XCTAssertEqual(descriptor.extensionRange[1].end, 400)
    XCTAssertEqual(descriptor.extensionRange[2].start, 500)
    XCTAssertEqual(descriptor.extensionRange[2].end, 536_870_912)
  }

  func test_build_proto2MessageWithMaxExtensionRange_setsCorrectEnd() throws {
    let messageNode = MessageNode(
      name: "Extendable",
      fields: [],
      extensionRanges: [ExtensionRangeNode(start: 1000, end: 536_870_912)]
    )

    let descriptor = try MessageDescriptorBuilder.build(from: messageNode)

    XCTAssertEqual(descriptor.extensionRange.count, 1)
    XCTAssertEqual(descriptor.extensionRange[0].start, 1000)
    XCTAssertEqual(descriptor.extensionRange[0].end, 536_870_912)
  }

  func test_build_proto2MessageNoExtensionRanges_hasEmptyExtensionRange() throws {
    let messageNode = MessageNode(
      name: "Plain",
      fields: []
    )

    let descriptor = try MessageDescriptorBuilder.build(from: messageNode)

    XCTAssertTrue(descriptor.extensionRange.isEmpty)
  }

  func test_buildFromProto_proto2ExtensionRange_roundTrip() {
    let proto = """
      syntax = "proto2";
      message Extendable {
        required int32 id = 1;
        extensions 100 to 199, 1000 to max;
      }
      """

    let result = SwiftProtoParser.parseProtoStringToDescriptors(proto)
    switch result {
    case .success(let fileDescriptor):
      let msgDescriptor = fileDescriptor.messageType[0]
      XCTAssertEqual(msgDescriptor.extensionRange.count, 2)
      XCTAssertEqual(msgDescriptor.extensionRange[0].start, 100)
      XCTAssertEqual(msgDescriptor.extensionRange[0].end, 200)
      XCTAssertEqual(msgDescriptor.extensionRange[1].start, 1000)
      XCTAssertEqual(msgDescriptor.extensionRange[1].end, 536_870_912)
    case .failure(let error):
      XCTFail("Round-trip must succeed, got: \(error.description)")
    }
  }

  // MARK: - AC-5: Top-level extend → FileDescriptorProto.extension

  func test_build_proto3TopLevelExtend_populatesFileExtension() {
    let proto = """
      syntax = "proto3";
      import "google/protobuf/descriptor.proto";
      extend google.protobuf.MessageOptions {
        optional string my_option = 51234;
      }
      """

    let result = SwiftProtoParser.parseProtoStringToDescriptors(proto)
    switch result {
    case .success(let fileDescriptor):
      XCTAssertFalse(
        fileDescriptor.extension.isEmpty,
        "FileDescriptorProto.extension must be non-empty for files with top-level extend blocks"
      )
      XCTAssertEqual(fileDescriptor.extension.count, 1)
      XCTAssertEqual(fileDescriptor.extension[0].name, "my_option")
      XCTAssertEqual(fileDescriptor.extension[0].number, 51234)
    case .failure(let error):
      XCTFail("proto3 top-level extend must succeed, got: \(error.description)")
    }
  }

  func test_build_proto3TopLevelExtend_extendeeIsFullyQualified() {
    let proto = """
      syntax = "proto3";
      extend google.protobuf.FileOptions {
        optional bool my_flag = 50000;
      }
      """

    let result = SwiftProtoParser.parseProtoStringToDescriptors(proto)
    switch result {
    case .success(let fileDescriptor):
      XCTAssertFalse(fileDescriptor.extension.isEmpty)
      let extendee = fileDescriptor.extension[0].extendee
      XCTAssertTrue(
        extendee.hasPrefix("."),
        "extendee must be fully qualified (start with '.'). Got: \(extendee)"
      )
      XCTAssertEqual(extendee, ".google.protobuf.FileOptions")
    case .failure(let error):
      XCTFail("proto3 top-level extend must succeed, got: \(error.description)")
    }
  }

  func test_build_proto2TopLevelExtend_populatesFileExtension() {
    let proto = """
      syntax = "proto2";
      message Base {
        required int32 id = 1;
        extensions 100 to 199;
      }
      extend Base {
        optional string extra = 100;
      }
      """

    let result = SwiftProtoParser.parseProtoStringToDescriptors(proto)
    switch result {
    case .success(let fileDescriptor):
      XCTAssertFalse(
        fileDescriptor.extension.isEmpty,
        "FileDescriptorProto.extension must contain the extend field"
      )
      XCTAssertEqual(fileDescriptor.extension[0].name, "extra")
      XCTAssertEqual(fileDescriptor.extension[0].number, 100)
    case .failure(let error):
      XCTFail("proto2 top-level extend must succeed, got: \(error.description)")
    }
  }

  func test_build_proto2TopLevelExtend_withPackage_extendeePrependedWithPackage() {
    let proto = """
      syntax = "proto2";
      package my.pkg;
      message Base {
        required int32 id = 1;
        extensions 100 to 199;
      }
      extend Base {
        optional string extra = 100;
      }
      """

    let result = SwiftProtoParser.parseProtoStringToDescriptors(proto)
    switch result {
    case .success(let fileDescriptor):
      XCTAssertFalse(fileDescriptor.extension.isEmpty)
      let extendee = fileDescriptor.extension[0].extendee
      XCTAssertTrue(
        extendee.hasPrefix("."),
        "extendee must start with '.'. Got: \(extendee)"
      )
      XCTAssertEqual(extendee, ".my.pkg.Base")
    case .failure(let error):
      XCTFail("proto2 top-level extend with package must succeed, got: \(error.description)")
    }
  }

  func test_build_topLevelExtendWithLeadingDot_extendeeUnchanged() throws {
    let fieldNode = FieldNode(
      name: "already_qualified",
      type: .int32,
      number: 51235,
      label: .optional
    )
    let extendNode = ExtendNode(
      extendedType: ".google.protobuf.MessageOptions",
      fields: [fieldNode],
      position: Token.Position(line: 1, column: 1)
    )
    let ast = ProtoAST(
      syntax: .proto3,
      package: nil,
      imports: [],
      options: [],
      messages: [],
      enums: [],
      services: [],
      extends: [extendNode]
    )

    let fileDescriptor = try DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")

    XCTAssertFalse(fileDescriptor.extension.isEmpty)
    XCTAssertEqual(
      fileDescriptor.extension[0].extendee,
      ".google.protobuf.MessageOptions",
      "extendee already starting with '.' must be kept as-is"
    )
  }

  func test_build_fileWithNoExtend_hasEmptyFileExtension() {
    let proto = """
      syntax = "proto2";
      message Plain {
        required int32 id = 1;
      }
      """

    let result = SwiftProtoParser.parseProtoStringToDescriptors(proto)
    switch result {
    case .success(let fileDescriptor):
      XCTAssertTrue(
        fileDescriptor.extension.isEmpty,
        "No extend blocks → FileDescriptorProto.extension must be empty"
      )
    case .failure(let error):
      XCTFail("Plain proto2 message must succeed, got: \(error.description)")
    }
  }

  func test_build_topLevelExtendMultipleFields_allPopulated() {
    let proto = """
      syntax = "proto3";
      extend google.protobuf.MessageOptions {
        optional string label = 51236;
        optional bool   hidden = 51237;
      }
      """

    let result = SwiftProtoParser.parseProtoStringToDescriptors(proto)
    switch result {
    case .success(let fileDescriptor):
      XCTAssertEqual(fileDescriptor.extension.count, 2)
      XCTAssertEqual(fileDescriptor.extension[0].name, "label")
      XCTAssertEqual(fileDescriptor.extension[1].name, "hidden")
      XCTAssertEqual(fileDescriptor.extension[0].extendee, ".google.protobuf.MessageOptions")
      XCTAssertEqual(fileDescriptor.extension[1].extendee, ".google.protobuf.MessageOptions")
    case .failure(let error):
      XCTFail("Multi-field top-level extend must succeed, got: \(error.description)")
    }
  }
}
