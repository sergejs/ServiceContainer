// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ServiceContainer",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "ServiceContainer",
            type: .dynamic,
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
