// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "RSParser",
	platforms: [.macOS(.v13), .iOS(.v17)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "RSParser",
            type: .dynamic,
            targets: ["RSParser"]),
        .library(
            name: "RSParserObjC",
            type: .dynamic,
            targets: ["RSParserObjC"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "RSParser",
            dependencies: ["RSParserObjC"],
            path: "Sources/Swift"),
		.target(
			name: "RSParserObjC",
			dependencies: [],
			path: "Sources/ObjC",
			cSettings: [
				.headerSearchPath("include"),
				.unsafeFlags(["-fprofile-instr-generate", "-fcoverage-mapping"])
			],
			linkerSettings: [
				.unsafeFlags(["-fprofile-instr-generate"])
			]
		),
        .testTarget(
            name: "RSParserTests",
            dependencies: ["RSParser"],
            exclude: ["Info.plist"],
            resources: [.copy("Resources")]),
    ]
)
