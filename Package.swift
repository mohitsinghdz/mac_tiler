// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacTiler",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MacTiler",
            targets: ["MacTiler"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MacTiler",
            dependencies: [],
            path: "Sources",
            resources: [
                .copy("../Resources")
            ]
        ),
        .testTarget(
            name: "MacTilerTests",
            dependencies: ["MacTiler"],
            path: "Tests"
        )
    ]
)
