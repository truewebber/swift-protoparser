import Foundation
import XCTest

@testable import SwiftProtoParser

/// Integration tests for cross-package type reference handling in FileDescriptorSet.
///
/// Tests how typeName fields are populated for message and enum fields that reference
/// types defined in other packages (imported files).
final class CrossPackageTypeResolutionTests: XCTestCase {

  // MARK: - Properties

  private var nestedDependencyTestCasesPath: String {
    let thisFileURL = URL(fileURLWithPath: #file)
    let projectDirectory =
      thisFileURL
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    return
      projectDirectory
      .appendingPathComponent("Tests/TestResources/NestedDependencyTestCases")
      .path
  }

  // MARK: - Positive: qualified cross-package message type

  func testParseFile_QualifiedCrossPackageMessageField_TypeNameIsCorrect() {
    let servicePath = nestedDependencyTestCasesPath + "/v1/service.proto"

    let result = SwiftProtoParser.parseFile(servicePath, importPaths: [nestedDependencyTestCasesPath])

    switch result {
    case .success(let set):
      let serviceDescriptor = set.file.first { $0.package == "nested.v1" }
      XCTAssertNotNil(serviceDescriptor)

      let responseMessage = serviceDescriptor?.messageType.first { $0.name == "GetItemResponse" }
      XCTAssertNotNil(responseMessage, "GetItemResponse message must exist")

      let itemField = responseMessage?.field.first { $0.name == "item" }
      XCTAssertNotNil(itemField, "item field must exist")
      XCTAssertEqual(itemField?.type, .message)
      XCTAssertEqual(
        itemField?.typeName,
        ".nested.common.BaseItem",
        "cross-package message type must resolve to .nested.common.BaseItem, not .nested.v1.BaseItem"
      )

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  // MARK: - Positive: qualified cross-package enum type — known limitation

  func testParseFile_QualifiedCrossPackageEnumField_TypeNameIsCorrect() {
    let servicePath = nestedDependencyTestCasesPath + "/v1/service.proto"

    let result = SwiftProtoParser.parseFile(servicePath, importPaths: [nestedDependencyTestCasesPath])

    switch result {
    case .success(let set):
      let serviceDescriptor = set.file.first { $0.package == "nested.v1" }
      let responseMessage = serviceDescriptor?.messageType.first { $0.name == "GetItemResponse" }
      let statusField = responseMessage?.field.first { $0.name == "status" }

      XCTAssertNotNil(statusField, "status field must exist")
      XCTAssertEqual(
        statusField?.typeName,
        ".nested.common.BaseStatus",
        "cross-package enum type must resolve to .nested.common.BaseStatus"
      )
      // NOTE: This is a known limitation — cross-file enums used via qualifiedType are stored
      // as .message because EnumFieldTypeResolver only scans the current file's AST.
      // A future fix would require passing the full FileDescriptorSet to the resolver.
      XCTAssertEqual(
        statusField?.type,
        .enum,
        "cross-package enum field must have type = .enum"
      )

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  // MARK: - Positive: local type (same package) gets package prefix

  func testParseFile_LocalMessageField_TypeNameHasCurrentPackage() {
    let servicePath = nestedDependencyTestCasesPath + "/v1/service.proto"

    let result = SwiftProtoParser.parseFile(servicePath, importPaths: [nestedDependencyTestCasesPath])

    switch result {
    case .success(let set):
      let serviceDescriptor = set.file.first { $0.package == "nested.v1" }
      let requestMessage = serviceDescriptor?.messageType.first { $0.name == "GetItemRequest" }
      XCTAssertNotNil(requestMessage, "GetItemRequest must exist")

      // GetItemRequest has only primitive fields — verify no typeName on primitive
      let itemIdField = requestMessage?.field.first { $0.name == "item_id" }
      XCTAssertNotNil(itemIdField)
      XCTAssertEqual(itemIdField?.type, .string)
      XCTAssertFalse(itemIdField?.hasTypeName ?? true, "primitive field must not have typeName")

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseFile_ServiceRPC_InputOutputTypesHaveCurrentPackage() {
    let servicePath = nestedDependencyTestCasesPath + "/v1/service.proto"

    let result = SwiftProtoParser.parseFile(servicePath, importPaths: [nestedDependencyTestCasesPath])

    switch result {
    case .success(let set):
      let serviceDescriptor = set.file.first { $0.package == "nested.v1" }
      let service = serviceDescriptor?.service.first { $0.name == "ItemService" }
      XCTAssertNotNil(service)

      let getItemMethod = service?.method.first { $0.name == "GetItem" }
      XCTAssertNotNil(getItemMethod)
      XCTAssertEqual(
        getItemMethod?.inputType,
        ".nested.v1.GetItemRequest",
        "RPC input type from same package must be prefixed with current package"
      )
      XCTAssertEqual(
        getItemMethod?.outputType,
        ".nested.v1.GetItemResponse",
        "RPC output type from same package must be prefixed with current package"
      )

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  // MARK: - Negative: unqualified cross-package type reference (sibling package)

  func testParseFile_UnqualifiedCrossPackageSiblingType_ReturnsSemanticError() {
    // BaseItem is defined in nested.common, not in nested.v1.
    // nested.v1 and nested.common are sibling packages — scope walking for
    // "BaseItem" in "nested.v1" tries .nested.v1.BaseItem, .nested.BaseItem,
    // .BaseItem — none of which exist.
    // protoc rejects this file; we must return a semantic error too.
    let servicePath = nestedDependencyTestCasesPath + "/v1/service_unqualified.proto"

    let result = SwiftProtoParser.parseFile(servicePath, importPaths: [nestedDependencyTestCasesPath])

    switch result {
    case .success:
      XCTFail("Expected semantic error for unqualified cross-package sibling type reference")
    case .failure(let error):
      guard case .semanticError(let message, _) = error else {
        XCTFail("Expected .semanticError, got: \(error)")
        return
      }
      XCTAssertTrue(
        message.contains("nested.v1.BaseItem") || message.contains("nested.v1.BaseStatus"),
        "Error message should name the unresolvable type, got: \(message)"
      )
    }
  }

  // MARK: - Positive: unqualified reference resolved via scope walking (sub-package)

  func testParseFile_UnqualifiedTypeInSubPackage_ResolvesViaParentPackageScopeWalking() {
    // nested.common.child is a sub-package of nested.common.
    // Scope walking for "BaseItem" in "nested.common.child" finds
    // .nested.common.BaseItem at the parent scope level.
    let childPath = nestedDependencyTestCasesPath + "/common_child/service.proto"

    let result = SwiftProtoParser.parseFile(childPath, importPaths: [nestedDependencyTestCasesPath])

    switch result {
    case .success(let set):
      let descriptor = set.file.first { $0.package == "nested.common.child" }
      XCTAssertNotNil(descriptor, "nested.common.child descriptor must be present")

      let requestMessage = descriptor?.messageType.first { $0.name == "ChildRequest" }
      XCTAssertNotNil(requestMessage, "ChildRequest must exist")

      let itemField = requestMessage?.field.first { $0.name == "item" }
      XCTAssertNotNil(itemField, "item field must exist")
      XCTAssertEqual(
        itemField?.typeName,
        ".nested.common.BaseItem",
        "unqualified BaseItem in sub-package must resolve to .nested.common.BaseItem"
      )
      XCTAssertEqual(itemField?.type, .message)

      let statusField = requestMessage?.field.first { $0.name == "status" }
      XCTAssertNotNil(statusField, "status field must exist")
      XCTAssertEqual(
        statusField?.typeName,
        ".nested.common.BaseStatus",
        "unqualified BaseStatus in sub-package must resolve to .nested.common.BaseStatus"
      )
      XCTAssertEqual(statusField?.type, .enum)

    case .failure(let error):
      XCTFail("Expected success for sub-package scope walking, got error: \(error)")
    }
  }

  // MARK: - Map value: cross-package enum

  func testParseFile_MapValue_CrossPackageEnum_ValueFieldTypeIsEnum() {
    let path = nestedDependencyTestCasesPath + "/v1/comprehensive.proto"

    let result = SwiftProtoParser.parseFile(path, importPaths: [nestedDependencyTestCasesPath])

    switch result {
    case .success(let set):
      let descriptor = set.file.first { $0.package == "nested.v1" }
      let message = descriptor?.messageType.first { $0.name == "ComprehensiveResponse" }
      XCTAssertNotNil(message)

      // Map field is represented as a synthetic nested entry message
      let entryMessage = message?.nestedType.first { $0.options.mapEntry }
      XCTAssertNotNil(entryMessage, "Map entry message must exist")

      let valueField = entryMessage?.field.first { $0.name == "value" }
      XCTAssertNotNil(valueField, "Map entry value field must exist")
      XCTAssertEqual(valueField?.typeName, ".nested.common.BaseStatus")
      XCTAssertEqual(
        valueField?.type,
        .enum,
        "cross-package enum as map value must have type = .enum"
      )

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  // MARK: - Oneof: cross-package enum field

  func testParseFile_OneofField_CrossPackageEnum_TypeIsEnum() {
    let path = nestedDependencyTestCasesPath + "/v1/comprehensive.proto"

    let result = SwiftProtoParser.parseFile(path, importPaths: [nestedDependencyTestCasesPath])

    switch result {
    case .success(let set):
      let descriptor = set.file.first { $0.package == "nested.v1" }
      let message = descriptor?.messageType.first { $0.name == "ComprehensiveResponse" }
      XCTAssertNotNil(message)

      let failureStatusField = message?.field.first { $0.name == "failure_status" }
      XCTAssertNotNil(failureStatusField, "failure_status oneof field must exist")
      XCTAssertEqual(failureStatusField?.typeName, ".nested.common.BaseStatus")
      XCTAssertEqual(
        failureStatusField?.type,
        .enum,
        "cross-package enum in oneof must have type = .enum"
      )

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseFile_OneofField_CrossPackageMessage_TypeIsMessage() {
    let path = nestedDependencyTestCasesPath + "/v1/comprehensive.proto"

    let result = SwiftProtoParser.parseFile(path, importPaths: [nestedDependencyTestCasesPath])

    switch result {
    case .success(let set):
      let descriptor = set.file.first { $0.package == "nested.v1" }
      let message = descriptor?.messageType.first { $0.name == "ComprehensiveResponse" }

      let successItemField = message?.field.first { $0.name == "success_item" }
      XCTAssertNotNil(successItemField, "success_item oneof field must exist")
      XCTAssertEqual(successItemField?.typeName, ".nested.common.BaseItem")
      XCTAssertEqual(
        successItemField?.type,
        .message,
        "cross-package message in oneof must stay type = .message"
      )

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  // MARK: - Nested message: cross-package enum field

  func testParseFile_NestedMessage_CrossPackageEnum_TypeIsEnum() {
    let path = nestedDependencyTestCasesPath + "/v1/comprehensive.proto"

    let result = SwiftProtoParser.parseFile(path, importPaths: [nestedDependencyTestCasesPath])

    switch result {
    case .success(let set):
      let descriptor = set.file.first { $0.package == "nested.v1" }
      let outerMessage = descriptor?.messageType.first { $0.name == "ComprehensiveResponse" }
      XCTAssertNotNil(outerMessage)

      let nestedMessage = outerMessage?.nestedType.first { $0.name == "Nested" }
      XCTAssertNotNil(nestedMessage, "Nested message must exist")

      let nestedStatusField = nestedMessage?.field.first { $0.name == "nested_status" }
      XCTAssertNotNil(nestedStatusField, "nested_status field must exist")
      XCTAssertEqual(nestedStatusField?.typeName, ".nested.common.BaseStatus")
      XCTAssertEqual(
        nestedStatusField?.type,
        .enum,
        "cross-package enum in nested message must have type = .enum"
      )

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  func testParseFile_NestedMessage_CrossPackageMessage_TypeIsMessage() {
    let path = nestedDependencyTestCasesPath + "/v1/comprehensive.proto"

    let result = SwiftProtoParser.parseFile(path, importPaths: [nestedDependencyTestCasesPath])

    switch result {
    case .success(let set):
      let descriptor = set.file.first { $0.package == "nested.v1" }
      let outerMessage = descriptor?.messageType.first { $0.name == "ComprehensiveResponse" }
      let nestedMessage = outerMessage?.nestedType.first { $0.name == "Nested" }

      let nestedItemField = nestedMessage?.field.first { $0.name == "nested_item" }
      XCTAssertNotNil(nestedItemField, "nested_item field must exist")
      XCTAssertEqual(nestedItemField?.typeName, ".nested.common.BaseItem")
      XCTAssertEqual(
        nestedItemField?.type,
        .message,
        "cross-package message in nested message must stay type = .message"
      )

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  // MARK: - Corner case: same type name in different packages

  func testParseFile_SameTypeNameInDifferentPackages_QualifiedResolvesCorrectly() {
    // v1/service.proto uses nested.common.BaseItem (qualified) — must resolve to nested.common
    // even if nested.v1 had a type named BaseItem too (it doesn't, but the rule holds).
    let servicePath = nestedDependencyTestCasesPath + "/v1/service.proto"

    let result = SwiftProtoParser.parseFile(servicePath, importPaths: [nestedDependencyTestCasesPath])

    switch result {
    case .success(let set):
      let serviceDescriptor = set.file.first { $0.package == "nested.v1" }
      let responseMessage = serviceDescriptor?.messageType.first { $0.name == "GetItemResponse" }
      let itemField = responseMessage?.field.first { $0.name == "item" }

      XCTAssertEqual(itemField?.typeName, ".nested.common.BaseItem")
      XCTAssertNotEqual(
        itemField?.typeName,
        ".nested.v1.BaseItem",
        "qualified type must never resolve to the current file's package"
      )

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }

  // MARK: - Corner case: primitive fields have no typeName

  func testParseFile_PrimitiveFields_NoTypeName() {
    let basePath = nestedDependencyTestCasesPath + "/common/base.proto"

    let result = SwiftProtoParser.parseFile(basePath, importPaths: [nestedDependencyTestCasesPath])

    switch result {
    case .success(let set):
      let baseDescriptor = set.file.first { $0.package == "nested.common" }
      let baseItemMessage = baseDescriptor?.messageType.first { $0.name == "BaseItem" }
      XCTAssertNotNil(baseItemMessage)

      for field in baseItemMessage?.field ?? [] {
        XCTAssertFalse(
          field.hasTypeName,
          "primitive field '\(field.name)' must not have typeName"
        )
      }

    case .failure(let error):
      XCTFail("Expected success, got error: \(error)")
    }
  }
}
