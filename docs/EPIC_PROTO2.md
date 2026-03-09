# Epic: Proto2 Full Support

**Status:** Proposed  
**Depends on:** Current proto3 implementation (complete)  
**Updates:** `docs/BUSINESS_REQUIREMENTS.md` §3.1 — removes "No Proto2 support" limitation  
**Verified against:** `protoc libprotoc 33.5` (all cases below tested and outputs confirmed)

---

## Problem Statement

SwiftProtoParser was initially scoped to proto3 only. In practice, proto3 files regularly import
well-known types from the official protobuf package — including `google/protobuf/descriptor.proto`,
which is a **proto2** file. Without proto2 support, any proto3 project that uses custom options
(extend `google.protobuf.MessageOptions` etc.) fails at dependency resolution, because
`descriptor.proto` cannot be parsed.

Beyond well-known types, a significant portion of the real-world `.proto` ecosystem is still
proto2. SwiftProtoParser claims to be a drop-in alternative to `protoc` for Swift; that claim
cannot be true if proto2 files are rejected outright.

**User value:** Developers can feed any legal `.proto` file — proto2, proto3, or no-syntax — to
SwiftProtoParser and receive a correct `FileDescriptorSet`, identical to what `protoc` would
produce.

---

## Scope

This epic covers **full proto2 parsing and descriptor generation** with behaviour matching
`protoc`. It does **not** cover Protobuf Editions (the `edition =` syntax introduced in 2023),
which is a separate future epic.

---

## Background: Current Feature Gap

Identified by static analysis of the current codebase (see session notes):


| Area                            | Current behaviour                                             | Required behaviour                                                                                                                                                             |
| ------------------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `syntax = "proto2"`             | Silently treated as proto3; output descriptor says `"proto3"` | Parse as proto2; output `syntax = ""` (**verified: protoc outputs `""` for proto2, not `"proto2"`**)                                                                           |
| No `syntax` declaration         | `missingSyntax` error thrown                                  | Treat as proto2; `FileDescriptorProto.syntax = ""`. No error, no warning (**verified: protoc 33.5 is silent**)                                                                 |
| `required` field label          | Parse error                                                   | `LABEL_REQUIRED` (value `2`) in descriptor                                                                                                                                     |
| `extensions N to M;` in message | Parse error                                                   | Populate `DescriptorProto.extensionRange`; end stored as **exclusive** (`end+1`); `max` stored as `536870912`                                                                  |
| `extend AnyMessage { }`         | Parse error if target is not `google.protobuf.`*              | Valid in proto2 for any message; extend fields → `FileDescriptorProto.extension` with `extendee` set to fully-qualified name                                                   |
| `group` type                    | Parse error                                                   | Field: `type=TYPE_GROUP`, `name=lowercase(groupName)`, `type_name=.pkg.ParentMsg.GroupName`; plus co-located nested `DescriptorProto` named with original (capital) group name |
| `[default = value]` on field    | Silently goes to `uninterpreted_option`                       | `FieldDescriptorProto.defaultValue` as string; int/float/bool → decimal string; string → raw value; enum → enum value name                                                     |
| Enum without zero value         | Parse error (proto3 rule applied globally)                    | Allowed in proto2; zero-value check only enforced for proto3                                                                                                                   |
| `import public` / `import weak` | Modifier silently discarded                                   | `publicDependency` / `weakDependency` → 0-based indices into `dependency` array                                                                                                |
| `FileDescriptorProto.syntax`    | Always `"proto3"`                                             | `""` for proto2 and no-syntax; `"proto3"` for proto3 (**proto2 and no-syntax are indistinguishable in descriptor output**)                                                     |
| `FileDescriptorProto.extension` | Never populated                                               | Top-level extension fields from `extend` blocks at file scope                                                                                                                  |
| `FieldDescriptorProto.label`    | No `LABEL_REQUIRED` path                                      | `LABEL_REQUIRED` for `required` fields                                                                                                                                         |


---

## Cross-Syntax Validation Rules (protoc-compatible)

These rules must be enforced as **hard errors**:

### proto2 file — forbidden proto3 constructs

All messages from actual `protoc libprotoc 33.5` output:


| Construct                                                            | Exact protoc error                                |
| -------------------------------------------------------------------- | ------------------------------------------------- |
| Field without any label (implicit singular), e.g. `string name = 1;` | `Expected "required", "optional", or "repeated".` |


> Note: `oneof` fields are label-free in both proto2 and proto3 — valid in proto2.  
> `map<K,V>` fields are valid in proto2.

### proto3 file — forbidden proto2 constructs

All messages from actual `protoc libprotoc 33.5` output:


| Construct                                                                            | Exact protoc error                                             |
| ------------------------------------------------------------------------------------ | -------------------------------------------------------------- |
| `required` field label                                                               | `Required fields are not allowed in proto3.`                   |
| `extensions N to M;` in message body                                                 | `Extension ranges are not allowed in proto3.`                  |
| `group` field type                                                                   | `Groups are not supported in proto3 syntax.`                   |
| `[default = value]` field option                                                     | `Explicit default values are not allowed in proto3.`           |
| `extend` any message in proto3 (target has no extension ranges — typical proto3 msg) | `"pkg.MessageName" does not declare N as an extension number.` |
| `extend` a proto2 message (which has extension ranges) from a proto3 file            | `Extensions in proto3 are only allowed for defining options.`  |


> **Note on `extend` in proto3:** protoc does not produce a single unified error for "you can't
> extend non-google messages in proto3". The error depends on whether the target message declares
> extension ranges. Since proto3 messages can't have `extensions N to M;`, the first error
> (does not declare extension number) is what users will typically see.
>
> `extend google.protobuf.`* in proto3 is **valid** (verified: exits 0, descriptor produced).
>
> `optional` keyword IS allowed in proto3 (field presence / proto3 optional, proto 3.12+). No change needed.

### No-syntax file

**Verified:** `protoc libprotoc 33.5` treats no-syntax files as proto2, exits 0, emits **no warning
and no error**. SwiftProtoParser must match this: parse as proto2, no diagnostic emitted.

---

## User Stories

### Story 1 — Syntax version routing

> As a library user, when I pass a file with `syntax = "proto2"` or no `syntax` statement, the
> library must parse it according to proto2 rules and produce a descriptor with the correct
> `syntax` field value.

### Story 2 — `required` fields

> As a library user, proto2 `required` fields must appear in the output descriptor as
> `LABEL_REQUIRED`, and must not be present in proto3 files.

### Story 3 — Extension ranges

> As a library user, `extensions N to M;` declarations inside proto2 messages must populate
> `DescriptorProto.extensionRange` in the output descriptor.

### Story 4 — `extend` any message in proto2, restricted to `google.protobuf.*` in proto3

> As a library user, `extend` blocks in proto2 files may target any message type (no restriction).
> In proto3 files, only `extend google.protobuf.*` is valid (custom options). Any other target in
> proto3 must produce an error that matches protoc verbatim.
>
> **Implementation notes (do not guess — verified with protoc 33.5):**
>
> | Proto3 `extend` scenario | Exact protoc error |
> |---|---|
> | Target is a **proto3 message** (no extension ranges declared) | `"<fqn>" does not declare <N> as an extension number.` |
> | Target is a **proto2 message** (has extension ranges) | `Extensions in proto3 are only allowed for defining options.` |
> | Target is `google.protobuf.*` | ✅ Valid, no error |
>
> The check must operate on the **fully-qualified name** of the target, not the literal source
> text. In a file whose `package = google.protobuf`, an unqualified `extend FieldOptions` is
> valid because the resolved FQN is `.google.protobuf.FieldOptions`.
>
> **Field labels in `extend` blocks:** proto3 extend fields do **not** require `optional`; the
> label is implicit. Do not emit an error for missing labels inside `extend` in proto3 files.
>
> Extended fields appear in `FileDescriptorProto.extension` (top-level extend) or
> `DescriptorProto.extension` (nested extend), with `extendee` set to the fully-qualified name
> (e.g. `.pkg.Foo`).

### Story 5 — `group` type

> As a library user, proto2 `group` fields must be parsed and emitted as
> `FieldDescriptorProto.type = TYPE_GROUP` with a co-located synthetic nested message, matching
> protoc output structure.

### Story 6 — Field default values

> As a library user, `[default = value]` on proto2 fields must populate
> `FieldDescriptorProto.defaultValue` as a string (same encoding protoc uses), not
> `uninterpreted_option`.

### Story 7 — Proto2 enum semantics

> As a library user, enums in proto2 files are not required to start at 0. The zero-value
> enforcement must only apply to proto3.

### Story 8 — `import public` / `import weak`

> As a library user, `import public "x.proto"` and `import weak "x.proto"` must populate
> `FileDescriptorProto.publicDependency` and `weakDependency` with the correct indices into the
> `dependency` array, matching protoc output.

### Story 9 — Cross-syntax validation

> As a library user, using proto2-only constructs in a proto3 file (or proto3-only constructs in
> a proto2 file) must produce clear, actionable error messages matching protoc wording.

---

## Acceptance Criteria

- **AC-1 (no syntax):** A `.proto` file with no `syntax` statement is parsed as proto2.
`FileDescriptorProto.syntax == ""`. No error, no warning emitted.
*(protoc 33.5 verified: exits 0, no stderr output, syntax field is empty string)*
- **AC-2 (proto2 syntax field):** A file with `syntax = "proto2";` produces
`FileDescriptorProto.syntax == ""` (empty string — identical to no-syntax; proto2 and no-syntax
are **indistinguishable** in descriptor output).
*(protoc 33.5 verified: protoc outputs `""` for proto2, not `"proto2"`)*
- **AC-3 (required label):** `required int32 foo = 1;` in a proto2 message produces a field
descriptor with `label == LABEL_REQUIRED` (value `2`). The same construct in a proto3 file
produces error `"Required fields are not allowed in proto3."`.
- **AC-4 (extension ranges):** `extensions 100 to 199;` in a proto2 message produces
`extensionRange {start: 100, end: 200}` (end is **exclusive**, i.e. written value + 1).
`extensions 1000 to max;` produces `extensionRange {start: 1000, end: 536870912}`.
`extensions 100 to 199, 300 to 399, 500 to max;` (comma-separated) is valid and produces
**three** separate `ExtensionRange` entries: `{100,200}`, `{300,400}`, `{500,536870912}`.
The same construct in a proto3 file produces error `"Extension ranges are not allowed in proto3."`.
*(protoc 33.5 verified: end is exclusive, max stored as 536870912, comma list produces multiple entries)*
- **AC-5 (extend any target in proto2, restricted in proto3):**
  - `extend Foo { optional int32 bar = 126; }` in a **proto2** file resolves `Foo` via normal
    scope rules and populates `FileDescriptorProto.extension` with `extendee` set to the
    fully-qualified name (e.g. `.pkg.Foo`). No `google.protobuf.` restriction in proto2.
  - `extend google.protobuf.MessageOptions { string my_opt = 50002; }` in a **proto3** file is
    valid (custom option). Field label is optional — no error for missing label.
    *(protoc 33.5 verified: bare `string my_opt = 50002;` inside a proto3 extend block, exit 0)*
  - `extend SomeProto3Message { string val = 1; }` in a **proto3** file (target has no extension
    ranges) produces: `"<fqn>" does not declare <N> as an extension number.`
    *(protoc 33.5 verified)*
  - `extend SomeProto2Message { string val = 1; }` in a **proto3** file (target has extension
    ranges) produces: `Extensions in proto3 are only allowed for defining options.`
    *(protoc 33.5 verified)*
  - The target FQN check must use **resolved** names, not literal source text. A file with
    `package = google.protobuf` may extend `FieldOptions` without qualification and it must
    be treated as valid.
- **AC-6 (group field):** `optional group SearchResult = 1 { required string url = 1; }` produces:
  - a `FieldDescriptorProto` with `name = "searchresult"` (lowercase), `type = TYPE_GROUP`,
  `type_name = ".pkg.ParentMessage.SearchResult"`
  - a co-located nested `DescriptorProto` named `"SearchResult"` (original capitalisation)
  - The same construct in a proto3 file produces error `"Groups are not supported in proto3 syntax."`.
  *(protoc 33.5 verified: field name is lowercased, nested type keeps original name)*
- **AC-7 (default value):** `optional int32 foo = 1 [default = 42];` → `"42"`.
`optional int32 neg = 2 [default = -42];` → `"-42"`.
`optional float f = 3 [default = 3.14];` → `"3.14"`.
`optional double d = 4 [default = 1.5e10];` → `"15000000000"` (**decimal expansion, no exponent**).
`optional float f2 = 5 [default = inf];` → `"inf"`.
`optional float f3 = 6 [default = nan];` → `"nan"`.
`optional string s = 7 [default = "hello\nworld"];` → `"hello\nworld"` (escape sequences preserved).
`optional bytes b = 8 [default = "\x41\x42"];` → raw bytes `AB` (**decoded**, not the escape text).
`optional bool bo = 9 [default = false];` → `"false"`.
`optional Color c = 10 [default = GREEN];` → `"GREEN"` (enum value name, not number).
The same `[default = ...]` in a proto3 file produces error
`"Explicit default values are not allowed in proto3."`.
*(protoc 33.5 verified: all types confirmed; notable: double 1.5e10 → "15000000000"; bytes decoded to raw)*
- **AC-8 (proto2 enum without zero):** An enum in a proto2 file with no value equal to `0`
is valid and produces no error.
*(protoc 33.5 verified: exits 0 cleanly)*
- **AC-9 (import public / import weak):** `import public "a.proto"` results in the 0-based
index of `"a.proto"` in the `dependency` array being present in `publicDependency`.
`import weak "b.proto"` results in the index being present in `weakDependency`.
*(protoc 33.5 verified: indices are 0-based; protoc emits a warning if weak import is unused)*
- **AC-10 (proto2 implicit-label error):** `string name = 1;` (no label) inside a proto2
message body produces error `"Expected "required", "optional", or "repeated"."`.
*(protoc 33.5 verified exact wording)*
- **AC-11 (descriptor.proto parses cleanly):** The official
`google/protobuf/descriptor.proto` (taken from protobuf release ≥ 3.20) is parsed by
SwiftProtoParser without any error. The resulting descriptor contains `DescriptorProto`,
`FieldDescriptorProto`, `FileOptions`, `MessageOptions`, and other key messages.
- **AC-12 (proto3 regression):** All existing proto3 tests pass without modification. No
proto3 behaviour changes.
- **AC-13 (oneof in proto2):** `oneof` blocks in proto2 files are valid; fields inside
`oneof` must **not** have labels (`required`/`optional`/`repeated`). Using a label inside
`oneof` produces error `"Fields in oneofs must not have labels (required / optional / repeated)."`.
In the descriptor, `oneof` fields have `label == LABEL_OPTIONAL` (1) regardless.
*(protoc 33.5 verified: `required` inside oneof → exit 1 with exact message above)*
- **AC-14 (reserved in proto2):** `reserved 2, 15, 9 to 11;` and `reserved "foo", "bar";`
inside a proto2 message are valid and populate `DescriptorProto.reservedRange` /
`reservedName` identically to proto3. *(protoc 33.5 verified: exit 0)*
- **AC-15 (allow_alias enum option):** `option allow_alias = true;` inside a proto2 enum
(and proto3 enum) allows duplicate numeric values. Without it, duplicate values produce error
`"<fqn>" uses the same enum value as "<fqn>". If this is intended, set 'option allow_alias = true;'`.
*(protoc 33.5 verified: exit 1 with exact message; with allow_alias exit 0)*
- **AC-16 (nested extend placement):** `extend` blocks at file scope populate
`FileDescriptorProto.extension`. `extend` blocks **nested inside a `message` body** populate
`DescriptorProto.extension` of that enclosing message, **not** the file-level `extension`.
*(protoc 33.5 verified: `message Bar { extend Foo { ... } }` → `Bar.extension`, not `file.extension`)*
- **AC-17 (map fields in proto2):** `map<string, int32>` is valid in proto2 and produces
the same synthetic `MapEntry` nested message as in proto3. *(protoc 33.5 verified: exit 0)*

---

## Definition of Ready (DoR)

- This document reviewed and approved by the team
- `docs/BUSINESS_REQUIREMENTS.md` updated to remove "No Proto2 support" limitation
- A reference set of proto2 `.proto` fixture files prepared in `Tests/Fixtures/proto2/`
including at minimum: `required_fields.proto`, `extensions.proto`, `groups.proto`,
`defaults.proto`, `no_syntax.proto`, `allow_alias.proto`, and a copy of the official
`google/protobuf/descriptor.proto`
- The current feature gap (above table) confirmed accurate against latest `main` branch
- Parser architecture decision made: separate parsing mode vs. unified parser with
version-aware validation rules (recommendation: unified parser, version flag passed through
parse context)
- No open blocking issues on `main` that would conflict with parser changes

---

## Definition of Done (DoD)

- All AC-1 through AC-17 pass
- `swift test` is green (zero failures, zero skips introduced by this epic)
- Test coverage for new proto2 code paths is ≥ 90% (line coverage)
- New test fixtures committed to `Tests/Fixtures/proto2/`
- `FieldLabel` enum extended with `.required`; `ProtoVersion` enum extended with `.proto2`
- `FileDescriptorProto.syntax` correctly set: `""` for proto2 and no-syntax (both identical), `"proto3"` for proto3
- `BUSINESS_REQUIREMENTS.md` §3.1 updated: "Proto2 support" replaces "No Proto2 support"
- `README.md` updated to reflect proto2 support
- `docs/QUICK_REFERENCE.md` updated with proto2 examples if applicable
- Public API `///` documentation updated for any changed or new public types
- No performance regression vs. proto3-only baseline (benchmark suite passes)
- Linear epic status set to **Done**

---

## Out of Scope

- Protobuf **Editions** (`edition = "2023"` syntax) — separate epic
- Proto2 **streaming / service** differences (none exist; services are identical)
- Runtime behaviour (serialisation, reflection) — SwiftProtoParser is a parser only
- Migrating existing proto2 files to proto3 — tooling concern, not parser concern

