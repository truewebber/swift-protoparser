import XCTest

@testable import SwiftProtoParser

// MARK: - ProtoVersionTests

final class ProtoVersionTests: XCTestCase {

  // MARK: - Basic Properties Tests

  func testProto3RawValue() {
    XCTAssertEqual(ProtoVersion.proto3.rawValue, "proto3")
  }

  func testDefaultVersion() {
    XCTAssertEqual(ProtoVersion.default, .proto3)
  }

  func testSyntaxString() {
    XCTAssertEqual(ProtoVersion.proto3.syntaxString, "proto3")
  }

  func testDescription() {
    XCTAssertEqual(ProtoVersion.proto3.description, "Protocol Buffers 3 (proto3)")
  }

  // MARK: - CustomStringConvertible Tests

  func testCustomStringConvertible() {
    let version = ProtoVersion.proto3
    let stringDescription = String(describing: version)
    XCTAssertEqual(stringDescription, "Protocol Buffers 3 (proto3)")
  }

  // MARK: - CaseIterable Tests

  func testAllCases() {
    let allCases = ProtoVersion.allCases
    XCTAssertEqual(allCases.count, 1)
    XCTAssertEqual(allCases.first, .proto3)
    XCTAssertTrue(allCases.contains(.proto3))
  }

  // MARK: - Equatable Tests

  func testEquatable() {
    XCTAssertEqual(ProtoVersion.proto3, ProtoVersion.proto3)
    XCTAssertEqual(ProtoVersion.default, ProtoVersion.proto3)
  }

  // MARK: - Hashable Tests

  func testHashable() {
    let version1 = ProtoVersion.proto3
    let version2 = ProtoVersion.proto3
    let version3 = ProtoVersion.default

    XCTAssertEqual(version1.hashValue, version2.hashValue)
    XCTAssertEqual(version1.hashValue, version3.hashValue)

    // Test that it can be used in Set
    let versionSet: Set<ProtoVersion> = [version1, version2, version3]
    XCTAssertEqual(versionSet.count, 1)
    XCTAssertTrue(versionSet.contains(.proto3))
  }

  // MARK: - RawValue Initialization Tests

  func testRawValueInitialization() {
    XCTAssertEqual(ProtoVersion(rawValue: "proto3"), .proto3)
    XCTAssertNil(ProtoVersion(rawValue: "proto2"))
    XCTAssertNil(ProtoVersion(rawValue: "invalid"))
    XCTAssertNil(ProtoVersion(rawValue: ""))
  }

  // MARK: - Edge Cases Tests

  func testCaseInsensitiveRawValue() {
    // Should be case-sensitive as per protobuf specification
    XCTAssertNil(ProtoVersion(rawValue: "PROTO3"))
    XCTAssertNil(ProtoVersion(rawValue: "Proto3"))
    XCTAssertNil(ProtoVersion(rawValue: "PROTO3"))
  }

  func testConsistentProperties() {
    let version = ProtoVersion.proto3
    XCTAssertEqual(version.rawValue, version.syntaxString)
    XCTAssertTrue(version.description.contains(version.rawValue))
  }
}
