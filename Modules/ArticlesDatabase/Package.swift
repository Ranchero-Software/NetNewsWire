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
		.package(path: "../Articles"),
		.package(path: "../RSCore"),
		.package(path: "../RSParser"),
		.package(path: "../RSDatabase"),
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
