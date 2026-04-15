// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Fuggstractor",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        // No external dependencies needed - using Apple frameworks
    ],
    targets: [
        .executableTarget(
            name: "Fuggstractor",
            dependencies: [],
            path: "Sources/macOS-App",
            swiftSettings: [
                .unsafeFlags(["-suppress-warnings"], .when(configuration: .release))
            ]
        ),
        .testTarget(
            name: "FuggstractorTests",
            dependencies: ["Fuggstractor"],
            path: "tests"
        )
    ]
)
