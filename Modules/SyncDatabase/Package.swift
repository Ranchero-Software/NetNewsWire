// swift-tools-version:6.2
import PackageDescription

let package = Package(
	name: "SyncDatabase",
	platforms: [.macOS(.v26), .iOS(.v26)],
	products: [
		.library(
			name: "SyncDatabase",
			type: .dynamic,
			targets: ["SyncDatabase"])
	],
	dependencies: [
		.package(path: "../Articles"),
		.package(path: "../RSCore"),
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
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances"),
				.unsafeFlags(["-warnings-as-errors"])
			]
		)
	]
)
