import Foundation

public struct FileMutationReceipt: Hashable, Sendable {
    public let destinationURL: URL
    public let resultingHash: String?
    public let recoveryURL: URL?

    public init(destinationURL: URL, resultingHash: String?, recoveryURL: URL?) {
        self.destinationURL = destinationURL
        self.resultingHash = resultingHash
        self.recoveryURL = recoveryURL
    }
}
