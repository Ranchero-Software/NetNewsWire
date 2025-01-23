// swift-tools-version:5.10

import PackageDescription

let package = Package(
	name: "RSWeb",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "RSWeb",
			type: .dynamic,
			targets: ["RSWeb"])
	],
	dependencies: [
		.package(path: "../Parser"),
		.package(path: "../RSCore")
	],
	targets: [
		.target(
			name: "RSWeb",
			dependencies: [
				"Parser",
				"RSCore"
			],
			swiftSettings: [.unsafeFlags(["-warnings-as-errors"])]
		),
		.testTarget(
			name: "RSWebTests",
			dependencies: ["RSWeb"])
	]
)
