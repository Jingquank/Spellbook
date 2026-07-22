import Foundation

public struct PackageArtworkQuery: Hashable, Sendable {
    public let packageID: PackageID
    public let sourceURL: URL
    public let revision: String?

    public init(packageID: PackageID, sourceURL: URL, revision: String? = nil) {
        self.packageID = packageID
        self.sourceURL = sourceURL
        self.revision = revision
    }
}

public protocol PackageArtworkDiscovering: Sendable {
    func discoverArtwork(for query: PackageArtworkQuery) async throws -> [PackageArtworkEvidence]
}
