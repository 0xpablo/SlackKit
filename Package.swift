// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "SlackKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SlackKit", targets: ["SlackKit"]),
        .library(name: "SKClient", targets: ["SKClient"]),
        .library(name: "SKCore", targets: ["SKCore"]),
        .library(name: "SKRTMAPI", targets: ["SKRTMAPI"]),
        .library(name: "SKServer", targets: ["SKServer"]),
        .library(name: "SKWebAPI", targets: ["SKWebAPI"])
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0-beta.2"),
        .package(url: "https://github.com/vapor/websocket-kit", from: "2.14.0"),
        .package(url: "https://github.com/daltoniam/Starscream", from: "4.0.4"),
    ],
    targets: [
        .target(name: "SlackKit",
                dependencies: ["SKCore", "SKClient", "SKRTMAPI", "SKServer"],
                path: "SlackKit/Sources"),
        .target(name: "SKClient",
                dependencies: ["SKCore"],
                path: "SKClient/Sources"),
        .target(name: "SKCore",
                path: "SKCore/Sources"),
        .target(name: "SKRTMAPI",
                dependencies: [
                    "SKCore",
                    "SKWebAPI",
                    .product(name: "Starscream", package: "Starscream", condition: .when(platforms: [.macOS, .iOS, .tvOS])),
                    .product(name: "WebSocketKit", package: "websocket-kit", condition: .when(platforms: [.macOS, .linux])),
                ],
                path: "SKRTMAPI/Sources"),
        .target(name: "SKServer",
                dependencies: ["SKCore", "SKWebAPI",
                    .product(name: "Hummingbird", package: "hummingbird")],
                path: "SKServer/Sources"),
        .target(name: "SKWebAPI",
                dependencies: ["SKCore"],
                path: "SKWebAPI/Sources"),
        .testTarget(name: "SlackKitTests",
                dependencies: ["SlackKit", "SKCore", "SKClient", "SKRTMAPI", "SKServer"],
                path: "SlackKitTests",
                exclude: [
                    "Supporting Files"
                ],
                resources: [
                    .copy("Resources")
                ])
    ]
)
