// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftAzureOpenAI",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftAzureOpenAI",
            targets: ["SwiftAzureOpenAI"]),
        .executable(
            name: "TestApp",
            targets: ["TestApp"])
    ],
    dependencies: [
        // Core dependency for HTTP networking
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.21.0"),
    ],
    targets: [
        // Main target with core Azure OpenAI functionality
        .target(
            name: "SwiftAzureOpenAI",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ]
        ),
        
        // Test app target for manual testing
        .executableTarget(
            name: "TestApp",
            dependencies: ["SwiftAzureOpenAI"]
        ),
        
        // Test target for unit tests
        .testTarget(
            name: "SwiftAzureOpenAITests",
            dependencies: ["SwiftAzureOpenAI"]
        ),
    ]
)
