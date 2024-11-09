// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "Account",
	platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "Account",
			type: .dynamic,
            targets: ["Account"]),
    ],
    dependencies: [
		.package(path: "../RSWeb"),
		.package(path: "../Articles"),
		.package(path: "../ArticlesDatabase"),
		.package(path: "../Secrets"),
		.package(path: "../SyncDatabase"),
		.package(path: "../RSCore"),
		.package(url: "https://github.com/Ranchero-Software/RSDatabase.git", .upToNextMajor(from: "1.0.0")),
		.package(url: "https://github.com/Ranchero-Software/RSParser.git", .upToNextMajor(from: "2.0.2")),
	],
    targets: [
        .target(
            name: "Account",
            dependencies: [
				"RSCore",
				"RSDatabase",
				"RSParser",
				"RSWeb",
				"Articles",
				"ArticlesDatabase",
				"Secrets",
				"SyncDatabase",
			]),
        .testTarget(
            name: "AccountTests",
            dependencies: ["Account"],
			resources: [
				.copy("JSON"),
			]),
    ]
)
