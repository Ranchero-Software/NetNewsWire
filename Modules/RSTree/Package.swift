// swift-tools-version:6.2
import PackageDescription

let package = Package(
	name: "RSTree",
	platforms: [.macOS(.v26), .iOS(.v26)],
	products: [
		.library(
			name: "RSTree",
			type: .dynamic,
			targets: ["RSTree"]),
	],
	targets: [
		.target(
			name: "RSTree",
			dependencies: [],
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances"),
				.defaultIsolation(MainActor.self)
			]),
	]
)
