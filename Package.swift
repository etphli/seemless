// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Seemless",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Seemless", targets: ["Seemless"])],
    targets: [
        .target(name: "SeemlessCore"),
        .executableTarget(name: "Seemless", dependencies: ["SeemlessCore"]),
        .testTarget(name: "SeemlessCoreTests", dependencies: ["SeemlessCore"]),
        .testTarget(name: "SeemlessTests", dependencies: ["Seemless", "SeemlessCore"])
    ],
    swiftLanguageModes: [.v5]
)
