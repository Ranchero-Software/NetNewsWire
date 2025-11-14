// swift-tools-version:6.2
import PackageDescription

let package = Package(
	name: "RSWeb",
	platforms: [.macOS(.v26), .iOS(.v26)],
	products: [
		.library(
			name: "RSWeb",
			type: .dynamic,
			targets: ["RSWeb"])
	],
	dependencies: [
		.package(path: "../RSParser"),
		.package(path: "../RSCore")
	],
	targets: [
		.target(
			name: "RSWeb",
			dependencies: [
				"RSParser",
				"RSCore"
			],
			swiftSettings: [
				.unsafeFlags(["-warnings-as-errors"]),
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances"),
				.defaultIsolation(MainActor.self)
			]
		),
		.testTarget(
			name: "RSWebTests",
			dependencies: ["RSWeb"])
	]
)
