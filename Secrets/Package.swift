// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Secrets",
	platforms: [.macOS(SupportedPlatform.MacOSVersion.v10_15), .iOS(SupportedPlatform.IOSVersion.v13)],
    products: [
        .library(
            name: "Secrets",
            targets: ["Secrets"]),
    ],
    dependencies: [
		.package(url: "https://github.com/OAuthSwift/OAuthSwift.git", .upToNextMajor(from: "2.1.2")),
    ],
    targets: [
        .target(
            name: "Secrets",
            dependencies: [
				"OAuthSwift",
			]),
    ]
)
