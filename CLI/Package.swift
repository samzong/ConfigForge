// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "ConfigForgeCLI",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "cf",
            targets: ["ConfigForgeCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "ConfigForgeCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
        .testTarget(
            name: "ConfigForgeCLITests",
            dependencies: ["ConfigForgeCLI"]),
    ]
) 