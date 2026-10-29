// swift-tools-version: 6.2
// OVRCAST-maintained source subset; original license retained.
import PackageDescription
let package = Package(name: "Commander", platforms: [.macOS(.v14)], products: [.library(name: "Commander", targets: ["Commander"])], targets: [.target(name: "Commander", path: "Sources/Commander")])
