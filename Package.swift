// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "connection-kit-irc",
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.10.1"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.2"),
        .package(url: "https://github.com/SwiftNIOExtras/swift-nio-irc.git", from: "0.8.0"),
        .package(url: "https://github.com/NozeIO/swift-nio-irc-eliza.git",
                 from: "0.5.2"),
        .package(url: "https://github.com/NozeIO/swift-nio-irc-webclient.git",
                 from: "0.6.1")
    ],
    targets: [
        .target(
            name: "IRCServer",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIOIRC", package: "swift-nio-irc"),
                .product(name: "IRCWebClient", package: "swift-nio-irc-webclient"),
                .product(name: "IRCElizaBot", package: "swift-nio-irc-eliza")
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]),
        .testTarget(
            name: "IRCServerTests",
            dependencies: ["IRCServer"]),
    ]
)
