// swift-tools-version:6.2
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
		.package(path: "../Articles"),
		.package(path: "../ArticlesDatabase"),
		.package(path: "../CloudKitSync"),
		.package(path: "../FeedFinder"),
		.package(path: "../Secrets"),
		.package(path: "../SyncDatabase"),
		.package(path: "../RSWeb"),
		.package(path: "../RSParser"),
		.package(path: "../RSCore"),
		.package(path: "../RSDatabase"),
	],
	targets: [
		.target(
			name: "Account",
			dependencies: [
				"RSCore",
				"RSDatabase",
				"RSParser",
				"RSWeb",
				"Articles",
				"ArticlesDatabase",
				"CloudKitSync",
				"FeedFinder",
				"Secrets",
				"SyncDatabase",
			],
			swiftSettings: [.swiftLanguageMode(.v5)]),
		.testTarget(
			name: "AccountTests",
			dependencies: ["Account"],
			resources: [
				.copy("JSON"),
			],
			swiftSettings: [.swiftLanguageMode(.v5)]
		),
	]
)
