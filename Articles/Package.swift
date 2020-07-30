// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Articles",
    products: [
        .library(
            name: "Articles",
            targets: ["Articles"]),
    ],
    dependencies: [
		.package(url: "https://github.com/Ranchero-Software/RSCore.git", .upToNextMajor(from: "1.0.0-beta1")),
    ],
    targets: [
        .target(
            name: "Articles",
            dependencies: []),
    ]
)
