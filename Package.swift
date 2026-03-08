// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CryptoScratchpad",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "ChainPad", targets: ["ChainPad"]),
        .library(name: "CryptoScratchpadKit", targets: ["CryptoScratchpadKit"]),
    ],
    targets: [
        .target(
            name: "CryptoScratchpadKit"
        ),
        .executableTarget(
            name: "ChainPad",
            dependencies: ["CryptoScratchpadKit"],
            path: "Sources/CryptoScratchpadApp"
        ),
        .testTarget(
            name: "CryptoScratchpadKitTests",
            dependencies: ["CryptoScratchpadKit"]
        ),
    ]
)
