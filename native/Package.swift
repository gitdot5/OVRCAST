// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UsageBoardMenuBar",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "UsageBoardMenuBar", targets: ["UsageBoardMenuBar"])],
    targets: [
        .executableTarget(name: "UsageBoardMenuBar"),
        .testTarget(name: "UsageBoardMenuBarTests", dependencies: ["UsageBoardMenuBar"])
    ]
)
