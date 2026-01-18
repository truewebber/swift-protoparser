# Issue: Incorrect Scoping for Nested Enum References

## Priority: Low
## Status: Identified, Not Critical
## Category: Spec Compliance / Edge Case

---

## User Problem

The parser currently accepts protobuf files that violate the official protobuf scoping rules for nested enums. Specifically, it allows **unqualified cross-message references** to nested enums, which the official `protoc` compiler correctly rejects.

### Example of Invalid Proto (Accepted by Our Parser, Rejected by protoc)

```protobuf
syntax = "proto3";

message MessageA {
  enum Status {
    UNKNOWN = 0;
    ACTIVE = 1;
  }
}

message MessageB {
  Status status = 1;  // ❌ Invalid: "Status" is not in scope!
}
```

### Official protoc Behavior

```bash
$ protoc test.proto
test.proto:10:3: "Status" is not defined.
```

**Reason**: According to protobuf spec, `Status` is nested inside `MessageA` and is **not visible** from `MessageB`'s scope without qualification.

### Our Parser's Behavior

```swift
✅ Parsing succeeds
field.type = .enumType("Status")
```

The parser incorrectly resolves this as a valid enum field, violating protobuf scoping rules.

---

## Impact

### Severity: **Low**

**Why Low Priority:**

1. **Real-world proto files are validated by `protoc`** before use
   - Invalid files (like the example above) won't compile with `protoc`
   - Therefore, they won't exist in production codebases
   - Our parser is used for analysis/tooling, not as the primary compiler

2. **99% of real proto files work correctly:**
   - ✅ Top-level enums → work perfectly
   - ✅ Nested enums used in the same message → work correctly
   - ✅ Qualified references (`MessageA.Status`) → parsed as `.qualifiedType()`, untouched by resolver
   - ⚠️ Only unqualified cross-message nested enum references are problematic

3. **Edge case is rare:**
   - Well-written proto files use top-level enums for shared types
   - Nested enums are typically used only within their parent message
   - Cross-message references use qualified names

### Potential Issues

- **False positives**: Parser accepts syntactically invalid proto files
- **Tooling confusion**: Static analysis tools built on this parser might report incorrect results
- **Spec divergence**: Parser behavior differs from official `protoc` in edge cases

---

## Current State

### Root Cause: Flat Enum Registry

The `EnumFieldTypeResolver` (lines 56-87) builds a **flat registry** of enum names without preserving scoping information:

```swift
private static func buildEnumRegistry(from ast: ProtoAST) -> Set<String> {
  var registry = Set<String>()
  
  // Add top-level enums
  for enumNode in ast.enums {
    registry.insert(enumNode.name)  // ✅ "TopLevelStatus"
  }
  
  // Add nested enums from messages
  for message in ast.messages {
    collectNestedEnums(from: message, into: &registry)
  }
  
  return registry
}

private static func collectNestedEnums(from message: MessageNode, into registry: inout Set<String>) {
  for enumNode in message.nestedEnums {
    registry.insert(enumNode.name)  // ⚠️ Just "Status", no context!
  }
  
  for nestedMessage in message.nestedMessages {
    collectNestedEnums(from: nestedMessage, into: &registry)
  }
}
```

**Problem**: Registry stores only simple names (`"Status"`), losing information about where they were defined (`"MessageA.Status"`).

### Resolution Logic

```swift
private func resolveFieldType(_ fieldType: FieldType) -> FieldType {
  switch fieldType {
  case .message(let typeName):
    // Check if this is actually an enum
    if enumRegistry.contains(typeName) {  // ⚠️ No scope checking!
      return .enumType(typeName)
    }
    return fieldType
  }
}
```

The resolver performs a **global lookup** without considering:
- Current message scope
- Parent message scopes
- Visibility rules for nested types

---

## Desired State

The parser should follow the official protobuf scoping rules:

### Valid Cases (Should Parse Successfully)

```protobuf
syntax = "proto3";

// 1. Top-level enum - visible everywhere
enum GlobalStatus {
  UNKNOWN = 0;
}

message MessageA {
  GlobalStatus status = 1;  // ✅ OK
}

// 2. Nested enum used in same message
message MessageB {
  enum LocalStatus {
    PENDING = 0;
  }
  LocalStatus status = 1;  // ✅ OK: same scope
}

// 3. Qualified reference to nested enum
message MessageC {
  MessageB.LocalStatus status = 1;  // ✅ OK: qualified name
}

// 4. Nested enum in parent scope
message Outer {
  enum Status {
    ACTIVE = 0;
  }
  
  message Inner {
    Status s = 1;  // ✅ OK: parent scope
  }
}
```

### Invalid Case (Should Fail or Remain Unresolved)

```protobuf
message MessageA {
  enum Status { UNKNOWN = 0; }
}

message MessageB {
  Status status = 1;  // ❌ Should fail: "Status" not in scope
}
```

**Expected behavior**: Field type should remain as `.message("Status")` (not resolved to `.enumType`) since proper scoping would reveal it's not accessible.

---

## Protobuf Scoping Rules (Official Spec)

From the official protobuf specification:

### Name Resolution Order

When resolving an unqualified type name (e.g., `Status`):

1. **Current message scope**: Check nested types in the current message
2. **Parent scopes**: Move up through enclosing messages
3. **Package scope**: Check top-level types in the same package
4. **Imported files**: Check public imports

### Qualified Names

- **Relative qualified name**: `Outer.Inner.Type`
  - Resolved relative to current scope
  
- **Fully-qualified name**: `.package.name.Outer.Inner.Type`
  - Leading `.` indicates absolute path from package root

### Visibility

- **Nested types** (messages, enums) are scoped inside their parent
- They are **not visible** outside their parent without qualification
- Exception: Can be seen by child messages (inner scopes see outer scopes)

---

## Solution Path

### Option 1: Scope-Aware Registry (Recommended)

Build a **hierarchical registry** that preserves scope information:

```swift
struct ScopedEnumRegistry {
  // Map of qualified name → true
  // e.g., "MessageA.Status" → true, "Status" → true (for top-level)
  private let qualifiedNames: Set<String>
  
  // Map of simple name → all qualified paths
  // e.g., "Status" → ["MessageA.Status", "MessageB.Status"]
  private let nameToQualifiedPaths: [String: Set<String>]
  
  func isEnum(_ name: String, inScope scope: [String]) -> Bool {
    // 1. Try current scope: scope.Status
    let currentScope = scope.joined(separator: ".")
    if qualifiedNames.contains("\(currentScope).\(name)") {
      return true
    }
    
    // 2. Try parent scopes (walk up the chain)
    for i in (0..<scope.count).reversed() {
      let parentScope = scope[0...i].joined(separator: ".")
      if qualifiedNames.contains("\(parentScope).\(name)") {
        return true
      }
    }
    
    // 3. Try top-level (package scope)
    if qualifiedNames.contains(name) {
      return true
    }
    
    return false
  }
}
```

**Changes required:**

1. Update `buildEnumRegistry()` to store qualified names:
   ```swift
   registry.insert("MessageA.Status")  // Qualified
   registry.insert("Status")           // Top-level only
   ```

2. Update `resolveMessage()` to pass scope context:
   ```swift
   func resolveMessage(_ message: MessageNode, parentContext: String?) -> MessageNode {
     let scope = parentContext.map { [$0, message.name] } ?? [message.name]
     // Pass scope to field resolver
   }
   ```

3. Update `resolveFieldType()` to perform scope-aware lookup:
   ```swift
   func resolveFieldType(_ fieldType: FieldType, scope: [String]) -> FieldType {
     case .message(let typeName):
       if registry.isEnum(typeName, inScope: scope) {
         return .enumType(typeName)
       }
   }
   ```

### Option 2: Conservative Approach (Simpler)

Only resolve enums that are **definitely valid**:

```swift
private func resolveFieldType(_ fieldType: FieldType, context: MessageNode) -> FieldType {
  switch fieldType {
  case .message(let typeName):
    // Only convert if:
    // 1. Top-level enum exists, OR
    // 2. Nested enum exists in current message
    
    if topLevelEnums.contains(typeName) {
      return .enumType(typeName)
    }
    
    if context.nestedEnums.contains(where: { $0.name == typeName }) {
      return .enumType(typeName)
    }
    
    // Don't resolve cross-message nested enums
    // Let them stay as .message() - safer
    return fieldType
  }
}
```

**Pros**: Much simpler, covers 95% of real cases
**Cons**: Won't resolve valid parent-scope enum references

### Option 3: Do Nothing (Current State)

Accept the limitation as a **known issue** because:
- Real proto files are validated by `protoc` first
- Edge case is extremely rare in practice
- Parser is permissive rather than restrictive (good for tooling)

---

## Testing Requirements

### Test Coverage Needed

1. **Valid unqualified references** (should resolve to `.enumType`):
   ```protobuf
   message Outer {
     enum Status { UNKNOWN = 0; }
     Status s = 1;  // Same scope
   }
   ```

2. **Invalid unqualified references** (should NOT resolve):
   ```protobuf
   message MessageA {
     enum Status { UNKNOWN = 0; }
   }
   message MessageB {
     Status s = 1;  // Different scope - keep as .message
   }
   ```

3. **Qualified references** (already handled correctly):
   ```protobuf
   message MessageB {
     MessageA.Status s = 1;  // Should be .qualifiedType
   }
   ```

4. **Parent scope access** (should resolve):
   ```protobuf
   message Outer {
     enum Status { UNKNOWN = 0; }
     message Inner {
       Status s = 1;  // Parent scope - should resolve
     }
   }
   ```

5. **Top-level enums** (already work correctly):
   ```protobuf
   enum GlobalStatus { UNKNOWN = 0; }
   message Msg {
     GlobalStatus s = 1;  // Should resolve
   }
   ```

6. **Name shadowing**:
   ```protobuf
   enum Status { TOP = 0; }
   message Outer {
     enum Status { NESTED = 0; }
     Status s = 1;  // Should prefer nested over top-level
   }
   ```

### Integration Tests

Create `Tests/SwiftProtoParserTests/Parser/EnumScopingTests.swift` with comprehensive test cases.

### Validation Against protoc

Use official `protoc` compiler to validate expected behavior:

```bash
protoc --descriptor_set_out=/dev/null test.proto
```

Compare parser behavior with `protoc` outcomes.

---

## Acceptance Criteria

✅ Parser correctly identifies enum types following protobuf scoping rules  
✅ Invalid cross-message unqualified references are NOT resolved to `.enumType`  
✅ Valid same-scope and parent-scope references ARE resolved correctly  
✅ Qualified names continue to work (remain as `.qualifiedType`)  
✅ Top-level enums continue to work in all messages  
✅ All existing tests continue to pass  
✅ New test suite validates scoping rules  
✅ Behavior matches `protoc` compiler for test cases

---

## Files to Modify

### Core Implementation

- `Sources/SwiftProtoParser/Parser/EnumFieldTypeResolver.swift`
  - Update `buildEnumRegistry()` to store qualified names
  - Add scope tracking to `collectNestedEnums()`
  - Update `resolveMessage()` to pass scope context
  - Update `resolveFieldType()` to perform scope-aware lookup

### Testing

- Create `Tests/SwiftProtoParserTests/Parser/EnumScopingTests.swift`
  - Comprehensive test suite for all scoping scenarios
  - Validation against `protoc` behavior

### Documentation

- Update `docs/modules/PARSER_MODULE.md`
  - Document scoping behavior
  - Add examples of valid vs invalid references

---

## Estimated Complexity

**Medium-High** - Requires careful implementation of scoping rules

### Breakdown

- **Research & Design**: 2-4 hours
  - Study protobuf spec in detail
  - Design scope-tracking data structures
  - Plan algorithm for scope-aware resolution

- **Implementation**: 4-8 hours
  - Refactor `EnumFieldTypeResolver` for scope awareness
  - Update registry building logic
  - Implement scope chain tracking
  - Update resolution logic

- **Testing**: 4-6 hours
  - Write comprehensive test suite
  - Validate against `protoc` behavior
  - Test edge cases (name shadowing, deep nesting, etc.)
  - Ensure no regressions in existing tests

- **Documentation**: 1-2 hours
  - Update module documentation
  - Add examples and gotchas

**Total Estimate**: 11-20 hours

---

## Alternative: Accept as Known Limitation

Given the **low priority** and **high complexity**, an alternative approach is to:

1. **Document the limitation** in code comments and documentation
2. **Add a warning comment** in `EnumFieldTypeResolver`:
   ```swift
   /// Note: This resolver uses a flat registry and does not enforce
   /// protobuf scoping rules. It may resolve cross-message nested enum
   /// references that would be invalid in protoc. This is a known
   /// limitation with low practical impact since real proto files
   /// are validated by protoc before use.
   ```

3. **Defer the fix** until:
   - Real-world issues are encountered
   - Parser is used for code generation (not just analysis)
   - Strict spec compliance becomes a requirement

---

## Context

This issue was discovered during implementation of the `EnumFieldTypeResolver` - a component that distinguishes enum field types from message field types in the parsed AST.

### Background: Why EnumFieldTypeResolver Exists

The parser initially marks all non-scalar, non-qualified types as `.message()` because it performs single-pass parsing without a type registry. For example:

```swift
// Before EnumFieldTypeResolver:
enum Status { UNKNOWN = 0; }
message Request { Status status = 1; }
// Field type: .message("Status")  ❌

// After EnumFieldTypeResolver:
// Field type: .enumType("Status")  ✅
```

The resolver was added as a **post-processing step** to correct field types by:
1. Building a registry of all enum names in the AST
2. Converting `.message(name)` to `.enumType(name)` where appropriate

### The Scoping Issue

While implementing the resolver, it was designed with a **flat enum registry** (all enum names in a single `Set<String>`) for simplicity. This works perfectly for 99% of cases but violates protobuf scoping rules in edge cases involving cross-message nested enum references.

This issue documents that limitation and proposes solutions if strict spec compliance becomes necessary.

---

## References

- [Protobuf Language Spec - Scoping Rules](https://protobuf.com/docs/language-spec)
- [Protobuf Developer Guide - Nested Types](https://protobuf.dev/programming-guides/proto3/)
- [Protobuf Descriptors - Name Resolution](https://protobuf.com/docs/descriptors)

---

## Recommendation

**Current recommendation: Document as known limitation, defer implementation.**

**Rationale:**
- Edge case is rare in real-world proto files
- High implementation complexity vs low practical benefit
- Parser is permissive (good for analysis tools)
- Real proto files are validated by `protoc` first

**Reconsider if:**
- Users report issues with real proto files
- Parser is repurposed for code generation
- Strict spec compliance becomes a project goal
