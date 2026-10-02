// swift-tools-version: 5.9
import AppleProductTypes
import PackageDescription

let package = Package(
    name: "ContainmentShift",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .iOSApplication(
            name: "Containment Shift",
            targets: ["ContainmentShift"],
            bundleIdentifier: "com.jpolecas000.ContainmentShift",
            teamIdentifier: "XXXXXXXXXX",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .lightningBolt),
            accentColor: .presetColor(.teal),
            supportedDeviceFamilies: [
                .phone,
                .pad
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeLeft,
                .landscapeRight,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(name: "ContainmentShift")
    ]
)
