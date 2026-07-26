// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "BarcodeAssignCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "BarcodeAssignCore", targets: ["BarcodeAssignCore"]),
    ],
    targets: [
        .target(name: "BarcodeAssignCore"),
        .testTarget(name: "BarcodeAssignCoreTests", dependencies: ["BarcodeAssignCore"]),
    ]
)
