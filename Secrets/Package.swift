// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Secrets",
	platforms: [.macOS(SupportedPlatform.MacOSVersion.v11), .iOS(SupportedPlatform.IOSVersion.v14)],
    products: [
        .library(
            name: "Secrets",
			type: .dynamic,
            targets: ["Secrets"]),
    ],
    dependencies: [
		.package(url: "https://github.com/OAuthSwift/OAuthSwift.git", .exact("2.1.2")),
    ],
    targets: [
        .target(
            name: "Secrets",
            dependencies: [
				"OAuthSwift",
			]),
    ]
)
