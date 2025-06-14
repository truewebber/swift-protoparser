# Swift ProtoParser - DEVELOPMENT PLAN

## 🎯 START HERE EVERY SESSION
1. Read `PROJECT_STATUS.md` - check CURRENT FOCUS
2. If first time - run `make setup` to create folder structure
3. Check module docs in `docs/modules/` for implementation details
4. Update `PROJECT_STATUS.md` at end of session

## 📁 PROJECT STRUCTURE (run `make setup` to create)
```
swift-protoparser/
├── PROJECT_STATUS.md           # ← MAIN STATUS TRACKER
├── DEVELOPMENT_PLAN.md         # ← THIS FILE
├── docs/
│   ├── QUICK_REFERENCE.md      # ← ARCHITECTURE SUMMARY
│   └── modules/                # ← MODULE IMPLEMENTATION PLANS
│       ├── CORE_MODULE.md
│       ├── LEXER_MODULE.md
│       ├── PARSER_MODULE.md
│       └── DESCRIPTOR_BUILDER_MODULE.md
├── Sources/SwiftProtoParser/
│   ├── Core/
│   ├── DependencyResolver/
│   ├── Lexer/
│   ├── Parser/
│   ├── DescriptorBuilder/
│   └── Public/
├── Tests/SwiftProtoParserTests/
│   ├── Core/
│   ├── Lexer/
│   ├── Parser/
│   ├── DescriptorBuilder/
│   └── Integration/
├── Tests/TestResources/
├── Package.swift
└── Makefile
```

## 🚀 DEVELOPMENT PHASES

### Phase 1: Foundation (CURRENT)
**Priority**: Get basic infrastructure working
1. **Package.swift** - SPM setup with swift-protobuf dependency
2. **Core Module** - Error types and basic utilities
3. **Lexer Module** - Token definitions and basic tokenizer
4. **Basic Tests** - Test infrastructure setup

### Phase 2: Core Parsing
**Priority**: Build the parsing pipeline
1. **Complete Lexer** - Full proto3 tokenization
2. **Parser Module** - AST construction
3. **Integration Tests** - End-to-end parsing

### Phase 3: Descriptor Building
**Priority**: Generate final output
1. **DescriptorBuilder Module** - AST to swift-protobuf conversion
2. **Dependency Resolution** - Import handling
3. **Public API** - Clean external interface

### Phase 4: Polish
**Priority**: Production readiness
1. **Performance optimization**
2. **Error message improvement** 
3. **Documentation**
4. **CI/CD setup**

## ⚡ QUICK COMMANDS
- `make start-session` - Begin work (shows status + reference)
- `make status` - Check current progress
- `make quick-ref` - Show architecture overview
- `make test` - Run all tests
- `make build` - Build project

## 🎯 FOCUS RULES
- **Single module at a time** - Complete one before starting next
- **MANDATORY TESTING** - Every new file MUST have tests (95%+ coverage)
- **Test as you go** - Write tests alongside implementation
- **Update status frequently** - Keep PROJECT_STATUS.md current
- **Start simple** - Basic functionality first, optimization later

## 🏁 DEFINITION OF DONE (per module)
- [ ] All planned files implemented
- [ ] Unit tests written and passing (95%+ coverage)
- [ ] Integration tests passing
- [ ] `make coverage` shows 95%+ for the module
- [ ] Integration with other modules working
- [ ] Documentation updated
- [ ] PROJECT_STATUS.md updated

---
**Next session**: Check PROJECT_STATUS.md for current focus!
