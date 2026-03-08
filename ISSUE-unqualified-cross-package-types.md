# Issue: Unqualified cross-package type references produce wrong typeName

## Context

SwiftProtoParser builds a `Google_Protobuf_FileDescriptorSet` from one or more `.proto` files.
Each file is parsed independently: the parser only sees the AST of the current file.
When a field references a type by its short (unqualified) name and that type is defined in a
different package (imported file), the parser has no way to know which package the type belongs
to. It falls back to prefixing the current file's own package — producing an incorrect
`typeName` in the resulting `FieldDescriptorProto`.

Qualified references (e.g. `nested.common.BaseStatus`) work correctly because the package
prefix is already present in the source.

**Affected pipeline stage:** `FieldDescriptorBuilder.buildFullyQualifiedTypeName` —
called per-field during single-file descriptor building, before cross-file context is available.

**Not affected:** same-package types, qualified cross-package types, primitive types,
`EnumTypePostProcessor` (it only corrects `.message → .enum` for already-correct qualified names).

---

## Observed behavior

Given two files sharing the same import root:

```
// common/base.proto
syntax = "proto3";
package nested.common;

message BaseItem   { string id = 1; }
enum   BaseStatus  { STATUS_UNKNOWN = 0; STATUS_ACTIVE = 1; }
```

```
// v1/service.proto
syntax = "proto3";
import "common/base.proto";
package nested.v1;

message GetItemResponse {
  BaseItem   item   = 1;   // unqualified — missing "nested.common."
  BaseStatus status = 2;   // unqualified — missing "nested.common."
}
```

Parsing `v1/service.proto` with import root set to the parent directory produces:

```
FieldDescriptorProto { name: "item",   type: MESSAGE, type_name: ".nested.v1.BaseItem"   }
FieldDescriptorProto { name: "status", type: MESSAGE, type_name: ".nested.v1.BaseStatus" }
```

Both `typeName` values are wrong (package `nested.v1` instead of `nested.common`).
`status` additionally has `type = MESSAGE` instead of `type = ENUM`.

The `FileDescriptorSet` is structurally invalid: `.nested.v1.BaseItem` and
`.nested.v1.BaseStatus` do not exist in any file in the set, so consumers (protoc plugins,
SwiftProtobuf reflection, gRPC code generators) cannot resolve the references.

---

## Expected behavior

```
FieldDescriptorProto { name: "item",   type: MESSAGE, type_name: ".nested.common.BaseItem"   }
FieldDescriptorProto { name: "status", type: ENUM,    type_name: ".nested.common.BaseStatus" }
```

This matches the output of `protoc --descriptor_set_out` for the same input.

---

## How to reproduce

```swift
import SwiftProtoParser

let importRoot = "/path/to/TestResources/NestedDependencyTestCases"
let result = SwiftProtoParser.parseFile(
    importRoot + "/v1/service_unqualified.proto",
    importPaths: [importRoot]
)

if case .success(let set) = result {
    let descriptor = set.file.first { $0.package == "nested.v1" }!
    let message    = descriptor.messageType.first { $0.name == "GetItemResponse" }!

    let itemField   = message.field.first { $0.name == "item" }!
    let statusField = message.field.first { $0.name == "status" }!

    print(itemField.typeName)   // prints ".nested.v1.BaseItem"   — wrong, expected ".nested.common.BaseItem"
    print(statusField.typeName) // prints ".nested.v1.BaseStatus" — wrong, expected ".nested.common.BaseStatus"
    print(statusField.type)     // prints .message               — wrong, expected .enum
}
```

The test fixture `Tests/TestResources/NestedDependencyTestCases/v1/service_unqualified.proto`
and the test `testParseFile_UnqualifiedCrossPackageType_TypeNameHasWrongPackage` in
`Tests/SwiftProtoParserTests/Public/CrossPackageTypeResolutionTests.swift` document and
assert this behavior.

---

## Root cause

The parser processes each file in isolation. `FieldDescriptorBuilder` receives only the
current file's package name — it has no access to the type registries of imported files.
When it encounters an unqualified identifier (`BaseItem`) it unconditionally prepends the
current package (`nested.v1`), producing `.nested.v1.BaseItem`.

Fixing this requires a **cross-file semantic resolution pass**: after all files in the
dependency graph are parsed, unresolved short names must be looked up in the type registries
of transitively imported files (depth-first, following proto3 scoping rules). This is
analogous to what `EnumTypePostProcessor` does for enum-vs-message disambiguation, but
more complex because it also needs to rewrite the `typeName` itself, not just the `type` field.

A natural implementation point would be a second post-processor applied in
`SwiftProtoParser.buildDescriptorSet` after `EnumTypePostProcessor`, operating on the
assembled `FileDescriptorSet` and its full dependency graph.
