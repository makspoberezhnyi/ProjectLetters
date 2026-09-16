// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LettersApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "LettersKit", targets: ["LettersKit"]),
        .executable(name: "LettersApp", targets: ["LettersApp"]),
    ],
    targets: [
        .target(
            name: "LettersCoreC",
            path: "Sources/LettersCoreC",
            publicHeadersPath: "include"
        ),
        .target(
            name: "LettersKit",
            dependencies: ["LettersCoreC"],
            path: "Sources/LettersKit"
        ),
        .executableTarget(
            name: "LettersApp",
            dependencies: ["LettersKit"],
            path: "Sources/LettersApp"
        ),
        .testTarget(
            name: "LettersKitTests",
            dependencies: ["LettersKit"],
            path: "Tests/LettersKitTests"
        ),
    ]
)
