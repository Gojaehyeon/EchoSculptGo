// swift-tools-version: 5.9

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "EchoSculptGo",
    platforms: [
        .iOS("18.0")
    ],
    products: [
        .iOSApplication(
            name: "EchoSculptGo",
            targets: ["EchoSculptGo"],
            bundleIdentifier: "com.echosculpt.go",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .microphone),
            accentColor: .presetColor(.cyan),
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [.portrait],
            capabilities: [
                .microphone(purposeString: "EchoSculptGo uses the microphone to capture sound and transform it into 3D Echo Sculptures.")
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "EchoSculptGo",
            path: "Sources"
        )
    ]
)
