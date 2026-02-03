// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NiriMacOS",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "NiriMacOS",
            targets: ["NiriMacOS"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "NiriMacOS",
            dependencies: [],
            path: "Sources",
            resources: [
                .copy("../Resources")
            ]
        ),
        .testTarget(
            name: "NiriMacOSTests",
            dependencies: ["NiriMacOS"],
            path: "Tests"
        )
    ]
)
