// swift-tools-version:5.7.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var dependencies: [Package.Dependency] = [
    .package(url: "https://github.com/Ranchero-Software/RSCore.git", .upToNextMajor(from: "2.0.1")),
    .package(url: "https://github.com/Ranchero-Software/RSDatabase.git", .upToNextMajor(from: "1.0.0")),
    .package(url: "https://github.com/Ranchero-Software/RSParser.git", .upToNextMajor(from: "2.0.2")),
]

#if swift(>=5.6)
dependencies.append(contentsOf: [
    .package(path: "../Articles"),
])
#else
dependencies.append(contentsOf: [
    .package(url: "../Articles", .upToNextMajor(from: "1.0.0")),
])
#endif

let package = Package(
    name: "ArticlesDatabase",
    platforms: [.macOS(SupportedPlatform.MacOSVersion.v13), .iOS(SupportedPlatform.IOSVersion.v16)],
    products: [
        .library(
            name: "ArticlesDatabase",
			type: .dynamic,
            targets: ["ArticlesDatabase"]),
    ],
    dependencies: dependencies,
    targets: [
        .target(
            name: "ArticlesDatabase",
            dependencies: [
				"RSCore",
				"RSDatabase",
				"RSParser",
				"Articles",
			]),
    ]
)
