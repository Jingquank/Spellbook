import Foundation

public struct MutationRequest: Hashable, Sendable {
    public let destinationURL: URL
    public let action: ManagedMutationAction
    public let expectedHash: String?
    public let proposedText: String?

    public init(
        destinationURL: URL,
        action: ManagedMutationAction,
        expectedHash: String?,
        proposedText: String?
    ) {
        self.destinationURL = destinationURL
        self.action = action
        self.expectedHash = expectedHash
        self.proposedText = proposedText
    }
}
