// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "FMDB",
	platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
         .library(
            name: "FMDB",
            targets: ["FMDB"]),
    ],
    targets: [
        .target(
            name: "FMDB"),
        .testTarget(
            name: "FMDBTests",
            dependencies: ["FMDB"]),
    ]
)
