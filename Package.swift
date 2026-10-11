// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Seemless",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Seemless", targets: ["Seemless"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],
    targets: [
        .target(name: "SeemlessCore"),
        .executableTarget(name: "Seemless", dependencies: ["SeemlessCore", .product(name: "Sparkle", package: "Sparkle")]),
        .testTarget(name: "SeemlessCoreTests", dependencies: ["SeemlessCore"]),
        .testTarget(name: "SeemlessTests", dependencies: ["Seemless", "SeemlessCore"])
    ],
    swiftLanguageModes: [.v5]
)
