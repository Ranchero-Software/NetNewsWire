// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "FoundationExtras",
	platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
         .library(
            name: "FoundationExtras",
            targets: ["FoundationExtras"]),
    ],
	targets: [
		.target(
			name: "FoundationExtras",
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]
		),
		.testTarget(
			name: "FoundationExtrasTests",
			dependencies: ["FoundationExtras"]),
	]
)
