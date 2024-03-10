// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Database",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "Database",
			targets: ["Database"]
		)
	],
	dependencies: [
		.package(path: "../FMDB"),
	],
	targets: [
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.target(
			name: "Database",
			dependencies: [
				"FMDB"
			]
		),
		.testTarget(
            name: "DatabaseTests",
            dependencies: ["Database"]),
    ]
)
