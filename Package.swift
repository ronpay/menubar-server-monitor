// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ServerMonitor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ServerMonitor",
            path: "Sources/ServerMonitor"
        )
    ]
)
