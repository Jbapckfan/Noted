// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NotedWatch",
    platforms: [.watchOS(.v10)],
    products: [
        .executable(name: "NotedWatch", targets: ["NotedWatch"])
    ],
    targets: [
        .executableTarget(name: "NotedWatch", path: "Sources")
    ]
)
