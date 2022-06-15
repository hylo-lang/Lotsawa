// swift-tools-version: 5.6
import PackageDescription

let package = Package(
    name: "Lotsawa",
    products: [
        .library(
            name: "Lotsawa",
            targets: ["Lotsawa"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Lotsawa",
            dependencies: []),
        .testTarget(
            name: "LotsawaTests",
            dependencies: ["Lotsawa"]),
    ]
)
