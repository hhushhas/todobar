// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TodoBar",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "TodoBar", targets: ["TodoBar"])
    ],
    dependencies: [
        .package(url: "https://github.com/get-convex/convex-swift", from: "0.8.1"),
        .package(url: "https://github.com/clerk/clerk-ios", from: "1.2.2"),
        .package(url: "https://github.com/clerk/clerk-convex-swift", from: "0.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "TodoBar",
            dependencies: [
                .product(name: "ConvexMobile", package: "convex-swift"),
                .product(name: "ClerkKit", package: "clerk-ios"),
                .product(name: "ClerkKitUI", package: "clerk-ios"),
                .product(name: "ClerkConvex", package: "clerk-convex-swift"),
            ],
            path: "app/macos/sources/todobar",
            exclude: ["Info.plist"],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "TodoBarTests",
            dependencies: ["TodoBar"],
            path: "app/macos/tests/todobar-tests"
        ),
    ]
)
