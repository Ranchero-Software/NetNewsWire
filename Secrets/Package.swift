// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Secrets",
	platforms: [.macOS(SupportedPlatform.MacOSVersion.v10_15), .iOS(SupportedPlatform.IOSVersion.v13)],
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
