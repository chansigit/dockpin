// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DockLock",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "docklock",
            path: "Sources"
        )
    ]
)
