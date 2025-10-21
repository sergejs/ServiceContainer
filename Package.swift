// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ServiceContainer",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .watchOS(.v9),
        .tvOS(.v16),
    ],
    products: [
        .library(
            name: "ServiceContainer",
            targets: ["ServiceContainer"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ServiceContainer",
            dependencies: []
        ),
        .testTarget(
            name: "ServiceContainerTests",
            dependencies: ["ServiceContainer"]
        ),
    ]
)
