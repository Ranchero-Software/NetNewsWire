// swift-tools-version:5.10
import PackageDescription

let package = Package(
	name: "RSCore",
	platforms: [.macOS(.v13), .iOS(.v17)],
	products: [
		.library(name: "RSCore", type: .dynamic, targets: ["RSCore"]),
		.library(name: "RSCoreObjC", type: .dynamic, targets: ["RSCoreObjC"]),
		.library(name: "RSCoreResources", type: .static, targets: ["RSCoreResources"])
	],
	targets: [
		.target(
			name: "RSCore",
			dependencies: ["RSCoreObjC"]),
		.target(
			name: "RSCoreObjC",
			dependencies: [],
			cSettings: [
				.headerSearchPath("include"),
				.unsafeFlags(["-fprofile-instr-generate", "-fcoverage-mapping"])
			],
			linkerSettings: [
				.unsafeFlags(["-fprofile-instr-generate"])
			]
		),
		.target(
			name: "RSCoreResources",
			resources: [
				.process("Resources/WebViewWindow.xib"),
				.process("Resources/IndeterminateProgressWindow.xib")
			]),
		.testTarget(
			name: "RSCoreTests",
			dependencies: ["RSCore"]),
	]
)
