// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CoverwallShared",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CoverwallShared", targets: ["CoverwallShared"])
    ],
    targets: [
        .target(name: "CoverwallShared"),
        .testTarget(name: "CoverwallSharedTests", dependencies: ["CoverwallShared"])
    ]
)
