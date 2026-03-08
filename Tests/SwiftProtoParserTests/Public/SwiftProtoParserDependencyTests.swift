import Foundation
import XCTest

@testable import SwiftProtoParser

/// Comprehensive integration tests for DependencyResolver API in SwiftProtoParser.
///
/// These tests validate multi-file parsing, import resolution, and descriptor generation.
final class SwiftProtoParserDependencyTests: XCTestCase {

  // MARK: - Properties

  private var testResourcesPath: String {
    // Use #file to determine the test directory location
    let thisFileURL = URL(fileURLWithPath: #file)
    let projectDirectory = thisFileURL.deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    let resourcesPath = projectDirectory.appendingPathComponent("Tests/TestResources").path
    return resourcesPath
  }

  private var dependencyTestCasesPath: String {
    return testResourcesPath + "/DependencyTestCases"
  }

  private var singleProtoFilesPath: String {
    return testResourcesPath + "/SingleProtoFiles"
  }

  private var nestedDependencyTestCasesPath: String {
    return testResourcesPath + "/NestedDependencyTestCases"
  }

  // MARK: - Setup & Teardown

  override func setUp() {
    super.setUp()
    // Verify test resources exist
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: testResourcesPath),
      "TestResources directory not found at: \(testResourcesPath)"
    )
  }

  // MARK: - parseFile Tests (Public API)

  func testParseFile_SimpleFileNoImports_ReturnsSingleFileDescriptorSet() {
    let simplePath = singleProtoFilesPath + "/simple.proto"

    let result = SwiftProtoParser.parseFile(simplePath)

    switch result {
    case .success(let descriptorSet):
      XCTAssertEqual(descriptorSet.file.count, 1)
      XCTAssertEqual(descriptorSet.file[0].package, "simple")
      XCTAssertEqual(descriptorSet.file[0].messageType.count, 1)
      XCTAssertEqual(descriptorSet.file[0].messageType[0].name, "SimpleMessage")
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseFile_WithDependencies_ReturnsAllDescriptors() {
    let servicePath = dependencyTestCasesPath + "/service.proto"

    let result = SwiftProtoParser.parseFile(servicePath, importPaths: [dependencyTestCasesPath])

    switch result {
    case .success(let descriptorSet):
      // service.proto depends on user.proto which depends on base.proto → 3 total
      XCTAssertEqual(descriptorSet.file.count, 3, "Expected 3 descriptors: base, user, service")
      let packages = descriptorSet.file.map { $0.package }
      XCTAssertTrue(packages.contains("test.base"))
      XCTAssertTrue(packages.contains("test.user"))
      XCTAssertTrue(packages.contains("test.service"))
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseFile_MainFileIsLast_TopologicalOrder() {
    let servicePath = dependencyTestCasesPath + "/service.proto"

    let result = SwiftProtoParser.parseFile(servicePath, importPaths: [dependencyTestCasesPath])

    switch result {
    case .success(let descriptorSet):
      XCTAssertEqual(descriptorSet.file.last?.package, "test.service")
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseFile_MissingImportPath_ReturnsFailure() {
    let userPath = dependencyTestCasesPath + "/user.proto"

    let result = SwiftProtoParser.parseFile(userPath)

    switch result {
    case .success:
      XCTFail("Expected failure due to missing import")
    case .failure:
      break
    }
  }

  func testParseFile_FileNotFound_ReturnsFailure() {
    let result = SwiftProtoParser.parseFile("/nonexistent/file.proto")

    switch result {
    case .success:
      XCTFail("Expected failure for non-existent file")
    case .failure:
      break
    }
  }

  // MARK: - parseDirectory Tests (Public API)

  func testParseDirectory_MultipleFiles_ReturnsFileDescriptorSet() {
    let result = SwiftProtoParser.parseDirectory(dependencyTestCasesPath)

    switch result {
    case .success(let descriptorSet):
      // base.proto, user.proto, service.proto — plus their deps (which are each other)
      // after deduplication should be exactly 3 unique descriptors
      XCTAssertGreaterThanOrEqual(descriptorSet.file.count, 3)
      let packages = descriptorSet.file.map { $0.package }
      XCTAssertTrue(packages.contains("test.base"))
      XCTAssertTrue(packages.contains("test.user"))
      XCTAssertTrue(packages.contains("test.service"))
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseDirectory_SingleFile_ReturnsSingleDescriptor() {
    let result = SwiftProtoParser.parseDirectory(singleProtoFilesPath)

    switch result {
    case .success(let descriptorSet):
      XCTAssertEqual(descriptorSet.file.count, 1)
      XCTAssertEqual(descriptorSet.file[0].package, "simple")
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseDirectory_NonExistentDirectory_ReturnsFailure() {
    let result = SwiftProtoParser.parseDirectory("/nonexistent/directory")

    switch result {
    case .success:
      XCTFail("Expected failure for non-existent directory")
    case .failure:
      break
    }
  }

  // MARK: - parseFile with importPaths Tests (migrated from parseProtoFileWithImports)

  func testParseProtoFileWithImports_SimpleFile() {
    let simplePath = singleProtoFilesPath + "/simple.proto"

    let result = SwiftProtoParser.parseFile(simplePath, importPaths: [singleProtoFilesPath])

    switch result {
    case .success(let set):
      let fd = set.file.last!
      XCTAssertEqual(fd.syntax, "proto3")
      XCTAssertEqual(fd.package, "simple")
      XCTAssertEqual(fd.messageType.count, 1)
      XCTAssertEqual(fd.messageType[0].name, "SimpleMessage")
      XCTAssertEqual(fd.messageType[0].field.count, 2)
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoFileWithImports_WithDependencies() {
    let userPath = dependencyTestCasesPath + "/user.proto"

    let result = SwiftProtoParser.parseFile(userPath, importPaths: [dependencyTestCasesPath])

    switch result {
    case .success(let set):
      let fd = set.file.last { $0.package == "test.user" }!
      XCTAssertEqual(fd.syntax, "proto3")
      XCTAssertEqual(fd.package, "test.user")
      XCTAssertEqual(fd.dependency.count, 1)
      XCTAssertEqual(fd.dependency[0], "base.proto")
      XCTAssertEqual(fd.messageType.count, 2)

      let userMessage = fd.messageType.first { $0.name == "User" }
      XCTAssertNotNil(userMessage)
      XCTAssertEqual(userMessage?.field.count, 4)

      let addressMessage = fd.messageType.first { $0.name == "Address" }
      XCTAssertNotNil(addressMessage)
      XCTAssertEqual(addressMessage?.field.count, 3)

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoFileWithImports_ComplexDependencies() {
    let servicePath = dependencyTestCasesPath + "/service.proto"

    let result = SwiftProtoParser.parseFile(servicePath, importPaths: [dependencyTestCasesPath])

    switch result {
    case .success(let set):
      let fd = set.file.last { $0.package == "test.service" }!
      XCTAssertEqual(fd.syntax, "proto3")
      XCTAssertEqual(fd.package, "test.service")
      XCTAssertEqual(fd.dependency.count, 1)
      XCTAssertEqual(fd.dependency[0], "user.proto")
      XCTAssertEqual(fd.service.count, 1)
      XCTAssertEqual(fd.messageType.count, 4)

      let userService = fd.service[0]
      XCTAssertEqual(userService.name, "UserService")
      XCTAssertEqual(userService.method.count, 3)

      let getUser = userService.method.first { $0.name == "GetUser" }
      XCTAssertNotNil(getUser)
      XCTAssertEqual(getUser?.inputType, ".test.service.GetUserRequest")
      XCTAssertEqual(getUser?.outputType, ".test.service.User")

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoFileWithImports_MissingImport() {
    let userPath = dependencyTestCasesPath + "/user.proto"

    // No import paths provided — base.proto cannot be resolved; strict mode fails
    let result = SwiftProtoParser.parseFile(userPath)

    switch result {
    case .success:
      XCTFail("Expected failure due to missing import")
    case .failure(let error):
      XCTAssertTrue(error.description.contains("Dependency resolution failed") || !error.description.isEmpty)
    }
  }

  func testParseProtoFileWithImports_AllowMissingImports() {
    let userPath = dependencyTestCasesPath + "/user.proto"

    // The new public API is strict — missing imports always cause failure.
    // This test verifies the expected strict-mode behavior.
    let result = SwiftProtoParser.parseFile(userPath, importPaths: [])

    switch result {
    case .success:
      XCTFail("Expected failure: public API does not allow missing imports")
    case .failure(let error):
      XCTAssertTrue(!error.description.isEmpty)
    }
  }

  func testParseProtoFileWithImports_FileNotFound() {
    let result = SwiftProtoParser.parseFile("/nonexistent/file.proto")

    switch result {
    case .success:
      XCTFail("Expected failure for non-existent file")
    case .failure(let error):
      XCTAssertTrue(error.description.contains("I/O error") || error.description.contains("Dependency"))
    }
  }

  // MARK: - parseDirectory Tests (migrated from parseProtoDirectory)

  func testParseProtoDirectory_SingleFile() {
    let result = SwiftProtoParser.parseDirectory(singleProtoFilesPath)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file.count, 1)
      XCTAssertEqual(set.file[0].syntax, "proto3")
      XCTAssertEqual(set.file[0].package, "simple")
      XCTAssertEqual(set.file[0].messageType.count, 1)
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoDirectory_MultipleFiles() {
    let result = SwiftProtoParser.parseDirectory(dependencyTestCasesPath)

    switch result {
    case .success(let set):
      // base.proto, user.proto, service.proto — all deduplicated
      XCTAssertEqual(set.file.count, 3)

      let baseDescriptor = set.file.first { $0.package == "test.base" }
      XCTAssertNotNil(baseDescriptor)
      XCTAssertEqual(baseDescriptor?.messageType.count, 1)
      XCTAssertEqual(baseDescriptor?.enumType.count, 1)

      let userDescriptor = set.file.first { $0.package == "test.user" }
      XCTAssertNotNil(userDescriptor)
      XCTAssertEqual(userDescriptor?.messageType.count, 2)
      XCTAssertEqual(userDescriptor?.dependency.count, 1)

      let serviceDescriptor = set.file.first { $0.package == "test.service" }
      XCTAssertNotNil(serviceDescriptor)
      XCTAssertEqual(serviceDescriptor?.service.count, 1)
      XCTAssertEqual(serviceDescriptor?.messageType.count, 4)

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoDirectory_WithMissingImports() {
    // The new public API is strict — a file with unresolvable imports causes failure.
    let tempDir = NSTemporaryDirectory() + "SwiftProtoParserTest_\(UUID().uuidString)"
    try! FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tempDir) }

    let testProtoContent = """
      syntax = "proto3";
      import "nonexistent.proto";

      message TestMessage {
        string name = 1;
      }
      """

    try! testProtoContent.write(
      toFile: tempDir + "/test.proto",
      atomically: true,
      encoding: .utf8
    )

    let result = SwiftProtoParser.parseDirectory(tempDir)

    switch result {
    case .success:
      XCTFail("Expected failure: unresolvable import should cause parseDirectory to fail")
    case .failure(let error):
      XCTAssertTrue(!error.description.isEmpty)
    }
  }

  // MARK: - parseFile returning main descriptor (migrated from parseProtoFileWithImportsToDescriptors)

  func testParseProtoFileWithImportsToDescriptors_SimpleFile() {
    let simplePath = singleProtoFilesPath + "/simple.proto"

    let result = SwiftProtoParser.parseFile(simplePath, importPaths: [singleProtoFilesPath])

    switch result {
    case .success(let set):
      // Main file is last in topological order
      let fd = set.file.last { $0.package == "simple" }!
      XCTAssertEqual(fd.name, "simple.proto")
      XCTAssertEqual(fd.syntax, "proto3")
      XCTAssertEqual(fd.package, "simple")
      XCTAssertEqual(fd.messageType.count, 1)

      let simpleMessage = fd.messageType[0]
      XCTAssertEqual(simpleMessage.name, "SimpleMessage")
      XCTAssertEqual(simpleMessage.field.count, 2)
      XCTAssertEqual(simpleMessage.field[0].name, "content")
      XCTAssertEqual(simpleMessage.field[0].number, 1)
      XCTAssertEqual(simpleMessage.field[0].type, .string)
      XCTAssertEqual(simpleMessage.field[1].name, "number")
      XCTAssertEqual(simpleMessage.field[1].number, 2)
      XCTAssertEqual(simpleMessage.field[1].type, .int32)
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoFileWithImportsToDescriptors_WithDependencies() {
    let userPath = dependencyTestCasesPath + "/user.proto"

    let result = SwiftProtoParser.parseFile(userPath, importPaths: [dependencyTestCasesPath])

    switch result {
    case .success(let set):
      let fd = set.file.last { $0.package == "test.user" }!
      XCTAssertEqual(fd.name, "user.proto")
      XCTAssertEqual(fd.syntax, "proto3")
      XCTAssertEqual(fd.package, "test.user")
      XCTAssertEqual(fd.dependency.count, 1)
      XCTAssertEqual(fd.dependency[0], "base.proto")
      XCTAssertEqual(fd.messageType.count, 2)

      let userMessage = fd.messageType.first { $0.name == "User" }
      XCTAssertNotNil(userMessage)
      XCTAssertEqual(userMessage?.field.count, 4)

      let addressMessage = fd.messageType.first { $0.name == "Address" }
      XCTAssertNotNil(addressMessage)
      XCTAssertEqual(addressMessage?.field.count, 3)
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  // MARK: - parseFile returning all descriptors (migrated from parseProtoFileWithImportsToAllDescriptors)

  func testParseProtoFileWithImportsToAllDescriptors_ReturnsMainAndDependencies() {
    let servicePath = dependencyTestCasesPath + "/service.proto"

    let result = SwiftProtoParser.parseFile(servicePath, importPaths: [dependencyTestCasesPath])

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file.count, 3)
      let packages = set.file.map { $0.package }
      XCTAssertTrue(packages.contains("test.base"))
      XCTAssertTrue(packages.contains("test.user"))
      XCTAssertTrue(packages.contains("test.service"))
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoFileWithImportsToAllDescriptors_MainFileIsLast() {
    let servicePath = dependencyTestCasesPath + "/service.proto"

    let result = SwiftProtoParser.parseFile(servicePath, importPaths: [dependencyTestCasesPath])

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file.last?.package, "test.service")
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoFileWithImportsToAllDescriptors_SimpleFileNoImports_ReturnsSingleDescriptor() {
    let simplePath = singleProtoFilesPath + "/simple.proto"

    let result = SwiftProtoParser.parseFile(simplePath, importPaths: [singleProtoFilesPath])

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file.count, 1)
      XCTAssertEqual(set.file[0].package, "simple")
      XCTAssertEqual(set.file[0].messageType.count, 1)
      XCTAssertEqual(set.file[0].messageType[0].name, "SimpleMessage")
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoFileWithImportsToAllDescriptors_MissingImport_ReturnsFailure() {
    let userPath = dependencyTestCasesPath + "/user.proto"

    let result = SwiftProtoParser.parseFile(userPath)

    switch result {
    case .success:
      XCTFail("Expected failure due to missing import")
    case .failure:
      break
    }
  }

  // MARK: - parseDirectory returning all descriptors (migrated from parseProtoDirectoryToDescriptors)

  func testParseProtoDirectoryToDescriptors_MultipleFiles() {
    let result = SwiftProtoParser.parseDirectory(dependencyTestCasesPath)

    switch result {
    case .success(let set):
      XCTAssertEqual(set.file.count, 3)

      let baseDescriptor = set.file.first { $0.package == "test.base" }
      XCTAssertNotNil(baseDescriptor)
      XCTAssertEqual(baseDescriptor?.messageType.count, 1)
      XCTAssertEqual(baseDescriptor?.enumType.count, 1)

      let userDescriptor = set.file.first { $0.package == "test.user" }
      XCTAssertNotNil(userDescriptor)
      XCTAssertEqual(userDescriptor?.messageType.count, 2)
      XCTAssertEqual(userDescriptor?.dependency.count, 1)

      let serviceDescriptor = set.file.first { $0.package == "test.service" }
      XCTAssertNotNil(serviceDescriptor)
      XCTAssertEqual(serviceDescriptor?.service.count, 1)
      XCTAssertEqual(serviceDescriptor?.messageType.count, 4)
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseProtoDirectoryToDescriptors_VerifyServiceDescriptor() {
    let result = SwiftProtoParser.parseDirectory(dependencyTestCasesPath)

    switch result {
    case .success(let set):
      guard let serviceDescriptor = set.file.first(where: { $0.package == "test.service" }) else {
        XCTFail("service descriptor not found")
        return
      }

      XCTAssertEqual(serviceDescriptor.service.count, 1)
      let userService = serviceDescriptor.service[0]
      XCTAssertEqual(userService.name, "UserService")
      XCTAssertEqual(userService.method.count, 3)

      let getUserMethod = userService.method.first { $0.name == "GetUser" }
      XCTAssertNotNil(getUserMethod)
      XCTAssertEqual(getUserMethod?.inputType, ".test.service.GetUserRequest")
      XCTAssertEqual(getUserMethod?.outputType, ".test.service.User")
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  // MARK: - Error Handling Tests

  func testParseProtoFileWithImports_InvalidSyntax() {
    let tempDir = NSTemporaryDirectory()
    let tempFilePath = tempDir + "invalid_\(UUID().uuidString).proto"
    defer { try? FileManager.default.removeItem(atPath: tempFilePath) }

    try! """
    syntax = "proto3";
    message Invalid {
      string name = ;
    }
    """.write(toFile: tempFilePath, atomically: true, encoding: .utf8)

    let result = SwiftProtoParser.parseFile(tempFilePath)

    switch result {
    case .success:
      XCTFail("Expected failure for invalid syntax")
    case .failure(let error):
      XCTAssertTrue(error.description.contains("Syntax error") || error.description.contains("Unexpected"))
    }
  }

  // MARK: - Performance Tests

  func testParseProtoDirectoryPerformance() {
    measure {
      let result = SwiftProtoParser.parseDirectory(dependencyTestCasesPath)

      switch result {
      case .success(let set):
        XCTAssertEqual(set.file.count, 3)
      case .failure(let error):
        XCTFail("Performance test failed: \(error)")
      }
    }
  }

  func testParseProtoDirectoryToDescriptorsPerformance() {
    measure {
      let result = SwiftProtoParser.parseDirectory(dependencyTestCasesPath)

      switch result {
      case .success(let set):
        XCTAssertEqual(set.file.count, 3)
      case .failure(let error):
        XCTFail("Performance test failed: \(error)")
      }
    }
  }

  // MARK: - fileProto.name must be import-relative path (not bare filename)

  func testParseFile_NestedFile_NameContainsRelativePath() {
    let servicePath = nestedDependencyTestCasesPath + "/v1/service.proto"

    let result = SwiftProtoParser.parseFile(servicePath, importPaths: [nestedDependencyTestCasesPath])

    switch result {
    case .success(let set):
      let serviceDescriptor = set.file.first { $0.package == "nested.v1" }
      XCTAssertNotNil(serviceDescriptor, "Expected descriptor for package nested.v1")
      XCTAssertEqual(
        serviceDescriptor?.name,
        "v1/service.proto",
        "name must be path relative to import root, not bare filename"
      )
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseFile_NestedDependency_NameContainsRelativePath() {
    let servicePath = nestedDependencyTestCasesPath + "/v1/service.proto"

    let result = SwiftProtoParser.parseFile(servicePath, importPaths: [nestedDependencyTestCasesPath])

    switch result {
    case .success(let set):
      let baseDescriptor = set.file.first { $0.package == "nested.common" }
      XCTAssertNotNil(baseDescriptor, "Expected descriptor for package nested.common")
      XCTAssertEqual(
        baseDescriptor?.name,
        "common/base.proto",
        "dependency name must be path relative to import root, not bare filename"
      )
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseFile_DependencyFieldMatchesDescriptorName() {
    let servicePath = nestedDependencyTestCasesPath + "/v1/service.proto"

    let result = SwiftProtoParser.parseFile(servicePath, importPaths: [nestedDependencyTestCasesPath])

    switch result {
    case .success(let set):
      let serviceDescriptor = set.file.first { $0.package == "nested.v1" }
      XCTAssertNotNil(serviceDescriptor)

      guard let dep = serviceDescriptor?.dependency.first else {
        XCTFail("Expected at least one dependency in nested.v1 descriptor")
        return
      }

      let referencedDescriptor = set.file.first { $0.name == dep }
      XCTAssertNotNil(
        referencedDescriptor,
        "dependency '\(dep)' must match the name of an existing FileDescriptorProto in the set"
      )
    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  // MARK: - Multiple imports: ALL dependency entries must match fileProto.name

  func testParseFile_MultipleImports_AllDependenciesMatchDescriptorNames() {
    // multi_import.proto imports TWO files: common/base.proto and ext/extra.proto.
    // Every entry in fileProto.dependency must exactly match fileProto.name of the
    // corresponding file in the FileDescriptorSet — this is the contract that
    // protoc and SwiftProtobuf consumers depend on to link descriptors together.
    let path = nestedDependencyTestCasesPath + "/v1/multi_import.proto"

    let result = SwiftProtoParser.parseFile(path, importPaths: [nestedDependencyTestCasesPath])

    switch result {
    case .success(let set):
      let multiDescriptor = set.file.first { $0.package == "nested.v1" && $0.name.contains("multi") }
      XCTAssertNotNil(multiDescriptor, "multi_import.proto descriptor must be present")

      let deps = multiDescriptor?.dependency ?? []
      XCTAssertEqual(deps.count, 2, "multi_import.proto must declare exactly 2 dependencies")
      XCTAssertTrue(deps.contains("common/base.proto"), "dependency must include common/base.proto")
      XCTAssertTrue(deps.contains("ext/extra.proto"), "dependency must include ext/extra.proto")

      let knownNames = Set(set.file.map { $0.name })
      for dep in deps {
        XCTAssertTrue(
          knownNames.contains(dep),
          "dependency '\(dep)' must match the name of an existing FileDescriptorProto in the set"
        )
      }

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseFile_MultipleImports_AllFileNamesAreImportRelative() {
    let path = nestedDependencyTestCasesPath + "/v1/multi_import.proto"

    let result = SwiftProtoParser.parseFile(path, importPaths: [nestedDependencyTestCasesPath])

    switch result {
    case .success(let set):
      let expectedNames: Set<String> = [
        "v1/multi_import.proto",
        "common/base.proto",
        "ext/extra.proto",
      ]
      let actualNames = Set(set.file.map { $0.name })
      XCTAssertEqual(actualNames, expectedNames, "All fileProto.name values must be import-relative paths")

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  // MARK: - Cross-package enum fields resolved correctly in multi-import scenario

  func testParseFile_MultipleImports_CrossPackageEnumTypeIsEnum() {
    let path = nestedDependencyTestCasesPath + "/v1/multi_import.proto"

    let result = SwiftProtoParser.parseFile(path, importPaths: [nestedDependencyTestCasesPath])

    switch result {
    case .success(let set):
      let descriptor = set.file.first { $0.package == "nested.v1" && $0.name.contains("multi") }
      let message = descriptor?.messageType.first { $0.name == "MultiImportResponse" }
      XCTAssertNotNil(message)

      // nested.common.BaseStatus — enum from first import
      let statusField = message?.field.first { $0.name == "status" }
      XCTAssertEqual(statusField?.type, .enum, "BaseStatus field must have type = .enum")
      XCTAssertEqual(statusField?.typeName, ".nested.common.BaseStatus")

      // nested.ext.ExtraCode — enum from second import
      let codeField = message?.field.first { $0.name == "code" }
      XCTAssertEqual(codeField?.type, .enum, "ExtraCode field must have type = .enum")
      XCTAssertEqual(codeField?.typeName, ".nested.ext.ExtraCode")

      // nested.common.BaseItem — message from first import (must stay .message)
      let itemField = message?.field.first { $0.name == "item" }
      XCTAssertEqual(itemField?.type, .message, "BaseItem field must have type = .message")

      // nested.ext.ExtraMetadata — message from second import (must stay .message)
      let metadataField = message?.field.first { $0.name == "metadata" }
      XCTAssertEqual(metadataField?.type, .message, "ExtraMetadata field must have type = .message")

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }
}
