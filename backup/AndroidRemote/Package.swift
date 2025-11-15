// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShieldPause",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        // Library target containing testable code
        .target(
            name: "ShieldPauseCore",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/ShieldPause",
            exclude: ["main.swift"]
        ),
        // Executable target - thin wrapper
        .executableTarget(
            name: "ShieldPause",
            dependencies: ["ShieldPauseCore"],
            path: "Sources/ShieldPause",
            sources: ["main.swift"]
        ),
        // Test target
        .testTarget(
            name: "ShieldPauseTests",
            dependencies: ["ShieldPauseCore"],
            path: "Tests/ShieldPauseTests"
        )
    ]
)
