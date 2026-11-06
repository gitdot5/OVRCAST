// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UsageBoardMenuBar",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "UsageBoardMenuBar", targets: ["UsageBoardMenuBar"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")],
    targets: [
        .executableTarget(name: "UsageBoardMenuBar", dependencies: [.product(name: "Sparkle", package: "Sparkle")],
                          linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "UsageBoardMenuBarTests", dependencies: ["UsageBoardMenuBar"], resources: [.copy("Fixtures")])
    ]
)
