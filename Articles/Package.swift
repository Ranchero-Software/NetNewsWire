// swift-tools-version: 5.10
import PackageDescription

let package = Package(
	name: "Articles",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "Articles",
			type: .dynamic,
			targets: ["Articles"]),
	],
	dependencies: [
		.package(path: "../FoundationExtras")
	],
	targets: [
		.target(
			name: "Articles",
			dependencies: [
				"FoundationExtras"
			],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]
		),
	]
)
