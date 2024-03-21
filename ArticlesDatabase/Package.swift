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
		.package(url: "https://github.com/Ranchero-Software/RSParser.git", .upToNextMajor(from: "2.0.2")),
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
				"RSParser",
				"Articles",
				"FMDB",
				"FoundationExtras"
			]),
    ]
)
