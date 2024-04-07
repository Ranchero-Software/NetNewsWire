// swift-tools-version: 5.10

import PackageDescription

let package = Package(
	name: "LocalAccount",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "LocalAccount",
			targets: ["LocalAccount"]),
	],
	dependencies: [
		.package(path: "../Parser"),
		.package(path: "../Web"),
	],
	targets: [
		.target(
			name: "LocalAccount",
			dependencies: [
				"Parser",
				"Web"
			],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]
		),
		.testTarget(
			name: "LocalAccountTests",
			dependencies: ["LocalAccount"]),
	]
)
