// swift-tools-version: 5.10

import PackageDescription

let package = Package(
	name: "FeedFinder",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "FeedFinder",
			targets: ["FeedFinder"]),
	],
	dependencies: [
		.package(path: "../Web"),
		.package(path: "../Parser"),
		.package(path: "../FoundationExtras"),
		.package(path: "../CommonErrors"),
	],
	targets: [
		.target(
			name: "FeedFinder",
			dependencies: [
				"Parser",
				"Web",
				"FoundationExtras",
				"CommonErrors"
			],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]
		),
		.testTarget(
			name: "FeedFinderTests",
			dependencies: ["FeedFinder"]),
	]
)
