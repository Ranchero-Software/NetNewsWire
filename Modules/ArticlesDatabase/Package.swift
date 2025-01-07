// swift-tools-version:5.10

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
		.package(path: "../RSDatabase"),
		.package(path: "../Parser"),
		.package(path: "../RSCore"),
		.package(path: "../Articles"),
	],
	targets: [
		.target(
			name: "ArticlesDatabase",
			dependencies: [
				"RSCore",
				"RSDatabase",
				"Parser",
				"Articles",
			],
			swiftSettings: [.unsafeFlags(["-warnings-as-errors"])]
		),
	]
)
