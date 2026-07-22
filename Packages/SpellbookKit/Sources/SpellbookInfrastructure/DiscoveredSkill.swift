import Foundation
import SpellbookCore

struct DiscoveredSkill: Sendable {
    let packageID: PackageID
    let packageName: String
    let packageAuthor: String?
    let packageSourceURL: URL?
    let packageWebsiteURL: URL?
    let packageArtwork: ArtworkReference?
    let skillID: SkillID
    let name: String
    let summary: String
    let author: String?
    let websiteURL: URL?
    let sourceURL: URL?
    let skillArtwork: ArtworkReference?
    let markdownSource: String
    let installation: SkillInstallation
    let contentIdentityKey: String
    let aliasTarget: String?
    let provenanceHint: InstallerProvenanceHint?
    let sourceConfidence: ProvenanceConfidence?
    let sourceRevision: String?

    func applyingBaseline(_ baseline: InstallationBaseline) -> DiscoveredSkill {
        DiscoveredSkill(
            packageID: packageID,
            packageName: packageName,
            packageAuthor: packageAuthor,
            packageSourceURL: packageSourceURL,
            packageWebsiteURL: packageWebsiteURL,
            packageArtwork: packageArtwork,
            skillID: skillID,
            name: name,
            summary: summary,
            author: author,
            websiteURL: websiteURL,
            sourceURL: sourceURL,
            skillArtwork: skillArtwork,
            markdownSource: markdownSource,
            installation: installation.applyingBaseline(baseline),
            contentIdentityKey: contentIdentityKey,
            aliasTarget: aliasTarget,
            provenanceHint: provenanceHint,
            sourceConfidence: sourceConfidence,
            sourceRevision: sourceRevision
        )
    }
}
