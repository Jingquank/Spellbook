import Foundation

public struct MutationTargetPlan: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let destinationURL: URL
    public let action: ManagedMutationAction
    public let expectedHash: String?
    public let proposedHash: String?
    public let originalText: String?
    public let proposedText: String?
    public let stagedURL: URL?
    public let diff: MutationDiffSummary

    public init(
        id: String,
        destinationURL: URL,
        action: ManagedMutationAction,
        expectedHash: String?,
        proposedHash: String?,
        originalText: String?,
        proposedText: String?,
        stagedURL: URL?,
        diff: MutationDiffSummary
    ) {
        self.id = id
        self.destinationURL = destinationURL
        self.action = action
        self.expectedHash = expectedHash
        self.proposedHash = proposedHash
        self.originalText = originalText
        self.proposedText = proposedText
        self.stagedURL = stagedURL
        self.diff = diff
    }
}
