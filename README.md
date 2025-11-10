# swift-amqp

This is AMQP 0-9-1 client library written in Swift.

## Features

- swift native
- async first
- swift 6 by default
- cross-platform

### Missing protocol features

- TLS (SSL) is not currently supported but should be possible to workaround

## Using swift-amqp in your project

Add this package as a dependency in a SwiftPM project:

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "MyPackage",
  dependencies: [
    .package(
      url: "https://github.com/nikolay-pv/swift-amqp.git",
      .upToNextMinor(from: "1.0.0")
    )
  ],
  targets: [
    .target(
      name: "MyTarget",
      dependencies: [
        .product(name: "AMQP", package: "swift-amqp")
      ]
    )
  ]
)
```
