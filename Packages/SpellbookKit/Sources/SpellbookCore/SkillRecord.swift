import Foundation

public struct SkillRecord: Identifiable, Hashable, Codable, Sendable {
    public let id: SkillID
    public let packageID: PackageID
    public let name: String
    public let summary: String
    public let author: String?
    public let websiteURL: URL?
    public let sourceURL: URL?
    public let artwork: ArtworkReference?
    public let markdownSource: String
    public let installations: [SkillInstallation]

    public init(
        id: SkillID,
        packageID: PackageID,
        name: String,
        summary: String,
        author: String? = nil,
        websiteURL: URL? = nil,
        sourceURL: URL? = nil,
        artwork: ArtworkReference? = nil,
        markdownSource: String,
        installations: [SkillInstallation]
    ) {
        self.id = id
        self.packageID = packageID
        self.name = name
        self.summary = summary
        self.author = author
        self.websiteURL = websiteURL
        self.sourceURL = sourceURL
        self.artwork = artwork
        self.markdownSource = markdownSource
        self.installations = installations
    }

    public var actionableStatus: ActionableStatus? {
        let statuses = installations.compactMap(\.actionableStatus)
        return statuses.max()
    }

    public var searchText: String {
        [
            name,
            summary,
            author,
            websiteURL?.absoluteString,
            sourceURL?.absoluteString,
            markdownSource,
            installations.map(\.entryURL.path).joined(separator: " "),
            installations.map(\.agent.displayName).joined(separator: " ")
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    public func settingUpdateAvailable(_ updateAvailable: Bool) -> SkillRecord {
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
            installations: installations.map { $0.settingUpdateAvailable(updateAvailable) }
        )
    }

    public func replacingInstallations(_ installations: [SkillInstallation]) -> SkillRecord {
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

    public func settingSourceURL(_ sourceURL: URL) -> SkillRecord {
        SkillRecord(
            id: id,
            packageID: packageID,
            name: name,
            summary: summary,
            author: author,
            websiteURL: websiteURL ?? sourceURL,
            sourceURL: sourceURL,
            artwork: artwork,
            markdownSource: markdownSource,
            installations: installations
        )
    }
}
