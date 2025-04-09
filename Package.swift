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
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-amqp",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        .library(
            name: "AMQP",
            targets: ["AMQP"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", .upToNextMajor(from: "2.67.0")),
        .package(
            url: "https://github.com/apple/swift-nio-extras.git",
            .upToNextMajor(from: "1.25.0")
        ),
        .package(
            url: "https://github.com/apple/swift-collections.git",
            .upToNextMajor(from: "1.1.0")
        ),
    ],
    targets: [
        .target(
            name: "AMQP",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                // TODO: use traits when they will be here, for now just enable it for all
                .product(name: "NIOExtras", package: "swift-nio-extras"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "Collections", package: "swift-collections"),
            ]
        ),
        .testTarget(
            name: "AMQPTests",
            dependencies: [
                "AMQP",
                .product(name: "NIOExtras", package: "swift-nio-extras"),
            ]
        ),
    ]
)
