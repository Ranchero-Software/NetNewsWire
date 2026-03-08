// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "RSMarkdown",
	platforms: [.macOS(.v15), .iOS(.v26)],
    products: [
        .library(
            name: "RSMarkdown",
            targets: ["RSMarkdown"])
    ],
    dependencies: [
		.package(url: "https://codeberg.org/brentsimmons/Tidemark", from: "0.2.0"),
    ],
    targets: [
        .target(
            name: "RSMarkdown",
			dependencies: ["Tidemark"],
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances"),
				.unsafeFlags(["-warnings-as-errors"])
			]
		),
        .testTarget(
            name: "RSMarkdownTests",
            dependencies: ["RSMarkdown"],
            resources: [.process("Resources")]
        )
    ]
)
