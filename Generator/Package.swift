// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Generator",

    dependencies: [
        .package(url: "https://github.com/groue/GRMustache.swift", from: "4.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Generator",
            dependencies: [.product(name: "Mustache", package: "GRMustache.swift")],
            resources: [.copy("Resources")]
        ),
    ]
)
