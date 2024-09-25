// swift-tools-version: 5.10

import PackageDescription

let package = Package(
	name: "NewsBlur",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "NewsBlur",
			targets: ["NewsBlur"]),
	],
	dependencies: [
		.package(path: "../Web"),
		.package(path: "../Secrets"),
	],
	targets: [
		.target(
			name: "NewsBlur",
			dependencies: [
				"Web",
				"Secrets"
			],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]
		),
		.testTarget(
			name: "NewsBlurTests",
			dependencies: ["NewsBlur"]),
	]
)
