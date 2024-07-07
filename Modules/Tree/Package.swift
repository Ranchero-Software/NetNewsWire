// swift-tools-version: 5.10

import PackageDescription

let package = Package(
	name: "Tree",
	products: [
		.library(
			name: "Tree",
			targets: ["Tree"]),
	],
	targets: [
		.target(
			name: "Tree",
			dependencies: [],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]
		),
		.testTarget(
			name: "TreeTests",
			dependencies: ["Tree"])
	]
)
