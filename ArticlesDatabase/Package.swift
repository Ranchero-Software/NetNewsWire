// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ArticlesDatabase",
    products: [
        .library(
            name: "ArticlesDatabase",
            targets: ["ArticlesDatabase"]),
    ],
    dependencies: [
		.package(url: "https://github.com/Ranchero-Software/RSCore.git", .upToNextMajor(from: "1.0.0-beta1")),
		.package(url: "https://github.com/Ranchero-Software/RSDatabase.git", .upToNextMajor(from: "1.0.0-beta1")),
		.package(url: "https://github.com/Ranchero-Software/RSParser.git", .upToNextMajor(from: "2.0.0-beta1")),
    ],
    targets: [
        .target(
            name: "ArticlesDatabase",
            dependencies: []),
    ]
)
