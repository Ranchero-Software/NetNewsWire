// swift-tools-version: 5.10

import PackageDescription

let package = Package(
	name: "ArticlesDatabase",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "ArticlesDatabase",
			type: .dynamic,
			targets: ["ArticlesDatabase"]),
	],
	dependencies: [
		.package(path: "../Parser"),
		.package(path: "../Articles"),
		.package(path: "../Database"),
		.package(path: "../FMDB"),
		.package(path: "../FoundationExtras"),
	],
	targets: [
		.target(
			name: "ArticlesDatabase",
			dependencies: [
				"Database",
				"Parser",
				"Articles",
				"FMDB",
				"FoundationExtras"
			],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]
		)
	]
)
