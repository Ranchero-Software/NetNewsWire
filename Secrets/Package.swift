// swift-tools-version:5.7.1
import PackageDescription

let package = Package(
    name: "Secrets",
    platforms: [.macOS(SupportedPlatform.MacOSVersion.v11), .iOS(SupportedPlatform.IOSVersion.v14)],
    products: [
        .library(
            name: "Secrets",
            type: .dynamic,
            targets: ["Secrets"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Secrets",
            dependencies: []
        )
    ]
)
