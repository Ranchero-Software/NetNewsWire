// swift-tools-version:6.2
import PackageDescription

let package = Package(
	name: "Articles",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "Articles",
			type: .dynamic,
			targets: ["Articles"]),
	],
	dependencies: [
		.package(path: "../RSCore"),
	],
	targets: [
		.target(
			name: "Articles",
			dependencies: [
				"RSCore"
			],
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances"),
				.defaultIsolation(MainActor.self)
			]),
	]
)
