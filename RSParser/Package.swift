// swift-tools-version:5.10
import PackageDescription

let package = Package(
	name: "RSParser",
	platforms: [.macOS(.v13), .iOS(.v17)],
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
			path: "Sources/Swift"),
		.target(
			name: "RSParserObjC",
			dependencies: [],
			path: "Sources/ObjC",
			cSettings: [
				.headerSearchPath("include"),
				.unsafeFlags(["-fprofile-instr-generate", "-fcoverage-mapping"])
			],
			linkerSettings: [
				.unsafeFlags(["-fprofile-instr-generate"])
			]
		),
		.testTarget(
			name: "RSParserTests",
			dependencies: ["RSParser"],
			exclude: ["Info.plist"],
			resources: [.copy("Resources")]),
	]
)
