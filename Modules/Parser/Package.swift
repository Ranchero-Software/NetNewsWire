// swift-tools-version:6.0

import PackageDescription

let package = Package(
	name: "Parser",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "Parser",
			targets: ["Parser"]),
	],
	dependencies: [
		.package(path: "../RSCore")
	],
	targets: [
		.target(
			name: "Parser",
			dependencies: [
				"RSCore"
			]
		),
		.testTarget(
			name: "ParserTests",
			dependencies: [
				"Parser"
			],
			resources: [.copy("Resources")]
		),
	]
)
