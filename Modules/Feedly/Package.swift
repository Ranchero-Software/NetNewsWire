// swift-tools-version: 5.10

import PackageDescription

let package = Package(
	name: "Feedly",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "Feedly",
			targets: ["Feedly"]),
	],
	dependencies: [
		.package(path: "../Parser"),
		.package(path: "../Articles"),
		.package(path: "../Secrets"),
		.package(path: "../Core"),
		.package(path: "../SyncDatabase"),
		.package(path: "../Web"),
	],
	targets: [
		.target(
			name: "Feedly",
			dependencies: [
				"Parser",
				"Articles",
				"Secrets",
				"Core",
				"SyncDatabase",
				"Web"
			],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]
		),
		.testTarget(
			name: "FeedlyTests",
			dependencies: ["Feedly"]),
	]
)
