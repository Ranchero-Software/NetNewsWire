// swift-tools-version:6.2
import PackageDescription

let package = Package(
	name: "RSCore",
	platforms: [.macOS(.v15), .iOS(.v26)],
	products: [
		.library(name: "RSCore", type: .dynamic, targets: ["RSCore"]),
		.library(name: "RSCoreObjC", type: .dynamic, targets: ["RSCoreObjC"]),
		.library(name: "RSCoreResources", type: .static, targets: ["RSCoreResources"])
	],
	targets: [
		.target(
			name: "RSCore",
			dependencies: ["RSCoreObjC"],
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances")
			]
		),
		.target(
			name: "RSCoreObjC",
			dependencies: [],
			cSettings: [
				.headerSearchPath("include")
			]
		),
		.target(
			name: "RSCoreResources",
			resources: [
				.process("Resources/WebViewWindow.xib"),
				.process("Resources/IndeterminateProgressWindow.xib")
			],
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances")
			]
		),
		.testTarget(
			name: "RSCoreTests",
			dependencies: ["RSCore"],
			resources: [.copy("Resources")],
			swiftSettings: [.swiftLanguageMode(.v5)]
		)
	]
)
