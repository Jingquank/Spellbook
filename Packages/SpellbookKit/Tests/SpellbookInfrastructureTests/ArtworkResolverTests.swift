import Foundation
import XCTest
@testable import SpellbookInfrastructure

final class ArtworkResolverTests: XCTestCase {
    func testRejectsUnsafeSVGAndOversizedArtwork() throws {
        let fixture = try TemporarySkillLibrary()
        let root = try fixture.makeDirectory(at: "skill")
        _ = try fixture.write(
            "<svg><script>alert(1)</script><image href=\"https://example.com/a.png\"/></svg>",
            at: "skill/icon.svg"
        )
        XCTAssertNil(ArtworkResolver.resolveSkillArtwork(
            skillRoot: root,
            packageRoot: root,
            skillName: "Skill",
            interfaceMetadata: nil,
            frontmatterPath: "icon.svg"
        ))

        _ = try fixture.write(Data(repeating: 0x89, count: 5 * 1_024 * 1_024 + 1), at: "skill/icon.png")
        XCTAssertNil(ArtworkResolver.resolveSkillArtwork(
            skillRoot: root,
            packageRoot: root,
            skillName: "Skill",
            interfaceMetadata: nil,
            frontmatterPath: "icon.png"
        ))
    }

    func testRejectsArtworkEscapingPackageRootThroughSymlink() throws {
        let fixture = try TemporarySkillLibrary()
        let root = try fixture.makeDirectory(at: "skill")
        let outside = try fixture.write(
            Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
            at: "outside.png"
        )
        try FileManager.default.createSymbolicLink(
            at: root.appending(path: "icon.png"),
            withDestinationURL: outside
        )
        XCTAssertNil(ArtworkResolver.resolvePackageArtwork(packageRoot: root, declaredPath: "icon.png"))
    }
}
