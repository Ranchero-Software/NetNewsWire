// swift-tools-version:6.2
import PackageDescription

let package = Package(
	name: "FeedFinder",
	platforms: [.macOS(.v15), .iOS(.v17)],
	products: [
		.library(
			name: "FeedFinder",
			type: .dynamic,
			targets: ["FeedFinder"])
	],
	dependencies: [
		.package(path: "../RSWeb"),
		.package(path: "../RSParser"),
		.package(path: "../RSCore")
	],
	targets: [
		.target(
			name: "FeedFinder",
			dependencies: [
				"RSWeb",
				"RSParser",
				"RSCore"
			],
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances"),
				.unsafeFlags(["-warnings-as-errors"])
			]
		),
		.testTarget(
			name: "FeedFinderTests",
			dependencies: ["FeedFinder"])
	]
)
