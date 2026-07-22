import Foundation

public struct PackageUpdateReceipt: Hashable, Sendable {
    public let repositoryURL: URL
    public let previousRevision: String
    public let resultingRevision: String

    public init(repositoryURL: URL, previousRevision: String, resultingRevision: String) {
        self.repositoryURL = repositoryURL
        self.previousRevision = previousRevision
        self.resultingRevision = resultingRevision
    }
}
