import SwiftProtobuf
import XCTest

@testable import SwiftProtoParser

/// Unit tests for `UnresolvedTypeValidator`.
///
/// All tests build `FileDescriptorSet` values in-memory without touching the
/// file system, allowing fast and deterministic coverage of the scope-walking
/// and error-reporting logic.
final class UnresolvedTypeValidatorTests: XCTestCase {

  // MARK: - Helpers

  /// Builds a minimal `FileDescriptorProto` with a single message and a single field.
  private func makeFile(
    name: String,
    package: String,
    messageName: String,
    fieldName: String,
    typeName: String,
    fieldType: Google_Protobuf_FieldDescriptorProto.TypeEnum = .message,
    dependencies: [String] = []
  ) -> Google_Protobuf_FileDescriptorProto {
    var field = Google_Protobuf_FieldDescriptorProto()
    field.name = fieldName
    field.number = 1
    field.label = .optional
    field.type = fieldType
    field.typeName = typeName

    var message = Google_Protobuf_DescriptorProto()
    message.name = messageName
    message.field = [field]

    var file = Google_Protobuf_FileDescriptorProto()
    file.name = name
    file.package = package
    file.syntax = "proto3"
    file.dependency = dependencies
    file.messageType = [message]
    return file
  }

  /// Builds a minimal `FileDescriptorProto` defining only messages and enums (no fields).
  private func makeDefinitionFile(
    name: String,
    package: String,
    messageNames: [String] = [],
    enumNames: [String] = []
  ) -> Google_Protobuf_FileDescriptorProto {
    var file = Google_Protobuf_FileDescriptorProto()
    file.name = name
    file.package = package
    file.syntax = "proto3"
    file.messageType = messageNames.map { n in
      var m = Google_Protobuf_DescriptorProto()
      m.name = n
      return m
    }
    file.enumType = enumNames.map { n in
      var e = Google_Protobuf_EnumDescriptorProto()
      e.name = n
      var v = Google_Protobuf_EnumValueDescriptorProto()
      v.name = "UNKNOWN"
      v.number = 0
      e.value = [v]
      return e
    }
    return file
  }

  private func makeSet(_ files: Google_Protobuf_FileDescriptorProto...)
    -> Google_Protobuf_FileDescriptorSet
  {
    var set = Google_Protobuf_FileDescriptorSet()
    set.file = files
    return set
  }

  // MARK: - Registry: types in set are found

  func test_typeExistsInSameFile_noChange() {
    // add Item message to the same file
    var defFile = makeDefinitionFile(name: "a.proto", package: "pkg", messageNames: ["Req", "Item"])
    // reuse file with both messages
    var itemField = Google_Protobuf_FieldDescriptorProto()
    itemField.name = "item"
    itemField.number = 1
    itemField.label = .optional
    itemField.type = .message
    itemField.typeName = ".pkg.Item"

    var reqMsg = Google_Protobuf_DescriptorProto()
    reqMsg.name = "Req"
    reqMsg.field = [itemField]

    var itemMsg = Google_Protobuf_DescriptorProto()
    itemMsg.name = "Item"

    defFile.messageType = [reqMsg, itemMsg]

    let set = makeSet(defFile)
    let result = UnresolvedTypeValidator.validate(set)

    guard case .success(let validated) = result else {
      XCTFail("Expected success, got: \(result)")
      return
    }
    let field = validated.file[0].messageType[0].field[0]
    XCTAssertEqual(field.typeName, ".pkg.Item")
    XCTAssertEqual(field.type, .message)
  }

  // MARK: - Scope walking: sub-package finds type in parent package

  func test_subPackage_unqualifiedRef_resolvesViaParentScope() {
    // File with package "a.b.c" references "Item" which only exists in "a.b"
    let defFile = makeDefinitionFile(name: "base.proto", package: "a.b", messageNames: ["Item"])
    let usingFile = makeFile(
      name: "using.proto",
      package: "a.b.c",
      messageName: "Req",
      fieldName: "item",
      typeName: ".a.b.c.Item",  // wrong — FieldDescriptorBuilder prepended current package
      dependencies: ["base.proto"]
    )
    let set = makeSet(defFile, usingFile)
    let result = UnresolvedTypeValidator.validate(set)

    guard case .success(let validated) = result else {
      XCTFail("Expected success via scope walking, got: \(result)")
      return
    }
    let field = validated.file[1].messageType[0].field[0]
    XCTAssertEqual(field.typeName, ".a.b.Item", "scope walking must find .a.b.Item")
    XCTAssertEqual(field.type, .message)
  }

  func test_subPackage_unqualifiedEnumRef_resolvesViaParentScope() {
    let defFile = makeDefinitionFile(name: "base.proto", package: "a.b", enumNames: ["Status"])
    let usingFile = makeFile(
      name: "using.proto",
      package: "a.b.c",
      messageName: "Req",
      fieldName: "status",
      typeName: ".a.b.c.Status",
      fieldType: .message,  // conservative initial value
      dependencies: ["base.proto"]
    )
    let set = makeSet(defFile, usingFile)
    let result = UnresolvedTypeValidator.validate(set)

    guard case .success(let validated) = result else {
      XCTFail("Expected success via scope walking, got: \(result)")
      return
    }
    let field = validated.file[1].messageType[0].field[0]
    XCTAssertEqual(field.typeName, ".a.b.Status")
    XCTAssertEqual(field.type, .enum, "kind must be corrected to .enum when found in registry")
  }

  func test_deepSubPackage_resolvesAtCorrectAncestorLevel() {
    // Package "x.y.z.w", type "Foo" exists in "x.y"
    let defFile = makeDefinitionFile(name: "base.proto", package: "x.y", messageNames: ["Foo"])
    let usingFile = makeFile(
      name: "using.proto",
      package: "x.y.z.w",
      messageName: "Req",
      fieldName: "foo",
      typeName: ".x.y.z.w.Foo",
      dependencies: ["base.proto"]
    )
    let set = makeSet(defFile, usingFile)
    let result = UnresolvedTypeValidator.validate(set)

    guard case .success(let validated) = result else {
      XCTFail("Expected success, got: \(result)")
      return
    }
    XCTAssertEqual(validated.file[1].messageType[0].field[0].typeName, ".x.y.Foo")
  }

  // MARK: - Root scope resolution

  func test_rootScopeType_resolvesCorrectly() {
    // Type exists at root scope (no package)
    let defFile = makeDefinitionFile(name: "base.proto", package: "", messageNames: ["GlobalMsg"])
    let usingFile = makeFile(
      name: "using.proto",
      package: "my.pkg",
      messageName: "Req",
      fieldName: "g",
      typeName: ".my.pkg.GlobalMsg",
      dependencies: ["base.proto"]
    )
    let set = makeSet(defFile, usingFile)
    let result = UnresolvedTypeValidator.validate(set)

    guard case .success(let validated) = result else {
      XCTFail("Expected success, got: \(result)")
      return
    }
    XCTAssertEqual(validated.file[1].messageType[0].field[0].typeName, ".GlobalMsg")
  }

  // MARK: - Error: sibling package cannot be resolved

  func test_siblingPackage_unqualifiedRef_returnsSemanticError() {
    // "a.b" and "a.c" are siblings — scope walking for "Item" in "a.b" never
    // visits "a.c".
    let defFile = makeDefinitionFile(name: "base.proto", package: "a.c", messageNames: ["Item"])
    let usingFile = makeFile(
      name: "using.proto",
      package: "a.b",
      messageName: "Req",
      fieldName: "item",
      typeName: ".a.b.Item",
      dependencies: ["base.proto"]
    )
    let set = makeSet(defFile, usingFile)
    let result = UnresolvedTypeValidator.validate(set)

    guard case .failure(let error) = result else {
      XCTFail("Expected .failure, got success")
      return
    }
    guard case .semanticError(let message, let context) = error else {
      XCTFail("Expected .semanticError, got: \(error)")
      return
    }
    XCTAssertTrue(message.contains(".a.b.Item"), "error must name the unresolvable type")
    XCTAssertTrue(context.contains("using.proto"), "error context must name the file")
  }

  func test_completelyUnrelatedPackage_returnsSemanticError() {
    let defFile = makeDefinitionFile(name: "other.proto", package: "x.y.z", messageNames: ["Thing"])
    let usingFile = makeFile(
      name: "using.proto",
      package: "a.b.c",
      messageName: "Req",
      fieldName: "t",
      typeName: ".a.b.c.Thing",
      dependencies: ["other.proto"]
    )
    let set = makeSet(defFile, usingFile)
    let result = UnresolvedTypeValidator.validate(set)
    XCTAssertTrue(
      {
        if case .failure(.semanticError) = result { return true }
        return false
      }(),
      "Expected .failure(.semanticError)"
    )
  }

  // MARK: - Primitive fields are not validated

  func test_primitiveField_noTypeName_notValidated() {
    var field = Google_Protobuf_FieldDescriptorProto()
    field.name = "id"
    field.number = 1
    field.label = .optional
    field.type = .string
    // typeName is empty — not set

    var message = Google_Protobuf_DescriptorProto()
    message.name = "Req"
    message.field = [field]

    var file = Google_Protobuf_FileDescriptorProto()
    file.name = "a.proto"
    file.package = "pkg"
    file.messageType = [message]

    let set = makeSet(file)
    let result = UnresolvedTypeValidator.validate(set)
    guard case .success = result else {
      XCTFail("Primitive field must not trigger validation: \(result)")
      return
    }
  }

  // MARK: - Synthetic map-entry references are not validated

  func test_mapEntryReference_noLeadingDot_notValidated() {
    // Synthetic map field has typeName without leading dot (e.g. "MetadataEntry")
    var field = Google_Protobuf_FieldDescriptorProto()
    field.name = "metadata"
    field.number = 1
    field.label = .repeated
    field.type = .message
    field.typeName = "MetadataEntry"  // no leading dot — synthetic reference

    var message = Google_Protobuf_DescriptorProto()
    message.name = "Req"
    message.field = [field]

    var file = Google_Protobuf_FileDescriptorProto()
    file.name = "a.proto"
    file.package = "pkg"
    file.messageType = [message]

    let set = makeSet(file)
    let result = UnresolvedTypeValidator.validate(set)
    guard case .success = result else {
      XCTFail("Map-entry synthetic reference must not trigger validation: \(result)")
      return
    }
  }

  // MARK: - Message scope: nested type referenced by unqualified name

  func test_nestedType_unqualifiedRef_resolvesViaMsgScope() {
    // Outer.inner references Inner (nested in Outer) by unqualified name.
    // FieldDescriptorBuilder produces typeName ".pkg.Inner" (file package only).
    // Scope walking with message scope ".pkg.Outer" finds ".pkg.Outer.Inner".
    var innerMsg = Google_Protobuf_DescriptorProto()
    innerMsg.name = "Inner"

    var innerField = Google_Protobuf_FieldDescriptorProto()
    innerField.name = "inner"
    innerField.number = 1
    innerField.label = .optional
    innerField.type = .message
    innerField.typeName = ".pkg.Inner"  // wrong — FieldDescriptorBuilder prefix

    var outerMsg = Google_Protobuf_DescriptorProto()
    outerMsg.name = "Outer"
    outerMsg.field = [innerField]
    outerMsg.nestedType = [innerMsg]

    var file = Google_Protobuf_FileDescriptorProto()
    file.name = "a.proto"
    file.package = "pkg"
    file.messageType = [outerMsg]

    let set = makeSet(file)
    let result = UnresolvedTypeValidator.validate(set)
    guard case .success(let validated) = result else {
      XCTFail("Expected success via message-scope walking, got: \(result)")
      return
    }
    XCTAssertEqual(validated.file[0].messageType[0].field[0].typeName, ".pkg.Outer.Inner")
  }

  func test_nestedType_noPackage_resolvesViaMsgScope() {
    // Same case with no file package (typeName = ".Inner", not ".pkg.Inner")
    var innerMsg = Google_Protobuf_DescriptorProto()
    innerMsg.name = "Inner"

    var innerField = Google_Protobuf_FieldDescriptorProto()
    innerField.name = "inner"
    innerField.number = 1
    innerField.label = .optional
    innerField.type = .message
    innerField.typeName = ".Inner"

    var outerMsg = Google_Protobuf_DescriptorProto()
    outerMsg.name = "Outer"
    outerMsg.field = [innerField]
    outerMsg.nestedType = [innerMsg]

    var file = Google_Protobuf_FileDescriptorProto()
    file.name = "a.proto"
    file.package = ""
    file.messageType = [outerMsg]

    let set = makeSet(file)
    let result = UnresolvedTypeValidator.validate(set)
    guard case .success(let validated) = result else {
      XCTFail("Expected success, got: \(result)")
      return
    }
    XCTAssertEqual(validated.file[0].messageType[0].field[0].typeName, ".Outer.Inner")
  }

  // MARK: - Nested messages are validated recursively

  func test_nestedMessageField_unresolvable_returnsSemanticError() {
    var nestedField = Google_Protobuf_FieldDescriptorProto()
    nestedField.name = "item"
    nestedField.number = 1
    nestedField.label = .optional
    nestedField.type = .message
    nestedField.typeName = ".pkg.Missing"

    var nestedMsg = Google_Protobuf_DescriptorProto()
    nestedMsg.name = "Inner"
    nestedMsg.field = [nestedField]

    var outerMsg = Google_Protobuf_DescriptorProto()
    outerMsg.name = "Outer"
    outerMsg.nestedType = [nestedMsg]

    var file = Google_Protobuf_FileDescriptorProto()
    file.name = "a.proto"
    file.package = "pkg"
    file.messageType = [outerMsg]

    let set = makeSet(file)
    let result = UnresolvedTypeValidator.validate(set)
    guard case .failure(.semanticError(let message, _)) = result else {
      XCTFail("Expected .failure(.semanticError), got: \(result)")
      return
    }
    XCTAssertTrue(message.contains(".pkg.Missing"))
  }

  // MARK: - Service method types are validated

  func test_serviceInputType_unresolvable_returnsSemanticError() {
    var method = Google_Protobuf_MethodDescriptorProto()
    method.name = "DoThing"
    method.inputType = ".pkg.MissingRequest"
    method.outputType = ".pkg.MissingResponse"

    var service = Google_Protobuf_ServiceDescriptorProto()
    service.name = "MyService"
    service.method = [method]

    var file = Google_Protobuf_FileDescriptorProto()
    file.name = "a.proto"
    file.package = "pkg"
    file.service = [service]

    let set = makeSet(file)
    let result = UnresolvedTypeValidator.validate(set)
    guard case .failure(.semanticError(let message, let context)) = result else {
      XCTFail("Expected .failure(.semanticError), got: \(result)")
      return
    }
    XCTAssertTrue(message.contains(".pkg.MissingRequest") || message.contains(".pkg.MissingResponse"))
    XCTAssertTrue(context.contains("MyService"))
  }

  func test_serviceInputType_resolvableViaParentScope_rewritten() {
    let defFile = makeDefinitionFile(name: "base.proto", package: "a.b", messageNames: ["Req", "Resp"])

    var method = Google_Protobuf_MethodDescriptorProto()
    method.name = "Call"
    method.inputType = ".a.b.c.Req"  // wrong — unqualified in sub-package
    method.outputType = ".a.b.c.Resp"  // wrong — unqualified in sub-package

    var service = Google_Protobuf_ServiceDescriptorProto()
    service.name = "Svc"
    service.method = [method]

    var usingFile = Google_Protobuf_FileDescriptorProto()
    usingFile.name = "using.proto"
    usingFile.package = "a.b.c"
    usingFile.service = [service]
    usingFile.dependency = ["base.proto"]

    let set = makeSet(defFile, usingFile)
    let result = UnresolvedTypeValidator.validate(set)

    guard case .success(let validated) = result else {
      XCTFail("Expected success, got: \(result)")
      return
    }
    let m = validated.file[1].service[0].method[0]
    XCTAssertEqual(m.inputType, ".a.b.Req")
    XCTAssertEqual(m.outputType, ".a.b.Resp")
  }

  // MARK: - Empty set is accepted

  func test_emptySet_succeeds() {
    var set = Google_Protobuf_FileDescriptorSet()
    set.file = []
    let result = UnresolvedTypeValidator.validate(set)
    guard case .success = result else {
      XCTFail("Empty set must succeed: \(result)")
      return
    }
  }

  // MARK: - Qualified cross-package type already in registry

  func test_qualifiedCrossPackageType_inRegistry_notModified() {
    let defFile = makeDefinitionFile(name: "base.proto", package: "other", messageNames: ["Ext"])
    let usingFile = makeFile(
      name: "using.proto",
      package: "my.pkg",
      messageName: "Req",
      fieldName: "ext",
      typeName: ".other.Ext",  // qualified, correct
      dependencies: ["base.proto"]
    )
    let set = makeSet(defFile, usingFile)
    let result = UnresolvedTypeValidator.validate(set)

    guard case .success(let validated) = result else {
      XCTFail("Expected success, got: \(result)")
      return
    }
    XCTAssertEqual(validated.file[1].messageType[0].field[0].typeName, ".other.Ext")
  }

  // MARK: - Sibling nested-message scope resolution

  /// Regression test: a field whose type is a sibling nested message
  /// (defined in the same parent, but not in the same nested message) must be
  /// resolved via the parent message scope.
  ///
  /// Proto structure:
  /// ```
  /// package pkg;
  /// message Outer {
  ///   message Top { }        // sibling
  ///   message Inner {
  ///     Top item = 1;        // references sibling, not self-nested
  ///   }
  /// }
  /// ```
  /// The descriptor builder initially sets `typeName` to
  /// `.pkg.Outer.Inner.Top` (which does not exist).  The validator must
  /// walk up to `.pkg.Outer.Top` and resolve it there.
  func test_siblingNestedMessageScope_resolvesToParentScope() {
    // Build the `Top` nested message (empty)
    var topMsg = Google_Protobuf_DescriptorProto()
    topMsg.name = "Top"

    // Build a field inside `Inner` referencing `Top`.
    // `FieldDescriptorBuilder.buildFullyQualifiedTypeName` prepends only the package prefix,
    // so the initial typeName is ".pkg.Top" — which does NOT exist; the actual type is
    // ".pkg.Outer.Top" (a sibling of Inner inside Outer).
    var field = Google_Protobuf_FieldDescriptorProto()
    field.name = "item"
    field.number = 1
    field.label = .optional
    field.type = .message
    field.typeName = ".pkg.Top"  // package-prefixed; must be resolved to sibling scope

    var innerMsg = Google_Protobuf_DescriptorProto()
    innerMsg.name = "Inner"
    innerMsg.field = [field]

    var outerMsg = Google_Protobuf_DescriptorProto()
    outerMsg.name = "Outer"
    outerMsg.nestedType = [topMsg, innerMsg]

    var file = Google_Protobuf_FileDescriptorProto()
    file.name = "test.proto"
    file.package = "pkg"
    file.syntax = "proto3"
    file.messageType = [outerMsg]

    var set = Google_Protobuf_FileDescriptorSet()
    set.file = [file]

    let result = UnresolvedTypeValidator.validate(set)
    guard case .success(let validated) = result else {
      XCTFail("Expected success, got: \(result)")
      return
    }

    let resolvedField = validated.file[0].messageType[0].nestedType[1].field[0]
    XCTAssertEqual(resolvedField.typeName, ".pkg.Outer.Top",
      "Must resolve to sibling scope, not fail with undefined type")
  }

  // MARK: - 3-level nesting: grandparent message scope

  /// `A.B.C` references a type `D` that lives at `A.D` — two message levels up.
  func test_grandparentMessageScope_resolvesToTwoLevelsUp() {
    var dMsg = Google_Protobuf_DescriptorProto()
    dMsg.name = "D"

    var field = Google_Protobuf_FieldDescriptorProto()
    field.name = "d"
    field.number = 1
    field.label = .optional
    field.type = .message
    field.typeName = ".pkg.D"  // builder prefix; real type is .pkg.A.D

    var cMsg = Google_Protobuf_DescriptorProto()
    cMsg.name = "C"
    cMsg.field = [field]

    var bMsg = Google_Protobuf_DescriptorProto()
    bMsg.name = "B"
    bMsg.nestedType = [cMsg]

    var aMsg = Google_Protobuf_DescriptorProto()
    aMsg.name = "A"
    aMsg.nestedType = [dMsg, bMsg]  // D is sibling of B inside A

    var file = Google_Protobuf_FileDescriptorProto()
    file.name = "test.proto"
    file.package = "pkg"
    file.messageType = [aMsg]

    var set = Google_Protobuf_FileDescriptorSet()
    set.file = [file]

    let result = UnresolvedTypeValidator.validate(set)
    guard case .success(let validated) = result else {
      XCTFail("Expected success for grandparent scope, got: \(result)")
      return
    }

    let resolvedField = validated.file[0].messageType[0]  // A
      .nestedType[1]  // B
      .nestedType[0]  // C
      .field[0]
    XCTAssertEqual(resolvedField.typeName, ".pkg.A.D",
      "Must resolve to grandparent scope .pkg.A.D")
  }

  // MARK: - Enum nested in parent, referenced from sibling message

  func test_enumNestedInParent_referencedFromSiblingMessage_resolved() {
    var statusEnum = Google_Protobuf_EnumDescriptorProto()
    statusEnum.name = "Status"
    var enumVal = Google_Protobuf_EnumValueDescriptorProto()
    enumVal.name = "UNKNOWN"
    enumVal.number = 0
    statusEnum.value = [enumVal]

    var field = Google_Protobuf_FieldDescriptorProto()
    field.name = "status"
    field.number = 1
    field.label = .optional
    field.type = .enum
    field.typeName = ".pkg.Status"  // builder prefix; real type is .pkg.Outer.Status

    var innerMsg = Google_Protobuf_DescriptorProto()
    innerMsg.name = "Inner"
    innerMsg.field = [field]

    var outerMsg = Google_Protobuf_DescriptorProto()
    outerMsg.name = "Outer"
    outerMsg.enumType = [statusEnum]
    outerMsg.nestedType = [innerMsg]

    var file = Google_Protobuf_FileDescriptorProto()
    file.name = "test.proto"
    file.package = "pkg"
    file.messageType = [outerMsg]

    var set = Google_Protobuf_FileDescriptorSet()
    set.file = [file]

    let result = UnresolvedTypeValidator.validate(set)
    guard case .success(let validated) = result else {
      XCTFail("Expected success for parent-scope enum, got: \(result)")
      return
    }

    let resolvedField = validated.file[0].messageType[0].nestedType[0].field[0]
    XCTAssertEqual(resolvedField.typeName, ".pkg.Outer.Status")
    XCTAssertEqual(resolvedField.type, .enum)
  }

  // MARK: - Cross-file qualified reference to nested type

  /// From a different file, `Outer.Top` is referenced by the qualified name `Outer.Top`.
  /// `FieldDescriptorBuilder` produces `.Outer.Top` (no package prefix for qualified names).
  /// The validator must resolve this to `.pkg.Outer.Top` via scope-walking.
  func test_crossFile_qualifiedNestedTypeRef_resolved() {
    // File A defines Outer.Top
    var topMsg = Google_Protobuf_DescriptorProto()
    topMsg.name = "Top"

    var outerMsg = Google_Protobuf_DescriptorProto()
    outerMsg.name = "Outer"
    outerMsg.nestedType = [topMsg]

    var defFile = Google_Protobuf_FileDescriptorProto()
    defFile.name = "base.proto"
    defFile.package = "pkg"
    defFile.messageType = [outerMsg]

    // File B uses the qualified source name "Outer.Top".
    // FieldDescriptorBuilder.qualifiedType case → typeName = ".Outer.Top" (no package prefix).
    var field = Google_Protobuf_FieldDescriptorProto()
    field.name = "top"
    field.number = 1
    field.label = .optional
    field.type = .message
    field.typeName = ".Outer.Top"  // qualified ref: no package prefix

    var wrapper = Google_Protobuf_DescriptorProto()
    wrapper.name = "Wrapper"
    wrapper.field = [field]

    var usingFile = Google_Protobuf_FileDescriptorProto()
    usingFile.name = "using.proto"
    usingFile.package = "pkg"
    usingFile.messageType = [wrapper]
    usingFile.dependency = ["base.proto"]

    var set = Google_Protobuf_FileDescriptorSet()
    set.file = [defFile, usingFile]

    let result = UnresolvedTypeValidator.validate(set)
    guard case .success(let validated) = result else {
      XCTFail("Expected success for cross-file qualified reference, got: \(result)")
      return
    }

    XCTAssertEqual(validated.file[1].messageType[0].field[0].typeName, ".pkg.Outer.Top")
  }

  // MARK: - End-to-end: proto string with sibling nested type

  /// Full pipeline test (parse → build → validate) mirrors the real-world failure:
  /// `TopList.top3` references sibling `Top` inside the same parent message.
  func test_endToEnd_siblingNestedTypeInProtoString_parsesSuccessfully() {
    let proto = """
      syntax = "proto3";
      package semrush.pt;

      message Response {
        message Top {
          int32 count = 1;
        }
        message TopList {
          Top top3   = 1;
          Top top10  = 2;
          Top top100 = 3;
        }
        TopList data = 1;
      }
      """

    // Parse → AST
    guard case .success(let ast) = ProtoParsingPipeline.parse(content: proto, fileName: "test.proto")
    else {
      XCTFail("Parsing failed")
      return
    }

    // AST → FileDescriptorProto
    guard
      let descriptor = try? DescriptorBuilder.buildFileDescriptor(from: ast, fileName: "test.proto")
    else {
      XCTFail("Descriptor building failed")
      return
    }

    // FileDescriptorProto → FileDescriptorSet → validate
    var set = Google_Protobuf_FileDescriptorSet()
    set.file = [descriptor]

    guard case .success(let validated) = UnresolvedTypeValidator.validate(set) else {
      XCTFail("Validation failed")
      return
    }

    let file = validated.file[0]
    let response = file.messageType.first { $0.name == "Response" }
    XCTAssertNotNil(response, "Response message must exist")

    let topList = response?.nestedType.first { $0.name == "TopList" }
    XCTAssertNotNil(topList, "TopList must exist")

    let top3Field = topList?.field.first { $0.name == "top3" }
    XCTAssertNotNil(top3Field, "top3 field must exist")
    XCTAssertEqual(
      top3Field?.typeName,
      ".semrush.pt.Response.Top",
      "top3 must resolve to sibling scope .semrush.pt.Response.Top"
    )
  }

  // MARK: - type field is corrected when kind changes

  func test_existingTypeWithWrongKind_kindIsCorrected() {
    // Field type is conservatively .message but the registry says .enum
    let defFile = makeDefinitionFile(name: "base.proto", package: "pkg", enumNames: ["Status"])
    let usingFile = makeFile(
      name: "using.proto",
      package: "pkg",
      messageName: "Req",
      fieldName: "status",
      typeName: ".pkg.Status",
      fieldType: .message,  // wrong kind — should become .enum
      dependencies: ["base.proto"]
    )
    let set = makeSet(defFile, usingFile)
    let result = UnresolvedTypeValidator.validate(set)

    guard case .success(let validated) = result else {
      XCTFail("Expected success, got: \(result)")
      return
    }
    XCTAssertEqual(validated.file[1].messageType[0].field[0].type, .enum)
  }
}
