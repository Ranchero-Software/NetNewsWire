// swift-tools-version:6.2
import PackageDescription

let package = Package(
	name: "Secrets",
	platforms: [.macOS(.v26), .iOS(.v26)],
	products: [
		.library(
			name: "Secrets",
			type: .dynamic,
			targets: ["Secrets"]
		)
	],
	dependencies: [],
	targets: [
		.target(
			name: "Secrets",
			dependencies: [],
			exclude: ["SecretKey.swift.gyb"],
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances"),
				.defaultIsolation(MainActor.self),
				.unsafeFlags(["-warnings-as-errors"])
			]
		)
	]
)
