// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "JSONKit",
    products: [
        .library(
            name: "JSONKit",
            targets: ["JSONKit"]
		),
    ],
    targets: [
        .target(
            name: "JSONKit"
		),
        .testTarget(
            name: "JSONKitTests",
            dependencies: ["JSONKit"]
		),
    ]
)
