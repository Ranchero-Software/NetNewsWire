// swift-tools-version:5.10
import PackageDescription

let package = Package(
	name: "RSWeb",
	platforms: [.macOS(.v13), .iOS(.v17)],
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
			]
			//swiftSettings: [.unsafeFlags(["-warnings-as-errors"])]
		),
		.testTarget(
			name: "RSWebTests",
			dependencies: ["RSWeb"])
	]
)
