import SpellbookCore

public actor SourceUpdateCoordinator: SkillUpdating {
    private let catalog: any CatalogStore
    private let localGitUpdater: GitPackageUpdater
    private let connectedUpdater: ConnectedSourceUpdater

    public init(
        catalog: any CatalogStore,
        manager: any SkillManaging
    ) {
        self.catalog = catalog
        localGitUpdater = GitPackageUpdater(catalog: catalog)
        connectedUpdater = ConnectedSourceUpdater(catalog: catalog, manager: manager)
    }

    public func check(snapshot: LibrarySnapshot) async throws -> [PackageUpdate] {
        let connectedPackageIDs = Set(
            try await catalog.loadSourceConnections().map(\.packageID)
        )
        let localSnapshot = snapshot.excludingPackages(connectedPackageIDs)
        let connectedUpdates = try await connectedUpdater.check(snapshot: snapshot)
        let localUpdates: [PackageUpdate]
        do {
            localUpdates = try await localGitUpdater.check(snapshot: localSnapshot)
        } catch {
            if connectedUpdates.isEmpty { throw error }
            localUpdates = []
        }
        return (connectedUpdates + localUpdates).sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    public func apply(_ update: PackageUpdate) async throws -> PackageUpdateReceipt {
        switch update.strategy {
        case .localGit:
            try await localGitUpdater.apply(update)
        case .connectedGit, .directFile:
            try await connectedUpdater.apply(update)
        }
    }
}

private extension LibrarySnapshot {
    func excludingPackages(_ packageIDs: Set<PackageID>) -> LibrarySnapshot {
        LibrarySnapshot(
            packages: packages.filter { !packageIDs.contains($0.id) },
            skills: skills.filter { !packageIDs.contains($0.packageID) },
            scannedAt: scannedAt
        )
    }
}
