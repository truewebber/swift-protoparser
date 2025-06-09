// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "SwiftProtoParser",
  platforms: [
    .macOS(.v12),
    .iOS(.v15),
  ],
  products: [
    .library(
      name: "SwiftProtoParser",
      targets: ["SwiftProtoParser"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.29.0")
  ],
  targets: [
    .target(
      name: "SwiftProtoParser",
      dependencies: [
        .product(name: "SwiftProtobuf", package: "swift-protobuf")
      ]
    ),
    .testTarget(
      name: "SwiftProtoParserTests",
      dependencies: ["SwiftProtoParser"]
    ),
  ]
)
