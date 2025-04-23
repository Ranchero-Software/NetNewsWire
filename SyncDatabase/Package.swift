// swift-tools-version:5.10
import PackageDescription

var dependencies: [Package.Dependency] = [
    .package(url: "https://github.com/Ranchero-Software/RSDatabase.git", .upToNextMajor(from: "1.0.0")),
]

#if swift(>=5.6)
dependencies.append(contentsOf: [
	.package(path: "../Articles"),
	.package(path: "../RSCore"),
])
#else
dependencies.append(contentsOf: [
    .package(url: "../Articles", .upToNextMajor(from: "1.0.0")),
])
#endif

let package = Package(
    name: "SyncDatabase",
	platforms: [.macOS(.v13), .iOS(.v17)],
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
