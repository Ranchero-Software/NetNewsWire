// swift-tools-version: 5.10

import PackageDescription

let package = Package(
	name: "Images",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "Images",
			targets: ["Images"]),
	],
	dependencies: [
		.package(path: "../Core"),
		.package(path: "../Articles"),
		.package(path: "../Account")
	],
	targets: [
		.target(
			name: "Images",
			dependencies: [
				"Core",
				"Articles",
				"Account"
			],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]
		),
		.testTarget(
			name: "ImagesTests",
			dependencies: ["Images"]),
	]
)
