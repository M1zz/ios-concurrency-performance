// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IOSConcurrencyPerformance",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "IOSConcurrencyPerformance",
            targets: ["IOSConcurrencyPerformance"]
        ),
    ],
    targets: [
        .target(
            name: "IOSConcurrencyPerformance",
            path: "Sources"
        ),
        .testTarget(
            name: "IOSConcurrencyPerformanceTests",
            dependencies: ["IOSConcurrencyPerformance"],
            path: "Tests"
        ),
    ]
)
