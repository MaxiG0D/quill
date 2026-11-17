// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "QuillKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "QuillKit", targets: ["QuillKit"]),
        .library(name: "QuillPictures", targets: ["QuillPictures"])
    ],
    targets: [
        .target(name: "QuillPictures"),
        .target(name: "QuillKit", dependencies: ["QuillPictures"], resources: [.process("Resources")]),
        .testTarget(name: "QuillKitTests", dependencies: ["QuillKit", "QuillPictures"])
    ],
    swiftLanguageModes: [.v6]
)
