// swift-tools-version: 5.10
import PackageDescription

var dependencies: [Package.Dependency] = [
    .package(url: "https://github.com/Ranchero-Software/RSCore.git", .upToNextMinor(from: "1.0.0")),
]

#if swift(>=5.6)
dependencies.append(contentsOf: [
	.package(path: "../Articles"),
	.package(path: "../Database"),
])
#else
dependencies.append(contentsOf: [
    .package(url: "../Articles", .upToNextMajor(from: "1.0.0")),
])
#endif

let package = Package(
    name: "SyncDatabase",
	platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "SyncDatabase",
            targets: ["SyncDatabase"]),
    ],
	dependencies: dependencies,
	targets: [
		.target(
			name: "SyncDatabase",
			dependencies: [
				"RSCore",
				"Database",
				"Articles",
			],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			  ]
		)
	]
)
