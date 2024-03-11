// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Articles",
	platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "Articles",
			type: .dynamic,
            targets: ["Articles"]),
    ],
    dependencies: [
		.package(url: "https://github.com/Ranchero-Software/RSCore.git", .upToNextMinor(from: "1.0.0")),
    ],
    targets: [
        .target(
            name: "Articles",
			dependencies: [
				"RSCore"
			]),
	]
)
