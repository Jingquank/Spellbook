import Foundation

public struct SourceDiscoveryQuery: Codable, Hashable, Sendable {
    public let packageID: PackageID
    public let packageName: String
    public let skillNames: [String]
    public let author: String?
    public let filenames: [String]
    public let manifestIDs: [String]

    public init(
        packageID: PackageID,
        packageName: String,
        skillNames: [String],
        author: String? = nil,
        filenames: [String] = [],
        manifestIDs: [String] = []
    ) {
        self.packageID = packageID
        self.packageName = packageName
        self.skillNames = skillNames
        self.author = author
        self.filenames = filenames
        self.manifestIDs = manifestIDs
    }
}

public protocol SourceDiscovering: Sendable {
    func findCandidates(for query: SourceDiscoveryQuery) async throws -> [SourceCandidate]
    func deepSearchCandidates(for query: SourceDiscoveryQuery) async throws -> [SourceCandidate]
}

public enum SourceDiscoveryError: LocalizedError, Sendable {
    case unavailable(String)
    case rateLimited(resetAt: Date?)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .unavailable(let message): message
        case .rateLimited(let resetAt):
            if let resetAt {
                "GitHub’s search limit was reached. Try again after \(resetAt.formatted())."
            } else {
                "GitHub’s search limit was reached. Try again later."
            }
        case .invalidResponse: "GitHub returned an unreadable response."
        }
    }
}
