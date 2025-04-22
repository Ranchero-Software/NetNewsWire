// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Articles",
	platforms: [.macOS(.v13), .iOS(.v16)],
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
