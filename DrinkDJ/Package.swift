// swift-tools-version: 6.0
import PackageDescription

// Runs the app's data-model tests on macOS without changing the iOS app target.
let package = Package(
    name: "DrinkDJModelValidation",
    platforms: [.iOS(.v17)],
    targets: [
        .target(
            name: "RemixCore",
            path: "DrinkDJ/Mocks",
            sources: ["MockData.swift", "RemixModels.swift", "RemixStore.swift"],
            swiftSettings: [.unsafeFlags(["-default-isolation", "MainActor"])]
        ),
        .testTarget(
            name: "RemixCoreTests",
            dependencies: ["RemixCore"],
            path: "Tests",
            swiftSettings: [.unsafeFlags(["-default-isolation", "MainActor"])]
        )
    ]
)
