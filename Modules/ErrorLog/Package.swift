// swift-tools-version:6.2
import PackageDescription

let package = Package(
	name: "ErrorLog",
	platforms: [.macOS(.v15), .iOS(.v17)],
	products: [
		.library(
			name: "ErrorLog",
			type: .dynamic,
			targets: ["ErrorLog"])
	],
	dependencies: [
		.package(path: "../RSCore"),
		.package(path: "../RSDatabase")
	],
	targets: [
		.target(
			name: "ErrorLog",
			dependencies: [
				"RSCore",
				"RSDatabase"
			],
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances"),
				.unsafeFlags(["-warnings-as-errors"])
			]
		),
		.testTarget(
			name: "ErrorLogTests",
			dependencies: ["ErrorLog"],
			swiftSettings: [.swiftLanguageMode(.v6)]
		)
	]
)
