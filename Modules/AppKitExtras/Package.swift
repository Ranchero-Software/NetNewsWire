// swift-tools-version: 5.10

import PackageDescription

let package = Package(
	name: "AppKitExtras",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "AppKitExtras",
			type: .dynamic,
			targets: ["AppKitExtras"]),
	],
	dependencies: [
		.package(path: "../FoundationExtras")
	],
	targets: [
		.target(
			name: "AppKitExtras",
			dependencies: [
				"FoundationExtras",
			],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]
		),
		.testTarget(
			name: "AppKitExtrasTests",
			dependencies: ["AppKitExtras"]),
	]
)
