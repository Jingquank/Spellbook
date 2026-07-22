import Foundation

public struct ProjectedGroup: Identifiable, Hashable, Sendable {
    public let id: String
    public let kind: LibraryGroupKind
    public let packageID: PackageID?
    public let title: String
    public let thumbnail: SkillThumbnail?
    public let skills: [ProjectedSkill]
    public let actionableStatus: ActionableStatus?
    public let effectiveInstalledAt: Date?

    public init(
        id: String,
        kind: LibraryGroupKind,
        packageID: PackageID? = nil,
        title: String,
        artwork: ArtworkReference? = nil,
        thumbnail: SkillThumbnail? = nil,
        skills: [ProjectedSkill],
        actionableStatus: ActionableStatus?,
        effectiveInstalledAt: Date? = nil,
        fallbackCategory: PackageArtworkCategory = .generalUtility
    ) {
        self.id = id
        self.kind = kind
        self.packageID = packageID
        self.title = title
        self.thumbnail = thumbnail ?? packageID.map { packageID in
            SkillThumbnail(
                artwork: artwork,
                sourceKind: artwork == nil ? .generatedFallback : .packageIcon,
                contentMode: artwork == nil ? .fill : .fit,
                fallbackCategory: fallbackCategory,
                paletteIndex: SkillThumbnail.stablePaletteIndex(for: packageID),
                fallbackStyleIndex: SkillThumbnail.stableFallbackStyleIndex(for: packageID)
            )
        }
        self.skills = skills
        self.actionableStatus = actionableStatus
        self.effectiveInstalledAt = effectiveInstalledAt
    }

    public var artwork: ArtworkReference? { thumbnail?.artwork }
    public var fallbackCategory: PackageArtworkCategory { thumbnail?.fallbackCategory ?? .generalUtility }
}
