# Technical Architecture: Proto2 Support

**Companion to:** `docs/EPIC_PROTO2.md`  
**Status:** Approved for implementation  
**Verified against:** `protoc libprotoc 33.5`

---

## 1. Guiding Principle

> One parser. Version-aware validation. Zero code duplication.

Proto2 and proto3 share ~95% of their grammar. Splitting them into two parser classes
would duplicate thousands of lines and create a permanent maintenance burden where bugs
get fixed in one branch but silently remain in the other. The correct approach is a single
unified `Parser` class that carries a `protoVersion` flag and applies version-specific rules
at the six grammar points where they actually differ.

This matches how `protoc` itself works internally.

---

## 2. What Is NOT Changing

| Component | Reason |
|---|---|
| `Lexer` | Already tokenises all proto2 keywords (`required`, `extensions`, `group`). Version is a grammar concern, not a lexer concern. |
| `DependencyResolver` | Already does regex-based header extraction (syntax, imports) before full parsing. Correct and sufficient. |
| `ResolvedProtoFile` | Header-only extraction for dependency graph. No parse involved. |
| `UnresolvedTypeValidator` | Type resolution logic is version-agnostic. |
| `ProtoParsingPipeline` | Orchestration is unchanged; it routes into the same Parser. |
| Module boundaries | No new modules. No new public API surface. |

---

## 3. What Is Changing

### 3.1 `Core/ProtoVersion.swift` — extend the enum

**Current:**
```swift
enum ProtoVersion: String, CaseIterable, Sendable {
    case proto3 = "proto3"
}
```

**After:**
```swift
enum ProtoVersion: String, CaseIterable, Sendable {
    case proto2 = "proto2"
    case proto3 = "proto3"

    /// Files with no `syntax` declaration are treated as proto2 per protoc behaviour.
    static let `default`: ProtoVersion = .proto2
}
```

---

### 3.2 `Parser/ParserState` — add version slot

`ParserState` is the single mutable object that flows through all parsing methods.
Adding `protoVersion` here makes the version available everywhere without changing
any method signatures.

```swift
struct ParserState {
    var tokens: [Token]
    var position: Int
    var errors: [ParserError]
    var protoVersion: ProtoVersion = .proto2   // ← NEW; default = proto2 (no-syntax rule)
}
```

The version is set once, as early as possible, by `parseSyntaxDeclaration()`.

---

### 3.3 `Parser/Parser.swift` — six change points

#### Change point 0 — `parseSyntaxDeclaration()` — write version into state

Currently returns `ProtoVersion` to a local variable in `parseProtoFile()` which is then
stored in `ProtoAST` but never propagated back to `state`. Fix: write it into `state` immediately.

```swift
private func parseSyntaxDeclaration() {
    // ... existing token consumption ...
    let version: ProtoVersion
    switch syntaxString {
    case "proto3": version = .proto3
    case "proto2": version = .proto2
    default:
        // Unknown syntax value → hard error, matching protoc exactly.
        // protoc 33.5 verified: exits 1, no descriptor produced.
        state.addError(.unrecognizedSyntax(syntaxString))
        // No further parsing makes sense; abort.
        return
    }
    state.protoVersion = version   // ← propagate to state immediately
}

// If syntax keyword is missing entirely, state.protoVersion stays at .proto2 (the default)
// — no error, no warning (protoc 33.5 verified)
```

**Unknown syntax is a hard error.** Exact protoc message (verified):

```
Unrecognized syntax identifier "X".  This parser only recognizes "proto2" and "proto3".
```

Note the two spaces before "This" — match exactly.

#### Change point 1 — `parseFieldDeclaration()` — `required` label

```swift
// Before: .required falls through to default → parse error
// After:
case .required:
    guard state.protoVersion == .proto2 else {
        state.addError(.requiredNotAllowedInProto3(...))
        // consume the field anyway so parsing can continue
        break
    }
    let field = try parseFieldDeclaration(label: .required)
    fields.append(field)

// In proto2, field label is mandatory for non-oneof fields:
case .identifier, .keyword where isTypeKeyword(token):
    guard state.protoVersion != .proto2 else {
        state.addError(.missingFieldLabel(...)) // "Expected required, optional, or repeated."
        break
    }
    // proto3 implicit-singular field (existing behaviour)
```

#### Change point 2 — `parseMessageDeclaration()` — `extensions` ranges

```swift
case .extensions:
    guard state.protoVersion == .proto2 else {
        state.addError(.extensionsNotAllowedInProto3(...))
        state.skipToNextSemicolon()
        break
    }
    let ranges = try parseExtensionRanges()
    extensionRanges.append(contentsOf: ranges)
```

`parseExtensionRanges()` parses `N`, `N to M`, `N to max` (where `max` → stored as `536870912`,
exclusive end per protoc behaviour).

**Multiple ranges on one line** — proto2 allows `extensions 100 to 199, 300 to 399, 500 to max;`
(comma-separated list in a single `extensions` statement). This is legal syntax and is used
in `descriptor.proto` itself. Produces multiple `ExtensionRange` entries in the descriptor.
*(protoc 33.5 verified: `extensions 100 to 199, 300 to 399, 500 to max;` → three entries:
`{100,200}`, `{300,400}`, `{500,536870912}` — all ends exclusive)*

**`reserved` keyword in proto2** — fully supported; `reserved 2, 15, 9 to 11;` and
`reserved "foo", "bar";` produce `reservedRange` / `reservedName` in `DescriptorProto`,
identical to proto3. *(protoc 33.5 verified: exit 0)*

#### Change point 3 — `parseMessageDeclaration()` — `group` fields

```swift
// Detected as: label token + .group keyword
case .group where previousTokenWasFieldLabel:
    guard state.protoVersion == .proto2 else {
        state.addError(.groupsNotSupportedInProto3(...))
        state.skipToClosingBrace()
        break
    }
    let groupField = try parseGroupField(label: currentLabel)
    fields.append(groupField.field)
    nestedMessages.append(groupField.syntheticMessage)
```

#### Change point 4 — `parseFieldOptions()` — `[default = value]`

```swift
if optionName == "default" {
    guard state.protoVersion == .proto2 else {
        state.addError(.explicitDefaultNotAllowedInProto3(...))
        break
    }
    // Store in FieldNode.defaultValue (new field), not in options array
    return FieldDefaultValue(from: optionValue)
}
```

**`defaultValue` encoding rules (all protoc 33.5 verified):**

| Field type | Source | Stored `defaultValue` string |
|---|---|---|
| `int32/int64/uint32/uint64/sint32/sint64/fixed32/fixed64/sfixed32/sfixed64` | `-42` | `"-42"` |
| `float/double` | `3.14` | `"3.14"` |
| `float/double` | `1.5e10` | `"15000000000"` (fully expanded decimal, no exponent notation) |
| `float/double` | `-1.5` | `"-1.5"` |
| `float/double` | `inf` | `"inf"` |
| `float/double` | `-inf` | `"-inf"` |
| `float/double` | `nan` | `"nan"` |
| `bool` | `false` | `"false"` |
| `string` | `"hello\nworld"` | `"hello\nworld"` (escape sequences preserved as-is) |
| `bytes` | `"\x41\x42"` | `"AB"` (**decoded to raw bytes**, stored as binary string) |
| `enum` | `GREEN` | `"GREEN"` (enum value name, not number) |

**Key surprise:** `bytes` defaults are stored as **decoded bytes**, not as the escape sequence
written in source. The string `"\x41\x42"` becomes `"AB"` (2 raw bytes). The `defaultValue`
field in the proto descriptor is `bytes` type, not `string`.

**Key surprise:** floating-point scientific notation is always expanded to decimal form —
`1.5e10` → `"15000000000"`. The parser must convert scientific notation before storing.

#### Change point 5 — `parseEnumDeclaration()` — zero-value enforcement

```swift
// Currently fires unconditionally. Gate behind proto3:
if state.protoVersion == .proto3 && !values.contains(where: { $0.number == 0 }) {
    state.addError(.missingEnumZeroValue(...))
}
```

#### Change point 6 — `parseExtendDeclaration()` — target restriction

**This is the most nuanced change point. Read carefully before implementing.**

Proto3 does NOT simply ban all `extend`. It allows `extend google.protobuf.*` for custom
options. Any other target is forbidden — but the error message varies depending on context:

| Proto3 `extend` scenario | Exact protoc error |
|---|---|
| Target is a proto3 message (no ext ranges declared) | `"pkg.Msg" does not declare N as an extension number.` |
| Target is a proto2 message (has ext ranges) imported from another file | `Extensions in proto3 are only allowed for defining options.` |
| Target is `google.protobuf.*` | ✅ No error — valid custom option |

**The current implementation is wrong in two ways:**

1. It checks the **literal string prefix** `"google.protobuf."` — but the target may be a
   short name inside a `google.protobuf` package (e.g. in `descriptor.proto` itself,
   `extend FieldOptions {}` is valid because the package is `google.protobuf`).
2. It fires the restriction in **all** proto versions, not just proto3.

**Correct implementation:**

```swift
// In proto2: any extend target is valid (no restriction).
// In proto3: only google.protobuf.* targets are allowed.
if state.protoVersion == .proto3 {
    // Resolve the target to its fully-qualified name first,
    // then check the fqn — not the literal source text.
    let fqn = resolveType(extendedType, inPackage: ast.package)
    if !fqn.hasPrefix(".google.protobuf.") {
        state.addError(.extensionsOnlyAllowedForOptions(fqn, fieldNumber: fieldNumber))
        // Error message: "Extensions in proto3 are only allowed for defining options."
    }
}
```

**Key consequence for implementation:** type resolution must happen *during* parsing of
`extend` declarations (or at least a package-aware check), not just at descriptor-build time.
The simplest approach: store the current `ast.package` in `ParserState` and use it to
qualify the target name before checking the prefix.

**Additionally** — in proto3, `optional` keyword on extend fields is NOT required (protoc 33.5
verified: `extend google.protobuf.MessageOptions { string my_opt = 50002; }` — no `optional`,
exit 0). Do not error on missing label in proto3 extend fields.

---

### 3.4 New AST nodes in `Parser/AST/`

| New type | Fields | Notes |
|---|---|---|
| `ExtensionRangeNode` | `start: Int`, `end: Int` | `end` is stored exclusive (written value + 1); `max` → `536870912` |
| `GroupFieldNode` | `label: FieldLabel`, `groupName: String`, `fieldNumber: Int`, `body: MessageNode` | Synthetic; produces both a field and a nested message in the descriptor |

**Existing types to extend:**

| Type | New field |
|---|---|
| `FieldLabel` | add `case required` |
| `FieldNode` | add `defaultValue: String?` |
| `MessageNode` | add `extensionRanges: [ExtensionRangeNode]` |
| `ImportNode` | add `modifier: ImportModifier` (`.none`, `.public`, `.weak`) — currently discarded |
| `ProtoAST` | no change needed; `extends` already collected |

---

### 3.5 `DescriptorBuilder/` — four change points

#### `FieldDescriptorBuilder`

```swift
// LABEL_REQUIRED
case .required:
    fieldProto.label = .required

// defaultValue
if let defaultValue = fieldNode.defaultValue {
    fieldProto.defaultValue = defaultValue
}
```

#### `MessageDescriptorBuilder`

```swift
// extensionRange (end is already exclusive)
for range in messageNode.extensionRanges {
    var er = Google_Protobuf_DescriptorProto.ExtensionRange()
    er.start = Int32(range.start)
    er.end   = Int32(range.end)    // already exclusive
    messageProto.extensionRange.append(er)
}

// group field → field + nested message
for groupField in messageNode.groupFields {
    messageProto.field.append(buildGroupField(groupField))
    messageProto.nestedType.append(buildGroupMessage(groupField))
}
```

`buildGroupField`: `name = groupField.groupName.lowercased()`, `type = .typeGroup`,
`typeName = ".\(package).\(parentName).\(groupField.groupName)"`.  
`buildGroupMessage`: `name = groupField.groupName` (original capitalisation).

#### `DescriptorBuilder` (file-level) — populate `extension`

```swift
// Currently ast.extends is never converted. Fix:
for extendNode in ast.extends {
    for field in extendNode.fields {
        var extField = buildField(field, extendee: extendNode.extendedType)
        fileProto.extension.append(extField)
    }
}
```

**Important: extend inside message body** — `extend` blocks can appear nested inside a
`message` declaration. In that case the extension fields go into
`DescriptorProto.extension` of that message, **not** into `FileDescriptorProto.extension`.
*(protoc 33.5 verified: see nested_extend test — `Extender.extension` holds the fields,
`FileDescriptorProto.extension` holds only top-level extends)*

```
top-level extend Foo { ... }        → FileDescriptorProto.extension
message Bar { extend Foo { ... } }  → Bar (DescriptorProto).extension
```

The descriptor builder must track the nesting context when processing `extend` nodes.

#### `DescriptorBuilder` — `publicDependency` / `weakDependency`

```swift
for (index, importNode) in ast.imports.enumerated() {
    switch importNode.modifier {
    case .public: fileProto.publicDependency.append(Int32(index))
    case .weak:   fileProto.weakDependency.append(Int32(index))
    case .none:   break
    }
}
```

#### `EnumDescriptorBuilder` — `syntax` output

```swift
// FileDescriptorProto.syntax: protoc verified behaviour:
//   proto3  → "proto3"
//   proto2  → ""  (empty string)
//   no-syntax → "" (empty string)
// proto2 and no-syntax are indistinguishable in descriptor output.
fileProto.syntax = (ast.syntax == .proto3) ? "proto3" : ""
```

---

## 4. Data Flow After the Change

```
SwiftProtoParser.parseFile()
  │
  ├─ DependencyResolver.resolveDependencies()
  │    └─ ResolvedProtoFile.from()            ← regex header extraction (unchanged)
  │
  └─ buildDescriptorSet(from: resolvedFiles)
       │
       ├─ for each file:
       │    ProtoParsingPipeline.parse(content:fileName:)
       │      ├─ Lexer(input:).tokenize()     ← unchanged
       │      └─ Parser(tokens:).parse()
       │           ├─ parseSyntaxDeclaration() → sets state.protoVersion  ← NEW
       │           ├─ parseMessageDeclaration() reads state.protoVersion   ← NEW
       │           ├─ parseFieldDeclaration()  reads state.protoVersion    ← NEW
       │           ├─ parseEnumDeclaration()   reads state.protoVersion    ← NEW
       │           └─ parseExtendDeclaration() reads state.protoVersion    ← NEW
       │
       ├─ for each ProtoAST:
       │    DescriptorBuilder.buildFileDescriptor(from: ast)
       │      ├─ fileProto.syntax ← "" or "proto3"                         ← NEW
       │      ├─ fileProto.extension ← from ast.extends                    ← NEW
       │      ├─ fileProto.publicDependency / weakDependency               ← NEW
       │      ├─ MessageDescriptorBuilder: extensionRange, group fields    ← NEW
       │      └─ FieldDescriptorBuilder: LABEL_REQUIRED, defaultValue      ← NEW
       │
       └─ UnresolvedTypeValidator.validate()  ← unchanged
```

---

## 5. Error Message Exact Strings (protoc 33.5 verified)

All error messages emitted by the Parser must match protoc exactly:

| Situation | Exact string |
|---|---|
| Unknown `syntax = "X"` value | `Unrecognized syntax identifier "X".  This parser only recognizes "proto2" and "proto3".` |
| proto2 field without label | `Expected "required", "optional", or "repeated".` |
| proto3 `required` field | `Required fields are not allowed in proto3.` |
| proto3 `extensions N to M;` | `Extension ranges are not allowed in proto3.` |
| proto3 `group` field | `Groups are not supported in proto3 syntax.` |
| proto3 `[default = value]` | `Explicit default values are not allowed in proto3.` |
| proto3 `extend` same-syntax target (no ext ranges) | `"pkg.Msg" does not declare N as an extension number.` |
| proto3 `extend` proto2 target (has ext ranges) | `Extensions in proto3 are only allowed for defining options.` |

> **Note:** The unknown-syntax error string contains **two spaces** before "This" — copy verbatim.

---

## 6. `FileDescriptorProto.syntax` Values (protoc 33.5 verified)

| Source file | Output `syntax` field |
|---|---|
| `syntax = "proto3";` | `"proto3"` |
| `syntax = "proto2";` | `""` (empty string) |
| No syntax declaration | `""` (empty string) |

**Proto2 and no-syntax produce identical descriptor output.** The parser tracks the distinction
internally (via `state.protoVersion`) for validation purposes, but the descriptor does not expose it.

---

## 7. `DescriptorProto.extensionRange` End Value (protoc 33.5 verified)

The end value stored in the descriptor is **exclusive** (one past the written value):

| Written in `.proto` | Stored in descriptor |
|---|---|
| `extensions 100 to 199;` | `{start: 100, end: 200}` |
| `extensions 1000 to max;` | `{start: 1000, end: 536870912}` |

The parser must add `+1` when converting written end values. `max` maps to `536870912`.

---

## 8. Group Field Descriptor Layout (protoc 33.5 verified)

Given: `optional group SearchResult = 1 { required string url = 1; }`

Output descriptor:
```
// Field entry in parent message:
FieldDescriptorProto {
    name:      "searchresult"           // lowercase of group name
    number:    1
    label:     LABEL_OPTIONAL
    type:      TYPE_GROUP
    type_name: ".pkg.ParentMsg.SearchResult"   // original capitalisation
}

// Synthetic nested message in parent message:
DescriptorProto {
    name: "SearchResult"                // original capitalisation
    field: [ FieldDescriptorProto { name: "url", ... } ]
}
```

---

## 9. Implementation Order

Stories map directly to change points. Implement in dependency order:

```
Story 1 (ProtoVersion + ParserState)   ← unblocks everything
  ├─ Story 2 (required field)
  ├─ Story 3 (extension ranges)         → Story 4 (extend any target)
  ├─ Story 5 (group fields)
  ├─ Story 6 (default values)
  ├─ Story 7 (enum zero-value gate)
  └─ Story 8 (import public/weak)
       └─ Story 9 (integration test + cross-syntax audit)
```

Stories 2–8 are independent of each other once Story 1 is merged.
They can be developed in parallel on separate branches.

---

## 10. Testing Strategy

### Unit tests (per story)

Each story ships with focused unit tests in the existing test directories:

- `Parser/Proto2ParserTests.swift` — new file; one `XCTestCase` subclass per story
- `DescriptorBuilder/Proto2DescriptorTests.swift` — new file; descriptor output assertions

### Fixture files

`Tests/Fixtures/proto2/` (new directory):

```
Tests/Fixtures/proto2/
  required_fields.proto
  extensions.proto
  groups.proto
  defaults.proto
  no_syntax.proto
  allow_alias.proto
  google/protobuf/descriptor.proto    ← official file, protobuf ≥ 3.20
```

### Integration test (Story 9)

Parse `descriptor.proto` end-to-end and assert:
- No errors returned
- `FileDescriptorProto.syntax == ""`
- `messageType` contains `DescriptorProto`, `FieldDescriptorProto`, `FileOptions`, `MessageOptions`
- At least one `extensionRange` present on one message
- `extension` array is non-empty at file level

### Regression

`swift test` must remain green throughout. Run the full suite after each story merge.

---

## 11. Out of Scope (Explicitly)

- **Protobuf Editions** (`edition = "2023"`) — different architecture, separate epic
- **Runtime proto2 semantics** (required-field presence checks, serialisation) — parser only
- **Proto2→proto3 migration tooling** — not a parser concern
- **A second `Proto2Parser` class** — rejected; see §1
