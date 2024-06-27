// swift-tools-version: 5.10

import PackageDescription

let package = Package(
	name: "AppConfig",
	products: [
		.library(
			name: "AppConfig",
			targets: ["AppConfig"]),
	],
	targets: [
		.target(
			name: "AppConfig",
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]
		),
		.testTarget(
			name: "AppConfigTests",
			dependencies: ["AppConfig"]),
	]
)
