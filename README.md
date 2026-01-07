# swift-amqp

> ‼️ **Project Status: in active early development**
>
> ‼️️ **API will change rapidly (as rapidly as it can for a hobby project). Do not use in production.**
>
> ️‼️️️ **There are still things which I might change fundamentally here. The current implementation doesn't follow specification to the letter.**

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
// swift-tools-version:6.2
import PackageDescription

let package = Package(
  name: "MyPackage",
  dependencies: [
    .package(
      url: "https://github.com/nikolay-pv/swift-amqp.git",
      branch: "main"
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
