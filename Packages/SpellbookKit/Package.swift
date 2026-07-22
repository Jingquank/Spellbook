// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SpellbookKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SpellbookCore", targets: ["SpellbookCore"]),
        .library(name: "SpellbookMarkdown", targets: ["SpellbookMarkdown"]),
        .library(name: "SpellbookInfrastructure", targets: ["SpellbookInfrastructure"]),
        .library(name: "SpellbookUI", targets: ["SpellbookUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1"),
        .package(url: "https://github.com/swiftlang/swift-markdown.git", exact: "0.8.0")
    ],
    targets: [
        .target(name: "SpellbookCore"),
        .target(
            name: "SpellbookMarkdown",
            dependencies: [
                "SpellbookCore",
                .product(name: "Markdown", package: "swift-markdown")
            ]
        ),
        .target(
            name: "SpellbookInfrastructure",
            dependencies: [
                "SpellbookCore",
                "SpellbookMarkdown",
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
        .target(
            name: "SpellbookUI",
            dependencies: [
                "SpellbookCore",
                "SpellbookMarkdown"
            ]
        ),
        .testTarget(
            name: "SpellbookCoreTests",
            dependencies: ["SpellbookCore"]
        ),
        .testTarget(
            name: "SpellbookMarkdownTests",
            dependencies: ["SpellbookMarkdown"]
        ),
        .testTarget(
            name: "SpellbookInfrastructureTests",
            dependencies: [
                "SpellbookInfrastructure",
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
        .testTarget(
            name: "SpellbookUIUnitTests",
            dependencies: ["SpellbookUI", "SpellbookInfrastructure"]
        )
    ]
)
