// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AIbar",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "AIbar", targets: ["AIbar"])],
    targets: [
        .executableTarget(name: "AIbar", swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]),
        .testTarget(name: "AIbarTests", dependencies: ["AIbar"])
    ]
)
