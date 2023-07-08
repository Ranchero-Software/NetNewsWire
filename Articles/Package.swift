// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Articles",
	platforms: [.macOS(SupportedPlatform.MacOSVersion.v11), .iOS(SupportedPlatform.IOSVersion.v14)],
    products: [
        .library(
            name: "Articles",
			type: .dynamic,
            targets: ["Articles"]),
    ],
    dependencies: [
		.package(url: "https://github.com/Ranchero-Software/RSCore.git", .upToNextMajor(from: "2.0.1")),
    ],
    targets: [
        .target(
            name: "Articles",
			dependencies: [
				"RSCore"
			]),
	]
)
