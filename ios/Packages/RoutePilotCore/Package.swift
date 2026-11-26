// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RoutePilotCore",
    platforms: [.iOS("17.4"), .macOS(.v13)],
    products: [.library(name: "RoutePilotCore", targets: ["RoutePilotCore"])],
    targets: [
        .target(name: "RoutePilotCore"),
        .testTarget(name: "RoutePilotCoreTests", dependencies: ["RoutePilotCore"])
    ]
)
