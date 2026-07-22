import Foundation
import SpellbookCore

public actor CatalogStoreProxy: CatalogStore {
    private var store: (any CatalogStore)?
    private let unavailableReason: String

    public init(store: (any CatalogStore)?, unavailableReason: String) {
        self.store = store
        self.unavailableReason = unavailableReason
    }

    public func install(_ store: any CatalogStore) {
        self.store = store
    }

    public func loadSnapshot() async throws -> LibrarySnapshot? {
        try await resolvedStore().loadSnapshot()
    }

    public func saveSnapshot(_ snapshot: LibrarySnapshot) async throws {
        try await resolvedStore().saveSnapshot(snapshot)
    }

    public func searchSkillIDs(matching query: String) async throws -> [SkillID] {
        try await resolvedStore().searchSkillIDs(matching: query)
    }

    public func rebuildIndex(from snapshot: LibrarySnapshot) async throws {
        try await resolvedStore().rebuildIndex(from: snapshot)
    }

    public func loadCustomRoots() async throws -> [DiscoveryRootRecord] {
        try await resolvedStore().loadCustomRoots()
    }

    public func saveCustomRoots(_ roots: [DiscoveryRootRecord]) async throws {
        try await resolvedStore().saveCustomRoots(roots)
    }

    public func recordOperation(_ operation: ManagedOperationRecord) async throws {
        try await resolvedStore().recordOperation(operation)
    }

    public func recentOperations(limit: Int) async throws -> [ManagedOperationRecord] {
        try await resolvedStore().recentOperations(limit: limit)
    }

    public func baseline(for entryURL: URL) async throws -> InstallationBaseline? {
        try await resolvedStore().baseline(for: entryURL)
    }

    public func saveBaseline(_ baseline: InstallationBaseline) async throws {
        try await resolvedStore().saveBaseline(baseline)
    }

    public func loadSourceConnections() async throws -> [SourceConnection] {
        try await resolvedStore().loadSourceConnections()
    }

    public func saveSourceConnection(_ connection: SourceConnection) async throws {
        try await resolvedStore().saveSourceConnection(connection)
    }

    public func removeSourceConnection(packageID: PackageID) async throws {
        try await resolvedStore().removeSourceConnection(packageID: packageID)
    }

    public func loadRepositories() async throws -> [SourceRepositoryRecord] {
        try await resolvedStore().loadRepositories()
    }

    public func saveRepositories(_ repositories: [SourceRepositoryRecord]) async throws {
        try await resolvedStore().saveRepositories(repositories)
    }

    public func loadPackageProvenance() async throws -> [PackageProvenance] {
        try await resolvedStore().loadPackageProvenance()
    }

    public func savePackageProvenance(_ provenance: [PackageProvenance]) async throws {
        try await resolvedStore().savePackageProvenance(provenance)
    }

    public func loadSourceEvidence() async throws -> [SourceEvidence] {
        try await resolvedStore().loadSourceEvidence()
    }

    public func saveSourceEvidence(_ evidence: [SourceEvidence]) async throws {
        try await resolvedStore().saveSourceEvidence(evidence)
    }

    public func loadInstallationSourceStates() async throws -> [InstallationSourceState] {
        try await resolvedStore().loadInstallationSourceStates()
    }

    public func saveInstallationSourceStates(_ states: [InstallationSourceState]) async throws {
        try await resolvedStore().saveInstallationSourceStates(states)
    }

    public func loadSourceCandidates() async throws -> [SourceCandidate] {
        try await resolvedStore().loadSourceCandidates()
    }

    public func saveSourceCandidates(_ candidates: [SourceCandidate]) async throws {
        try await resolvedStore().saveSourceCandidates(candidates)
    }

    public func loadIdentityAliases() async throws -> [IdentityAlias] {
        try await resolvedStore().loadIdentityAliases()
    }

    public func saveIdentityAliases(_ aliases: [IdentityAlias]) async throws {
        try await resolvedStore().saveIdentityAliases(aliases)
    }

    public func loadArtworkReferences() async throws -> [ArtworkReference] {
        try await resolvedStore().loadArtworkReferences()
    }

    public func saveArtworkReferences(_ references: [ArtworkReference]) async throws {
        try await resolvedStore().saveArtworkReferences(references)
    }

    public func loadPublishingTargets() async throws -> [PublishingTarget] {
        try await resolvedStore().loadPublishingTargets()
    }

    public func savePublishingTargets(_ targets: [PublishingTarget]) async throws {
        try await resolvedStore().savePublishingTargets(targets)
    }

    public func loadPublishingReceipts() async throws -> [PublishingReceipt] {
        try await resolvedStore().loadPublishingReceipts()
    }

    public func savePublishingReceipts(_ receipts: [PublishingReceipt]) async throws {
        try await resolvedStore().savePublishingReceipts(receipts)
    }

    public func loadInstallerPackageReceipts() async throws -> [InstallerPackageReceipt] {
        try await resolvedStore().loadInstallerPackageReceipts()
    }

    public func saveInstallerPackageReceipts(_ receipts: [InstallerPackageReceipt]) async throws {
        try await resolvedStore().saveInstallerPackageReceipts(receipts)
    }

    public func loadPackageNameEvidence() async throws -> [PackageNameEvidence] {
        try await resolvedStore().loadPackageNameEvidence()
    }

    public func savePackageNameEvidence(_ evidence: [PackageNameEvidence]) async throws {
        try await resolvedStore().savePackageNameEvidence(evidence)
    }

    public func loadPackageTitleOverrides() async throws -> [PackageTitleOverride] {
        try await resolvedStore().loadPackageTitleOverrides()
    }

    public func savePackageTitleOverrides(_ overrides: [PackageTitleOverride]) async throws {
        try await resolvedStore().savePackageTitleOverrides(overrides)
    }

    public func loadSourceSearchRoots() async throws -> [SourceSearchRootRecord] {
        try await resolvedStore().loadSourceSearchRoots()
    }

    public func saveSourceSearchRoots(_ roots: [SourceSearchRootRecord]) async throws {
        try await resolvedStore().saveSourceSearchRoots(roots)
    }

    public func loadIdentityClusterDecisions() async throws -> [IdentityClusterDecision] {
        try await resolvedStore().loadIdentityClusterDecisions()
    }

    public func saveIdentityClusterDecisions(_ decisions: [IdentityClusterDecision]) async throws {
        try await resolvedStore().saveIdentityClusterDecisions(decisions)
    }

    public func loadPackageArtworkEvidence() async throws -> [PackageArtworkEvidence] {
        try await resolvedStore().loadPackageArtworkEvidence()
    }

    public func savePackageArtworkEvidence(_ evidence: [PackageArtworkEvidence]) async throws {
        try await resolvedStore().savePackageArtworkEvidence(evidence)
    }

    public func loadPackageArtworkUploads() async throws -> [PackageArtworkUpload] {
        try await resolvedStore().loadPackageArtworkUploads()
    }

    public func savePackageArtworkUploads(_ uploads: [PackageArtworkUpload]) async throws {
        try await resolvedStore().savePackageArtworkUploads(uploads)
    }

    private func resolvedStore() throws -> any CatalogStore {
        guard let store else { throw CatalogAccessError.unavailable(unavailableReason) }
        return store
    }
}
