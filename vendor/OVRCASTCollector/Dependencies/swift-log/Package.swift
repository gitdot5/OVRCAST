// swift-tools-version: 6.2
// OVRCAST-maintained source subset; original license retained.
import PackageDescription
let package = Package(name: "swift-log", platforms: [.macOS(.v14)], products: [.library(name: "Logging", targets: ["Logging"])], targets: [.target(name: "Logging", path: "Sources/Logging")])
