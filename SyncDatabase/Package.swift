// swift-tools-version: 5.10
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
		.package(path: "../Articles"),
		.package(path: "../Database"),
		.package(path: "../FMDB"),
	],
	targets: [
		.target(
			name: "SyncDatabase",
			dependencies: [
				"Database",
				"Articles",
				"FMDB"
			],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			  ]
		)
	]
)
