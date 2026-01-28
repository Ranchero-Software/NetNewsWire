// swift-tools-version: 6.2
import PackageDescription

let package = Package(
	name: "NewsBlur",
	platforms: [.macOS(.v26), .iOS(.v26)],
	products: [
		.library(
			name: "NewsBlur",
			targets: ["NewsBlur"]
		)
	],
	dependencies: [
		.package(path: "../Secrets"),
		.package(path: "../RSWeb"),
		.package(path: "../RSParser"),
		.package(path: "../RSCore")
	],
	targets: [
		.target(
			name: "NewsBlur",
			dependencies: [
				"Secrets",
				"RSWeb",
				"RSParser",
				"RSCore"
			]
		),
		.testTarget(
			name: "NewsBlurTests",
			dependencies: ["NewsBlur"]
		)
	]
)
