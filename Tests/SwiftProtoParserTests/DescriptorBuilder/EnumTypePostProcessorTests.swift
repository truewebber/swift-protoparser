import SwiftProtobuf
import XCTest

@testable import SwiftProtoParser

final class EnumTypePostProcessorTests: XCTestCase {

  // MARK: - Helpers

  private func makeSet(files: [Google_Protobuf_FileDescriptorProto]) -> Google_Protobuf_FileDescriptorSet {
    var set = Google_Protobuf_FileDescriptorSet()
    set.file = files
    return set
  }

  private func makeFile(
    name: String,
    package: String,
    topLevelEnums: [String] = [],
    messages: [Google_Protobuf_DescriptorProto] = []
  ) -> Google_Protobuf_FileDescriptorProto {
    var file = Google_Protobuf_FileDescriptorProto()
    file.name = name
    file.package = package
    file.enumType = topLevelEnums.map { enumName in
      var e = Google_Protobuf_EnumDescriptorProto()
      e.name = enumName
      var v = Google_Protobuf_EnumValueDescriptorProto()
      v.name = "\(enumName.uppercased())_UNSPECIFIED"
      v.number = 0
      e.value = [v]
      return e
    }
    file.messageType = messages
    return file
  }

  private func makeField(
    name: String,
    number: Int32,
    type: Google_Protobuf_FieldDescriptorProto.TypeEnum,
    typeName: String = ""
  ) -> Google_Protobuf_FieldDescriptorProto {
    var field = Google_Protobuf_FieldDescriptorProto()
    field.name = name
    field.number = number
    field.type = type
    field.typeName = typeName
    field.label = .optional
    return field
  }

  private func makeMessage(
    name: String,
    fields: [Google_Protobuf_FieldDescriptorProto] = [],
    nested: [Google_Protobuf_DescriptorProto] = [],
    nestedEnums: [String] = []
  ) -> Google_Protobuf_DescriptorProto {
    var msg = Google_Protobuf_DescriptorProto()
    msg.name = name
    msg.field = fields
    msg.nestedType = nested
    msg.enumType = nestedEnums.map { enumName in
      var e = Google_Protobuf_EnumDescriptorProto()
      e.name = enumName
      var v = Google_Protobuf_EnumValueDescriptorProto()
      v.name = "\(enumName.uppercased())_UNSPECIFIED"
      v.number = 0
      e.value = [v]
      return e
    }
    return msg
  }

  // MARK: - No-op cases

  func testProcess_EmptySet_ReturnsEmptySet() {
    let result = EnumTypePostProcessor.process(makeSet(files: []))
    XCTAssertTrue(result.file.isEmpty)
  }

  func testProcess_FieldWithScalarType_Unchanged() {
    let field = makeField(name: "count", number: 1, type: .int32)
    let msg = makeMessage(name: "Msg", fields: [field])
    let file = makeFile(name: "a.proto", package: "pkg", messages: [msg])
    let result = EnumTypePostProcessor.process(makeSet(files: [file]))
    XCTAssertEqual(result.file[0].messageType[0].field[0].type, .int32)
  }

  func testProcess_MessageField_NoMatchingEnum_Unchanged() {
    let field = makeField(name: "item", number: 1, type: .message, typeName: ".pkg.SomeMessage")
    let msg = makeMessage(name: "Msg", fields: [field])
    let file = makeFile(name: "a.proto", package: "pkg", messages: [msg])
    let result = EnumTypePostProcessor.process(makeSet(files: [file]))
    XCTAssertEqual(result.file[0].messageType[0].field[0].type, .message)
  }

  // MARK: - Correction: top-level enum in same file

  func testProcess_SameFileTopLevelEnum_CorrectedToEnum() {
    let field = makeField(name: "status", number: 1, type: .message, typeName: ".pkg.Status")
    let msg = makeMessage(name: "Msg", fields: [field])
    let file = makeFile(name: "a.proto", package: "pkg", topLevelEnums: ["Status"], messages: [msg])
    let result = EnumTypePostProcessor.process(makeSet(files: [file]))
    XCTAssertEqual(result.file[0].messageType[0].field[0].type, .enum)
  }

  // MARK: - Correction: cross-file enum

  func testProcess_CrossFileEnum_CorrectedToEnum() {
    // common.proto defines BaseStatus enum
    let commonFile = makeFile(name: "common/base.proto", package: "nested.common", topLevelEnums: ["BaseStatus"])

    // service.proto has a field referencing it as .message (raw builder output)
    let statusField = makeField(
      name: "status",
      number: 1,
      type: .message,
      typeName: ".nested.common.BaseStatus"
    )
    let msg = makeMessage(name: "Response", fields: [statusField])
    let serviceFile = makeFile(name: "v1/service.proto", package: "nested.v1", messages: [msg])

    let result = EnumTypePostProcessor.process(makeSet(files: [commonFile, serviceFile]))

    let field = result.file[1].messageType[0].field[0]
    XCTAssertEqual(field.type, .enum)
    XCTAssertEqual(field.typeName, ".nested.common.BaseStatus")
  }

  func testProcess_CrossFileMessage_StaysMessage() {
    let commonFile = makeFile(name: "common/base.proto", package: "nested.common")
    // BaseItem is a message, NOT an enum
    let itemField = makeField(
      name: "item",
      number: 1,
      type: .message,
      typeName: ".nested.common.BaseItem"
    )
    let msg = makeMessage(name: "Response", fields: [itemField])
    let serviceFile = makeFile(name: "v1/service.proto", package: "nested.v1", messages: [msg])

    let result = EnumTypePostProcessor.process(makeSet(files: [commonFile, serviceFile]))

    XCTAssertEqual(result.file[1].messageType[0].field[0].type, .message)
  }

  // MARK: - Nested message fields

  func testProcess_NestedMessageField_CrossFileEnum_Corrected() {
    let commonFile = makeFile(name: "common/base.proto", package: "pkg.common", topLevelEnums: ["Status"])

    let innerField = makeField(name: "status", number: 1, type: .message, typeName: ".pkg.common.Status")
    let nested = makeMessage(name: "Inner", fields: [innerField])
    let outer = makeMessage(name: "Outer", nested: [nested])
    let serviceFile = makeFile(name: "svc.proto", package: "pkg.v1", messages: [outer])

    let result = EnumTypePostProcessor.process(makeSet(files: [commonFile, serviceFile]))

    let correctedField = result.file[1].messageType[0].nestedType[0].field[0]
    XCTAssertEqual(correctedField.type, .enum)
  }

  // MARK: - Map entry value field

  func testProcess_MapEntryValueField_CrossFileEnum_Corrected() {
    let commonFile = makeFile(name: "common/base.proto", package: "pkg.common", topLevelEnums: ["Status"])

    // Simulate synthetic map-entry message (mapEntry = true)
    var entryOptions = Google_Protobuf_MessageOptions()
    entryOptions.mapEntry = true
    let valueField = makeField(name: "value", number: 2, type: .message, typeName: ".pkg.common.Status")
    var entryMsg = makeMessage(name: "StatusMapEntry", fields: [valueField])
    entryMsg.options = entryOptions

    let outerMsg = makeMessage(name: "Request", nested: [entryMsg])
    let serviceFile = makeFile(name: "svc.proto", package: "pkg.v1", messages: [outerMsg])

    let result = EnumTypePostProcessor.process(makeSet(files: [commonFile, serviceFile]))

    let correctedEntry = result.file[1].messageType[0].nestedType[0]
    XCTAssertEqual(correctedEntry.field[0].type, .enum)
  }

  // MARK: - Nested enum in message

  func testProcess_NestedEnumInMessage_CrossFileRef_Corrected() {
    // Enum defined as nested type inside a message in another file
    var innerEnum = Google_Protobuf_EnumDescriptorProto()
    innerEnum.name = "Code"
    var v = Google_Protobuf_EnumValueDescriptorProto()
    v.name = "CODE_UNSPECIFIED"
    v.number = 0
    innerEnum.value = [v]

    var parentMsg = makeMessage(name: "Error")
    parentMsg.enumType = [innerEnum]
    let commonFile = makeFile(name: "common.proto", package: "com.pkg", messages: [parentMsg])

    // Field referencing the nested enum as .message
    let field = makeField(name: "code", number: 1, type: .message, typeName: ".com.pkg.Error.Code")
    let msg = makeMessage(name: "Response", fields: [field])
    let serviceFile = makeFile(name: "svc.proto", package: "com.v1", messages: [msg])

    let result = EnumTypePostProcessor.process(makeSet(files: [commonFile, serviceFile]))

    XCTAssertEqual(result.file[1].messageType[0].field[0].type, .enum)
  }

  // MARK: - typeName without leading dot

  func testProcess_TypeNameWithoutLeadingDot_Corrected() {
    // Some builders may emit typeName without a leading "."; the post-processor normalises it.
    let commonFile = makeFile(name: "common.proto", package: "pkg", topLevelEnums: ["Status"])

    let field = makeField(name: "status", number: 1, type: .message, typeName: "pkg.Status")
    let msg = makeMessage(name: "Msg", fields: [field])
    let svcFile = makeFile(name: "svc.proto", package: "pkg", messages: [msg])

    let result = EnumTypePostProcessor.process(makeSet(files: [commonFile, svcFile]))

    XCTAssertEqual(result.file[1].messageType[0].field[0].type, .enum)
  }

  // MARK: - Already-correct .enum field is not touched

  func testProcess_AlreadyEnumField_Unchanged() {
    let field = makeField(name: "status", number: 1, type: .enum, typeName: ".pkg.Status")
    let msg = makeMessage(name: "Msg", fields: [field])
    let file = makeFile(name: "a.proto", package: "pkg", topLevelEnums: ["Status"], messages: [msg])
    let result = EnumTypePostProcessor.process(makeSet(files: [file]))
    XCTAssertEqual(result.file[0].messageType[0].field[0].type, .enum)
  }
}
