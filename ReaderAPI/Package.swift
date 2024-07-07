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
		.package(path: "../FoundationExtras"),
		.package(path: "../Web"),
		.package(path: "../Secrets"),
		.package(path: "../CommonErrors"),
	],
	targets: [
		.target(
			name: "ReaderAPI",
			dependencies: [
				"FoundationExtras",
				"Web",
				"Secrets",
				"CommonErrors"
			],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]
		),
		.testTarget(
			name: "ReaderAPITests",
			dependencies: ["ReaderAPI"]),
	]
)
