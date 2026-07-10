// swift-tools-version: 6.0
import PackageDescription

// NotedCoreKit — the durable encounter store for NotedCore (PR1 of the offline
// rearchitecture). Pure SwiftData + Foundation, NO app/MLX/UIKit dependencies, so
// its persistence guarantees are unit-testable on macOS via `swift test` without an
// iOS device or a Metal GPU. The app links this package and owns all UI/engine code.
let package = Package(
    name: "NotedCoreKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NotedCoreKit", targets: ["NotedCoreKit"]),
    ],
    targets: [
        .target(
            name: "NotedCoreKit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Offline eval tool: feed an LLM extraction + the transcript through the REAL grounding +
        // template + calculator-suggestion pipeline. `swift run nc-summarize <transcript> <json>`.
        .executableTarget(
            name: "nc-summarize",
            dependencies: ["NotedCoreKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "NotedCoreKitTests",
            dependencies: ["NotedCoreKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
