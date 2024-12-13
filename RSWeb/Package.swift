// swift-tools-version:5.7

import PackageDescription

let package = Package(
	name: "RSWeb",
	platforms: [.macOS(.v13), .iOS(.v16)],
	products: [
		.library(
			name: "RSWeb",
			type: .dynamic,
			targets: ["RSWeb"]),
	],
	dependencies: [
		.package(url: "https://github.com/Ranchero-Software/RSParser.git", .upToNextMinor(from: "2.0.2")),
		.package(path: "../Core")
	],
	targets: [
		.target(
			name: "RSWeb",
			dependencies: [
				"RSParser",
				"Core"
			],
			resources: [.copy("UTS46/uts46")],
			swiftSettings: [.define("SWIFT_PACKAGE")]),
		.testTarget(
			name: "RSWebTests",
			dependencies: [
				"RSWeb",
				"RSParser",
				"Core"
			]),
	]
)
