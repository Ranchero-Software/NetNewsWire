// swift-tools-version: 5.10

import PackageDescription

let package = Package(
	name: "ReaderAPI",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "ReaderAPI",
			targets: ["ReaderAPI"]),
	],
	dependencies: [
		.package(path: "../FoundationExtras")
	],
	targets: [
		.target(
			name: "ReaderAPI",
			dependencies: ["FoundationExtras"],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]
		),
		.testTarget(
			name: "ReaderAPITests",
			dependencies: ["ReaderAPI"]),
	]
)
