// swift-tools-version:5.10

import PackageDescription

let package = Package(
	name: "SyncDatabase",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "SyncDatabase",
			type: .dynamic,
			targets: ["SyncDatabase"])
	],
	dependencies: [
		.package(path: "../RSCore"),
		.package(path: "../Articles"),
		.package(path: "../RSDatabase")
	],
	targets: [
		.target(
			name: "SyncDatabase",
			dependencies: [
				"RSCore",
				"RSDatabase",
				"Articles"
			],
			swiftSettings: [.unsafeFlags(["-warnings-as-errors"])]
		)
	]
)
