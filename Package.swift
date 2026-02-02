// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SwiftProtoParser",
  platforms: [
    .macOS(.v12),
    .iOS(.v15),
    .watchOS(.v8),
    .tvOS(.v15),
  ],
  products: [
    .library(
      name: "SwiftProtoParser",
      targets: ["SwiftProtoParser"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.33.0")
  ],
  targets: [
    .target(
      name: "SwiftProtoParser",
      dependencies: [
        .product(name: "SwiftProtobuf", package: "swift-protobuf")
      ],
      path: "Sources/SwiftProtoParser"
    ),
    .testTarget(
      name: "SwiftProtoParserTests",
      dependencies: [
        "SwiftProtoParser",
        .product(name: "SwiftProtobuf", package: "swift-protobuf"),
      ],
      path: "Tests/SwiftProtoParserTests",
      resources: [
        .copy("../TestResources")
      ]
    ),
  ]
)
