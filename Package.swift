// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-amqp",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        .library(
            name: "AMQP",
            targets: ["AMQP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", .upToNextMajor(from: "2.67.0")),
    ],
    targets: [
        .target(
            name: "AMQP"),
        .testTarget(
            name: "AMQPTests",
            dependencies: ["AMQP"]
        ),
    ]
)
