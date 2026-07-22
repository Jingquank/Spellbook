import Foundation

public struct ManagedOperationRecord: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let kind: ManagedOperationKind
    public let status: ManagedOperationStatus
    public let startedAt: Date
    public let finishedAt: Date
    public let targetURLs: [URL]
    public let recoveryURLs: [URL]
    public let message: String?

    public init(
        id: String,
        kind: ManagedOperationKind,
        status: ManagedOperationStatus,
        startedAt: Date,
        finishedAt: Date,
        targetURLs: [URL],
        recoveryURLs: [URL],
        message: String?
    ) {
        self.id = id
        self.kind = kind
        self.status = status
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.targetURLs = targetURLs
        self.recoveryURLs = recoveryURLs
        self.message = message
    }
}
