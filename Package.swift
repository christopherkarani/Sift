// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Sift",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .executable(name: "wax", targets: ["SiftCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/christopherkarani/Wax.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/rensbreur/SwiftTUI.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "SiftCLI",
            dependencies: [
                .product(name: "Wax", package: "Wax"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftTUI", package: "SwiftTUI"),
            ],
            path: "Sources/wax",
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
    ]
)
