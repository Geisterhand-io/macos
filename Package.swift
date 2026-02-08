// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Geisterhand",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "GeisterhandApp", targets: ["GeisterhandApp"]),
        .executable(name: "geisterhand", targets: ["geisterhand"]),
        .library(name: "GeisterhandCore", targets: ["GeisterhandCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "GeisterhandApp",
            dependencies: ["GeisterhandCore"]
        ),
        .executableTarget(
            name: "geisterhand",
            dependencies: [
                "GeisterhandCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(
            name: "GeisterhandCore",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                "CAXKeyboardEvent"
            ]
        ),
        .target(name: "CAXKeyboardEvent"),
        .testTarget(
            name: "GeisterhandTests",
            dependencies: ["GeisterhandCore"]
        )
    ]
)
