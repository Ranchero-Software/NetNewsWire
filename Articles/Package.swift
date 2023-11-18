// swift-tools-version:5.7.1
import PackageDescription

let package = Package(
    name: "Articles",
	platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(
            name: "Articles",
			type: .dynamic,
            targets: ["Articles"]),
    ],
    dependencies: [
		.package(url: "https://github.com/Ranchero-Software/RSCore.git", .upToNextMajor(from: "3.0.0")),
    ],
    targets: [
        .target(
            name: "Articles",
			dependencies: [
				"RSCore"
			]),
	]
)
