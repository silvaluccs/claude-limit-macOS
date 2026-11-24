// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeTouchBar",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "ClaudeTouchBar",
            path: "Sources/ClaudeTouchBar"
        )
    ]
)
