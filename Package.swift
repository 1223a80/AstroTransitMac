// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AstroTransitMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TransitStudio", targets: ["TransitStudio"]),
        .library(name: "HamburgCore", targets: ["HamburgCore"]),
        .executable(name: "hamburg", targets: ["HamburgCLI"]),
    ],
    targets: [
        .executableTarget(
            name: "TransitStudio",
            path: "Sources/TransitStudio",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "HamburgCore",
            path: "Sources/HamburgCore"
        ),
        .executableTarget(
            name: "HamburgCLI",
            dependencies: ["HamburgCore"],
            path: "Sources/HamburgCLI"
        ),
        .testTarget(
            name: "TransitStudioTests",
            dependencies: ["TransitStudio"],
            path: "SwiftTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
        .testTarget(
            name: "HamburgCoreTests",
            dependencies: ["HamburgCore"],
            path: "HamburgTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
