// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LuminaMax",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "LuminaMax",
            dependencies: [],
            path: "Sources/LuminaMax",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("CoreGraphics")
            ]
        )
    ]
)
