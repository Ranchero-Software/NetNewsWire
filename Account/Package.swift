// swift-tools-version: 5.10
import PackageDescription

let package = Package(
	name: "Account",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "Account",
			type: .dynamic,
			targets: ["Account"]),
	],
	dependencies: [
		.package(url: "https://github.com/Ranchero-Software/RSParser.git", .upToNextMajor(from: "2.0.2")),
		.package(path: "../Articles"),
		.package(path: "../ArticlesDatabase"),
		.package(path: "../Web"),
		.package(path: "../Secrets"),
		.package(path: "../Database"),
		.package(path: "../SyncDatabase"),
		.package(path: "../Core"),
		.package(path: "../CloudKitExtras")
	],
	targets: [
		.target(
			name: "Account",
			dependencies: [
				"RSParser",
				"Web",
				"Articles",
				"ArticlesDatabase",
				"Secrets",
				"SyncDatabase",
				"Database",
				"Core",
				"CloudKitExtras"
			],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]
		),
		.testTarget(
			name: "AccountTests",
			dependencies: ["Account"],
			resources: [
				.copy("JSON"),
			]),
	]
)
