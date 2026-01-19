//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-amqp open source project
//
// Copyright (c) 2024-2025 swift-amqp project authors
// Licensed under Apache License 2.0
//
// See LICENSE for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
// swift-tools-version: 6.2

import PackageDescription

let sharedSwiftSettings: [SwiftSetting] =
    [
        .enableUpcomingFeature("StrictConcurrency"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .defaultIsolation(nil),  // nonisolated by default, as recommended by https://developer.apple.com/videos/play/wwdc2025/268?time=1638
    ]

let package = Package(
    name: "swift-amqp",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        .library(
            name: "AMQP",
            targets: ["AMQP"]
        )
    ],
    traits: [
        .trait(
            name: "DebugNIOEventHandlers",
            description:
                "logs debug message for in/outbound frames (primary used to ease debugging in development)"
        ),
        .default(enabledTraits: []),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", .upToNextMajor(from: "2.67.0")),
        .package(url: "https://github.com/apple/swift-log", .upToNextMajor(from: "1.6.0")),
        .package(
            url: "https://github.com/apple/swift-nio-extras.git",
            .upToNextMajor(from: "1.25.0")
        ),
        .package(
            url: "https://github.com/apple/swift-collections.git",
            .upToNextMajor(from: "1.1.0")
        ),
        .package(
            url: "https://github.com/apple/swift-async-algorithms.git",
            .upToNextMajor(from: "1.0.0")
        ),
    ],
    targets: [
        .target(
            name: "AMQP",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(
                    name: "NIOExtras",
                    package: "swift-nio-extras",
                    condition: .when(traits: ["DebugNIOEventHandlers"])
                ),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
            swiftSettings: sharedSwiftSettings,
        ),
        .testTarget(
            name: "AMQPTests",
            dependencies: [
                "AMQP"
            ],
            resources: [.process("Resources")],
            swiftSettings: sharedSwiftSettings,
        ),
    ]
)
