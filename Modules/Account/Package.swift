// swift-tools-version:5.10
import PackageDescription

let package = Package(
	name: "Account",
	platforms: [.macOS(.v13), .iOS(.v17)],
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
				"Secrets",
				"SyncDatabase",
			]),
		.testTarget(
			name: "AccountTests",
			dependencies: ["Account"],
			resources: [
				.copy("JSON"),
			]),
	]
)
