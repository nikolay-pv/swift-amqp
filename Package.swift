// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-amqp",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        .library(
            name: "RabbitMQ",
            targets: ["RabbitMQ"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", .upToNextMajor(from: "2.67.0")),
        .package(url: "https://github.com/apple/swift-collections.git", .upToNextMajor(from: "1.1.0")),
    ],
    targets: [
        .target(
            name: "RabbitMQ",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "Collections", package: "swift-collections")
            ]
        ),
        .testTarget(
            name: "RabbitMQTests",
            dependencies: ["RabbitMQ"]
        ),
    ]
)
