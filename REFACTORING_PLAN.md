# Refactoring Plan: Fix Layer Violations in Performance Module

## Problem Statement

`IncrementalParser` and `PerformanceBenchmark` — internal implementation modules — call upward
into `SwiftProtoParser` (the public facade) to perform parsing. This inverts the dependency
direction and creates tight coupling between implementation layers and the public API.

### Symptoms

```
IncrementalParser.swift:271   → SwiftProtoParser.parseProtoFile(filePath)
IncrementalParser.swift:399   → SwiftProtoParser.parseProtoFileWithImports(filePath, importPaths:)
IncrementalParser.swift:459   → SwiftProtoParser.parseProtoString(content, fileName:)

PerformanceBenchmark.swift:197,204 → SwiftProtoParser.parseProtoFile(filePath)
PerformanceBenchmark.swift:237,244 → SwiftProtoParser.parseProtoString(content)
PerformanceBenchmark.swift:279,286 → SwiftProtoParser.parseProtoFileWithImports(filePath, importPaths:)
PerformanceBenchmark.swift:319,326 → SwiftProtoParser.parseProtoDirectory(directoryPath, recursive:)
PerformanceBenchmark.swift:359,366 → SwiftProtoParser.parseProtoToDescriptors(filePath)
```

### Consequence

`SwiftProtoParser.swift` had to expose 6 "Internal Helpers" (`parseProtoFile`,
`parseProtoFileWithImports`, `parseProtoDirectory`, `parseProtoToDescriptors`,
`parseProtoStringToDescriptors`, `parseProtoFileWithImportsToDescriptors`) as `internal` — not
because the public API needs them, but to serve the broken layering in the Performance module.

---

## Target Architecture

Dependencies must flow strictly **downward**:

```
Layer 0: Core
  ProtoParseError, ProtoVersion          (no deps)

Layer 1: Lexer
  Lexer, Token, LexerError               (→ Core)

Layer 2: Parser
  Parser, ProtoAST, *Node                (→ Lexer, Core)
  ProtoParsingPipeline  ← NEW            (→ Lexer, Parser, Core)

Layer 3: DescriptorBuilder
  DescriptorBuilder, *Builder            (→ Parser, Core)

Layer 4: DependencyResolver
  DependencyResolver, *                  (→ Lexer, Parser, Core)

Layer 5: Performance
  PerformanceCache                       (→ Parser)
  IncrementalParser                      (→ Layer 2 ProtoParsingPipeline, Layer 4, Layer 5 Cache)
  PerformanceBenchmark                   (→ Layer 2 ProtoParsingPipeline, Layer 3, Layer 4, Layer 5 Cache)

Layer 6: Public API
  SwiftProtoParser                       (→ all layers)
```

No lower layer may reference a higher layer.

---

## Step-by-Step Implementation

### Step 1 — Create `ProtoParsingPipeline` (Layer 2)

**File**: `Sources/SwiftProtoParser/Parser/ProtoParsingPipeline.swift`

Encapsulates the Lexer → Parser pipeline in a single internal utility that any layer can use
without going through the public facade.

```swift
struct ProtoParsingPipeline {

  /// Parse .proto content from a string into a ProtoAST.
  static func parse(
    content: String,
    fileName: String = "string"
  ) -> Result<ProtoAST, ProtoParseError> { ... }

  /// Read a file from disk and parse it into a ProtoAST.
  static func parseFile(
    at filePath: String
  ) -> Result<ProtoAST, ProtoParseError> { ... }
}
```

**Dependencies**: `Lexer`, `Parser`, `ProtoParseError` — all Layer 1/2, no upward references.

---

### Step 2 — Fix `IncrementalParser`

Replace three `SwiftProtoParser.*` call sites:

| Location | Old call | New call |
|---|---|---|
| `parseStreamingFile` (line ~271) | `SwiftProtoParser.parseProtoFile(filePath)` | `ProtoParsingPipeline.parseFile(at: filePath)` |
| `parseFileWithCaching` (line ~399) | `SwiftProtoParser.parseProtoFileWithImports(filePath, importPaths:)` | `DependencyResolver` directly + `ProtoParsingPipeline.parse` |
| `parseFileInChunks` (line ~459) | `SwiftProtoParser.parseProtoString(content, fileName:)` | `ProtoParsingPipeline.parse(content:fileName:)` |

**Result**: `IncrementalParser` depends only on Layer 2/4/5 — no reference to the facade.

---

### Step 3 — Fix `PerformanceBenchmark`

Replace five `SwiftProtoParser.*` call sites:

| Method | Old call | New call |
|---|---|---|
| `benchmarkSingleFile` | `SwiftProtoParser.parseProtoFile(filePath)` | `ProtoParsingPipeline.parseFile(at: filePath)` |
| `benchmarkStringParsing` | `SwiftProtoParser.parseProtoString(content)` | `ProtoParsingPipeline.parse(content:fileName:)` |
| `benchmarkWithDependencies` | `SwiftProtoParser.parseProtoFileWithImports(filePath, importPaths:)` | `DependencyResolver` + `ProtoParsingPipeline.parse` |
| `benchmarkDirectory` | `SwiftProtoParser.parseProtoDirectory(directoryPath, recursive:)` | `DependencyResolver.resolveDirectory` + `ProtoParsingPipeline.parse` |
| `benchmarkDescriptorGeneration` | `SwiftProtoParser.parseProtoToDescriptors(filePath)` | `ProtoParsingPipeline.parseFile` + `DescriptorBuilder.buildFileDescriptor` |

**Result**: `PerformanceBenchmark` depends only on Layer 2/3/4/5 — no reference to the facade.

---

### Step 4 — Remove `// MARK: - Internal Helpers` from `SwiftProtoParser.swift`

After Steps 2–3, the following methods have zero callers in production code and can be deleted:

- `parseProtoFile(_:)`
- `parseProtoFileWithImports(_:importPaths:allowMissingImports:)`
- `parseProtoDirectory(_:recursive:importPaths:allowMissingImports:)`
- `parseProtoToDescriptors(_:)`
- `parseProtoFileWithImportsToDescriptors(_:importPaths:allowMissingImports:)` ← already dead
- `parseProtoStringToDescriptors(_:fileName:)`

`parseProtoString(_:fileName:)` stays `internal` — it is used by hundreds of internal tests
(`@testable import`). Its proper long-term home is `ProtoParsingPipeline`, but migrating all
tests is a separate effort.

**Result**: `SwiftProtoParser.swift` contains only:
- `public static func parseFile`
- `public static func parseDirectory`
- `private static func buildDescriptorSet`
- `internal static func parseProtoString` (test access)

---

### Step 5 — Update Tests

Tests in `Tests/SwiftProtoParserTests/Public/` that call the deleted helpers directly:
- `testParseProtoToDescriptors_fileNotFound` → replace with `parseFile` check or remove
- `testParseProtoFileWithImportsToDescriptors_fileNotFound` → same
- `testParseProtoStringToDescriptors_*` → replace with `parseProtoString` + direct
  `DescriptorBuilder` call if needed, or remove if redundant

Tests in `Tests/SwiftProtoParserTests/Parser/` that call `parseProtoString` directly:
- These are fine — they test parser internals and `@testable import` is the correct mechanism.

---

## Files Changed

| File | Change |
|---|---|
| `Sources/SwiftProtoParser/Parser/ProtoParsingPipeline.swift` | **CREATE** |
| `Sources/SwiftProtoParser/Performance/IncrementalParser.swift` | Fix 3 call sites |
| `Sources/SwiftProtoParser/Performance/PerformanceBenchmark.swift` | Fix 5 call sites |
| `Sources/SwiftProtoParser/Public/SwiftProtoParser.swift` | Remove `Internal Helpers` section |
| `Tests/SwiftProtoParserTests/Public/SwiftProtoParserTests.swift` | Remove/update 3 tests |
| `README.md` | Already correct (uses `parseFile`/`parseDirectory`) |
| `docs/ARCHITECTURE.md` | Update layer diagram and API section |
| `docs/QUICK_REFERENCE.md` | Update public API section |
| `docs/modules/PERFORMANCE_MODULE.md` | Fix dependency arrows |

---

## Success Criteria

- [ ] Build passes with zero errors
- [ ] All tests green (target: ≥ 1246 passing)
- [ ] `SwiftProtoParser.swift` has no `// MARK: - Internal Helpers`
- [ ] `grep -r "SwiftProtoParser\." Sources/SwiftProtoParser/Performance/` returns empty
- [ ] `make lint` passes
- [ ] Coverage ≥ previous baseline (92.67% regions)
- [ ] Tagged as `0.7.0` (breaking internal change, though public API is unchanged)

---

## Non-Goals

- Splitting into SPM multi-target (out of scope, adds complexity without proportional benefit)
- Migrating all `parseProtoString` test calls to `ProtoParsingPipeline` (large volume, low ROI)
- Removing `PerformanceCache`, `IncrementalParser`, `PerformanceBenchmark` (separate decision)
- Making Performance module public API (separate product decision)
