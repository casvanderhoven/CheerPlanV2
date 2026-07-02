// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CheerPlanUI",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "CheerPlanUI", targets: ["CheerPlanUI"])
    ],
    dependencies: [
        .package(path: "../CheerPlanCore")
    ],
    targets: [
        .target(
            name: "CheerPlanUI",
            dependencies: [
                .product(name: "CheerPlanCore", package: "CheerPlanCore")
            ]
        ),
        .testTarget(
            name: "CheerPlanUITests",
            dependencies: ["CheerPlanUI"]
        )
    ]
)
