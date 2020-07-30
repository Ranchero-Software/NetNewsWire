// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "SyncDatabase",
    products: [
        .library(
            name: "SyncDatabase",
            targets: ["SyncDatabase"]),
    ],
    dependencies: [
		.package(url: "https://github.com/Ranchero-Software/RSDatabase.git", .upToNextMajor(from: "1.0.0-beta1")),
    ],
    targets: [
        .target(
            name: "SyncDatabase",
            dependencies: []),
    ]
)
