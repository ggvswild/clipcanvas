// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClipCanvas",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ClipCanvas", targets: ["ClipCanvasApp"])
    ],
    targets: [
        .executableTarget(
            name: "ClipCanvasApp",
            path: "Sources/ClipCanvasApp",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .testTarget(
            name: "ClipCanvasAppTests",
            dependencies: ["ClipCanvasApp"],
            path: "Tests/ClipCanvasAppTests"
        )
    ]
)
