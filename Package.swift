// swift-tools-version:5.9
import PackageDescription

let package = Package(
	name: "SwiftProtoParser",
	platforms: [
		.macOS(.v13),
		.iOS(.v16),
	],
	products: [
		.library(
			name: "SwiftProtoParser",
			targets: ["SwiftProtoParser"]
		),
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-protobuf.git", from: "1.25.0"),
	],
	targets: [
		.target(
			name: "SwiftProtoParser",
			dependencies: [
				.product(name: "SwiftProtobuf", package: "swift-protobuf"),
			]
		),
		.testTarget(
			name: "SwiftProtoParserTests",
			dependencies: ["SwiftProtoParser"]
		),
	]
)

// Project structure:
/*
SwiftProtoParser/
├── Package.swift
├── README.md
├── Sources/
│   └── SwiftProtoParser/
│       ├── Core/
│       │   ├── Lexer/
│       │   │   ├── Token.swift
│       │   │   ├── TokenType.swift
│       │   │   └── Lexer.swift
│       │   ├── Parser/
│       │   │   ├── Parser.swift
│       │   │   ├── AST/
│       │   │   │   ├── Node.swift
│       │   │   │   ├── FileNode.swift
│       │   │   │   ├── MessageNode.swift
│       │   │   │   ├── EnumNode.swift
│       │   │   │   ├── ServiceNode.swift
│       │   │   │   └── FieldNode.swift
│       │   │   └── Errors/
│       │   │       └── ParserError.swift
│       │   ├── Validator/
│       │   │   ├── Validator.swift
│       │   │   └── ValidationError.swift
│       │   └── Generator/
│       │       ├── DescriptorGenerator.swift
│       │       └── SourceInfoGenerator.swift
│       ├── Models/
│       │   ├── Context.swift
│       │   ├── SymbolTable.swift
│       │   └── ImportResolver.swift
│       └── Public/
│           ├── ProtoParser.swift
│           ├── Configuration.swift
│           └── ParserError.swift
└── Tests/
	└── SwiftProtoParserTests/
		├── LexerTests/
		│   └── LexerTests.swift
		├── ParserTests/
		│   └── ParserTests.swift
		├── ValidatorTests/
		│   └── ValidatorTests.swift
		└── GeneratorTests/
			└── DescriptorGeneratorTests.swift
*/
