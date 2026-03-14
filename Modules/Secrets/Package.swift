// swift-tools-version:6.2
import PackageDescription

let package = Package(
	name: "Secrets",
	platforms: [.macOS(.v15), .iOS(.v26)],
	products: [
		.library(
			name: "Secrets",
			type: .dynamic,
			targets: ["Secrets"]
		)
	],
	dependencies: [
		.package(path: "../ErrorLog"),
		.package(path: "../RSCore")
	],
	targets: [
		.target(
			name: "Secrets",
			dependencies: [
				"ErrorLog",
				"RSCore"
			],
			exclude: ["SecretKey.swift.gyb"],
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances"),
				.unsafeFlags(["-warnings-as-errors"])
			]
		)
	]
)
