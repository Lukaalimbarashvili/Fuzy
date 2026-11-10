// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Packages",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "Domain", targets: ["Domain"]),
    ],
    targets: [
        .target(name: "Networking", path: "Networking"),
        .target(name: "Domain", dependencies: ["Networking"], path: "Domain"),
    ]
)
