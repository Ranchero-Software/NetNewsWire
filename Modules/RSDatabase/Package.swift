// swift-tools-version:5.10
import PackageDescription

let package = Package(
	name: "RSDatabase",
	platforms: [.macOS(.v13), .iOS(.v17)],
	products: [
		.library(
			name: "RSDatabase",
			type: .dynamic,
			targets: ["RSDatabase"]),
		.library(
			name: "RSDatabaseObjC",
			type: .dynamic,
			targets: ["RSDatabaseObjC"]),
	],
	dependencies: [
	],
	targets: [
		.target(
			name: "RSDatabase",
			dependencies: ["RSDatabaseObjC"]
		),
		.target(
			name: "RSDatabaseObjC",
			dependencies: []
		),
		.testTarget(
			name: "RSDatabaseTests",
			dependencies: ["RSDatabase"]),
	]
)
