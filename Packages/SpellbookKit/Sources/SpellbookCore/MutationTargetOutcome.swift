import Foundation

public struct MutationTargetOutcome: Identifiable, Hashable, Sendable {
    public let id: String
    public let destinationURL: URL
    public let resultingHash: String?
    public let recoveryURL: URL?

    public init(
        id: String,
        destinationURL: URL,
        resultingHash: String?,
        recoveryURL: URL?
    ) {
        self.id = id
        self.destinationURL = destinationURL
        self.resultingHash = resultingHash
        self.recoveryURL = recoveryURL
    }
}
