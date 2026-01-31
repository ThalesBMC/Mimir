// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SoundManager",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SoundManager", targets: ["SoundManager"])
    ],
    targets: [
        .executableTarget(
            name: "SoundManager",
            path: "App",
            exclude: ["Info.plist", "SoundManager.entitlements"],
            resources: [
                .process("Assets.xcassets")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AudioToolbox")
            ]
        )
    ]
)
