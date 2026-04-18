// swift-tools-version:6.2
import PackageDescription

let package = Package(
	name: "RSParser",
	platforms: [.macOS(.v15), .iOS(.v17)],
	products: [
		.library(
			name: "RSParser",
			type: .dynamic,
			targets: ["RSParser"]),
		.library(
			name: "RSParserObjC",
			type: .dynamic,
			targets: ["RSParserObjC"])
	],
	dependencies: [
		.package(url: "https://github.com/brentsimmons/Tidemark", from: "1.0.0")
	],
	targets: [
		.target(
			name: "RSParser",
			dependencies: ["RSParserObjC", "Tidemark"],
			path: "Sources/Swift",
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances")
			]),
		.target(
			name: "RSParserObjC",
			dependencies: [],
			path: "Sources/ObjC",
			cSettings: [
				.headerSearchPath("include")
			]
		),
		.testTarget(
			name: "RSParserTests",
			dependencies: ["RSParser"],
			exclude: ["Info.plist"],
			resources: [.copy("Resources")],
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances")
			]
		)
	]
)
