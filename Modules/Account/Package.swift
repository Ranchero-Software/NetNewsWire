// swift-tools-version:6.2
import PackageDescription

let package = Package(
	name: "Account",
	platforms: [.macOS(.v26), .iOS(.v26)],
	products: [
		.library(
			name: "Account",
			type: .dynamic,
			targets: ["Account"])
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
		.package(path: "../NewsBlur")
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
				"NewsBlur"
			],
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances")
			]
		),
		.testTarget(
			name: "AccountTests",
			dependencies: ["Account"],
			resources: [
				.copy("JSON")
			],
			swiftSettings: [.swiftLanguageMode(.v6)]
		)
	]
)
