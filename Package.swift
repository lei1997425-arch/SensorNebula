// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SensorNebula",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "SensorNebula", targets: ["SensorNebula"])],
    targets: [
        .executableTarget(
            name: "SensorNebula",
            path: "Sources/SensorNebula",
            resources: [.copy("Resources/MacBook_Pro_14-inch_M5.usdz"), .copy("Resources/MODEL_CREDITS.txt")]
        )
    ]
)
