// swift-tools-version: 5.10

import PackageDescription

let package = Package(
	name: "Web",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "Web",
			type: .dynamic,
			targets: ["Web"]),
	],
	targets: [
		.target(
			name: "Web",
			dependencies: [],
			swiftSettings: [
				.define("SWIFT_PACKAGE"),
				.enableExperimentalFeature("StrictConcurrency")
			]
		),
		.testTarget(
			name: "WebTests",
			dependencies: ["Web"]),
	]
)
