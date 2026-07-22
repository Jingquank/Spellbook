import Foundation

public struct ArtworkReference: Identifiable, Codable, Hashable, Sendable {
    public let scope: ArtworkScope
    public let declaredPath: String
    public let localURL: URL?
    public let remoteURL: URL?
    public let sourceRevision: String?
    public let contentHash: String?
    public let confidence: ProvenanceConfidence

    public var id: String {
        [
            scope.rawValue,
            declaredPath,
            localURL?.absoluteString,
            remoteURL?.absoluteString,
            sourceRevision,
            contentHash
        ]
        .compactMap { $0 }
        .joined(separator: "::")
    }

    public init(
        scope: ArtworkScope,
        declaredPath: String,
        localURL: URL? = nil,
        remoteURL: URL? = nil,
        sourceRevision: String? = nil,
        contentHash: String? = nil,
        confidence: ProvenanceConfidence
    ) {
        self.scope = scope
        self.declaredPath = declaredPath
        self.localURL = localURL
        self.remoteURL = remoteURL
        self.sourceRevision = sourceRevision
        self.contentHash = contentHash
        self.confidence = confidence
    }
}
