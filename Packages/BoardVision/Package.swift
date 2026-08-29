// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BoardVision",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "BoardVision", targets: ["BoardVision"]),
    ],
    targets: [
        .target(name: "BoardVision"),
        .testTarget(name: "BoardVisionTests", dependencies: ["BoardVision"]),
    ]
)
