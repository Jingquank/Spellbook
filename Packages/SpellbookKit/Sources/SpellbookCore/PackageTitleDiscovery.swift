import Foundation

public struct PackageTitleQuery: Hashable, Codable, Sendable {
    public let packageID: PackageID
    public let sourceURL: URL
    public let revision: String?

    public init(packageID: PackageID, sourceURL: URL, revision: String? = nil) {
        self.packageID = packageID
        self.sourceURL = sourceURL
        self.revision = revision
    }
}

public protocol PackageTitleDiscovering: Sendable {
    func discoverTitle(for query: PackageTitleQuery) async throws -> PackageNameEvidence
}
