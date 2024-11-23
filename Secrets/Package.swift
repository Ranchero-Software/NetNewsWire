// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Secrets",
	platforms: [.macOS(.v13), .iOS(.v16)],
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
