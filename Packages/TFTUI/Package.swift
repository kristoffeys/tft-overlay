// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TFTUI",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "TFTUI", targets: ["TFTUI"]),
    ],
    dependencies: [
        .package(path: "../TFTData"),
    ],
    targets: [
        .target(
            name: "TFTUI",
            dependencies: [
                .product(name: "TFTData", package: "TFTData"),
            ],
            resources: [
                .copy("Resources/Comps"),
            ]
        ),
        .executableTarget(
            name: "TFTUIDemo",
            dependencies: ["TFTUI"]
        ),
        .testTarget(
            name: "TFTUITests",
            dependencies: ["TFTUI"]
        ),
    ]
)
