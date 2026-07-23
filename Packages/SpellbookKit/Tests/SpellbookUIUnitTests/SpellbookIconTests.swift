import CryptoKit
import Foundation
import Testing
@testable import SpellbookUI

@Suite("Spellbook icon policy")
struct SpellbookIconTests {
    @Test("Every icon resolves to one bundled asset")
    func bundledAssetsResolve() throws {
        for icon in SpellbookIcon.allCases {
            #expect(icon.bundledImage != nil, "Missing bundled asset for \(icon)")
            let imageset = resourcesURL
                .appending(path: "Icons.xcassets")
                .appending(path: "\(icon.assetName).imageset")
            let svgs = try FileManager.default.contentsOfDirectory(
                at: imageset,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "svg" }
            #expect(svgs.count == 1, "\(icon) must resolve to exactly one SVG")
        }
    }

    @Test("Iconoir assets retain geometry and use the approved strokes")
    func iconGeometryAndStrokes() throws {
        for icon in SpellbookIcon.allCases {
            let svg = try String(
                contentsOf: resourcesURL
                    .appending(path: "Icons.xcassets")
                    .appending(path: "\(icon.assetName).imageset")
                    .appending(path: "\(icon.assetName).svg"),
                encoding: .utf8
            )
            #expect(svg.contains("width=\"24\""))
            #expect(svg.contains("height=\"24\""))
            #expect(svg.contains("viewBox=\"0 0 24 24\""))
            if icon.isSolid {
                #expect([SpellbookIcon.clear, .checked].contains(icon))
                #expect(!svg.contains("stroke-width=\""))
            } else {
                #expect(svg.contains("stroke-width=\"2\""))
                #expect(!svg.contains("stroke-width=\"1.5\""))
            }
        }
    }

    @Test("Icon sizes and button frames are the complete token sets")
    func sizeTokens() {
        #expect(SpellbookIconSize.allCases.map(\.points) == [10, 12, 14, 16, 20])
        #expect(SpellbookIconButtonFrame.allCases.map(\.points) == [24, 28, 32])
        #expect(SpellbookIconUsage.denseChrome == .micro)
        #expect(SpellbookIconUsage.standardControl == .small)
        #expect(SpellbookIconUsage.content == .standard)
        #expect(SpellbookIconUsage.emphasized == .large)
        #expect(SpellbookDesign.Size.agentMark == 22)
    }

    @Test("Manifest checksums cover every icon and authentic agent tile")
    func manifestChecksums() throws {
        let manifestURL = resourcesURL
            .appending(path: "IconAttribution")
            .appending(path: "icon-assets.sha256")
        let manifest = try String(contentsOf: manifestURL, encoding: .utf8)
        #expect(manifest.contains("10a66d02c6e3c94437bbf268352b1652e9eae7e5"))
        #expect(manifest.contains("cursor.com"))
        #expect(manifest.contains("anthropic.gallerycdn.vsassets.io"))
        #expect(manifest.contains("openai.gallerycdn.vsassets.io"))

        let entries = manifest.split(separator: "\n")
            .filter { !$0.hasPrefix("#") }
        #expect(entries.count == SpellbookIcon.allCases.count + 4)
        for entry in entries {
            let components = entry.split(separator: " ", maxSplits: 1)
            #expect(components.count == 2)
            guard components.count == 2 else { continue }
            let expected = String(components[0])
            let relativePath = String(components[1]).trimmingCharacters(in: .whitespaces)
            let data = try Data(contentsOf: repositoryRootURL.appending(path: relativePath))
            let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            #expect(actual == expected)
        }
    }

    @Test("SF Symbol calls are limited to the native allowlist")
    func nativeSymbolSourcePolicy() throws {
        let sources = packageRootURL.appending(path: "Sources/SpellbookUI")
        let files = try FileManager.default
            .subpathsOfDirectory(atPath: sources.path)
            .filter { $0.hasSuffix(".swift") }
        for file in files {
            let text = try String(
                contentsOf: sources.appending(path: file),
                encoding: .utf8
            )
            for line in text.split(separator: "\n") where
                line.contains("systemName:") || line.contains("systemImage:") {
                #expect(
                    line.contains("NativeSystemSymbol"),
                    "Raw SF Symbol call in \(file): \(line)"
                )
            }
        }
    }

    private var packageRootURL: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var resourcesURL: URL {
        packageRootURL.appending(path: "Sources/SpellbookUI/Resources")
    }

    private var repositoryRootURL: URL {
        packageRootURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
