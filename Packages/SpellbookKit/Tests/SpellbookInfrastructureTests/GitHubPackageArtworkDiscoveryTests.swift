import AppKit
import SpellbookCore
import XCTest
@testable import SpellbookInfrastructure

final class GitHubPackageArtworkDiscoveryTests: XCTestCase {
    func testLocalReadmeSelectsFirstSquareContentImageBeforeFirstH2() async throws {
        let fixture = try TemporarySkillLibrary()
        let license = try png(width: 64, height: 64, color: .gray)
        let wide = try png(width: 128, height: 64, color: .orange)
        let square = try png(width: 96, height: 80, color: .systemBlue)
        _ = try fixture.write(license, at: "license.png")
        _ = try fixture.write(wide, at: "wide.png")
        _ = try fixture.write(square, at: "square.png")
        _ = try fixture.write(try png(width: 100, height: 100, color: .red), at: "late.png")
        _ = try fixture.write(
            """
            ![MIT license badge](license.png)
            <img src="wide.png" alt="Wide project card" />
            ![Project mark](square.png)
            ## Install
            ![Too late](late.png)
            """,
            at: "README.md"
        )

        let evidence = try await GitHubPackageArtworkDiscovery().discoverArtwork(for: PackageArtworkQuery(
            packageID: PackageID(rawValue: "package.local"),
            sourceURL: fixture.url
        ))

        XCTAssertEqual(evidence.count, 1)
        XCTAssertEqual(evidence.first?.sourceKind, .readmeImage)
        XCTAssertEqual(evidence.first?.artwork.localURL?.lastPathComponent, "square.png")
        XCTAssertEqual(evidence.first?.contentMode, .fill)
    }

    func testLocalReadmeRejectsEscapesTinyImagesAndImagesAfterH2() async throws {
        let fixture = try TemporarySkillLibrary()
        _ = try fixture.write(try png(width: 32, height: 32, color: .green), at: "tiny.png")
        _ = try fixture.write(try png(width: 96, height: 96, color: .purple), at: "late.png")
        _ = try fixture.write(
            """
            ![Escape](../outside.png)
            ![Remote](https://example.com/image.png)
            ![Tiny](tiny.png)
            ## Details
            ![Late](late.png)
            """,
            at: "README.md"
        )

        let evidence = try await GitHubPackageArtworkDiscovery().discoverArtwork(for: PackageArtworkQuery(
            packageID: PackageID(rawValue: "package.local"),
            sourceURL: fixture.url
        ))
        XCTAssertTrue(evidence.isEmpty)
    }

    func testEmilKowalskiSkillsShapeFallsThroughToPersonalOwnerAvatar() async throws {
        let fixture = try TemporarySkillLibrary()
        _ = try fixture.write(try png(width: 320, height: 168, color: .black), at: "preview.png")
        _ = try fixture.write(try png(width: 180, height: 40, color: .gray), at: "badge.png")
        _ = try fixture.write(
            """
            # Skills
            ![Skills preview](preview.png)
            [![MIT badge](badge.png)](LICENSE)
            ## Installation
            """,
            at: "README.md"
        )
        let packageID = PackageID(rawValue: "github.com/emilkowalski/skills")
        let readmeEvidence = try await GitHubPackageArtworkDiscovery().discoverArtwork(for: PackageArtworkQuery(
            packageID: packageID,
            sourceURL: fixture.url
        ))
        XCTAssertTrue(readmeEvidence.isEmpty)

        let ownerEvidence = PackageArtworkEvidence(
            packageID: packageID,
            sourceKind: .githubOwnerAvatar,
            artwork: ArtworkReference(
                scope: .package,
                declaredPath: "github-owner-avatar.png",
                remoteURL: URL(string: "https://avatars.githubusercontent.com/u/36730035"),
                confidence: .verified
            )
        )
        let package = SkillPackageRecord(id: packageID, name: "Skills", skillIDs: [])
        let thumbnail = SkillThumbnailResolver.resolvePackage(
            package: package,
            upload: nil,
            evidence: [ownerEvidence],
            category: .generalUtility
        )
        XCTAssertEqual(thumbnail.sourceKind, .githubOwnerAvatar)
    }

    private func png(width: Int, height: Int, color: NSColor) throws -> Data {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { throw FixtureError.bitmap }
        _ = color
        bitmap.bitmapData?.initialize(
            repeating: 0x7F,
            count: bitmap.bytesPerRow * height
        )
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw FixtureError.encoding
        }
        return data
    }

    private enum FixtureError: Error {
        case bitmap
        case encoding
    }
}
