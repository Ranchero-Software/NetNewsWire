// swift-tools-version:6.2
import PackageDescription

let package = Package(
	name: "ActivityLog",
	defaultLocalization: "en",
	platforms: [.macOS(.v15), .iOS(.v17)],
	products: [
		.library(
			name: "ActivityLog",
			type: .dynamic,
			targets: ["ActivityLog"])
	],
	targets: [
		.target(
			name: "ActivityLog",
			resources: [.process("Resources")],
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances"),
				.unsafeFlags(["-warnings-as-errors"])
			]
		),
		.testTarget(
			name: "ActivityLogTests",
			dependencies: ["ActivityLog"],
			swiftSettings: [.swiftLanguageMode(.v6)]
		)
	]
)
