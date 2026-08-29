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
        .target(name: "TFTData", resources: [.copy("Resources/fallback-set-data.json")]),
        .testTarget(
            name: "TFTDataTests",
            dependencies: ["TFTData"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
