// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Account",
	platforms: [.macOS(SupportedPlatform.MacOSVersion.v10_15), .iOS(SupportedPlatform.IOSVersion.v13)],
    products: [
        .library(
            name: "Account",
			type: .dynamic,
            targets: ["Account"]),
    ],
    dependencies: [
		.package(url: "https://github.com/Ranchero-Software/RSCore.git", .upToNextMajor(from: "1.0.0")),
		.package(url: "https://github.com/Ranchero-Software/RSDatabase.git", .upToNextMajor(from: "1.0.0")),
		.package(url: "https://github.com/Ranchero-Software/RSParser.git", .upToNextMajor(from: "2.0.0")),
		.package(url: "https://github.com/Ranchero-Software/RSWeb.git", .upToNextMajor(from: "1.0.0")),
		.package(url: "../Articles", .upToNextMajor(from: "1.0.0")),
		.package(url: "../ArticlesDatabase", .upToNextMajor(from: "1.0.0")),
		.package(url: "../Secrets", .upToNextMajor(from: "1.0.0")),
		.package(url: "../SyncDatabase", .upToNextMajor(from: "1.0.0")),
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
