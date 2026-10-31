// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CopyTrail",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "CopyTrail", targets: ["CopyTrail"])],
    targets: [
        .target(name: "CopyTrailCore"),
        .executableTarget(name: "CopyTrail", dependencies: ["CopyTrailCore"]),
        .testTarget(name: "CopyTrailCoreTests", dependencies: ["CopyTrailCore"]),
        .testTarget(name: "CopyTrailTests", dependencies: ["CopyTrail"])
    ]
)
