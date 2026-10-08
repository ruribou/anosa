// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AnosaKit",
    platforms: [
        .iOS(.v26),
        .watchOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "AnosaKit", targets: ["AnosaKit"]),
    ],
    targets: [
        .target(name: "AnosaKit"),
        .testTarget(name: "AnosaKitTests", dependencies: ["AnosaKit"]),
    ]
)
