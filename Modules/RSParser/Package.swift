// swift-tools-version:6.2
import PackageDescription

let package = Package(
	name: "RSParser",
	platforms: [.macOS(.v15), .iOS(.v17)],
	products: [
		.library(
			name: "RSParser",
			type: .dynamic,
			targets: ["RSParser"])
	],
	dependencies: [
		.package(url: "https://github.com/brentsimmons/Tidemark", from: "1.0.0"),
		.package(path: "../RSCore")
	],
	targets: [
		.target(
			name: "RSParser",
			dependencies: ["Tidemark", "RSCore"],
			swiftSettings: [
				.swiftLanguageMode(.v6),
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances")
			]),
		.testTarget(
			name: "RSParserTests",
			dependencies: ["RSParser"],
			resources: [.copy("Resources")],
			swiftSettings: [
				.swiftLanguageMode(.v6),
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances")
			]
		)
	]
)
