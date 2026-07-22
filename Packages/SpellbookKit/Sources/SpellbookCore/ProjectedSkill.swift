import Foundation

public struct ProjectedSkill: Identifiable, Hashable, Sendable {
    public let id: LibrarySelection
    public let skillID: SkillID
    public let packageID: PackageID
    public let memberSkillIDs: [SkillID]
    public let name: String
    public let summary: String
    public let thumbnail: SkillThumbnail
    public let effectiveInstalledAt: Date?
    public let actionableStatus: ActionableStatus?
    public let isProvisionalCluster: Bool

    public init(
        id: LibrarySelection,
        skillID: SkillID,
        packageID: PackageID = PackageID(rawValue: "package.unknown"),
        memberSkillIDs: [SkillID]? = nil,
        name: String,
        summary: String,
        artwork: ArtworkReference? = nil,
        thumbnail: SkillThumbnail? = nil,
        fallbackCategory: PackageArtworkCategory = .generalUtility,
        effectiveInstalledAt: Date? = nil,
        actionableStatus: ActionableStatus?,
        isProvisionalCluster: Bool = false
    ) {
        self.id = id
        self.skillID = skillID
        self.packageID = packageID
        self.memberSkillIDs = memberSkillIDs ?? [skillID]
        self.name = name
        self.summary = summary
        self.thumbnail = thumbnail ?? SkillThumbnail(
            artwork: artwork,
            sourceKind: artwork == nil ? .generatedFallback : .skillIcon,
            contentMode: artwork == nil ? .fill : .fit,
            fallbackCategory: fallbackCategory,
            paletteIndex: SkillThumbnail.stablePaletteIndex(for: packageID),
            fallbackStyleIndex: SkillThumbnail.stableFallbackStyleIndex(for: skillID)
        )
        self.effectiveInstalledAt = effectiveInstalledAt
        self.actionableStatus = actionableStatus
        self.isProvisionalCluster = isProvisionalCluster
    }

    public var artwork: ArtworkReference? { thumbnail.artwork }
    public var fallbackCategory: PackageArtworkCategory { thumbnail.fallbackCategory }
}
