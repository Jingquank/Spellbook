import Foundation

public struct PublishingTarget: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let repositoryURL: URL
    public let branch: String
    public let packageOverrideIDs: [PackageID]

    public init(
        id: String = UUID().uuidString,
        repositoryURL: URL,
        branch: String,
        packageOverrideIDs: [PackageID] = []
    ) {
        self.id = id
        self.repositoryURL = repositoryURL
        self.branch = branch
        self.packageOverrideIDs = packageOverrideIDs
    }
}

public struct PublishingFileChange: Identifiable, Codable, Hashable, Sendable {
    public let relativePath: String
    public let previousHash: String?
    public let proposedHash: String
    public let isArtwork: Bool

    public var id: String { relativePath }
    public var isNew: Bool { previousHash == nil }

    public init(relativePath: String, previousHash: String?, proposedHash: String, isArtwork: Bool) {
        self.relativePath = relativePath
        self.previousHash = previousHash
        self.proposedHash = proposedHash
        self.isArtwork = isArtwork
    }
}

public struct PublishingPlan: Identifiable, Hashable, Sendable {
    public let id: String
    public let target: PublishingTarget
    public let packageID: PackageID
    public let packageName: String
    public let agent: AgentKind
    public let expectedRemoteRevision: String?
    public let stagingURL: URL
    public let changes: [PublishingFileChange]

    public init(
        id: String,
        target: PublishingTarget,
        packageID: PackageID,
        packageName: String,
        agent: AgentKind,
        expectedRemoteRevision: String?,
        stagingURL: URL,
        changes: [PublishingFileChange]
    ) {
        self.id = id
        self.target = target
        self.packageID = packageID
        self.packageName = packageName
        self.agent = agent
        self.expectedRemoteRevision = expectedRemoteRevision
        self.stagingURL = stagingURL
        self.changes = changes
    }
}

public struct PublishingReceipt: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let packageID: PackageID
    public let agent: AgentKind
    public let repositoryURL: URL
    public let branch: String
    public let commit: String
    public let publishedAt: Date

    public init(
        id: String = UUID().uuidString,
        packageID: PackageID,
        agent: AgentKind,
        repositoryURL: URL,
        branch: String,
        commit: String,
        publishedAt: Date = .now
    ) {
        self.id = id
        self.packageID = packageID
        self.agent = agent
        self.repositoryURL = repositoryURL
        self.branch = branch
        self.commit = commit
        self.publishedAt = publishedAt
    }
}

public protocol SkillPublishing: Sendable {
    func preview(
        package: SkillPackageRecord,
        skills: [SkillRecord],
        agent: AgentKind,
        target: PublishingTarget
    ) async throws -> PublishingPlan
    func publish(_ plan: PublishingPlan, approveNewFiles: Bool) async throws -> PublishingReceipt
}

public enum PublishingError: LocalizedError, Sendable {
    case invalidRepository(String)
    case noInstallations(AgentKind)
    case newFilesNeedApproval
    case remoteMoved
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidRepository(let message): message
        case .noInstallations(let agent): "This package has no \(agent.displayName) installation to publish."
        case .newFilesNeedApproval: "Review and approve the new files before publishing."
        case .remoteMoved: "The remote branch moved after the preview. Fetch and review a fresh publishing plan."
        case .commandFailed(let message): message
        }
    }
}
