// swift-tools-version: 6.0
import PackageDescription

// SafetyWalkCore — portable model/enum/template-loader core shared by the iOS app
// and (future) native macOS app. Swift 5 language mode to match the app target
// (SWIFT_VERSION = 5.0); extraction must not change compilation semantics.
let package = Package(
    name: "SafetyWalkCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SafetyWalkCore", targets: ["SafetyWalkCore"]),
    ],
    targets: [
        .target(
            name: "SafetyWalkCore",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "SafetyWalkCoreTests",
            dependencies: ["SafetyWalkCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
