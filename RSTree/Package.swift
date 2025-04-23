// swift-tools-version:5.10
import PackageDescription

let package = Package(
	name: "RSTree",
	platforms: [.macOS(.v13), .iOS(.v17)],
	products: [
		.library(
			name: "RSTree",
			type: .dynamic,
			targets: ["RSTree"]),
	],
	targets: [
		.target(
			name: "RSTree",
			dependencies: []),
	]
)
