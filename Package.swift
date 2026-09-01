// swift-tools-version: 5.10
import PackageDescription

var products: [Product] = [
    .library(name: "CodexTranscriptCore", targets: ["CodexTranscriptCore"])
]

var targets: [Target] = [
    .target(name: "CodexTranscriptCore"),
    .testTarget(
        name: "CodexTranscriptCoreTests",
        dependencies: ["CodexTranscriptCore"],
        resources: [.copy("Fixtures")]
    )
]

#if os(macOS)
products.append(.executable(name: "CodexTranscript", targets: ["CodexTranscriptApp"]))
targets.append(
    .executableTarget(
        name: "CodexTranscriptApp",
        dependencies: ["CodexTranscriptCore"]
    )
)
#endif

let package = Package(
    name: "CodexTranscript",
    platforms: [.macOS(.v14)],
    products: products,
    targets: targets
)
