import Foundation

public struct SourceCandidate: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let packageID: PackageID
    public let sourceURL: URL
    public let packagePath: String?
    public let confidence: ProvenanceConfidence
    public let explanation: String
    public let discoveredAt: Date
    public let isRejected: Bool

    public init(
        id: String = UUID().uuidString,
        packageID: PackageID,
        sourceURL: URL,
        packagePath: String? = nil,
        confidence: ProvenanceConfidence,
        explanation: String,
        discoveredAt: Date = .now,
        isRejected: Bool = false
    ) {
        self.id = id
        self.packageID = packageID
        self.sourceURL = sourceURL
        self.packagePath = packagePath
        self.confidence = confidence
        self.explanation = explanation
        self.discoveredAt = discoveredAt
        self.isRejected = isRejected
    }
}
