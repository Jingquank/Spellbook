import Foundation
import SpellbookCore

public struct FileSystemSkillScanner: TargetedSkillScanning, Sendable {
    public let roots: [SkillDiscoveryRoot]
    private let registry: DiscoveryRootRegistry?
    private let catalog: (any CatalogStore)?

    public init(
        roots: [SkillDiscoveryRoot] = SkillDiscoveryRoot.known,
        catalog: (any CatalogStore)? = nil
    ) {
        self.roots = roots
        registry = nil
        self.catalog = catalog
    }

    public init(
        registry: DiscoveryRootRegistry,
        catalog: (any CatalogStore)? = nil
    ) {
        roots = []
        self.registry = registry
        self.catalog = catalog
    }

    public func scan() -> AsyncThrowingStream<ScanUpdate, any Error> {
        let roots = roots
        let registry = registry
        let catalog = catalog

        return AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .utility) {
                do {
                    let resolvedRoots = try await registry?.skillDiscoveryRoots() ?? roots
                    try await scanRoots(
                        resolvedRoots,
                        catalog: catalog,
                        continuation: continuation
                    )
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func reconcile(
        snapshot: LibrarySnapshot,
        changes: FileChangeBatch
    ) -> AsyncThrowingStream<ScanUpdate, any Error> {
        let configuredRoots = roots
        let registry = registry
        let catalog = catalog

        return AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .utility) {
                do {
                    let allRoots = try await registry?.skillDiscoveryRoots() ?? configuredRoots
                    let affectedRoots = allRoots.filter { root in
                        changes.urls.contains { changedURL in
                            changedURL.isDescendantOrEqual(to: root.url)
                                || root.url.isDescendantOrEqual(to: changedURL)
                        }
                    }
                    guard !affectedRoots.isEmpty else {
                        continuation.finish()
                        return
                    }
                    let rootRecords = affectedRoots.map {
                        DiscoveryRootRecord(agent: $0.agent, url: $0.url, isKnown: false)
                    }
                    let partialScanner = FileSystemSkillScanner(
                        roots: affectedRoots,
                        catalog: catalog
                    )
                    for try await update in partialScanner.scan() {
                        switch update {
                        case .progress(let partial, let count):
                            continuation.yield(.progress(
                                snapshot: snapshot.replacingRoots(rootRecords, with: partial),
                                scannedFileCount: count
                            ))
                        case .finished(let partial, let count):
                            continuation.yield(.finished(
                                snapshot: snapshot.replacingRoots(rootRecords, with: partial),
                                scannedFileCount: count
                            ))
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

private extension URL {
    func isDescendantOrEqual(to ancestor: URL) -> Bool {
        let components = standardizedFileURL.pathComponents
        let ancestorComponents = ancestor.standardizedFileURL.pathComponents
        return components.count >= ancestorComponents.count
            && Array(components.prefix(ancestorComponents.count)) == ancestorComponents
    }
}

private func scanRoots(
    _ roots: [SkillDiscoveryRoot],
    catalog: (any CatalogStore)?,
    continuation: AsyncThrowingStream<ScanUpdate, any Error>.Continuation
) async throws {
    var discoveries = [DiscoveredSkill]()
    let configuredSourceRoots = (try? await catalog?.loadSourceSearchRoots()) ?? []
    let sourceSearchRoots = configuredSourceRoots.isEmpty
        ? [SourceSearchRootRecord(url: URL(filePath: "/Users/keding/Cursor", directoryHint: .isDirectory))]
        : configuredSourceRoots
    let provenanceIndex = InstallerProvenanceIndex.load(
        roots: roots,
        sourceSearchRoots: sourceSearchRoots
    )
    let artworkCache = ArtworkResolutionCache()
    let manifestCache = PackageManifestResolutionCache()
    let gitCache = GitRepositoryInspectionCache()
    let cachedSnapshot = try? await catalog?.loadSnapshot()
    var visitedInstallations = Set<String>()
    var scannedFileCount = 0
    var unavailableRoots = [(root: SkillDiscoveryRoot, state: LocalState)]()

    for root in roots {
        try Task.checkCancellation()

        if let unavailableState = unavailableState(for: root.url) {
            unavailableRoots.append((root, unavailableState))
            continue
        }

        for entryURL in SkillFileEnumerator.entries(in: root.url) {
            try Task.checkCancellation()

            let installationKey = "\(root.agent.rawValue)::\(entryURL.standardizedFileURL.path)"
            guard visitedInstallations.insert(installationKey).inserted else { continue }
            scannedFileCount += 1

            guard var discovery = DiscoveredSkillReader.read(
                entryURL: entryURL,
                discoveryRoot: root,
                provenanceIndex: provenanceIndex,
                artworkCache: artworkCache,
                manifestCache: manifestCache,
                gitCache: gitCache
            ) else {
                continue
            }
            if let baseline = try? await catalog?.baseline(for: discovery.installation.entryURL) {
                discovery = discovery.applyingBaseline(baseline)
            }

            discoveries.append(discovery)
            if discoveries.count == 1 || discoveries.count.isMultiple(of: 100) {
                let built = LibrarySnapshotBuilder.snapshot(from: discoveries, scannedAt: .now)
                let snapshot = IdentityReconciler.reconcile(
                    discovered: built,
                    with: cachedSnapshot
                ).snapshot
                continuation.yield(.progress(snapshot: snapshot, scannedFileCount: scannedFileCount))
            }
        }
    }

    let scannedAt = Date.now
    let builtSnapshot = LibrarySnapshotBuilder.snapshot(from: discoveries, scannedAt: scannedAt)
    let reconciliation = IdentityReconciler.reconcile(
        discovered: builtSnapshot,
        with: cachedSnapshot
    )
    var snapshot = reconciliation.snapshot
    if !unavailableRoots.isEmpty, let cached = cachedSnapshot {
        for unavailableRoot in unavailableRoots {
            let rootRecord = DiscoveryRootRecord(
                agent: unavailableRoot.root.agent,
                url: unavailableRoot.root.url,
                isKnown: false
            )
            let unavailableSnapshot = cached.projectingRoots(
                [rootRecord],
                localState: unavailableRoot.state,
                scannedAt: scannedAt
            )
            snapshot = snapshot.replacingRoots([rootRecord], with: unavailableSnapshot)
        }
    }
    if let catalog {
        try? await catalog.saveInstallerPackageReceipts(provenanceIndex.receipts)
        try? await persistDiscoveryMetadata(
            discoveries: discoveries,
            snapshot: snapshot,
            aliases: reconciliation.aliases,
            catalog: catalog,
            observedAt: scannedAt
        )
    }
    continuation.yield(.finished(snapshot: snapshot, scannedFileCount: scannedFileCount))
    continuation.finish()
}

private func persistDiscoveryMetadata(
    discoveries: [DiscoveredSkill],
    snapshot: LibrarySnapshot,
    aliases: [IdentityAlias],
    catalog: any CatalogStore,
    observedAt: Date
) async throws {
    let skillByPath = Dictionary(uniqueKeysWithValues: snapshot.skills.flatMap { skill in
        skill.installations.map { ($0.entryURL.standardizedFileURL.path, skill) }
    })
    var evidence = [SourceEvidence]()
    var provenanceByPackage = Dictionary(uniqueKeysWithValues:
        try await catalog.loadPackageProvenance().map { ($0.packageID, $0) }
    )
    var repositoriesByURL = Dictionary(uniqueKeysWithValues:
        try await catalog.loadRepositories().map {
            (RepositoryURLNormalizer.stableString($0.sourceURL), $0)
        }
    )
    let existingInstallationStates = try await catalog.loadInstallationSourceStates()
    var installationStates = [InstallationSourceState]()

    for discovery in discoveries {
        guard let skill = skillByPath[discovery.installation.entryURL.standardizedFileURL.path] else {
            continue
        }
        let sourceURL = discovery.packageSourceURL
        if let sourceURL, let confidence = discovery.sourceConfidence {
            let normalizedURL = RepositoryURLNormalizer.stableString(sourceURL)
            let repositoryID = "repository-\(StableHasher.sha256(normalizedURL))"
            repositoriesByURL[normalizedURL] = SourceRepositoryRecord(
                id: repositoryID,
                sourceURL: sourceURL,
                provider: sourceURL.host?.contains("github.com") == true ? "github" : "git",
                lastVerifiedAt: confidence == .verified ? observedAt : nil
            )
            let existing = provenanceByPackage[skill.packageID]
            let chosenConfidence = max(existing?.confidence ?? .possible, confidence)
            provenanceByPackage[skill.packageID] = PackageProvenance(
                packageID: skill.packageID,
                originURL: existing?.originURL ?? sourceURL,
                originSubdirectory: existing?.originSubdirectory ?? discovery.provenanceHint?.skillPath,
                updateURL: existing?.updateURL ?? sourceURL,
                publishingURL: existing?.publishingURL,
                branch: existing?.branch,
                confidence: chosenConfidence,
                lastVerifiedAt: chosenConfidence == .verified ? observedAt : existing?.lastVerifiedAt
            )
            let evidenceKind = discovery.provenanceHint == nil
                ? (confidence == .verified ? "enclosing-git" : "declared-source")
                : "installer-receipt"
            evidence.append(SourceEvidence(
                id: "\(evidenceKind)::\(discovery.installation.id.rawValue)::\(normalizedURL)",
                packageID: skill.packageID,
                installationID: discovery.installation.id,
                kind: evidenceKind,
                sourceURL: sourceURL,
                packagePath: discovery.provenanceHint?.skillPath,
                skillPath: discovery.provenanceHint?.skillPath,
                revision: discovery.sourceRevision,
                contentHash: discovery.provenanceHint?.contentHash,
                confidence: confidence,
                explanation: discovery.provenanceHint?.explanation
                    ?? (confidence == .verified
                        ? "Matched an enclosing Git repository."
                        : "Declared by local package metadata or skill frontmatter."),
                observedAt: observedAt
            ))
        }
        installationStates.append(InstallationSourceState(
            installationID: discovery.installation.id,
            packageID: skill.packageID,
            installedRevision: discovery.sourceRevision,
            baselineHash: discovery.provenanceHint?.contentHash,
            lastCheckedAt: observedAt
        ))
    }

    let existingEvidence = try await catalog.loadSourceEvidence()
    let retainedEvidence = existingEvidence.filter { existing in
        !evidence.contains(where: { $0.id == existing.id })
    }
    let existingAliases = try await catalog.loadIdentityAliases()
    let retainedAliases = existingAliases.filter { existing in
        !aliases.contains(where: { $0.id == existing.id })
    }
    let artwork = snapshot.packages.compactMap(\.artwork) + snapshot.skills.compactMap(\.artwork)
    let discoveredInstallationIDs = Set(installationStates.map(\.installationID))
    try await catalog.saveRepositories(Array(repositoriesByURL.values))
    try await catalog.savePackageProvenance(Array(provenanceByPackage.values))
    try await catalog.saveSourceEvidence(retainedEvidence + evidence)
    try await catalog.saveInstallationSourceStates(
        existingInstallationStates.filter { !discoveredInstallationIDs.contains($0.installationID) }
            + installationStates
    )
    try await catalog.saveIdentityAliases(retainedAliases + aliases)
    try await catalog.saveArtworkReferences(artwork)
}

private func unavailableState(for rootURL: URL) -> LocalState? {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirectory) else {
        return .missing
    }
    guard FileManager.default.isReadableFile(atPath: rootURL.path) else {
        return .accessRequired
    }
    return nil
}
