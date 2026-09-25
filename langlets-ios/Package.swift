// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LangletsNativeCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "LangletsNativeCore", targets: ["LangletsNativeCore"])],
    targets: [
        .target(name: "LangletsNativeCore", path: "langlets/langlets/Native", sources: ["Models.swift"]),
        .testTarget(name: "NativeCoreTests", dependencies: ["LangletsNativeCore"], path: "NativeCoreTests")
    ]
)
