// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "Articles",
	platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "Articles",
			type: .dynamic,
            targets: ["Articles"]),
    ],
    dependencies: [
		.package(path: "../RSCore"),
    ],
    targets: [
        .target(
            name: "Articles",
			dependencies: [
				"RSCore"
			]),
	]
)
