// swift-tools-version:5.10

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
		.package(path: "../RSWeb"),
		.package(path: "../Articles"),
		.package(path: "../ArticlesDatabase"),
		.package(path: "../Secrets"),
		.package(path: "../SyncDatabase"),
		.package(path: "../RSCore"),
		.package(path: "../RSDatabase"),
		.package(path: "../Parser"),
	],
	targets: [
		.target(
			name: "Account",
			dependencies: [
				"RSCore",
				"RSDatabase",
				"Parser",
				"RSWeb",
				"Articles",
				"ArticlesDatabase",
				"Secrets",
				"SyncDatabase",
			],
			swiftSettings: [.unsafeFlags(["-warnings-as-errors"])]
		),
		.testTarget(
			name: "AccountTests",
			dependencies: ["Account"],
			resources: [
				.copy("JSON"),
			]),
	]
)
