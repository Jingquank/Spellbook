import Foundation

public struct SkillInstallation: Identifiable, Hashable, Codable, Sendable {
    public let id: InstallationID
    public let agent: AgentKind
    public let entryURL: URL
    public let rootURL: URL
    public let resolvedEntryURL: URL?
    public let markdownSource: String?
    public let agentVersion: String?
    public let observedModifiedAt: Date?
    public let managedUpdatedAt: Date?
    public let installationDateEvidence: InstallationDateEvidence?
    public let contentHash: String
    public let localState: LocalState
    public let updateAvailable: Bool

    public init(
        id: InstallationID,
        agent: AgentKind,
        entryURL: URL,
        rootURL: URL,
        resolvedEntryURL: URL? = nil,
        markdownSource: String? = nil,
        agentVersion: String? = nil,
        observedModifiedAt: Date? = nil,
        managedUpdatedAt: Date? = nil,
        installationDateEvidence: InstallationDateEvidence? = nil,
        contentHash: String,
        localState: LocalState = .unverified,
        updateAvailable: Bool = false
    ) {
        self.id = id
        self.agent = agent
        self.entryURL = entryURL
        self.rootURL = rootURL
        self.resolvedEntryURL = resolvedEntryURL
        self.markdownSource = markdownSource
        self.agentVersion = agentVersion
        self.observedModifiedAt = observedModifiedAt
        self.managedUpdatedAt = managedUpdatedAt
        self.installationDateEvidence = installationDateEvidence
        self.contentHash = contentHash
        self.localState = localState
        self.updateAvailable = updateAvailable
    }

    public func settingUpdateAvailable(_ updateAvailable: Bool) -> SkillInstallation {
        SkillInstallation(
            id: id,
            agent: agent,
            entryURL: entryURL,
            rootURL: rootURL,
            resolvedEntryURL: resolvedEntryURL,
            markdownSource: markdownSource,
            agentVersion: agentVersion,
            observedModifiedAt: observedModifiedAt,
            managedUpdatedAt: managedUpdatedAt,
            installationDateEvidence: installationDateEvidence,
            contentHash: contentHash,
            localState: localState,
            updateAvailable: updateAvailable
        )
    }

    public func applyingBaseline(_ baseline: InstallationBaseline) -> SkillInstallation {
        SkillInstallation(
            id: id,
            agent: agent,
            entryURL: entryURL,
            rootURL: rootURL,
            resolvedEntryURL: resolvedEntryURL,
            markdownSource: markdownSource,
            agentVersion: agentVersion,
            observedModifiedAt: observedModifiedAt,
            managedUpdatedAt: baseline.setAt,
            installationDateEvidence: installationDateEvidence,
            contentHash: contentHash,
            localState: baseline.contentHash == contentHash ? .clean : .modified,
            updateAvailable: updateAvailable
        )
    }

    public func settingLocalState(_ localState: LocalState) -> SkillInstallation {
        SkillInstallation(
            id: id,
            agent: agent,
            entryURL: entryURL,
            rootURL: rootURL,
            resolvedEntryURL: resolvedEntryURL,
            markdownSource: markdownSource,
            agentVersion: agentVersion,
            observedModifiedAt: observedModifiedAt,
            managedUpdatedAt: managedUpdatedAt,
            installationDateEvidence: installationDateEvidence,
            contentHash: contentHash,
            localState: localState,
            updateAvailable: updateAvailable
        )
    }

    public func settingInstallationDateEvidence(
        _ installationDateEvidence: InstallationDateEvidence?
    ) -> SkillInstallation {
        SkillInstallation(
            id: id,
            agent: agent,
            entryURL: entryURL,
            rootURL: rootURL,
            resolvedEntryURL: resolvedEntryURL,
            markdownSource: markdownSource,
            agentVersion: agentVersion,
            observedModifiedAt: observedModifiedAt,
            managedUpdatedAt: managedUpdatedAt,
            installationDateEvidence: installationDateEvidence,
            contentHash: contentHash,
            localState: localState,
            updateAvailable: updateAvailable
        )
    }

    public var actionableStatus: ActionableStatus? {
        switch localState {
        case .conflict: .conflict
        case .missing, .accessRequired: .actionRequired
        case .modified: .modified
        default: updateAvailable ? .updateAvailable : nil
        }
    }
}
