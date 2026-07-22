import Foundation

public struct SourceEvidence: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let packageID: PackageID
    public let installationID: InstallationID?
    public let kind: String
    public let sourceURL: URL?
    public let packagePath: String?
    public let skillPath: String?
    public let revision: String?
    public let contentHash: String?
    public let confidence: ProvenanceConfidence
    public let explanation: String
    public let observedAt: Date

    public init(
        id: String = UUID().uuidString,
        packageID: PackageID,
        installationID: InstallationID? = nil,
        kind: String,
        sourceURL: URL? = nil,
        packagePath: String? = nil,
        skillPath: String? = nil,
        revision: String? = nil,
        contentHash: String? = nil,
        confidence: ProvenanceConfidence,
        explanation: String,
        observedAt: Date = .now
    ) {
        self.id = id
        self.packageID = packageID
        self.installationID = installationID
        self.kind = kind
        self.sourceURL = sourceURL
        self.packagePath = packagePath
        self.skillPath = skillPath
        self.revision = revision
        self.contentHash = contentHash
        self.confidence = confidence
        self.explanation = explanation
        self.observedAt = observedAt
    }
}
