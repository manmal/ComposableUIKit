// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "ComposableUIKit",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "ComposableUIKit",
            targets: ["ComposableUIKit"]),
    ],
    dependencies: [
        .package(
            name: "swift-composable-architecture",
            url: "https://github.com/pointfreeco/swift-composable-architecture.git",
            from: "0.33.1"
        ),
        .package(
            name: "CombineProperty",
            url: "https://github.com/manmal/CombineProperty.git",
            from: "0.3.1"
        ),
        .package(
            name: "CombineLifetime",
            url: "https://github.com/manmal/CombineLifetime.git",
            from: "1.0.0"
        )
    ],
    targets: [
        .target(
            name: "ComposableUIKit",
            dependencies: [
                .product(
                    name: "ComposableArchitecture",
                    package: "swift-composable-architecture"
                ),
                "CombineProperty",
                "CombineLifetime"
            ]),
        .testTarget(
            name: "ComposableUIKitTests",
            dependencies: ["ComposableUIKit"]),
    ]
)
