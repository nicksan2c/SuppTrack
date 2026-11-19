// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SuppTrackCore",
    platforms: [.iOS("26.0"), .watchOS("26.0"), .macOS("15.0")],
    products: [.library(name: "SuppTrackCore", targets: ["SuppTrackCore"])],
    targets: [
        .target(name: "SuppTrackCore"),
        .testTarget(
            name: "SuppTrackCoreTests",
            dependencies: ["SuppTrackCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
