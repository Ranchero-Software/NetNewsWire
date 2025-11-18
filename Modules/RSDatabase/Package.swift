// swift-tools-version:6.2
import PackageDescription

let package = Package(
	name: "RSDatabase",
	platforms: [.macOS(.v26), .iOS(.v26)],
	products: [
		.library(
			name: "RSDatabase",
			type: .dynamic,
			targets: ["RSDatabase"]),
		.library(
			name: "RSDatabaseObjC",
			type: .dynamic,
			targets: ["RSDatabaseObjC"]),
	],
	dependencies: [
	],
	targets: [
		.target(
			name: "RSDatabase",
			dependencies: ["RSDatabaseObjC"],
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances"),
			]
		),
		.target(
			name: "RSDatabaseObjC",
			dependencies: []
		),
		.testTarget(
			name: "RSDatabaseTests",
			dependencies: ["RSDatabase"]),
	]
)
