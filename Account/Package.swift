// swift-tools-version:5.9
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
		.package(url: "https://github.com/Ranchero-Software/RSCore.git", .upToNextMinor(from: "1.0.0")),
		.package(url: "https://github.com/Ranchero-Software/RSDatabase.git", .upToNextMajor(from: "1.0.0")),
		.package(url: "https://github.com/Ranchero-Software/RSParser.git", .upToNextMajor(from: "2.0.2")),
		.package(url: "https://github.com/Ranchero-Software/RSWeb.git", .upToNextMajor(from: "1.0.0")),
		.package(path: "../Articles"),
		.package(path: "../ArticlesDatabase"),
		.package(path: "../Secrets"),
		.package(path: "../SyncDatabase")
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
