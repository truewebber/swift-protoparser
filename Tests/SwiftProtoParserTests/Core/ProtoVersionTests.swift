import XCTest

@testable import SwiftProtoParser

// MARK: - ProtoVersionTests

final class ProtoVersionTests: XCTestCase {

  // MARK: - Basic Properties Tests

  func testProto3RawValue() {
    XCTAssertEqual(ProtoVersion.proto3.rawValue, "proto3")
  }

  func testProto2RawValue() {
    XCTAssertEqual(ProtoVersion.proto2.rawValue, "proto2")
  }

  func testDefaultVersion() {
    XCTAssertEqual(ProtoVersion.default, .proto2, "Default version must be proto2 per protoc behaviour")
  }

  func testSyntaxString() {
    XCTAssertEqual(ProtoVersion.proto3.syntaxString, "proto3")
    XCTAssertEqual(ProtoVersion.proto2.syntaxString, "proto2")
  }

  func testDescriptorSyntaxValue_proto3() {
    XCTAssertEqual(ProtoVersion.proto3.descriptorSyntaxValue, "proto3")
  }

  func testDescriptorSyntaxValue_proto2() {
    XCTAssertEqual(
      ProtoVersion.proto2.descriptorSyntaxValue,
      "",
      "proto2 descriptor syntax must be empty string per protoc 33.5"
    )
  }

  func testDescription() {
    XCTAssertEqual(ProtoVersion.proto3.description, "Protocol Buffers 3 (proto3)")
    XCTAssertEqual(ProtoVersion.proto2.description, "Protocol Buffers 2 (proto2)")
  }

  // MARK: - CustomStringConvertible Tests

  func testCustomStringConvertible_proto3() {
    let version = ProtoVersion.proto3
    let stringDescription = String(describing: version)
    XCTAssertEqual(stringDescription, "Protocol Buffers 3 (proto3)")
  }

  func testCustomStringConvertible_proto2() {
    let version = ProtoVersion.proto2
    let stringDescription = String(describing: version)
    XCTAssertEqual(stringDescription, "Protocol Buffers 2 (proto2)")
  }

  // MARK: - CaseIterable Tests

  func testAllCases() {
    let allCases = ProtoVersion.allCases
    XCTAssertEqual(allCases.count, 2)
    XCTAssertTrue(allCases.contains(.proto2))
    XCTAssertTrue(allCases.contains(.proto3))
  }

  // MARK: - Equatable Tests

  func testEquatable() {
    XCTAssertEqual(ProtoVersion.proto3, ProtoVersion.proto3)
    XCTAssertEqual(ProtoVersion.proto2, ProtoVersion.proto2)
    XCTAssertNotEqual(ProtoVersion.proto2, ProtoVersion.proto3)
    XCTAssertEqual(ProtoVersion.default, ProtoVersion.proto2)
  }

  // MARK: - Hashable Tests

  func testHashable() {
    let version1 = ProtoVersion.proto3
    let version2 = ProtoVersion.proto3
    let version3 = ProtoVersion.proto2

    XCTAssertEqual(version1.hashValue, version2.hashValue)
    XCTAssertNotEqual(version1.hashValue, version3.hashValue)

    let versionSet: Set<ProtoVersion> = [version1, version2, version3]
    XCTAssertEqual(versionSet.count, 2)
    XCTAssertTrue(versionSet.contains(.proto3))
    XCTAssertTrue(versionSet.contains(.proto2))
  }

  // MARK: - RawValue Initialization Tests

  func testRawValueInitialization() {
    XCTAssertEqual(ProtoVersion(rawValue: "proto3"), .proto3)
    XCTAssertEqual(ProtoVersion(rawValue: "proto2"), .proto2)
    XCTAssertNil(ProtoVersion(rawValue: "invalid"))
    XCTAssertNil(ProtoVersion(rawValue: ""))
  }

  // MARK: - Edge Cases Tests

  func testCaseInsensitiveRawValue() {
    XCTAssertNil(ProtoVersion(rawValue: "PROTO3"))
    XCTAssertNil(ProtoVersion(rawValue: "Proto3"))
    XCTAssertNil(ProtoVersion(rawValue: "PROTO2"))
    XCTAssertNil(ProtoVersion(rawValue: "Proto2"))
  }

  func testConsistentProperties_proto3() {
    let version = ProtoVersion.proto3
    XCTAssertEqual(version.rawValue, version.syntaxString)
    XCTAssertTrue(version.description.contains(version.rawValue))
  }

  func testConsistentProperties_proto2() {
    let version = ProtoVersion.proto2
    XCTAssertEqual(version.rawValue, version.syntaxString)
    XCTAssertTrue(version.description.contains(version.rawValue))
  }
}
