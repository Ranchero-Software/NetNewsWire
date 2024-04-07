// swift-tools-version: 5.10
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
		.package(path: "../Parser"),
		.package(path: "../Articles"),
		.package(path: "../ArticlesDatabase"),
		.package(path: "../Web"),
		.package(path: "../Secrets"),
		.package(path: "../Database"),
		.package(path: "../SyncDatabase"),
		.package(path: "../Core"),
		.package(path: "../CloudKitExtras"),
		.package(path: "../ReaderAPI"),
		.package(path: "../CommonErrors")
	],
	targets: [
		.target(
			name: "Account",
			dependencies: [
				"Parser",
				"Web",
				"Articles",
				"ArticlesDatabase",
				"Secrets",
				"SyncDatabase",
				"Database",
				"Core",
				"CloudKitExtras",
				"ReaderAPI",
				"CommonErrors"
			],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]
		),
		.testTarget(
			name: "AccountTests",
			dependencies: ["Account"],
			resources: [
				.copy("JSON"),
			]),
	]
)
