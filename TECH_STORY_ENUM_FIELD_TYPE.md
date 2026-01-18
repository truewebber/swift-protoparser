# Tech Story: Enum Field Type Recognition

## User Problem

When users parse a `.proto` file containing an enum and a message that uses this enum as a field type, the parser returns `FieldType.message("EnumName")` instead of `FieldType.enumType("EnumName")`.

This makes it **impossible** to distinguish between enum fields and message fields programmatically without maintaining a separate type registry and checking against it manually.

### Example

Proto file:
```protobuf
enum Status {
  UNKNOWN = 0;
  ACTIVE = 1;
}

message Request {
  Status status = 1;  // enum field
}
```

Current behavior:
```swift
field.type  // returns: .message("Status")  ❌
```

Expected behavior:
```swift
field.type  // should return: .enumType("Status")  ✅
```

## Impact

- Users cannot differentiate between enum and message types without workarounds
- The `FieldType.enumType` case exists but is never used by the parser
- Code generators and analyzers built on top of this parser produce incorrect results

## Current State

The parser performs single-pass parsing in `Parser.parseQualifiedTypeName()` (lines 632-670). When encountering a type name, it only checks if the name contains a dot:

- **Has dot** → `.qualifiedType(name)`
- **No dot** → `.message(name)` ← always assumes message, never checks for enum

The parser has no type registry or symbol table to distinguish between message and enum names during parsing.

**Important:** The `DescriptorBuilder` (which converts AST to protobuf descriptors) already correctly handles both `.message()` and `.enumType()` cases - see `FieldDescriptorBuilder.swift` lines 78-84. The architecture is sound, only the Parser doesn't create `.enumType` nodes.

## Desired State

The parser should correctly identify enum types and return `FieldType.enumType(name)` when a field uses an enum type.

## Solution Path

### Architecture Note

**No architectural changes required!** Current flow:
```
Parser → ProtoAST → DescriptorBuilder → FileDescriptorProto
```

We're adding a lightweight post-processing step:
```
Parser → ProtoAST → [EnumFieldTypeResolver fixes types] → ProtoAST (corrected) → DescriptorBuilder → FileDescriptorProto
```

This is a **pure function transformation** - takes AST, returns corrected AST. No side effects, no state changes.

### Implementation (Recommended Approach)

Create `EnumFieldTypeResolver` - a simple post-processor that runs after parsing:

1. **Initialize with AST**: Scan and build enum registry
   - Collect all top-level enum names → `Set<String>`
   - Collect all nested enum names with parent context → `Set<String>` (e.g., "Message.Status")
   - Handle scoping correctly (nested types don't conflict with top-level)

2. **Resolve field types**: Traverse all messages and their fields
   - For each field with `.message(name)`:
     - Check if `name` exists in enum registry
     - If yes → replace with `.enumType(name)`
     - If no → keep as `.message(name)`
   - Skip `.qualifiedType()` - they need import resolution
   - Skip scalar types

3. **Return corrected AST**: New `ProtoAST` with fixed field types

### Alternative: Inline in Parser

Instead of separate class, add private method `fixEnumFieldTypes(ast: ProtoAST) -> ProtoAST` directly in `Parser.swift` and call it in `parse()` method after line 40.

### Scope Considerations

- **Nested enums**: Must be registered with qualified names (e.g., `Message.Status`)
- **Package names**: Handle fully qualified names from imports
- **Name conflicts**: Ensure nested types don't conflict with top-level types

## Testing Requirements

Create `Tests/SwiftProtoParserTests/Parser/EnumFieldTypeResolverTests.swift` covering:

1. Simple enum field (top-level enum)
2. Nested enum field (enum inside message)
3. Multiple enums with same name in different messages (scoping)
4. Message field remains as `.message()` (not changed to enum)
5. Qualified types are not touched (`.qualifiedType()` unchanged)
6. Enum from imported file (if dependency resolution is implemented)

## Acceptance Criteria

✅ Field with enum type returns `FieldType.enumType("EnumName")`  
✅ Field with message type still returns `FieldType.message("MessageName")`  
✅ Nested enums are correctly identified  
✅ Existing tests continue to pass  
✅ New test `EnumFieldTypeBugTests.testEnumFieldTypeIsCorrect` passes

## Files to Modify

- `Sources/SwiftProtoParser/Parser/Parser.swift` - integrate `EnumFieldTypeResolver` call in `parse()` method
- Create new file: `Sources/SwiftProtoParser/Parser/EnumFieldTypeResolver.swift` - contains the resolver logic
- Alternative: implement as private method directly in Parser.swift (lighter approach)

## Estimated Complexity

**Medium** - requires understanding of scoping and name resolution, but the parsing infrastructure is already in place.
