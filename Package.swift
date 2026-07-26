// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LangPilot",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "LangPilot", targets: ["LangPilot"])],
    targets: [
        .executableTarget(name: "LangPilot"),
        .testTarget(name: "LangPilotTests", dependencies: ["LangPilot"])
    ]
)
