// swift-tools-version:5.7.1
import PackageDescription

let package = Package(
	name: "Account",
	defaultLocalization: "en",
	platforms: [.macOS(.v13), .iOS(.v16)],
	products: [
		.library(
			name: "Account",
			type: .dynamic,
			targets: ["Account"]),
	],
	dependencies: [
		.package(url: "https://github.com/Ranchero-Software/RSCore.git", .upToNextMajor(from: "3.0.0")),
		.package(url: "https://github.com/Ranchero-Software/RSDatabase.git", .upToNextMajor(from: "2.0.0")),
		.package(url: "https://github.com/Ranchero-Software/RSParser.git", .upToNextMajor(from: "2.0.2")),
		.package(url: "https://github.com/Ranchero-Software/RSWeb.git", .upToNextMajor(from: "1.0.0")),
		.package(path: "../AccountError"),
		.package(path: "../Articles"),
		.package(path: "../ArticlesDatabase"),
		.package(path: "../FeedFinder"),
		.package(path: "../Secrets"),
		.package(path: "../SyncDatabase"),
		.package(path: "../SyncClients/NewsBlur"),
		.package(path: "../SyncClients/ReaderAPI"),
		.package(path: "../SyncClients/Feedbin"),
		.package(path: "../SyncClients/LocalAccount"),
	],
	targets: [
		.target(
			name: "Account",
			dependencies: [
				"RSCore",
				"RSDatabase",
				"RSParser",
				"RSWeb",
				"AccountError",
				"Articles",
				"ArticlesDatabase",
				"FeedFinder",
				"Secrets",
				"SyncDatabase",
				"NewsBlur",
				"ReaderAPI",
				"Feedbin",
				"LocalAccount"
			],
			linkerSettings: [
				.unsafeFlags(["-Xlinker", "-no_application_extension"])
			]),
		.testTarget(
			name: "AccountTests",
			dependencies: ["Account"],
			resources: [
				.copy("JSON"),
			]),
	]
)
