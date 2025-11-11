// swift-tools-version: 6.2
import PackageDescription

let package = Package(
	name: "CloudKitSync",
	platforms: [.macOS(.v26), .iOS(.v26)],
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
			swiftSettings: [.swiftLanguageMode(.v5)]
		),
		.testTarget(
			name: "CloudKitSyncTests",
			dependencies: ["CloudKitSync"]
		),
	]
)
