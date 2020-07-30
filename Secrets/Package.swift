// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Secrets",
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
            dependencies: [],
			exclude: ["Secrets.swift.gyb"]),
    ]
)
