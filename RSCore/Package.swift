// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RSCore",
    platforms: [.macOS(SupportedPlatform.MacOSVersion.v10_15), .iOS(SupportedPlatform.IOSVersion.v13)],
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
				.headerSearchPath("include")
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
