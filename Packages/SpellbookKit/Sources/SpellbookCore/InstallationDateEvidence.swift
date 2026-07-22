import Foundation

public enum InstallationDateSource: String, Codable, Hashable, Sendable {
    case installerReceipt
    case spellbookOperation
    case filesystemCreation
    case firstSeen
}

public struct InstallationDateEvidence: Hashable, Codable, Sendable {
    public let installedAt: Date
    public let source: InstallationDateSource
    public let confidence: ProvenanceConfidence

    public init(
        installedAt: Date,
        source: InstallationDateSource,
        confidence: ProvenanceConfidence
    ) {
        self.installedAt = installedAt
        self.source = source
        self.confidence = confidence
    }
}
