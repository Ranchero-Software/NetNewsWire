// swift-tools-version:6.2
import PackageDescription

let package = Package(
	name: "ArticlesDatabase",
	platforms: [.macOS(.v15), .iOS(.v26)],
	products: [
		.library(
			name: "ArticlesDatabase",
			type: .dynamic,
			targets: ["ArticlesDatabase"])
	],
	dependencies: [
		.package(path: "../Articles"),
		.package(path: "../RSCore"),
		.package(path: "../RSParser"),
		.package(path: "../RSDatabase")
	],
	targets: [
		.target(
			name: "ArticlesDatabase",
			dependencies: [
				"RSCore",
				"RSDatabase",
				"RSParser",
				"Articles"
			],
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances")
			]
		)
	]
)
