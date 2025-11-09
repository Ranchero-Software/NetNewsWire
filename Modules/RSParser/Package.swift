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
		.package(path: "../RSMarkdown")
	],
	targets: [
		.target(
			name: "RSParser",
			dependencies: ["RSParserObjC", "RSMarkdown"],
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
