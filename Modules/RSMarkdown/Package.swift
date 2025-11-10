// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "RSMarkdown",
	platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "RSMarkdown",
            targets: ["RSMarkdown"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.4.0")
    ],
    targets: [
        .target(
            name: "RSMarkdown",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances"),
				.defaultIsolation(MainActor.self),
				.unsafeFlags(["-warnings-as-errors"])
			]
		),
        .testTarget(
            name: "RSMarkdownTests",
            dependencies: ["RSMarkdown"],
            resources: [.process("Resources")]
        ),
    ]
)
