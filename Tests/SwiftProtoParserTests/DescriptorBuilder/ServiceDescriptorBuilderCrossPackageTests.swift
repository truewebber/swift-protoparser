import SwiftProtobuf
import XCTest

@testable import SwiftProtoParser

/// Tests for cross-package type name resolution in ServiceDescriptorBuilder.
///
/// A type reference containing dots (e.g. `google.protobuf.Empty`) is already
/// a qualified path into a foreign package. Only a leading dot should be prepended,
/// never the current file's package name.
final class ServiceDescriptorBuilderCrossPackageTests: XCTestCase {

  // MARK: - Local types: package must be prepended

  func test_localType_noPackage_getsLeadingDot() throws {
    let service = ServiceNode(
      name: "S",
      methods: [RPCMethodNode(name: "M", inputType: "Request", outputType: "Response")]
    )
    let proto = try ServiceDescriptorBuilder.build(from: service, packageName: nil)
    XCTAssertEqual(proto.method[0].inputType, ".Request")
    XCTAssertEqual(proto.method[0].outputType, ".Response")
  }

  func test_localType_emptyPackage_getsLeadingDot() throws {
    let service = ServiceNode(
      name: "S",
      methods: [RPCMethodNode(name: "M", inputType: "Request", outputType: "Response")]
    )
    let proto = try ServiceDescriptorBuilder.build(from: service, packageName: "")
    XCTAssertEqual(proto.method[0].inputType, ".Request")
    XCTAssertEqual(proto.method[0].outputType, ".Response")
  }

  func test_localType_simplePackage_getsPackagePrepended() throws {
    let service = ServiceNode(
      name: "S",
      methods: [RPCMethodNode(name: "M", inputType: "Request", outputType: "Response")]
    )
    let proto = try ServiceDescriptorBuilder.build(from: service, packageName: "mypackage")
    XCTAssertEqual(proto.method[0].inputType, ".mypackage.Request")
    XCTAssertEqual(proto.method[0].outputType, ".mypackage.Response")
  }

  func test_localType_deepPackage_getsPackagePrepended() throws {
    let service = ServiceNode(
      name: "S",
      methods: [RPCMethodNode(name: "M", inputType: "Request", outputType: "Response")]
    )
    let proto = try ServiceDescriptorBuilder.build(from: service, packageName: "a.b.c.d")
    XCTAssertEqual(proto.method[0].inputType, ".a.b.c.d.Request")
    XCTAssertEqual(proto.method[0].outputType, ".a.b.c.d.Response")
  }

  // MARK: - Cross-package types: only leading dot, no file package

  func test_crossPackageType_noFilePackage_getsLeadingDot() throws {
    let service = ServiceNode(
      name: "S",
      methods: [
        RPCMethodNode(name: "M", inputType: "google.protobuf.Empty", outputType: "google.protobuf.Empty")
      ]
    )
    let proto = try ServiceDescriptorBuilder.build(from: service, packageName: nil)
    XCTAssertEqual(proto.method[0].inputType, ".google.protobuf.Empty")
    XCTAssertEqual(proto.method[0].outputType, ".google.protobuf.Empty")
  }

  func test_crossPackageType_withFilePackage_filePackageNotPrepended() throws {
    let service = ServiceNode(
      name: "S",
      methods: [
        RPCMethodNode(name: "M", inputType: "google.protobuf.Empty", outputType: "google.protobuf.Empty")
      ]
    )
    let proto = try ServiceDescriptorBuilder.build(from: service, packageName: "mypackage")
    XCTAssertEqual(proto.method[0].inputType, ".google.protobuf.Empty")
    XCTAssertEqual(proto.method[0].outputType, ".google.protobuf.Empty")
  }

  func test_crossPackageType_deepFilePackage_filePackageNotPrepended() throws {
    let service = ServiceNode(
      name: "S",
      methods: [
        RPCMethodNode(name: "M", inputType: "google.protobuf.Empty", outputType: "google.protobuf.Empty")
      ]
    )
    let proto = try ServiceDescriptorBuilder.build(from: service, packageName: "mattis.dev.v1.regionspy")
    XCTAssertEqual(proto.method[0].inputType, ".google.protobuf.Empty")
    XCTAssertEqual(proto.method[0].outputType, ".google.protobuf.Empty")
  }

  func test_crossPackageType_genericPackage_filePackageNotPrepended() throws {
    let service = ServiceNode(
      name: "S",
      methods: [RPCMethodNode(name: "M", inputType: "other.pkg.SomeType", outputType: "Response")]
    )
    let proto = try ServiceDescriptorBuilder.build(from: service, packageName: "mypackage")
    XCTAssertEqual(proto.method[0].inputType, ".other.pkg.SomeType")
    XCTAssertEqual(proto.method[0].outputType, ".mypackage.Response")
  }

  func test_crossPackageType_twoComponents_filePackageNotPrepended() throws {
    let service = ServiceNode(
      name: "S",
      methods: [RPCMethodNode(name: "M", inputType: "a.b", outputType: "c.d")]
    )
    let proto = try ServiceDescriptorBuilder.build(from: service, packageName: "x.y.z")
    XCTAssertEqual(proto.method[0].inputType, ".a.b")
    XCTAssertEqual(proto.method[0].outputType, ".c.d")
  }

  // MARK: - Already fully-qualified (leading dot) — unchanged in all cases

  func test_alreadyFullyQualified_withPackage_returnedAsIs() throws {
    let service = ServiceNode(
      name: "S",
      methods: [
        RPCMethodNode(
          name: "M",
          inputType: ".google.protobuf.Empty",
          outputType: ".google.protobuf.Empty"
        )
      ]
    )
    let proto = try ServiceDescriptorBuilder.build(from: service, packageName: "mypackage")
    XCTAssertEqual(proto.method[0].inputType, ".google.protobuf.Empty")
    XCTAssertEqual(proto.method[0].outputType, ".google.protobuf.Empty")
  }

  func test_alreadyFullyQualified_noPackage_returnedAsIs() throws {
    let service = ServiceNode(
      name: "S",
      methods: [
        RPCMethodNode(name: "M", inputType: ".google.protobuf.Empty", outputType: ".Request")
      ]
    )
    let proto = try ServiceDescriptorBuilder.build(from: service, packageName: nil)
    XCTAssertEqual(proto.method[0].inputType, ".google.protobuf.Empty")
    XCTAssertEqual(proto.method[0].outputType, ".Request")
  }

  func test_alreadyFullyQualifiedSimple_withPackage_returnedAsIs() throws {
    let service = ServiceNode(
      name: "S",
      methods: [RPCMethodNode(name: "M", inputType: ".Request", outputType: ".Response")]
    )
    let proto = try ServiceDescriptorBuilder.build(from: service, packageName: "mypackage")
    XCTAssertEqual(proto.method[0].inputType, ".Request")
    XCTAssertEqual(proto.method[0].outputType, ".Response")
  }

  // MARK: - Corner: file package is a prefix of the type's package

  func test_crossPackageType_filePackageSameAsTypePackage_noDoublePrepend() throws {
    let service = ServiceNode(
      name: "S",
      methods: [
        RPCMethodNode(name: "M", inputType: "google.protobuf.Empty", outputType: "Response")
      ]
    )
    let proto = try ServiceDescriptorBuilder.build(from: service, packageName: "google.protobuf")
    XCTAssertEqual(proto.method[0].inputType, ".google.protobuf.Empty")
    XCTAssertEqual(proto.method[0].outputType, ".google.protobuf.Response")
  }

  func test_crossPackageType_sharedFirstComponent_correctlyDistinguished() throws {
    let service = ServiceNode(
      name: "S",
      methods: [RPCMethodNode(name: "M", inputType: "google.apis.Type", outputType: "Response")]
    )
    let proto = try ServiceDescriptorBuilder.build(from: service, packageName: "google.protobuf")
    XCTAssertEqual(proto.method[0].inputType, ".google.apis.Type")
    XCTAssertEqual(proto.method[0].outputType, ".google.protobuf.Response")
  }

  // MARK: - Mixed: one local, one cross-package in the same method

  func test_mixedTypes_inputLocal_outputCrossPackage() throws {
    let service = ServiceNode(
      name: "S",
      methods: [
        RPCMethodNode(name: "M", inputType: "AnalyzeURLRequest", outputType: "google.protobuf.Empty")
      ]
    )
    let proto = try ServiceDescriptorBuilder.build(from: service, packageName: "mattis.dev.v1.regionspy")
    XCTAssertEqual(proto.method[0].inputType, ".mattis.dev.v1.regionspy.AnalyzeURLRequest")
    XCTAssertEqual(proto.method[0].outputType, ".google.protobuf.Empty")
  }

  func test_mixedTypes_inputCrossPackage_outputLocal() throws {
    let service = ServiceNode(
      name: "S",
      methods: [
        RPCMethodNode(
          name: "M",
          inputType: "google.protobuf.Empty",
          outputType: "ReceiverStatusResponse"
        )
      ]
    )
    let proto = try ServiceDescriptorBuilder.build(from: service, packageName: "mattis.dev.v1.regionspy")
    XCTAssertEqual(proto.method[0].inputType, ".google.protobuf.Empty")
    XCTAssertEqual(proto.method[0].outputType, ".mattis.dev.v1.regionspy.ReceiverStatusResponse")
  }

  // MARK: - Multiple methods

  func test_multipleRpcs_mixedTypes_allResolvedCorrectly() throws {
    let service = ServiceNode(
      name: "ReceiverService",
      methods: [
        RPCMethodNode(
          name: "Status",
          inputType: "google.protobuf.Empty",
          outputType: "ReceiverStatusResponse"
        ),
        RPCMethodNode(
          name: "AnalyzeURL",
          inputType: "AnalyzeURLRequest",
          outputType: "google.protobuf.Empty"
        ),
        RPCMethodNode(
          name: "Local",
          inputType: "LocalRequest",
          outputType: "LocalResponse"
        ),
      ]
    )
    let proto = try ServiceDescriptorBuilder.build(from: service, packageName: "mattis.dev.v1.regionspy")
    XCTAssertEqual(proto.method[0].inputType, ".google.protobuf.Empty")
    XCTAssertEqual(proto.method[0].outputType, ".mattis.dev.v1.regionspy.ReceiverStatusResponse")
    XCTAssertEqual(proto.method[1].inputType, ".mattis.dev.v1.regionspy.AnalyzeURLRequest")
    XCTAssertEqual(proto.method[1].outputType, ".google.protobuf.Empty")
    XCTAssertEqual(proto.method[2].inputType, ".mattis.dev.v1.regionspy.LocalRequest")
    XCTAssertEqual(proto.method[2].outputType, ".mattis.dev.v1.regionspy.LocalResponse")
  }

  func test_streamingRpc_crossPackageTypes_resolvedCorrectly() throws {
    let service = ServiceNode(
      name: "S",
      methods: [
        RPCMethodNode(
          name: "Stream",
          inputType: "google.protobuf.Empty",
          outputType: "other.pkg.StreamResponse",
          inputStreaming: true,
          outputStreaming: true
        )
      ]
    )
    let proto = try ServiceDescriptorBuilder.build(from: service, packageName: "mypackage")
    XCTAssertEqual(proto.method[0].inputType, ".google.protobuf.Empty")
    XCTAssertEqual(proto.method[0].outputType, ".other.pkg.StreamResponse")
    XCTAssertTrue(proto.method[0].clientStreaming)
    XCTAssertTrue(proto.method[0].serverStreaming)
  }

  // MARK: - Integration via public API (parseProtoStringToDescriptors)

  func test_integration_crossPackageEmpty_input() throws {
    let proto = """
      syntax = "proto3";

      package mattis.dev.v1.regionspy;

      message ReceiverStatusResponse {
        string service_name = 1;
        bool ok = 2;
      }

      service ReceiverService {
        rpc Status(google.protobuf.Empty) returns (ReceiverStatusResponse) {}
      }
      """

    let result = SwiftProtoParser.parseProtoStringToDescriptors(proto)
    guard case .success(let fd) = result else {
      XCTFail("Parsing failed: \(result)")
      return
    }

    XCTAssertEqual(fd.service.count, 1)
    let method = fd.service[0].method[0]
    XCTAssertEqual(method.inputType, ".google.protobuf.Empty")
    XCTAssertEqual(method.outputType, ".mattis.dev.v1.regionspy.ReceiverStatusResponse")
  }

  func test_integration_crossPackageEmpty_output() throws {
    let proto = """
      syntax = "proto3";

      package mattis.dev.v1.regionspy;

      message AnalyzeURLRequest {
        string domain = 1;
        string location = 2;
      }

      service ReceiverService {
        rpc AnalyzeURL(AnalyzeURLRequest) returns (google.protobuf.Empty) {}
      }
      """

    let result = SwiftProtoParser.parseProtoStringToDescriptors(proto)
    guard case .success(let fd) = result else {
      XCTFail("Parsing failed: \(result)")
      return
    }

    let method = fd.service[0].method[0]
    XCTAssertEqual(method.inputType, ".mattis.dev.v1.regionspy.AnalyzeURLRequest")
    XCTAssertEqual(method.outputType, ".google.protobuf.Empty")
  }

  func test_integration_crossPackageEmpty_bothArgs() throws {
    let proto = """
      syntax = "proto3";

      package mattis.dev.v1.regionspy;

      service PingService {
        rpc Ping(google.protobuf.Empty) returns (google.protobuf.Empty) {}
      }
      """

    let result = SwiftProtoParser.parseProtoStringToDescriptors(proto)
    guard case .success(let fd) = result else {
      XCTFail("Parsing failed: \(result)")
      return
    }

    let method = fd.service[0].method[0]
    XCTAssertEqual(method.inputType, ".google.protobuf.Empty")
    XCTAssertEqual(method.outputType, ".google.protobuf.Empty")
  }

  func test_integration_noFilePackage_crossPackageType() throws {
    let proto = """
      syntax = "proto3";

      service PingService {
        rpc Ping(google.protobuf.Empty) returns (google.protobuf.Empty) {}
      }
      """

    let result = SwiftProtoParser.parseProtoStringToDescriptors(proto)
    guard case .success(let fd) = result else {
      XCTFail("Parsing failed: \(result)")
      return
    }

    let method = fd.service[0].method[0]
    XCTAssertEqual(method.inputType, ".google.protobuf.Empty")
    XCTAssertEqual(method.outputType, ".google.protobuf.Empty")
  }

  func test_integration_fullExampleFromIssue() throws {
    let proto = """
      syntax = "proto3";

      package mattis.dev.v1.regionspy;

      message ReceiverStatusResponse {
        string service_name = 1;
        bool ok = 2;
      }

      message AnalyzeURLRequest {
        string domain = 1;
        string location = 2;
      }

      service ReceiverService {
        rpc Status(google.protobuf.Empty) returns (ReceiverStatusResponse) {}
        rpc AnalyzeURL(AnalyzeURLRequest) returns (google.protobuf.Empty) {}
      }
      """

    let result = SwiftProtoParser.parseProtoStringToDescriptors(proto)
    guard case .success(let fd) = result else {
      XCTFail("Parsing failed: \(result)")
      return
    }

    let service = fd.service[0]
    XCTAssertEqual(service.method.count, 2)

    let status = service.method[0]
    XCTAssertEqual(status.name, "Status")
    XCTAssertEqual(status.inputType, ".google.protobuf.Empty")
    XCTAssertEqual(status.outputType, ".mattis.dev.v1.regionspy.ReceiverStatusResponse")

    let analyze = service.method[1]
    XCTAssertEqual(analyze.name, "AnalyzeURL")
    XCTAssertEqual(analyze.inputType, ".mattis.dev.v1.regionspy.AnalyzeURLRequest")
    XCTAssertEqual(analyze.outputType, ".google.protobuf.Empty")
  }

  func test_integration_multipleServices_mixedTypes() throws {
    let proto = """
      syntax = "proto3";

      package example.v1;

      message Req {}
      message Resp {}

      service ServiceA {
        rpc Call(Req) returns (Resp) {}
      }

      service ServiceB {
        rpc Call(google.protobuf.Empty) returns (Resp) {}
      }
      """

    let result = SwiftProtoParser.parseProtoStringToDescriptors(proto)
    guard case .success(let fd) = result else {
      XCTFail("Parsing failed: \(result)")
      return
    }

    XCTAssertEqual(fd.service.count, 2)
    XCTAssertEqual(fd.service[0].method[0].inputType, ".example.v1.Req")
    XCTAssertEqual(fd.service[0].method[0].outputType, ".example.v1.Resp")
    XCTAssertEqual(fd.service[1].method[0].inputType, ".google.protobuf.Empty")
    XCTAssertEqual(fd.service[1].method[0].outputType, ".example.v1.Resp")
  }

  // MARK: - Negative: local types must not be treated as cross-package

  func test_localType_withDotInPackageNotInType_packageCorrectlyApplied() throws {
    let service = ServiceNode(
      name: "S",
      methods: [RPCMethodNode(name: "M", inputType: "Request", outputType: "Response")]
    )
    let proto = try ServiceDescriptorBuilder.build(from: service, packageName: "google.protobuf")
    XCTAssertEqual(proto.method[0].inputType, ".google.protobuf.Request")
    XCTAssertEqual(proto.method[0].outputType, ".google.protobuf.Response")
  }
}
