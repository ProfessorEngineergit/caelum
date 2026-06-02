// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Caelum",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Caelum", targets: ["Caelum"])
    ],
    targets: [
        .executableTarget(
            name: "Caelum",
            path: "Sources/Caelum",
            swiftSettings: [
                .unsafeFlags(["-suppress-warnings"], .when(configuration: .release))
            ]
        ),
        .testTarget(
            name: "CaelumTests",
            dependencies: ["Caelum"],
            path: "Tests/CaelumTests"
        )
    ]
)
