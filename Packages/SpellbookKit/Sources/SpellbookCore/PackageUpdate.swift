import Foundation

public struct PackageUpdate: Identifiable, Hashable, Sendable {
    public let id: String
    public let packageIDs: [PackageID]
    public let packageNames: [String]
    public let repositoryURL: URL
    public let sourceURL: URL?
    public let currentRevision: String
    public let targetRevision: String
    public let canApply: Bool
    public let blockingReason: String?
    public let strategy: PackageUpdateStrategy
    public let affectedSkillNames: [String]
    public let affectedInstallationCount: Int
    public let mutationPlan: ManagedMutationPlan?
    public let sourceConnection: SourceConnection?
    public let targetAgent: AgentKind?
    public let offeredSkillNames: [String]

    public init(
        id: String,
        packageIDs: [PackageID],
        packageNames: [String],
        repositoryURL: URL,
        sourceURL: URL?,
        currentRevision: String,
        targetRevision: String,
        canApply: Bool,
        blockingReason: String?,
        strategy: PackageUpdateStrategy = .localGit,
        affectedSkillNames: [String] = [],
        affectedInstallationCount: Int = 0,
        mutationPlan: ManagedMutationPlan? = nil,
        sourceConnection: SourceConnection? = nil,
        targetAgent: AgentKind? = nil,
        offeredSkillNames: [String] = []
    ) {
        self.id = id
        self.packageIDs = packageIDs
        self.packageNames = packageNames
        self.repositoryURL = repositoryURL
        self.sourceURL = sourceURL
        self.currentRevision = currentRevision
        self.targetRevision = targetRevision
        self.canApply = canApply
        self.blockingReason = blockingReason
        self.strategy = strategy
        self.affectedSkillNames = affectedSkillNames
        self.affectedInstallationCount = affectedInstallationCount
        self.mutationPlan = mutationPlan
        self.sourceConnection = sourceConnection
        self.targetAgent = targetAgent
        self.offeredSkillNames = offeredSkillNames
    }

    public var displayName: String {
        packageNames.joined(separator: ", ")
    }
}
