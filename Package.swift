// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HKNetworkKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        // Core networking — zero third-party dependencies.
        .library(
            name: "HKNetworkKit",
            targets: ["HKNetworkKit"]
        ),
        // Optional image loading (UIKit + SwiftUI helpers). Custom, dependency-free.
        .library(
            name: "HKNetworkKitImage",
            targets: ["HKNetworkKitImage"]
        ),
        // Optional automatic keyboard handling for UIKit (iOS). Custom,
        // dependency-free alternative to IQKeyboardManagerSwift.
        .library(
            name: "KeyboardKit",
            targets: ["KeyboardKit"]
        )
    ],
    targets: [
        .target(
            name: "HKNetworkKit",
            path: "Sources/HKNetworkKit"
        ),
        .target(
            name: "HKNetworkKitImage",
            dependencies: ["HKNetworkKit"],
            path: "Sources/HKNetworkKitImage"
        ),
        .target(
            name: "KeyboardKit",
            path: "Sources/KeyboardKit"
        ),
        .testTarget(
            name: "HKNetworkKitTests",
            dependencies: ["HKNetworkKit", "HKNetworkKitImage"],
            path: "Tests/HKNetworkKitTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
