# Swift ProtoParser - Архитектурный Документ

## 1. Архитектурный Обзор

### Цель
Нативная Swift библиотека для парсинга Protocol Buffers (.proto) файлов в ProtoDescriptors без внешних зависимостей от protoc.

### Принципы Архитектуры
- **Модульность**: Четкое разделение ответственности между компонентами
- **Читаемость**: Приоритет понимания кода над микро-оптимизациями  
- **Переиспользование**: Максимальное использование swift-protobuf компонентов
- **Стабильность**: Минимизация breaking changes в публичном API
- **Тестируемость**: Архитектура, ориентированная на тестирование

## 2. Общая Архитектура

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ .proto Files│───▶│ Dependency  │───▶│    Lexer    │───▶│   Parser    │───▶│ Descriptor  │
│   + Deps    │    │  Resolver   │    │   Module    │    │   Module    │    │   Builder   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                          │                   │                   │                   │
                          ▼                   ▼                   ▼                   ▼
                   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
                   │  Resolved   │    │   Tokens    │    │     AST     │    │ Proto       │
                   │   Files     │    │             │    │   Nodes     │    │ Descriptors │
                   └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

### Поток Данных
1. **Input**: .proto файл + папки с зависимостями
2. **DependencyResolver**: Разрешение импортов → [ResolvedProtoFile]
3. **Lexer**: Токенизация каждого файла → [Token]
4. **Parser**: AST построение → [ProtoAST]  
5. **Builder**: Descriptor создание с учетом зависимостей → ProtoDescriptor
6. **Output**: Готовые swift-protobuf дескрипторы

## 3. Модульная Структура

### 3.1 Основные Модули

```
SwiftProtoParser/
├── Core/                     # Основные типы и утилиты
│   ├── ProtoParseError.swift
│   ├── ProtoVersion.swift
│   └── Extensions/
├── DependencyResolver/       # Разрешение импортов
│   ├── DependencyResolver.swift
│   ├── ImportResolver.swift
│   ├── FileSystemScanner.swift
│   ├── ResolvedProtoFile.swift
│   └── ResolverError.swift
├── Lexer/                    # Токенизация
│   ├── Token.swift
│   ├── Lexer.swift
│   ├── KeywordRecognizer.swift
│   └── LexerError.swift
├── Parser/                   # AST построение  
│   ├── AST/
│   │   ├── ProtoAST.swift
│   │   ├── MessageNode.swift
│   │   ├── FieldNode.swift
│   │   └── ServiceNode.swift
│   ├── Parser.swift
│   ├── ParserState.swift
│   └── ParserError.swift
├── DescriptorBuilder/        # Конвертация в Descriptors
│   ├── DescriptorBuilder.swift
│   ├── MessageDescriptorBuilder.swift
│   ├── FieldDescriptorBuilder.swift
│   └── BuilderError.swift
└── Public/                   # Публичный API
    ├── SwiftProtoParser.swift
    └── Extensions/
```

### 3.2 Детализация Модулей

#### Core Модуль
**Ответственность**: Общие типы, утилиты, ошибки
- `ProtoParseError` - главный error enum для публичного API
- `ProtoVersion` - поддержка только Proto3
- Расширения для стандартных типов

#### DependencyResolver Модуль
**Ответственность**: Разрешение импортов и зависимостей
- `DependencyResolver` - основной класс для разрешения зависимостей
- `ImportResolver` - обработка `import` директив в .proto файлах
- `FileSystemScanner` - поиск .proto файлов в файловой системе
- `ResolvedProtoFile` - модель разрешенного файла с метаданными
- Обработка циклических зависимостей и кеширование

#### Lexer Модуль  
**Ответственность**: Токенизация .proto файлов
- `Token` - все типы токенов (keywords, identifiers, literals)
- `Lexer` - основной класс токенизации
- `KeywordRecognizer` - распознавание proto3 ключевых слов
- Обработка комментариев, whitespace, строковых литералов

#### Parser Модуль
**Ответственность**: Построение AST из токенов
- **AST подмодуль** - все узлы синтаксического дерева
- `Parser` - рекурсивный парсер с предиктивным анализом
- `ParserState` - состояние парсера для error recovery
- Валидация синтаксиса Proto3

#### DescriptorBuilder Модуль
**Ответственность**: Конвертация AST в swift-protobuf дескрипторы
- `DescriptorBuilder` - главный построитель
- Специализированные билдеры для каждого типа дескриптора
- Интеграция с `Google.Protobuf.*` типами
- Семантическая валидация

#### Public Модуль
**Ответственность**: Публичный API
- `SwiftProtoParser` - главный класс с функцией `parseProtoFile`
- Удобные расширения и утилиты

## 4. API Дизайн

### 4.1 Публичный API

```swift
public struct SwiftProtoParser {
    /// Основная функция парсинга .proto файла
    public static func parseProtoFile(_ filePath: String) -> Result<ProtoDescriptor, ProtoParseError>
    
    /// Парсинг из строки (для тестирования/in-memory)
    public static func parseProtoString(_ content: String) -> Result<ProtoDescriptor, ProtoParseError>
    
    /// Парсинг с поддержкой зависимостей из папок
    public static func parseProtoFile(
        _ mainFilePath: String,
        importPaths: [String] = [],
        options: ParseOptions = .default
    ) -> Result<ProtoDescriptor, ProtoParseError>
    
    /// Парсинг папки с .proto файлами (все файлы как зависимости)
    public static func parseProtoDirectory(
        _ directoryPath: String,
        mainFile: String? = nil,
        options: ParseOptions = .default
    ) -> Result<[ProtoDescriptor], ProtoParseError>
}

public struct ParseOptions {
    public static let `default` = ParseOptions()
    public let validateSemantics: Bool = true
    public let strictMode: Bool = false
    public let resolveDependencies: Bool = true
    public let allowMissingImports: Bool = false
}
```

### 4.2 Обработка Ошибок

```swift
public enum ProtoParseError: Error, LocalizedError {
    case fileNotFound(String)
    case dependencyResolutionError(ResolverError, importPath: String)
    case circularDependency([String])
    case lexicalError(LexerError, file: String, line: Int, column: Int)
    case syntaxError(ParserError, file: String, line: Int, column: Int)  
    case semanticError(BuilderError, context: String)
    case ioError(underlying: Error)
    
    public var errorDescription: String? {
        // Детальные сообщения с локализацией ошибок
    }
}
```

### 4.3 Межмодульные Интерфейсы

```swift
// DependencyResolver → Lexer
internal func resolveDependencies(
    mainFile: String, 
    importPaths: [String]
) -> Result<[ResolvedProtoFile], ResolverError>

// Lexer → Parser
internal func tokenize(_ file: ResolvedProtoFile) -> Result<[Token], LexerError>

// Parser → DescriptorBuilder  
internal func parse(_ tokens: [Token]) -> Result<ProtoAST, ParserError>

// DescriptorBuilder → Public
internal func buildDescriptor(
    mainAST: ProtoAST, 
    dependencies: [ProtoAST]
) -> Result<ProtoDescriptor, BuilderError>
```

## 5. Технологический Стек

### 5.1 Основные Технологии
- **Swift 5.9+** - минимальная версия
- **swift-protobuf 1.29.0+** - для ProtoDescriptor типов
- **Swift Package Manager** - управление зависимостями

### 5.2 Поддерживаемые Платформы
- **macOS 12.0+**
- **iOS 15.0+** 
- **Linux** (все поддерживаемые Swift дистрибутивы)

### 5.3 Инструменты Разработки
- **swift-format** - форматирование кода
- **XCTest** - фреймворк тестирования
- **swift test** - запуск тестов
- **Makefile** - автоматизация сборки

## 6. Производительность и Оптимизация

### 6.1 Целевые Метрики
- **Производительность**: В пределах 20% от protoc
- **Memory Usage**: Профилирование с помощью Instruments
- **Throughput**: Benchmark тесты на больших .proto файлах

### 6.2 Стратегии Оптимизации
1. **Ленивая инициализация** AST узлов
2. **String interning** для повторяющихся идентификаторов  
3. **Оптимизированные коллекции** для токенов
4. **Copy-on-Write** семантика для больших структур

### 6.3 Профилирование
- Benchmark тесты в `Tests/BenchmarkTests/`
- Memory profiling с XCTest
- Performance regression detection

## 7. Тестовая Стратегия

### 7.1 Покрытие
- **Минимум 95%** покрытие кода
- **Unit тесты** для каждого модуля
- **Integration тесты** для полного pipeline
- **Performance тесты** против protoc

### 7.2 Структура Тестов
```
Tests/
├── SwiftProtoParserTests/
│   ├── DependencyResolverTests/
│   ├── LexerTests/
│   ├── ParserTests/ 
│   ├── DescriptorBuilderTests/
│   └── IntegrationTests/
├── BenchmarkTests/
└── TestResources/
    ├── SingleProtoFiles/
    └── DependencyTestCases/
        ├── SimpleImports/
        ├── CircularDeps/
        └── MissingDeps/
```

### 7.3 Тестовые Данные
- **Простые .proto файлы** для unit тестов
- **Сложные real-world файлы** для интеграционных тестов
- **Edge cases** для граничных условий
- **Error cases** для тестирования обработки ошибок

## 8. Принципы Разработки

### 8.1 Кодовая База
- **Явные типы** предпочтительнее неявных
- **Малые функции** с единственной ответственностью
- **Immutable структуры** где возможно
- **Protocol-oriented design** для расширяемости

### 8.2 Error Handling
- **Fail-fast** подход для критических ошибок
- **Детальные сообщения** с позицией в файле
- **Error recovery** для продолжения парсинга после ошибок
- **Structured logging** для диагностики

### 8.3 Документация
- **DocC комментарии** для всех публичных API
- **Usage examples** в документации
- **Architecture Decision Records** для важных решений
- **Contributing guide** для участников

## 9. Работа с Зависимостями

### 9.1 Типы Импортов
```swift
// Стандартные Google импорты
import "google/protobuf/timestamp.proto";
import "google/protobuf/duration.proto";

// Пользовательские импорты  
import "user/profile.proto";
import "common/types.proto";
```

### 9.2 Стратегии Поиска
1. **Относительные пути**: от текущего .proto файла
2. **Import paths**: из указанных директорий  
3. **Стандартные локации**: well-known types от Google
4. **Кеширование**: переиспользование уже разрешенных файлов

### 9.3 Разрешение Конфликтов
- **Duplicate imports**: игнорирование повторных импортов
- **Version conflicts**: ошибка с детальным описанием
- **Circular dependencies**: обнаружение и ошибка
- **Missing imports**: опциональная ошибка или предупреждение

### 9.4 Примеры Использования API

```swift
// Простой случай - один файл
let result = SwiftProtoParser.parseProtoFile("user.proto")

// С зависимостями в папках
let result = SwiftProtoParser.parseProtoFile(
    "main.proto",
    importPaths: ["./protos", "./vendor/protos"]
)

// Парсинг всей папки
let results = SwiftProtoParser.parseProtoDirectory(
    "./protos",
    mainFile: "api.proto"
)
```

## 10. Интеграция с swift-protobuf

### 10.1 Используемые Типы
```swift
import SwiftProtobuf

// Основные дескрипторы
- Google.Protobuf.FileDescriptorProto
- Google.Protobuf.DescriptorProto  
- Google.Protobuf.FieldDescriptorProto
- Google.Protobuf.ServiceDescriptorProto
```

### 10.2 Стратегия Интеграции
- **Максимальное переиспользование** существующих типов
- **Конвертация AST → Protobuf типы** в DescriptorBuilder
- **Валидация** соответствия официальной спецификации
- **Backward compatibility** с существующими проектами

## 11. Развертывание и Релизы

### 11.1 Versioning
- **Semantic Versioning 2.0** (major.minor.patch)
- **API stability** гарантии для major версий
- **Deprecation warnings** за одну major версию

### 11.2 Distribution
- **GitHub Releases** с changelog
- **Swift Package Index** регистрация
- **Swift Package Manager** основной способ установки
- **MIT License** для максимальной совместимости
