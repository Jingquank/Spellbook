import Foundation

public struct PackageProvenance: Identifiable, Codable, Hashable, Sendable {
    public let packageID: PackageID
    public let originURL: URL?
    public let originSubdirectory: String?
    public let updateURL: URL?
    public let publishingURL: URL?
    public let branch: String?
    public let confidence: ProvenanceConfidence
    public let lastVerifiedAt: Date?

    public var id: PackageID { packageID }

    public init(
        packageID: PackageID,
        originURL: URL? = nil,
        originSubdirectory: String? = nil,
        updateURL: URL? = nil,
        publishingURL: URL? = nil,
        branch: String? = nil,
        confidence: ProvenanceConfidence,
        lastVerifiedAt: Date? = nil
    ) {
        self.packageID = packageID
        self.originURL = originURL
        self.originSubdirectory = originSubdirectory
        self.updateURL = updateURL
        self.publishingURL = publishingURL
        self.branch = branch
        self.confidence = confidence
        self.lastVerifiedAt = lastVerifiedAt
    }
}
