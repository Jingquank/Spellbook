import Foundation

public struct SkillPackageRecord: Identifiable, Hashable, Codable, Sendable {
    public let id: PackageID
    public let name: String
    public let author: String?
    public let sourceURL: URL?
    public let websiteURL: URL?
    public let artwork: ArtworkReference?
    public let skillIDs: [SkillID]

    public init(
        id: PackageID,
        name: String,
        author: String? = nil,
        sourceURL: URL? = nil,
        websiteURL: URL? = nil,
        artwork: ArtworkReference? = nil,
        skillIDs: [SkillID]
    ) {
        self.id = id
        self.name = name
        self.author = author
        self.sourceURL = sourceURL
        self.websiteURL = websiteURL
        self.artwork = artwork
        self.skillIDs = skillIDs
    }

    public func replacingSkillIDs(_ skillIDs: [SkillID]) -> SkillPackageRecord {
        SkillPackageRecord(
            id: id,
            name: name,
            author: author,
            sourceURL: sourceURL,
            websiteURL: websiteURL,
            artwork: artwork,
            skillIDs: skillIDs
        )
    }

    public func settingSourceURL(_ sourceURL: URL) -> SkillPackageRecord {
        SkillPackageRecord(
            id: id,
            name: name,
            author: author,
            sourceURL: sourceURL,
            websiteURL: websiteURL ?? sourceURL,
            artwork: artwork,
            skillIDs: skillIDs
        )
    }

    public func settingName(_ name: String) -> SkillPackageRecord {
        SkillPackageRecord(
            id: id,
            name: name,
            author: author,
            sourceURL: sourceURL,
            websiteURL: websiteURL,
            artwork: artwork,
            skillIDs: skillIDs
        )
    }

    public func settingArtwork(_ artwork: ArtworkReference?) -> SkillPackageRecord {
        SkillPackageRecord(
            id: id,
            name: name,
            author: author,
            sourceURL: sourceURL,
            websiteURL: websiteURL,
            artwork: artwork,
            skillIDs: skillIDs
        )
    }
}
