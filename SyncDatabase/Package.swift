// swift-tools-version: 5.10
import PackageDescription

var dependencies: [Package.Dependency] = [
]

#if swift(>=5.6)
dependencies.append(contentsOf: [
	.package(path: "../Articles"),
	.package(path: "../Database"),
	.package(path: "../FMDB"),
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
			type: .dynamic,
            targets: ["SyncDatabase"]),
    ],
	dependencies: dependencies,
	targets: [
		.target(
			name: "SyncDatabase",
			dependencies: [
				"Database",
				"Articles",
				"FMDB"
			],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			  ]
		)
	]
)
