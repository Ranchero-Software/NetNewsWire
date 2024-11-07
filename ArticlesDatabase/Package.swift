// swift-tools-version:5.9

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
		.package(url: "https://github.com/Ranchero-Software/RSDatabase.git", .upToNextMajor(from: "1.0.0")),
		.package(url: "https://github.com/Ranchero-Software/RSParser.git", .upToNextMajor(from: "2.0.2")),
		.package(path: "../RSCore"),
		.package(path: "../Articles"),
	],
	targets: [
		.target(
			name: "ArticlesDatabase",
			dependencies: [
				"RSCore",
				"RSDatabase",
				"RSParser",
				"Articles",
			]),
	]
)
