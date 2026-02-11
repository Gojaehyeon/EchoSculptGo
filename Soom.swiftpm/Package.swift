// swift-tools-version: 5.9

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Soom",
    platforms: [
        .iOS("26.0")
    ],
    products: [
        .iOSApplication(
            name: "Soom",
            targets: ["Soom"],
            bundleIdentifier: "com.soom.app",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .microphone),
            accentColor: .presetColor(.cyan),
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [.portrait],
            capabilities: [
                .microphone(purposeString: "Soom uses the microphone to capture sound and transform it into 3D Echo Sculptures for accessibility.")
            ]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Soom",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("SoundAnalysis"),
                .linkedFramework("CoreHaptics"),
                .linkedFramework("RealityKit"),
                .linkedFramework("FoundationModels"),
                .linkedFramework("Accelerate")
            ]
        )
    ]
)
