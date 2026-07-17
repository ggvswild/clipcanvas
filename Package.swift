// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClipCanvas",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ClipCanvas", targets: ["ClipCanvasApp"]),
        .executable(name: "clipcanvas-mcp", targets: ["ClipCanvasMCPBridge"]),
        .library(name: "ClipCanvasCore", targets: ["ClipCanvasCore"])
    ],
    targets: [
        .target(
            name: "ClipCanvasCore",
            path: "Sources/ClipCanvasCore",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "ClipCanvasApp",
            dependencies: ["ClipCanvasCore"],
            path: "Sources/ClipCanvasApp",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .executableTarget(
            name: "ClipCanvasMCPBridge",
            path: "Sources/ClipCanvasMCPBridge"
        ),
        .testTarget(
            name: "ClipCanvasAppTests",
            dependencies: ["ClipCanvasApp", "ClipCanvasCore"],
            path: "Tests/ClipCanvasAppTests"
        ),
        .testTarget(
            name: "ClipCanvasCoreTests",
            dependencies: ["ClipCanvasCore"],
            path: "Tests/ClipCanvasCoreTests"
        )
    ]
)
