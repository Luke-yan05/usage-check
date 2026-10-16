// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UsageCheckCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "UsageCheckCore", targets: ["UsageCheckCore"])],
    targets: [
        .target(name: "UsageCheckCore", path: "Core"),
        .testTarget(name: "UsageCheckCoreTests", dependencies: ["UsageCheckCore"], path: "Tests/UsageCheckCoreTests")
    ]
)
