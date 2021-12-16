// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ServiceContainer",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .watchOS(.v6),
        .tvOS(.v13),
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
