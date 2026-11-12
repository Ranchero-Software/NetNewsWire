// swift-tools-version:6.2
import PackageDescription

let package = Package(
	name: "Articles",
	platforms: [.macOS(.v15), .iOS(.v18)],
	products: [
		.library(
			name: "Articles",
			type: .dynamic,
			targets: ["Articles"])
	],
	dependencies: [
		.package(path: "../RSCore")
	],
	targets: [
		.target(
			name: "Articles",
			dependencies: [
				"RSCore"
			],
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances")
			]),
		.testTarget(
			name: "ArticlesTests",
			dependencies: ["Articles"])
	]
)
