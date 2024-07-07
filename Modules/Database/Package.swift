// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Database",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "Database",
			targets: ["Database"]
		)
	],
	dependencies: [
		.package(path: "../FMDB"),
	],
	targets: [
		.target(
			name: "Database",
			dependencies: [
				"FMDB"
			],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]
		),
		.testTarget(
			name: "DatabaseTests",
			dependencies: ["Database"]),
	]
)
