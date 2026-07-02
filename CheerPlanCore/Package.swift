// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CheerPlanCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "CheerPlanCore", targets: ["CheerPlanCore"])
    ],
    targets: [
        .target(name: "CheerPlanCore"),
        .testTarget(
            name: "CheerPlanCoreTests",
            dependencies: ["CheerPlanCore"],
            resources: [.copy("Fixtures")]
        )
    ]
)
