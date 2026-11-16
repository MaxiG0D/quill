// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "QuillKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "QuillKit", targets: ["QuillKit"])
    ],
    targets: [
        .target(name: "QuillKit", resources: [.process("Resources")]),
        .testTarget(name: "QuillKitTests", dependencies: ["QuillKit"])
    ],
    swiftLanguageModes: [.v6]
)
