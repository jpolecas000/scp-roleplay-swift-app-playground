// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ContainmentShift",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "ContainmentShift",
            targets: ["ContainmentShift"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ContainmentShift",
            path: "ContainmentShift.swiftpm/Sources/ContainmentShift"
        )
    ]
)
