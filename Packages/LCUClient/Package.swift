// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LCUClient",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "LCUClient", targets: ["LCUClient"]),
    ],
    targets: [
        .target(name: "LCUClient"),
        .testTarget(name: "LCUClientTests", dependencies: ["LCUClient"]),
    ]
)
