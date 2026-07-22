import Foundation

public struct SourceRepositoryRecord: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let sourceURL: URL
    public let provider: String
    public let defaultBranch: String?
    public let lastVerifiedAt: Date?

    public init(
        id: String,
        sourceURL: URL,
        provider: String,
        defaultBranch: String? = nil,
        lastVerifiedAt: Date? = nil
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.provider = provider
        self.defaultBranch = defaultBranch
        self.lastVerifiedAt = lastVerifiedAt
    }
}
