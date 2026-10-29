// swift-tools-version: 6.2
// OVRCAST-maintained source subset; original license retained.
import PackageDescription
let package = Package(name: "SweetCookieKit", platforms: [.macOS(.v14)], products: [.library(name: "SweetCookieKit", targets: ["SweetCookieKit"])], targets: [.target(name: "SweetCookieKit", path: "Sources/SweetCookieKit", linkerSettings: [.linkedLibrary("sqlite3")])])
