// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IronBuddyHelpers",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "IronBuddyHelpers", targets: ["IronBuddyHelpers"]),
    ],
    targets: [
        .target(name: "IronBuddyHelpers"),
    ]
)
