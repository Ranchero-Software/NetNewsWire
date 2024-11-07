// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "RSWeb",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
        .library(
            name: "RSWeb",
            type: .dynamic,
            targets: ["RSWeb"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "RSWeb",
			resources: [.copy("UTS46/uts46")],
			swiftSettings: [.define("SWIFT_PACKAGE")]),
        .testTarget(
            name: "RSWebTests",
            dependencies: ["RSWeb"]),
    ]
)
