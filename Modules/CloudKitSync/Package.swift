// swift-tools-version: 5.10
import PackageDescription

let package = Package(
	name: "CloudKitSync",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "CloudKitSync",
			targets: ["CloudKitSync"]
		),
	],
	dependencies: [
		.package(path: "../RSCore")
	],
	targets: [
		.target(
			name: "CloudKitSync",
			dependencies: [
				"RSCore"
			],
		),
		.testTarget(
			name: "CloudKitSyncTests",
			dependencies: ["CloudKitSync"]
		),
	]
)
