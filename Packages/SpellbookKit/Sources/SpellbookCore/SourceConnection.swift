import Foundation

public struct SourceConnection: Identifiable, Codable, Hashable, Sendable {
    public let packageID: PackageID
    public let kind: SourceConnectionKind
    public let sourceURL: URL
    public let branch: String?
    public let subdirectory: String?
    public let lastRevision: String?
    public let connectedAt: Date

    public var id: String { packageID.rawValue }

    public init(
        packageID: PackageID,
        kind: SourceConnectionKind,
        sourceURL: URL,
        branch: String? = nil,
        subdirectory: String? = nil,
        lastRevision: String? = nil,
        connectedAt: Date = .now
    ) {
        self.packageID = packageID
        self.kind = kind
        self.sourceURL = sourceURL
        self.branch = branch
        self.subdirectory = subdirectory
        self.lastRevision = lastRevision
        self.connectedAt = connectedAt
    }

    public func settingLastRevision(_ revision: String) -> SourceConnection {
        SourceConnection(
            packageID: packageID,
            kind: kind,
            sourceURL: sourceURL,
            branch: branch,
            subdirectory: subdirectory,
            lastRevision: revision,
            connectedAt: connectedAt
        )
    }
}
