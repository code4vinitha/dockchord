// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "DockChord", platforms: [.macOS(.v13)], products: [.executable(name: "DockChord", targets: ["DockChord"])], targets: [.executableTarget(name: "DockChord")])
