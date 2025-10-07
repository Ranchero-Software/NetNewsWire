// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "RSMarkdown",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
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
            ]),
        .testTarget(
            name: "RSMarkdownTests",
            dependencies: ["RSMarkdown"],
            resources: [.process("Resources")]
        ),
    ]
)
