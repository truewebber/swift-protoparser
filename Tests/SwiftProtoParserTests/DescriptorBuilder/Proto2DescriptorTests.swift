import XCTest

@testable import SwiftProtoParser

// MARK: - Proto2DescriptorTests

/// Tests for proto2 descriptor generation — AC-4: extension ranges.
///
/// Verifies that `extensionRanges` in `MessageNode` are correctly converted
/// to `DescriptorProto.extensionRange` entries with exclusive end values.
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
}
