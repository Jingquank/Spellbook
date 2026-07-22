import Foundation
import Testing
@testable import SpellbookCore

@Suite("Package artwork")
struct PackageArtworkTests {
    @Test("The semantic taxonomy stays at 24 categories")
    func curatedTaxonomySize() {
        #expect(PackageArtworkCategory.allCases.count == 24)
        #expect((0..<100).allSatisfy {
            (0..<7).contains(SkillThumbnail.stablePaletteIndex(for: PackageID(rawValue: "package.\($0)")))
        })
        let styleIndexes = Set((0..<100).map {
            SkillThumbnail.stableFallbackStyleIndex(for: SkillID(rawValue: "skill.\($0)"))
        })
        #expect(styleIndexes == Set(0..<5))
    }

    @Test("Generated fallbacks keep stable package colors and per-skill compositions")
    func generatedFallbackVisualIdentity() {
        let packageID = PackageID(rawValue: "package.visual-identity")
        let skillID = SkillID(rawValue: "skill.visual-identity")
        let package = SkillPackageRecord(id: packageID, name: "Visual Identity", skillIDs: [skillID])
        let skill = SkillRecord(
            id: skillID,
            packageID: packageID,
            name: "Visual Identity",
            summary: "",
            markdownSource: "",
            installations: []
        )

        let thumbnail = SkillThumbnailResolver.resolveSkill(
            package: package,
            skill: skill,
            upload: nil,
            evidence: [],
            category: .designUI
        )

        #expect(thumbnail.sourceKind == .generatedFallback)
        #expect(thumbnail.paletteIndex == SkillThumbnail.stablePaletteIndex(for: packageID))
        #expect(thumbnail.fallbackStyleIndex == SkillThumbnail.stableFallbackStyleIndex(for: skillID))
    }

    @Test("Category inference uses package and skill meaning")
    func categoryInference() {
        let packageID = PackageID(rawValue: "swiftui")
        let skill = SkillRecord(
            id: SkillID(rawValue: "swiftui-pro"),
            packageID: packageID,
            name: "SwiftUI Pro",
            summary: "Review modern Apple platform code",
            markdownSource: "# SwiftUI review",
            installations: []
        )
        let package = SkillPackageRecord(id: packageID, name: "SwiftUI Pro", skillIDs: [skill.id])
        #expect(PackageArtworkCategory.infer(package: package, skills: [skill]) == .appleDevelopment)
    }

    @Test("Thumbnail precedence is upload, package, skill, then web evidence")
    func thumbnailPrecedence() {
        let packageID = PackageID(rawValue: "package.precedence")
        let packageArtwork = reference("package.png", scope: .package)
        let skillArtwork = reference("skill.png", scope: .skill)
        let package = SkillPackageRecord(
            id: packageID,
            name: "Precedence",
            artwork: packageArtwork,
            skillIDs: [SkillID(rawValue: "skill")]
        )
        let skill = SkillRecord(
            id: SkillID(rawValue: "skill"),
            packageID: packageID,
            name: "Skill",
            summary: "",
            artwork: skillArtwork,
            markdownSource: "",
            installations: []
        )
        let owner = PackageArtworkEvidence(
            packageID: packageID,
            sourceKind: .githubOwnerAvatar,
            artwork: reference("owner.png", scope: .package)
        )
        let upload = PackageArtworkUpload(
            packageID: packageID,
            localURL: URL(filePath: "/tmp/upload.png"),
            contentHash: "upload"
        )

        #expect(SkillThumbnailResolver.resolveSkill(
            package: package, skill: skill, upload: upload, evidence: [owner], category: .generalUtility
        ).sourceKind == .userUpload)
        #expect(SkillThumbnailResolver.resolveSkill(
            package: package, skill: skill, upload: nil, evidence: [owner], category: .generalUtility
        ).sourceKind == .packageIcon)
        #expect(SkillThumbnailResolver.resolveSkill(
            package: package.settingArtwork(nil), skill: skill, upload: nil, evidence: [owner], category: .generalUtility
        ).sourceKind == .skillIcon)
        #expect(SkillThumbnailResolver.resolveSkill(
            package: package.settingArtwork(nil),
            skill: skill.settingArtworkForTest(nil as ArtworkReference?),
            upload: nil,
            evidence: [owner],
            category: .generalUtility
        ).sourceKind == .githubOwnerAvatar)
    }

    @Test("Web evidence follows social, organization, README, owner order")
    func webEvidencePrecedence() {
        let packageID = PackageID(rawValue: "package.web")
        let package = SkillPackageRecord(id: packageID, name: "Web", skillIDs: [])
        let evidence: [PackageArtworkEvidence] = [
            .init(packageID: packageID, sourceKind: .githubOwnerAvatar, artwork: reference("owner.png", scope: .package)),
            .init(packageID: packageID, sourceKind: .readmeImage, artwork: reference("readme.png", scope: .package)),
            .init(packageID: packageID, sourceKind: .githubOrganizationAvatar, artwork: reference("org.png", scope: .package)),
            .init(packageID: packageID, sourceKind: .githubSocialPreview, artwork: reference("social.png", scope: .package))
        ]
        #expect(SkillThumbnailResolver.resolvePackage(
            package: package, upload: nil, evidence: evidence, category: .generalUtility
        ).sourceKind == .githubSocialPreview)
    }

    private func reference(_ path: String, scope: ArtworkScope) -> ArtworkReference {
        ArtworkReference(scope: scope, declaredPath: path, remoteURL: URL(string: "https://example.com/\(path)"), confidence: .verified)
    }
}

private extension SkillRecord {
    func settingArtworkForTest(_ artwork: ArtworkReference?) -> SkillRecord {
        SkillRecord(
            id: id,
            packageID: packageID,
            name: name,
            summary: summary,
            author: author,
            websiteURL: websiteURL,
            sourceURL: sourceURL,
            artwork: artwork,
            markdownSource: markdownSource,
            installations: installations
        )
    }
}
