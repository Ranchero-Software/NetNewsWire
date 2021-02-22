// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Articles",
	platforms: [.macOS(SupportedPlatform.MacOSVersion.v10_15), .iOS(SupportedPlatform.IOSVersion.v13)],
    products: [
        .library(
            name: "Articles",
			type: .dynamic,
            targets: ["Articles"]),
    ],
    dependencies: [
		.package(url: "https://github.com/Ranchero-Software/RSCore.git", .upToNextMajor(from: "1.0.0")),
    ],
    targets: [
        .target(
            name: "Articles",
			dependencies: [
				"RSCore"
			]),
	]
)
