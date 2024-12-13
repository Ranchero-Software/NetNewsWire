// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Core",
	platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(
            name: "Core",
            targets: ["Core"]),
    ],
    targets: [
        .target(
            name: "Core"),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"]
        ),
    ]
)
