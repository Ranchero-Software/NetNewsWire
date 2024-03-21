// swift-tools-version: 5.10

import PackageDescription

let package = Package(
	name: "CloudKitExtras",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "CloudKitExtras",
			targets: ["CloudKitExtras"]),
	],
	dependencies: [
		.package(path: "../FoundationExtras")
	],
	targets: [
		.target(
			name: "CloudKitExtras",
			dependencies: [
				"FoundationExtras",
			],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]
		),
		.testTarget(
			name: "CloudKitExtrasTests",
			dependencies: ["CloudKitExtras"]),
	]
)
