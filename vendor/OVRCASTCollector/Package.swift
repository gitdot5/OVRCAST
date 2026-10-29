// swift-tools-version: 6.2
// OVRCAST-maintained collector fork of CodexBar 0.81.0. See FORK.md and LICENSE.
import PackageDescription
let package = Package(
    name: "CodexBar", defaultLocalization: "en", platforms: [.macOS(.v14)],
    products: [.executable(name: "OVRCASTCollector", targets: ["CodexBarCLI"])],
    dependencies: [.package(path: "Dependencies/Commander"), .package(path: "Dependencies/SweetCookieKit"), .package(path: "Dependencies/swift-log")],
    targets: [
        .target(name: "CQuickJS", path: "Sources/CQuickJS", exclude: ["README.md", "LICENSE"], publicHeadersPath: "include", cSettings: [.define("_GNU_SOURCE")]),
        .target(name: "CodexBarCore", dependencies: ["CQuickJS", .product(name: "Logging", package: "swift-log"), .product(name: "SweetCookieKit", package: "SweetCookieKit")], resources: [.process("Resources")], linkerSettings: [.linkedFramework("JavaScriptCore")]),
        .executableTarget(name: "CodexBarCLI", dependencies: ["CodexBarCore", .product(name: "Commander", package: "Commander")], path: "Sources/CodexBarCLI")
    ])
