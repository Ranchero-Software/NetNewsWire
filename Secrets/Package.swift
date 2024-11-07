// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "Secrets",
	platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "Secrets",
			type: .dynamic,
            targets: ["Secrets"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Secrets",
            dependencies: []
        )
    ]
)
