import Foundation

public protocol CatalogStore: Sendable {
    func loadSnapshot() async throws -> LibrarySnapshot?
    func saveSnapshot(_ snapshot: LibrarySnapshot) async throws
    func searchSkillIDs(matching query: String) async throws -> [SkillID]
    func rebuildIndex(from snapshot: LibrarySnapshot) async throws
    func loadCustomRoots() async throws -> [DiscoveryRootRecord]
    func saveCustomRoots(_ roots: [DiscoveryRootRecord]) async throws
    func recordOperation(_ operation: ManagedOperationRecord) async throws
    func recentOperations(limit: Int) async throws -> [ManagedOperationRecord]
    func baseline(for entryURL: URL) async throws -> InstallationBaseline?
    func saveBaseline(_ baseline: InstallationBaseline) async throws
    func loadSourceConnections() async throws -> [SourceConnection]
    func saveSourceConnection(_ connection: SourceConnection) async throws
    func removeSourceConnection(packageID: PackageID) async throws
    func loadRepositories() async throws -> [SourceRepositoryRecord]
    func saveRepositories(_ repositories: [SourceRepositoryRecord]) async throws
    func loadPackageProvenance() async throws -> [PackageProvenance]
    func savePackageProvenance(_ provenance: [PackageProvenance]) async throws
    func loadSourceEvidence() async throws -> [SourceEvidence]
    func saveSourceEvidence(_ evidence: [SourceEvidence]) async throws
    func loadInstallationSourceStates() async throws -> [InstallationSourceState]
    func saveInstallationSourceStates(_ states: [InstallationSourceState]) async throws
    func loadSourceCandidates() async throws -> [SourceCandidate]
    func saveSourceCandidates(_ candidates: [SourceCandidate]) async throws
    func loadIdentityAliases() async throws -> [IdentityAlias]
    func saveIdentityAliases(_ aliases: [IdentityAlias]) async throws
    func loadArtworkReferences() async throws -> [ArtworkReference]
    func saveArtworkReferences(_ references: [ArtworkReference]) async throws
    func loadPublishingTargets() async throws -> [PublishingTarget]
    func savePublishingTargets(_ targets: [PublishingTarget]) async throws
    func loadPublishingReceipts() async throws -> [PublishingReceipt]
    func savePublishingReceipts(_ receipts: [PublishingReceipt]) async throws
    func loadInstallerPackageReceipts() async throws -> [InstallerPackageReceipt]
    func saveInstallerPackageReceipts(_ receipts: [InstallerPackageReceipt]) async throws
    func loadPackageNameEvidence() async throws -> [PackageNameEvidence]
    func savePackageNameEvidence(_ evidence: [PackageNameEvidence]) async throws
    func loadPackageTitleOverrides() async throws -> [PackageTitleOverride]
    func savePackageTitleOverrides(_ overrides: [PackageTitleOverride]) async throws
    func loadSourceSearchRoots() async throws -> [SourceSearchRootRecord]
    func saveSourceSearchRoots(_ roots: [SourceSearchRootRecord]) async throws
    func loadIdentityClusterDecisions() async throws -> [IdentityClusterDecision]
    func saveIdentityClusterDecisions(_ decisions: [IdentityClusterDecision]) async throws
    func loadPackageArtworkEvidence() async throws -> [PackageArtworkEvidence]
    func savePackageArtworkEvidence(_ evidence: [PackageArtworkEvidence]) async throws
    func loadPackageArtworkUploads() async throws -> [PackageArtworkUpload]
    func savePackageArtworkUploads(_ uploads: [PackageArtworkUpload]) async throws
}

public extension CatalogStore {
    func loadRepositories() async throws -> [SourceRepositoryRecord] { [] }
    func saveRepositories(_ repositories: [SourceRepositoryRecord]) async throws {}
    func loadPackageProvenance() async throws -> [PackageProvenance] { [] }
    func savePackageProvenance(_ provenance: [PackageProvenance]) async throws {}
    func loadSourceEvidence() async throws -> [SourceEvidence] { [] }
    func saveSourceEvidence(_ evidence: [SourceEvidence]) async throws {}
    func loadInstallationSourceStates() async throws -> [InstallationSourceState] { [] }
    func saveInstallationSourceStates(_ states: [InstallationSourceState]) async throws {}
    func loadSourceCandidates() async throws -> [SourceCandidate] { [] }
    func saveSourceCandidates(_ candidates: [SourceCandidate]) async throws {}
    func loadIdentityAliases() async throws -> [IdentityAlias] { [] }
    func saveIdentityAliases(_ aliases: [IdentityAlias]) async throws {}
    func loadArtworkReferences() async throws -> [ArtworkReference] { [] }
    func saveArtworkReferences(_ references: [ArtworkReference]) async throws {}
    func loadPublishingTargets() async throws -> [PublishingTarget] { [] }
    func savePublishingTargets(_ targets: [PublishingTarget]) async throws {}
    func loadPublishingReceipts() async throws -> [PublishingReceipt] { [] }
    func savePublishingReceipts(_ receipts: [PublishingReceipt]) async throws {}
    func loadInstallerPackageReceipts() async throws -> [InstallerPackageReceipt] { [] }
    func saveInstallerPackageReceipts(_ receipts: [InstallerPackageReceipt]) async throws {}
    func loadPackageNameEvidence() async throws -> [PackageNameEvidence] { [] }
    func savePackageNameEvidence(_ evidence: [PackageNameEvidence]) async throws {}
    func loadPackageTitleOverrides() async throws -> [PackageTitleOverride] { [] }
    func savePackageTitleOverrides(_ overrides: [PackageTitleOverride]) async throws {}
    func loadSourceSearchRoots() async throws -> [SourceSearchRootRecord] { [] }
    func saveSourceSearchRoots(_ roots: [SourceSearchRootRecord]) async throws {}
    func loadIdentityClusterDecisions() async throws -> [IdentityClusterDecision] { [] }
    func saveIdentityClusterDecisions(_ decisions: [IdentityClusterDecision]) async throws {}
    func loadPackageArtworkEvidence() async throws -> [PackageArtworkEvidence] { [] }
    func savePackageArtworkEvidence(_ evidence: [PackageArtworkEvidence]) async throws {}
    func loadPackageArtworkUploads() async throws -> [PackageArtworkUpload] { [] }
    func savePackageArtworkUploads(_ uploads: [PackageArtworkUpload]) async throws {}
}
