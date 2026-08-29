// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "OverlayKit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "OverlayKit", targets: ["OverlayKit"]),
    ],
    targets: [
        .target(name: "OverlayKit"),
        .testTarget(name: "OverlayKitTests", dependencies: ["OverlayKit"]),
    ]
)
