// swift-tools-version:5.10

import PackageDescription

let package = Package(
	name: "RSParser",
	platforms: [.macOS(.v14), .iOS(.v17)],
	products: [
		.library(
			name: "RSParser",
			type: .dynamic,
			targets: ["RSParser"]),
		.library(
			name: "RSParserObjC",
			type: .dynamic,
			targets: ["RSParserObjC"]),
	],
	dependencies: [
	],
	targets: [
		.target(
			name: "RSParser",
			dependencies: ["RSParserObjC"],
			path: "Sources/Swift",
			swiftSettings: [.unsafeFlags(["-warnings-as-errors"])]
		),
		.target(
			name: "RSParserObjC",
			dependencies: [],
			path: "Sources/ObjC",
			cSettings: [
				.headerSearchPath("include")
			]),
		.testTarget(
			name: "RSParserTests",
			dependencies: ["RSParser"],
			exclude: ["Info.plist"],
			resources: [.copy("Resources")]),
	]
)
