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
		.package(path: "../ParserObjC"),
		.package(path: "../Articles"),
		.package(path: "../ArticlesDatabase"),
		.package(path: "../Web"),
		.package(path: "../Secrets"),
		.package(path: "../Database"),
		.package(path: "../SyncDatabase"),
		.package(path: "../Core"),
		.package(path: "../ReaderAPI"),
		.package(path: "../CloudKitSync"),
		.package(path: "../NewsBlur"),
		.package(path: "../Feedbin"),
		.package(path: "../LocalAccount"),
		.package(path: "../FeedFinder"),
		.package(path: "../Feedly"),
		.package(path: "../CommonErrors"),
		.package(path: "../FeedDownloader")
	],
	targets: [
		.target(
			name: "Account",
			dependencies: [
				"Parser",
				"ParserObjC",
				"Web",
				"Articles",
				"ArticlesDatabase",
				"Secrets",
				"SyncDatabase",
				"Database",
				"Core",
				"ReaderAPI",
				"NewsBlur",
				"CloudKitSync",
				"Feedbin",
				"LocalAccount",
				"FeedFinder",
				"CommonErrors",
				"Feedly",
				"FeedDownloader"
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
