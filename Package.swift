// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftYaciAPI",
    platforms: [
        .iOS(.v14),
        .macOS(.v13),
        .watchOS(.v7),
        .tvOS(.v14),
    ],
    products: [
        .library(
            name: "SwiftYaciAPI",
            targets: ["SwiftYaciAPI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.11.1"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.11.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "SwiftYaciAPI",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator"),
            ]
        ),
        .testTarget(
            name: "SwiftYaciAPITests",
            dependencies: ["SwiftYaciAPI"]
        ),
    ]
)
