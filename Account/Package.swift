// swift-tools-version:5.7
import PackageDescription

var dependencies: [Package.Dependency] = [
	.package(url: "https://github.com/Ranchero-Software/RSCore.git", .upToNextMinor(from: "1.0.0")),
	.package(url: "https://github.com/Ranchero-Software/RSDatabase.git", .upToNextMajor(from: "1.0.0")),
]

dependencies.append(contentsOf: [
	.package(path: "../Articles"),
	.package(path: "../ArticlesDatabase"),
	.package(path: "../Secrets"),
	.package(path: "../SyncDatabase"),
	.package(path: "../RSWeb"),
	.package(path: "../RSParser"),
])

let package = Package(
    name: "Account",
	platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(
            name: "Account",
			type: .dynamic,
            targets: ["Account"]),
    ],
    dependencies: dependencies,
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
