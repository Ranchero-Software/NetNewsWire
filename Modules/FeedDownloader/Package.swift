// swift-tools-version: 5.10

import PackageDescription

let package = Package(
	name: "FeedDownloader",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "FeedDownloader",
			targets: ["FeedDownloader"]),
	],
	dependencies: [
		.package(path: "../Web"),
		.package(path: "../FoundationExtras"),
	],
	targets: [
		.target(
			name: "FeedDownloader",
			dependencies: [
				"Web",
				"FoundationExtras"
			],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]
		),
		.testTarget(
			name: "FeedDownloaderTests",
			dependencies: ["FeedDownloader"]),
	]
)
