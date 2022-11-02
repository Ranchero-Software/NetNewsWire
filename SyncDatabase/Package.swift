// swift-tools-version:5.3
import PackageDescription

var dependencies: [Package.Dependency] = [
    .package(url: "https://github.com/Ranchero-Software/RSCore.git", .upToNextMinor(from: "1.0.0")),
    .package(url: "https://github.com/Ranchero-Software/RSDatabase.git", .upToNextMajor(from: "1.0.0")),
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
    name: "SyncDatabase",
	platforms: [.macOS(SupportedPlatform.MacOSVersion.v10_15), .iOS(SupportedPlatform.IOSVersion.v13)],
    products: [
        .library(
            name: "SyncDatabase",
			type: .dynamic,
            targets: ["SyncDatabase"]),
    ],
    dependencies: dependencies,
    targets: [
        .target(
            name: "SyncDatabase",
            dependencies: [
				"RSCore",
				"RSDatabase",
				"Articles",
			]),
    ]
)
