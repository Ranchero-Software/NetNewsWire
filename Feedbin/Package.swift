// swift-tools-version: 5.10

import PackageDescription

let package = Package(
	name: "Feedbin",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "Feedbin",
			targets: ["Feedbin"]),
	],
	dependencies: [
		.package(path: "../Parser"),
	],

	targets: [
		.target(
			name: "Feedbin",
			dependencies: [
				"Parser"
			],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]
		),
		.testTarget(
			name: "FeedbinTests",
			dependencies: ["Feedbin"]),
	]
)
