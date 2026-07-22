import Foundation

public struct InstallationBaseline: Identifiable, Hashable, Codable, Sendable {
    public let entryURL: URL
    public let contentHash: String
    public let sourceRevision: String?
    public let setAt: Date

    public var id: String { entryURL.standardizedFileURL.path }

    public init(
        entryURL: URL,
        contentHash: String,
        sourceRevision: String?,
        setAt: Date
    ) {
        self.entryURL = entryURL.standardizedFileURL
        self.contentHash = contentHash
        self.sourceRevision = sourceRevision
        self.setAt = setAt
    }
}
