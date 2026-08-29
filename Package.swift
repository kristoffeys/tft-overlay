// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TFTOverlay",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "TFTOverlay", targets: ["TFTOverlay"]),
    ],
    dependencies: [
        .package(path: "Packages/TFTData"),
        .package(path: "Packages/LCUClient"),
        .package(path: "Packages/OverlayKit"),
        .package(path: "Packages/TFTUI"),
        .package(path: "Packages/BoardVision"),
    ],
    targets: [
        .executableTarget(
            name: "TFTOverlay",
            dependencies: [
                .product(name: "TFTData", package: "TFTData"),
                .product(name: "LCUClient", package: "LCUClient"),
                .product(name: "OverlayKit", package: "OverlayKit"),
                .product(name: "TFTUI", package: "TFTUI"),
            ],
            path: "Sources/TFTOverlay",
            linkerSettings: [
                // Embeds Info.plist (LSUIElement, etc.) directly into the Mach-O binary
                // so the plain SwiftPM executable behaves like an app bundle at runtime,
                // without requiring a hand-authored .xcodeproj. See docs/adr/0001.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Support/Info.plist",
                ]),
            ]
        ),
    ]
)
