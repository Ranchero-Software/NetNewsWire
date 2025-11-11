// swift-tools-version:6.2
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
		.package(path: "../RSParser"),
		.package(path: "../RSCore")
	],
	targets: [
		.target(
			name: "RSWeb",
			dependencies: [
				"RSParser",
				"RSCore"
			],
			swiftSettings: [
				.unsafeFlags(["-warnings-as-errors"]),
				.swiftLanguageMode(.v5)
			]
		),
		.testTarget(
			name: "RSWebTests",
			dependencies: ["RSWeb"])
	]
)
