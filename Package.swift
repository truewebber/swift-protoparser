// swift-tools-version:5.3
import PackageDescription

let package = Package(
	name: "SwiftProtoParse",
	products: [
		.library(
			name: "SwiftProtoParse",
			targets: ["SwiftProtoParse"]
		),
	],
	dependencies: [
		.package(
			url: "https://github.com/apple/swift-protobuf.git",
			from: "1.0.0"
		),
	],
	targets: [
		.target(
			name: "SwiftProtoParse",
			dependencies: [
				.product(name: "SwiftProtobuf", package: "swift-protobuf")
			]
		),
		.testTarget(
			name: "SwiftProtoParseTests",
			dependencies: ["SwiftProtoParse"]
		),
	]
)
