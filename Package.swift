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
    targets: [
        .target(
            name: "AMQP"),
        .testTarget(
            name: "AMQPTests",
            dependencies: ["AMQP"]
        ),
    ]
)
