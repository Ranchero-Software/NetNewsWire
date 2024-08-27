// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "Parser",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		// Products define the executables and libraries a package produces, and make them visible to other packages.
		.library(
			name: "Parser",
			type: .dynamic,
			targets: ["Parser"]),
		.library(
			name: "SAX",
			type: .dynamic,
			targets: ["SAX"])
	],
	dependencies: [
	],
	targets: [
		// Targets are the basic building blocks of a package. A target can define a module or a test suite.
		// Targets can depend on other targets in this package, and on products in packages this package depends on.
		.target(
			name: "Parser",
			dependencies: [
				"SAX"
			],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]),
		.target(
			name: "SAX",
			dependencies: [],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]),
		.testTarget(
			name: "ParserTests",
			dependencies: ["Parser"],
			exclude: ["Info.plist"],
			resources: [.copy("Resources")]),
	]
)

