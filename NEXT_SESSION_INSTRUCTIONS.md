# Next Session Instructions

## Current Status
- **Tests**: 792 passing (79.89% coverage) - **КРИТИЧЕСКИ НУЖНО 95%+ ДЛЯ КАЖДОГО ФАЙЛА**
- **Progress**: 98% complete
- **Last Completed**: Performance & Caching System ✅

## Session Startup
```bash
make start-session
make test    # Verify 792 tests passing
make coverage # Check coverage gaps - TARGET: 95%+ per file
```

## Next Priority: КРИТИЧЕСКОЕ УЛУЧШЕНИЕ ПОКРЫТИЯ ДО 95%+ ДЛЯ КАЖДОГО ФАЙЛА

### **CRITICAL PRIORITY**: Улучшение покрытия до 95%+ для КАЖДОГО файла

**Проблемные файлы требующие КРИТИЧЕСКОГО внимания (95%+ стандарт):**
1. **PerformanceBenchmark.swift**: 23.94% → **95%+** (КРИТИЧНО! +71% нужно)
2. **DescriptorBuilder.swift**: 32.88% → **95%+** (КРИТИЧНО! +62% нужно)
3. **PerformanceCache.swift**: 42.00% → **95%+** (КРИТИЧНО! +53% нужно)
4. **FieldDescriptorBuilder.swift**: 40.79% → **95%+** (КРИТИЧНО! +54% нужно)
5. **IncrementalParser.swift**: 61.86% → **95%+** (ВАЖНО! +33% нужно)
6. **Parser.swift**: 89.24% → **95%+** (Улучшить +6%)
7. **SwiftProtoParser.swift**: 84.26% → **95%+** (Улучшить +11%)

**МАСШТАБ РАБОТЫ:**
- Добавить **~100-150 новых тестов** для достижения 95% по всем файлам
- Comprehensive edge case coverage для всех неохваченных функций
- Полное покрытие error handling во всех компонентах
- Performance stress тесты и граничные условия
- Integration edge cases и сложные сценарии

**ЦЕЛЬ**: Regions/Functions/Lines coverage 95%+ для КАЖДОГО файла без исключений

### **HIGH PRIORITY**: После достижения 95% покрытия во всех файлах
1. **CLI tool** для валидации proto файлов
2. **Comprehensive API documentation** с DocC
3. **Integration examples** и туториалы
4. **Advanced error reporting** с указанием строк
5. **Production deployment guide**

### Option D: Production Polish (MEDIUM PRIORITY)
**Tasks**:
1. **API documentation** with DocC
2. **CLI tool** for proto validation
3. **Integration examples**
4. **Large file optimization** (>10MB)

## Requirements
- **ПЕРВООЧЕРЕДНО**: Поднять покрытие до 95%+ (regions & functions)
- **Maintain**: 792+ tests, NO regressions
- **Quality focus**: Comprehensive edge case coverage
- **Performance module focus**: Новые модули требуют больше тестов

## Architecture Status
```
✅ Core, Lexer, Parser, DependencyResolver (нужно улучшить до 95%+)
✅ Public API - Complete with dependency resolution (84% → 95%+)
🚨 Performance modules - КРИТИЧЕСКИ низкое покрытие (23-61% → 95%+)! 
🚨 DescriptorBuilder - Критически низкое покрытие (33% → 95%+)
🚨 URGENT: Нужно добавить 100-150 тестов для достижения 95%+ во всех файлах
🚨 СТАНДАРТ: Каждый файл должен иметь 95%+ regions/functions/lines coverage
```

## Development Commands
```bash
# Coverage focus - TARGET 95%+ per file
make coverage | grep -E "(23\.|32\.|42\.|40\.|61\.|84\.|89\.)" # Problem files
swift test --filter "Performance" --enable-code-coverage
swift test --filter "DescriptorBuilder" --enable-code-coverage

# Per-file coverage analysis
xcrun llvm-cov show .build/arm64-apple-macosx/debug/SwiftProtoParserPackageTests.xctest/Contents/MacOS/SwiftProtoParserPackageTests -instr-profile .build/arm64-apple-macosx/debug/codecov/merged.profdata Sources/SwiftProtoParser/Performance/PerformanceBenchmark.swift

# Memory validation  
swift test --sanitize=address

# Documentation generation
swift package generate-documentation
```

---
**Status**: **КРИТИЧЕСКАЯ ЗАДАЧА - УЛУЧШЕНИЕ ПОКРЫТИЯ ТЕСТОВ**
**Next Target**: Достичь 95%+ regions/functions coverage, затем CLI и документация
