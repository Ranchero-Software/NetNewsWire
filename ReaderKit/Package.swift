// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ReaderKit",
    platforms: [.macOS("27.0"), .iOS("27.0")],
    products: ["ReaderDomain", "ReaderPersistence", "ReaderSync", "ReaderContent", "ReaderIntelligence", "ReaderUI"].map {
        .library(name: $0, targets: [$0])
    },
    targets: [
        .target(name: "ReaderDomain"),
        .target(name: "ReaderPersistence", dependencies: ["ReaderDomain"], exclude: ["README.md"]),
        .target(name: "ReaderSync", dependencies: ["ReaderDomain", "ReaderContent"], exclude: ["README.md"]),
        .target(name: "ReaderContent", dependencies: ["ReaderDomain"], resources: [.process("Resources")]),
        .target(name: "ReaderIntelligence", dependencies: ["ReaderDomain", "ReaderContent"]),
        .target(name: "ReaderUI", dependencies: ["ReaderDomain", "ReaderPersistence", "ReaderSync", "ReaderContent", "ReaderIntelligence"], exclude: ["README.md"]),
        .testTarget(name: "ReaderUITests", dependencies: ["ReaderUI"]),
        .testTarget(name: "ReaderDomainTests", dependencies: ["ReaderDomain"]),
        .testTarget(name: "ReaderPersistenceTests", dependencies: ["ReaderPersistence"]),
        .testTarget(name: "ReaderSyncTests", dependencies: ["ReaderSync", "ReaderPersistence"]),
        .testTarget(name: "ReaderContentTests", dependencies: ["ReaderContent"]),
        .testTarget(name: "ReaderIntelligenceTests", dependencies: ["ReaderIntelligence", "ReaderPersistence"])
    ]
)
