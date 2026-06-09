// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NetworkKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        // Core networking — zero third-party dependencies.
        .library(
            name: "NetworkKit",
            targets: ["NetworkKit"]
        ),
        // Optional image loading (UIKit + SwiftUI helpers). Custom, dependency-free.
        .library(
            name: "NetworkKitImage",
            targets: ["NetworkKitImage"]
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
            name: "NetworkKit",
            path: "Sources/NetworkKit"
        ),
        .target(
            name: "NetworkKitImage",
            dependencies: ["NetworkKit"],
            path: "Sources/NetworkKitImage"
        ),
        .target(
            name: "KeyboardKit",
            path: "Sources/KeyboardKit"
        ),
        .testTarget(
            name: "NetworkKitTests",
            dependencies: ["NetworkKit", "NetworkKitImage"],
            path: "Tests/NetworkKitTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
