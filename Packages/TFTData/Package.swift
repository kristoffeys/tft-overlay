// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TFTData",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "TFTData", targets: ["TFTData"]),
    ],
    targets: [
        .target(name: "TFTData"),
        .testTarget(name: "TFTDataTests", dependencies: ["TFTData"]),
    ]
)
