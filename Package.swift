// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MediaControl",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ShieldClient", targets: ["ShieldClient"]),
        .library(name: "OnkyoClient", targets: ["OnkyoClient"])
    ],
    targets: [
        .target(
            name: "ShieldClient",
            dependencies: [],
            path: "Sources/ShieldClient"
        ),
        .target(
            name: "OnkyoClient",
            dependencies: [],
            path: "Sources/OnkyoClient"
        ),
        .testTarget(
            name: "ShieldClientTests",
            dependencies: ["ShieldClient"],
            path: "Tests/ShieldClientTests"
        ),
        .testTarget(
            name: "OnkyoClientTests",
            dependencies: ["OnkyoClient"],
            path: "Tests/OnkyoClientTests"
        )
    ]
)
