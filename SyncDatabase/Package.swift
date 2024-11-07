// swift-tools-version:5.9

import PackageDescription

let package = Package(
	name: "SyncDatabase",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "SyncDatabase",
			type: .dynamic,
			targets: ["SyncDatabase"]),
	],
	dependencies: [
		.package(path: "../RSCore"),
		.package(path: "../Articles"),
		.package(url: "https://github.com/Ranchero-Software/RSDatabase.git", .upToNextMajor(from: "1.0.0")),
	],
	targets: [
		.target(
			name: "SyncDatabase",
			dependencies: [
				"RSCore",
				"RSDatabase",
				"Articles",
			]),
	]
)
