// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AstroTransitMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TransitStudio", targets: ["TransitStudio"])
    ],
    targets: [
        .executableTarget(
            name: "TransitStudio",
            path: "Sources/TransitStudio",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "TransitStudioTests",
            dependencies: ["TransitStudio"],
            path: "SwiftTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
