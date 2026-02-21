// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CapgoCapacitorTwilioVideo",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "CapgoCapacitorTwilioVideo",
            targets: ["CapacitorTwilioVideoPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "8.0.0"),
        .package(url: "https://github.com/twilio/twilio-video-ios", from: "5.0.0")
    ],
    targets: [
        .target(
            name: "CapacitorTwilioVideoPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm"),
                .product(name: "TwilioVideo", package: "twilio-video-ios")
            ],
            path: "ios/Sources/CapacitorTwilioVideoPlugin"),
        .testTarget(
            name: "CapacitorTwilioVideoPluginTests",
            dependencies: ["CapacitorTwilioVideoPlugin"],
            path: "ios/Tests/CapacitorTwilioVideoPluginTests")
    ]
)
