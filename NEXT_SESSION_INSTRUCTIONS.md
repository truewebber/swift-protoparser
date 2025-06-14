# NEXT SESSION INSTRUCTIONS

## 🎯 EVERY SESSION STARTS HERE

### 1. Get Context (30 seconds)
```bash
make start-session
```
This shows:
- Current project status
- Quick architecture reference
- What to do next

### 2. Check Specific Focus
```bash
cat PROJECT_STATUS.md
```
Look for the "CURRENT FOCUS" section - this tells you exactly what to work on.

### 3. Get Implementation Details
If working on a specific module, check:
```bash
cat docs/modules/CORE_MODULE.md        # For Core module
cat docs/modules/LEXER_MODULE.md       # For Lexer module
cat docs/modules/PARSER_MODULE.md      # For Parser module
```

### 4. Work on Current Task
- Follow the implementation order in the module docs
- Write tests alongside code
- Keep it simple - MVP first, optimize later

### 5. Before Ending Session
```bash
# Update your progress
vim PROJECT_STATUS.md
# Update the "CURRENT FOCUS" section
# Update the module completion percentages
# Add 2-3 bullet points to "LAST SESSION NOTES"
```

## 🚨 CRITICAL SUCCESS FACTORS

### Always Update Status
- **CURRENT FOCUS**: What's the next immediate task?
- **MODULE PROGRESS**: Update completion percentages
- **LAST SESSION NOTES**: 2-3 bullet points max

### One Module at a Time
- Complete Core before Lexer
- Complete Lexer before Parser
- Don't jump between modules

### Test as You Go
- **MANDATORY**: Write tests for EVERY file you create
- **TARGET**: Maintain 95%+ code coverage at all times
- Run `make test` and `make coverage` frequently
- NO new code without corresponding tests

## 📋 CURRENT PHASE 1 PRIORITY ORDER
1. **Package.swift** ✅ (Done)
2. **Core Module** - Start here next
3. **Lexer Module** - After Core is done
4. **Basic Integration Test** - After Lexer works

## 💡 QUICK TIPS
- Use `make build` to check compilation
- Use `make test` to run tests
- Use `make coverage` to check current coverage
- Use `make status` to see progress
- Keep docs in `docs/modules/` updated if you change plans

---
**Remember**: This conversation will be forgotten. Everything you need is in these files!
