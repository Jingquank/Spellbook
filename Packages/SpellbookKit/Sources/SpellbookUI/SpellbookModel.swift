import Foundation
import Observation
import SpellbookCore

public enum LibraryScanPhase: Equatable, Sendable {
    case idle
    case scanning(fileCount: Int)
    case failed(message: String)
}

@MainActor
@Observable
public final class SpellbookModel {
    public var selection: LibrarySelection?
    public var viewMode: LibraryViewMode {
        didSet { if oldValue != viewMode { invalidateProjection() } }
    }
    public var searchText = "" {
        didSet { if oldValue != searchText { invalidateProjection() } }
    }
    public var appearanceMode: AppearanceMode
    public var density: InterfaceDensity
    public var textScale: InterfaceTextScale
    public var readerWidth: ReaderWidth
    public var readerTextScale: ReaderTextScale
    public var wrapsCode: Bool
    public var alwaysShowsPackageGroups: Bool {
        didSet { if oldValue != alwaysShowsPackageGroups { invalidateProjection() } }
    }
    public var scanOnLaunch: Bool
    public var preferRepositoryTitles: Bool
    public var searchesEntireHome: Bool
    public var skillSortMode: SidebarSortMode {
        didSet { if oldValue != skillSortMode { invalidateProjection() } }
    }
    public var agentSortMode: SidebarSortMode {
        didSet { if oldValue != agentSortMode { invalidateProjection() } }
    }
    public var groupsFirst: Bool {
        didSet { if oldValue != groupsFirst { invalidateProjection() } }
    }
    public var showsUpdateReview = false
    public var updateReviewPackageIDs: Set<PackageID>?

    public private(set) var snapshot = LibrarySnapshot.empty {
        didSet {
            if oldValue != snapshot {
                cachedArtworkCategories = nil
                invalidateProjection()
            }
        }
    }
    public private(set) var scanPhase = LibraryScanPhase.idle
    public private(set) var catalogError: String?
    public private(set) var preservedCatalogURL: URL?
    public private(set) var discoveryRoots = [DiscoveryRootRecord]()
    public private(set) var rootError: String?
    public private(set) var recentOperations = [ManagedOperationRecord]()
    public private(set) var updateCandidates = [PackageUpdate]()
    public private(set) var sourceConnections = [SourceConnection]()
    public private(set) var packageProvenance = [PackageProvenance]() {
        didSet { if oldValue != packageProvenance { invalidateProjection() } }
    }
    public private(set) var sourceEvidence = [SourceEvidence]()
    public private(set) var sourceCandidates = [SourceCandidate]()
    public private(set) var repositories = [SourceRepositoryRecord]()
    public private(set) var publishingTargets = [PublishingTarget]()
    public private(set) var publishingReceipts = [PublishingReceipt]()
    public private(set) var installationSourceStates = [InstallationSourceState]()
    public private(set) var installerPackageReceipts = [InstallerPackageReceipt]()
    public private(set) var packageNameEvidence = [PackageNameEvidence]()
    public private(set) var sourceSearchRoots = [SourceSearchRootRecord]()
    public private(set) var identityClusterDecisions = [IdentityClusterDecision]() {
        didSet { if oldValue != identityClusterDecisions { invalidateProjection() } }
    }
    public private(set) var packageArtworkEvidence = [PackageArtworkEvidence]() {
        didSet {
            if oldValue != packageArtworkEvidence {
                cachedArtworkEvidenceByPackage = nil
                invalidateProjection()
            }
        }
    }
    public private(set) var packageArtworkUploads = [PackageArtworkUpload]() {
        didSet {
            if oldValue != packageArtworkUploads {
                cachedArtworkUploadsByPackage = nil
                invalidateProjection()
            }
        }
    }
    public private(set) var isPreparingPublish = false
    public private(set) var publishingError: String?
    public private(set) var isFindingSource = false
    public private(set) var sourceDiscoveryError: String?
    public private(set) var searchResultIDs: Set<SkillID>? {
        didSet { if oldValue != searchResultIDs { invalidateProjection() } }
    }
    public private(set) var isCheckingForUpdates = false
    public private(set) var updateError: String?

    private let scanner: any SkillScanning
    private let manager: any SkillManaging
    private let changeMonitor: (any SkillChangeMonitoring)?
    private let updater: (any SkillUpdating)?
    private let sourceDiscovery: (any SourceDiscovering)?
    private let packageTitleDiscovery: (any PackageTitleDiscovering)?
    private let packageArtworkDiscovery: (any PackageArtworkDiscovering)?
    private let publisher: (any SkillPublishing)?
    private let catalog: (any CatalogStore)?
    private let rootManager: (any DiscoveryRootManaging)?
    private let catalogRepairer: (any CatalogRepairing)?
    private let defaults: UserDefaults
    private var hasStarted = false
    private var projectionRevision = 0
    @ObservationIgnored private var cachedProjection: LibraryProjection?
    @ObservationIgnored private var cachedArtworkCategories: [PackageID: PackageArtworkCategory]?
    @ObservationIgnored private var cachedArtworkEvidenceByPackage: [PackageID: [PackageArtworkEvidence]]?
    @ObservationIgnored private var cachedArtworkUploadsByPackage: [PackageID: PackageArtworkUpload]?
    @ObservationIgnored internal private(set) var projectionComputationCount = 0
    @ObservationIgnored private var pendingFileChangeURLs = Set<URL>()

    public init(
        scanner: any SkillScanning,
        manager: any SkillManaging,
        changeMonitor: (any SkillChangeMonitoring)? = nil,
        updater: (any SkillUpdating)? = nil,
        sourceDiscovery: (any SourceDiscovering)? = nil,
        packageTitleDiscovery: (any PackageTitleDiscovering)? = nil,
        packageArtworkDiscovery: (any PackageArtworkDiscovering)? = nil,
        publisher: (any SkillPublishing)? = nil,
        catalog: (any CatalogStore)? = nil,
        rootManager: (any DiscoveryRootManaging)? = nil,
        catalogRepairer: (any CatalogRepairing)? = nil,
        initialCatalogError: String? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.scanner = scanner
        self.manager = manager
        self.changeMonitor = changeMonitor
        self.updater = updater
        self.sourceDiscovery = sourceDiscovery
        self.packageTitleDiscovery = packageTitleDiscovery
        self.packageArtworkDiscovery = packageArtworkDiscovery
        self.publisher = publisher
        self.catalog = catalog
        self.rootManager = rootManager
        self.catalogRepairer = catalogRepairer
        self.defaults = defaults
        catalogError = initialCatalogError
        viewMode = defaults.string(forKey: PreferenceKey.viewMode)
            .flatMap(LibraryViewMode.init(rawValue:)) ?? .skillFirst
        appearanceMode = defaults.string(forKey: PreferenceKey.appearance)
            .flatMap(AppearanceMode.init(rawValue:)) ?? .system
        density = defaults.string(forKey: PreferenceKey.density)
            .flatMap(InterfaceDensity.init(rawValue:)) ?? .compact
        textScale = defaults.string(forKey: PreferenceKey.textScale)
            .flatMap(InterfaceTextScale.init(rawValue:)) ?? .standard
        readerWidth = defaults.string(forKey: PreferenceKey.readerWidth)
            .flatMap(ReaderWidth.init(rawValue:)) ?? .focused
        readerTextScale = defaults.string(forKey: PreferenceKey.readerTextScale)
            .flatMap(ReaderTextScale.init(rawValue:)) ?? .standard
        wrapsCode = defaults.object(forKey: PreferenceKey.wrapsCode) as? Bool ?? false
        alwaysShowsPackageGroups = defaults.object(forKey: PreferenceKey.alwaysShowsPackageGroups) as? Bool ?? false
        scanOnLaunch = defaults.object(forKey: PreferenceKey.scanOnLaunch) as? Bool ?? true
        preferRepositoryTitles = defaults.object(forKey: PreferenceKey.preferRepositoryTitles) as? Bool ?? false
        searchesEntireHome = defaults.object(forKey: PreferenceKey.searchEntireHome) as? Bool ?? false
        skillSortMode = defaults.string(forKey: PreferenceKey.skillSortMode)
            .flatMap(SidebarSortMode.init(rawValue:)) ?? .alphabeticalAscending
        agentSortMode = defaults.string(forKey: PreferenceKey.agentSortMode)
            .flatMap(SidebarSortMode.init(rawValue:)) ?? .alphabeticalAscending
        groupsFirst = defaults.object(forKey: PreferenceKey.groupsFirst) as? Bool ?? true
    }

    public var projection: LibraryProjection {
        _ = projectionRevision
        if let cachedProjection { return cachedProjection }
        projectionComputationCount += 1
        let result = LibraryProjection(
            snapshot: snapshot,
            mode: viewMode,
            searchText: searchText,
            alwaysShowsPackageGroups: alwaysShowsPackageGroups,
            matchingSkillIDs: searchResultIDs,
            verifiedSourceByPackage: Dictionary(uniqueKeysWithValues: packageProvenance.compactMap { provenance in
                guard provenance.confidence == .verified,
                      let sourceURL = provenance.originURL ?? provenance.updateURL else { return nil }
                return (provenance.packageID, sourceURL)
            }),
            rejectedClusterFingerprints: Set(identityClusterDecisions.filter(\.isRejected).map(\.evidenceFingerprint))
            ,sortMode: activeSortMode,
            groupsFirst: viewMode == .skillFirst && groupsFirst,
            artworkCategoryByPackage: resolvedArtworkCategories,
            artworkUploadsByPackage: artworkUploadsByPackage,
            artworkEvidenceByPackage: artworkEvidenceByPackage
        )
        cachedProjection = result
        return result
    }

    public var isScanning: Bool {
        if case .scanning = scanPhase { return true }
        return false
    }

    public var scannedFileCount: Int {
        if case .scanning(let fileCount) = scanPhase { return fileCount }
        return 0
    }

    public var scanError: String? {
        if case .failed(let message) = scanPhase { return message }
        return nil
    }

    private func invalidateProjection() {
        cachedProjection = nil
        projectionRevision &+= 1
    }

    public var activeSortMode: SidebarSortMode {
        get { viewMode == .skillFirst ? skillSortMode : agentSortMode }
        set {
            if viewMode == .skillFirst { skillSortMode = newValue }
            else { agentSortMode = newValue }
            savePreferences()
        }
    }

    public var selectedSkill: SkillRecord? {
        guard let selection else { return nil }
        let members = selectedProjectedSkill?.memberSkillIDs ?? [selection.skillID]
        let skills = members.compactMap(snapshot.skill(id:))
        guard let primary = skills.first else { return nil }
        guard skills.count > 1 else { return primary }
        let installations = skills.flatMap(\.installations).sorted { lhs, rhs in
            let lhsRank = AgentKind.allCases.firstIndex(of: lhs.agent) ?? .max
            let rhsRank = AgentKind.allCases.firstIndex(of: rhs.agent) ?? .max
            return lhsRank == rhsRank ? lhs.entryURL.path < rhs.entryURL.path : lhsRank < rhsRank
        }
        return SkillRecord(
            id: primary.id,
            packageID: primary.packageID,
            name: primary.name,
            summary: skills.first(where: { !$0.summary.isEmpty })?.summary ?? "",
            author: skills.compactMap(\.author).first,
            websiteURL: skills.compactMap(\.websiteURL).first,
            sourceURL: skills.compactMap(\.sourceURL).first,
            artwork: skills.compactMap(\.artwork).first,
            markdownSource: installations.first?.markdownSource ?? primary.markdownSource,
            installations: installations
        )
    }

    public var selectedProjectedSkill: ProjectedSkill? {
        guard let selection else { return nil }
        return projection.nodes.lazy.compactMap { node -> [ProjectedSkill]? in
            switch node {
            case .skill(let skill): [skill]
            case .group(let group): group.skills
            }
        }.flatMap { $0 }.first { $0.memberSkillIDs.contains(selection.skillID) }
    }

    public var selectedSkillIsProvisionalCluster: Bool {
        selectedProjectedSkill?.isProvisionalCluster == true
    }

    public var selectedInstallation: SkillInstallation? {
        guard let selectedSkill else { return nil }
        if let installationID = selection?.installationID {
            return selectedSkill.installations.first { $0.id == installationID }
        }
        if
            let rawID = defaults.string(
                forKey: PreferenceKey.installationSelectionPrefix + selectedSkill.id.rawValue
            ),
            let remembered = selectedSkill.installations.first(where: { $0.id.rawValue == rawID })
        {
            return remembered
        }
        return selectedSkill.installations.first
    }

    public var installationCount: Int {
        snapshot.skills.reduce(0) { $0 + $1.installations.count }
    }

    public var logicalSkillCount: Int { projection.logicalSkillCount }

    public var reviewedUpdateCandidates: [PackageUpdate] {
        guard let updateReviewPackageIDs else { return updateCandidates }
        return updateCandidates.filter { update in
            !Set(update.packageIDs).isDisjoint(with: updateReviewPackageIDs)
        }
    }

    public var preferences: AppearancePreferences {
        AppearancePreferences(
            appearance: appearanceMode,
            density: density,
            textScale: textScale,
            readerWidth: readerWidth,
            readerTextScale: readerTextScale,
            wrapsCode: wrapsCode,
            alwaysShowsPackageGroups: alwaysShowsPackageGroups
        )
    }

    public func latestManagedOperation(for installation: SkillInstallation) -> ManagedOperationRecord? {
        recentOperations.first { operation in
            operation.targetURLs.contains { target in
                target.standardizedFileURL == installation.entryURL.standardizedFileURL
            }
        }
    }

    public func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        do {
            _ = try await manager.recoverInterruptedOperations()
        } catch {
            catalogError = error.localizedDescription
        }
        await refreshDiscoveryRoots()
        await loadCachedLibrary()
        await refreshSourceConnections()
        await refreshProvenance()
        schedulePackageTitleBackfill()
        schedulePackageArtworkBackfill()
        await refreshOperations()
        if scanOnLaunch {
            await rescan()
        }
        guard let changeMonitor else { return }
        for await changes in changeMonitor.changes() {
            guard !Task.isCancelled else { break }
            await reconcile(changes)
        }
    }

    public func rescan() async {
        guard !isScanning else { return }
        scanPhase = .scanning(fileCount: 0)
        var completedSnapshot: LibrarySnapshot?
        var failureMessage: String?

        do {
            for try await update in scanner.scan() {
                guard !Task.isCancelled else { break }
                switch update {
                case .progress(let snapshot, let count):
                    self.snapshot = enriched(snapshot)
                    scanPhase = .scanning(fileCount: count)
                    selectFirstSkillIfNeeded()
                case .finished(let snapshot, let count):
                    self.snapshot = enriched(snapshot)
                    scanPhase = .scanning(fileCount: count)
                    completedSnapshot = snapshot
                    selectFirstSkillIfNeeded()
                }
            }
        } catch is CancellationError {
            // Cancellation is expected when the owning window closes.
        } catch {
            failureMessage = error.localizedDescription
        }

        if let completedSnapshot {
            await saveCachedLibrary(enriched(completedSnapshot))
            await refreshProvenance()
            schedulePackageTitleBackfill()
            schedulePackageArtworkBackfill()
            await updateSearchResults()
        }
        scanPhase = failureMessage.map(LibraryScanPhase.failed(message:)) ?? .idle
        await reconcilePendingFileChanges()
    }

    private func reconcile(_ changes: FileChangeBatch) async {
        guard !isScanning else {
            pendingFileChangeURLs.formUnion(changes.urls)
            return
        }
        guard let targetedScanner = scanner as? any TargetedSkillScanning else {
            await rescan()
            return
        }

        scanPhase = .scanning(fileCount: 0)
        var completedSnapshot: LibrarySnapshot?
        var failureMessage: String?
        do {
            for try await update in targetedScanner.reconcile(snapshot: snapshot, changes: changes) {
                switch update {
                case .progress(let snapshot, let count):
                    self.snapshot = enriched(snapshot)
                    scanPhase = .scanning(fileCount: count)
                case .finished(let snapshot, let count):
                    self.snapshot = enriched(snapshot)
                    scanPhase = .scanning(fileCount: count)
                    completedSnapshot = snapshot
                }
            }
        } catch is CancellationError {
            // Expected when the window closes.
        } catch {
            failureMessage = error.localizedDescription
        }
        if let completedSnapshot {
            await saveCachedLibrary(enriched(completedSnapshot))
            await refreshProvenance()
            schedulePackageTitleBackfill()
            schedulePackageArtworkBackfill()
            await updateSearchResults()
        }
        scanPhase = failureMessage.map(LibraryScanPhase.failed(message:)) ?? .idle
        await reconcilePendingFileChanges()
    }

    private func reconcilePendingFileChanges() async {
        guard !isScanning, !pendingFileChangeURLs.isEmpty else { return }
        let changes = FileChangeBatch(urls: Array(pendingFileChangeURLs))
        pendingFileChangeURLs.removeAll(keepingCapacity: true)
        await reconcile(changes)
    }

    public func updateSearchResults() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResultIDs = nil
            return
        }
        guard let catalog, !isScanning else {
            searchResultIDs = nil
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(150))
            try Task.checkCancellation()
            let result = Set(try await catalog.searchSkillIDs(matching: query))
            try Task.checkCancellation()
            guard searchText.trimmingCharacters(in: .whitespacesAndNewlines) == query else { return }
            searchResultIDs = result
        } catch is CancellationError {
            // A newer query superseded this one.
        } catch {
            searchResultIDs = nil
            catalogError = error.localizedDescription
        }
    }

    public func select(_ projectedSkill: ProjectedSkill) {
        if let installationID = projectedSkill.id.installationID {
            selection = projectedSkill.id
            rememberInstallation(installationID, for: projectedSkill.skillID)
            return
        }
        let remembered = defaults.string(
            forKey: PreferenceKey.installationSelectionPrefix + projectedSkill.skillID.rawValue
        ).map(InstallationID.init(rawValue:))
        selection = LibrarySelection(skillID: projectedSkill.skillID, installationID: remembered)
    }

    public func selectInstallation(_ installation: SkillInstallation, for skill: SkillRecord) {
        selection = LibrarySelection(skillID: skill.id, installationID: installation.id)
        rememberInstallation(installation.id, for: skill.id)
    }

    public func activateStatus(for projectedSkill: ProjectedSkill) {
        if projectedSkill.isProvisionalCluster {
            select(projectedSkill)
            if let skill = selectedSkill, let installation = installationRequiringAction(in: skill) {
                selectInstallation(installation, for: skill)
            }
            return
        }
        if let skill = snapshot.skill(id: projectedSkill.skillID),
           let installation = installationRequiringAction(in: skill) {
            selectInstallation(installation, for: skill)
        } else {
            select(projectedSkill)
        }
        guard
            projectedSkill.actionableStatus == .updateAvailable,
            let skill = snapshot.skill(id: projectedSkill.skillID)
        else { return }
        reviewUpdate(for: skill)
    }

    public func activateStatus(in group: ProjectedGroup) {
        guard let urgent = group.skills.max(by: {
            ($0.actionableStatus?.rawValue ?? 0) < ($1.actionableStatus?.rawValue ?? 0)
        }) else { return }
        activateStatus(for: urgent)
    }

    public func checkForUpdates() async {
        guard let updater, !isCheckingForUpdates else { return }
        isCheckingForUpdates = true
        updateError = nil
        defer { isCheckingForUpdates = false }

        do {
            updateCandidates = try await updater.check(snapshot: snapshot)
            snapshot = snapshot.settingUpdateAvailability(for: updateCandidates)
            if !updateCandidates.isEmpty {
                updateReviewPackageIDs = nil
                showsUpdateReview = true
            }
        } catch {
            updateError = error.localizedDescription
        }
    }

    public func dismissUpdateError() {
        updateError = nil
    }

    public func reviewAllUpdates() {
        updateReviewPackageIDs = nil
        showsUpdateReview = true
    }

    public func reviewUpdate(for skill: SkillRecord) {
        updateReviewPackageIDs = [skill.packageID]
        showsUpdateReview = true
    }

    public func addDiscoveryRoot(agent: AgentKind, url: URL) async {
        guard let rootManager else { return }
        do {
            try await rootManager.addRoot(
                DiscoveryRootRecord(agent: agent, url: url, isKnown: false)
            )
            await refreshDiscoveryRoots()
            await rescan()
        } catch {
            rootError = error.localizedDescription
        }
    }

    public func removeDiscoveryRoot(id: String) async {
        guard let rootManager else { return }
        do {
            try await rootManager.removeRoot(id: id)
            await refreshDiscoveryRoots()
            await rescan()
        } catch {
            rootError = error.localizedDescription
        }
    }

    public func dismissRootError() {
        rootError = nil
    }

    public func rebuildCatalog() async {
        guard let catalogRepairer else { return }
        do {
            let receipt = try await catalogRepairer.rebuildCatalog()
            preservedCatalogURL = receipt.preservedCatalogURL
            catalogError = nil
            await refreshDiscoveryRoots()
            await rescan()
            await refreshOperations()
        } catch {
            catalogError = error.localizedDescription
        }
    }

    public func setCurrentAsBaseline(_ installation: SkillInstallation) async {
        guard let catalog else { return }
        do {
            try await catalog.saveBaseline(
                InstallationBaseline(
                    entryURL: installation.entryURL,
                    contentHash: installation.contentHash,
                    sourceRevision: nil,
                    setAt: .now
                )
            )
            await rescan()
            catalogError = nil
        } catch {
            catalogError = error.localizedDescription
        }
    }

    public func sourceConnection(for skill: SkillRecord) -> SourceConnection? {
        sourceConnections.first { $0.packageID == skill.packageID }
    }

    public func provenance(for skill: SkillRecord) -> PackageProvenance? {
        packageProvenance.first { $0.packageID == skill.packageID }
    }

    public func evidence(for skill: SkillRecord) -> [SourceEvidence] {
        sourceEvidence.filter { $0.packageID == skill.packageID }
            .sorted { $0.confidence > $1.confidence }
    }

    public func sourceState(for installation: SkillInstallation) -> InstallationSourceState? {
        installationSourceStates.first { $0.installationID == installation.id }
    }

    public func candidates(for skill: SkillRecord) -> [SourceCandidate] {
        sourceCandidates.filter { $0.packageID == skill.packageID && !$0.isRejected }
            .sorted { $0.confidence > $1.confidence }
    }

    public func sourceDiscoveryTerms(for skill: SkillRecord) -> [String] {
        guard let package = snapshot.package(id: skill.packageID) else { return [skill.name, "SKILL.md"] }
        return ([package.name] + package.skillIDs.compactMap { snapshot.skill(id: $0)?.name } + ["SKILL.md"])
            .uniqued()
    }

    public func findSource(for skill: SkillRecord, deep: Bool = false) async {
        guard let sourceDiscovery, !isFindingSource else { return }
        isFindingSource = true
        sourceDiscoveryError = nil
        defer { isFindingSource = false }
        do {
            let query = sourceDiscoveryQuery(for: skill)
            let found = if deep {
                try await sourceDiscovery.deepSearchCandidates(for: query)
            } else {
                try await sourceDiscovery.findCandidates(for: query)
            }
            let retained = sourceCandidates.filter { candidate in
                candidate.packageID != skill.packageID || candidate.isRejected
            }
            sourceCandidates = retained + found.filter { candidate in
                !sourceCandidates.contains(where: { $0.id == candidate.id && $0.isRejected })
            }
            try await catalog?.saveSourceCandidates(sourceCandidates)
        } catch is CancellationError {
            // Search cancellation is intentional.
        } catch {
            sourceDiscoveryError = error.localizedDescription
        }
    }

    public func acceptSourceCandidate(_ candidate: SourceCandidate, for skill: SkillRecord) async throws {
        try await connectSource(
            to: skill,
            kind: .gitRepository,
            sourceURL: candidate.sourceURL,
            branch: nil,
            subdirectory: candidate.packagePath
        )
        sourceCandidates.removeAll { $0.id == candidate.id }
        try await catalog?.saveSourceCandidates(sourceCandidates)
        await refreshProvenance()
    }

    public func rejectSourceCandidate(_ candidate: SourceCandidate) async {
        guard let index = sourceCandidates.firstIndex(where: { $0.id == candidate.id }) else { return }
        sourceCandidates[index] = SourceCandidate(
            id: candidate.id,
            packageID: candidate.packageID,
            sourceURL: candidate.sourceURL,
            packagePath: candidate.packagePath,
            confidence: candidate.confidence,
            explanation: candidate.explanation,
            discoveredAt: candidate.discoveredAt,
            isRejected: true
        )
        do {
            try await catalog?.saveSourceCandidates(sourceCandidates)
        } catch {
            sourceDiscoveryError = error.localizedDescription
        }
    }

    public func publishingTarget(for skill: SkillRecord) -> PublishingTarget? {
        publishingTargets.first { $0.packageOverrideIDs.contains(skill.packageID) }
            ?? publishingTargets.first { $0.packageOverrideIDs.isEmpty }
    }

    public func configurePublishingTarget(repositoryURL: URL, branch: String) async throws {
        guard let catalog else { throw SkillMutationError.invalidPlan }
        let defaultTarget = PublishingTarget(
            id: "personal-spellbook",
            repositoryURL: repositoryURL,
            branch: branch.nilIfEmpty ?? "main"
        )
        publishingTargets.removeAll { $0.id == defaultTarget.id }
        publishingTargets.insert(defaultTarget, at: 0)
        try await catalog.savePublishingTargets(publishingTargets)
    }

    public func configurePublishingOverride(
        for skill: SkillRecord,
        repositoryURL: URL,
        branch: String
    ) async throws {
        guard let catalog else { throw SkillMutationError.invalidPlan }
        publishingTargets.removeAll { $0.packageOverrideIDs.contains(skill.packageID) }
        publishingTargets.append(PublishingTarget(
            id: "package::\(skill.packageID.rawValue)",
            repositoryURL: repositoryURL,
            branch: branch.nilIfEmpty ?? "main",
            packageOverrideIDs: [skill.packageID]
        ))
        try await catalog.savePublishingTargets(publishingTargets)
    }

    public func removePublishingOverride(for skill: SkillRecord) async {
        let overrides = publishingTargets.filter { $0.packageOverrideIDs.contains(skill.packageID) }
        for target in overrides { await removePublishingTarget(target) }
    }

    public func removePublishingTarget(_ target: PublishingTarget) async {
        publishingTargets.removeAll { $0.id == target.id }
        do {
            try await catalog?.savePublishingTargets(publishingTargets)
        } catch {
            publishingError = error.localizedDescription
        }
    }

    public func previewPublish(skill: SkillRecord) async throws -> PublishingPlan {
        guard let publisher, let target = publishingTarget(for: skill) else {
            throw PublishingError.invalidRepository("Configure an existing personal repository in Settings → Sources first.")
        }
        guard
            let package = snapshot.package(id: skill.packageID),
            let installation = selectedInstallation
        else { throw SkillMutationError.invalidPlan }
        isPreparingPublish = true
        publishingError = nil
        defer { isPreparingPublish = false }
        do {
            let skills = package.skillIDs.compactMap(snapshot.skill(id:))
            return try await publisher.preview(
                package: package,
                skills: skills,
                agent: installation.agent,
                target: target
            )
        } catch {
            publishingError = error.localizedDescription
            throw error
        }
    }

    public func publish(_ plan: PublishingPlan, approveNewFiles: Bool) async throws {
        guard let publisher else { throw SkillMutationError.invalidPlan }
        let receipt = try await publisher.publish(plan, approveNewFiles: approveNewFiles)
        publishingReceipts.insert(receipt, at: 0)
        try await catalog?.savePublishingReceipts(publishingReceipts)
        var provenance = packageProvenance.filter { $0.packageID != plan.packageID }
        let existing = packageProvenance.first { $0.packageID == plan.packageID }
        provenance.append(PackageProvenance(
            packageID: plan.packageID,
            originURL: existing?.originURL,
            originSubdirectory: existing?.originSubdirectory,
            updateURL: existing?.updateURL,
            publishingURL: plan.target.repositoryURL,
            branch: existing?.branch,
            confidence: existing?.confidence ?? .verified,
            lastVerifiedAt: existing?.lastVerifiedAt
        ))
        packageProvenance = provenance
        try await catalog?.savePackageProvenance(provenance)
    }

    public func connectSource(
        to skill: SkillRecord,
        kind: SourceConnectionKind,
        sourceURL: URL,
        branch: String?,
        subdirectory: String?
    ) async throws {
        guard let catalog else { throw SkillMutationError.invalidPlan }
        let connection = SourceConnection(
            packageID: skill.packageID,
            kind: kind,
            sourceURL: sourceURL,
            branch: branch?.nilIfEmpty,
            subdirectory: subdirectory?.nilIfEmpty
        )
        try await catalog.saveSourceConnection(connection)
        var provenance = packageProvenance.filter { $0.packageID != skill.packageID }
        provenance.append(PackageProvenance(
            packageID: skill.packageID,
            originURL: sourceURL,
            originSubdirectory: subdirectory?.nilIfEmpty,
            updateURL: sourceURL,
            branch: branch?.nilIfEmpty,
            confidence: .verified,
            lastVerifiedAt: .now
        ))
        try await catalog.savePackageProvenance(provenance)
        for installation in skill.installations {
            try await catalog.saveBaseline(InstallationBaseline(
                entryURL: installation.entryURL,
                contentHash: installation.contentHash,
                sourceRevision: nil,
                setAt: .now
            ))
        }
        var sourceStates = installationSourceStates.filter { state in
            !skill.installations.contains(where: { $0.id == state.installationID })
        }
        sourceStates.append(contentsOf: skill.installations.map { installation in
            InstallationSourceState(
                installationID: installation.id,
                packageID: skill.packageID,
                track: branch?.nilIfEmpty,
                baselineHash: installation.contentHash,
                lastCheckedAt: .now
            )
        })
        try await catalog.saveInstallationSourceStates(sourceStates)
        await refreshSourceConnections()
        await refreshProvenance()
        await rescan()
    }

    public func disconnectSource(for skill: SkillRecord) async {
        guard let catalog else { return }
        do {
            try await catalog.removeSourceConnection(packageID: skill.packageID)
            await refreshSourceConnections()
            await rescan()
        } catch {
            catalogError = error.localizedDescription
        }
    }

    public func applyUpdates(ids: Set<String>) async throws {
        guard let updater else { return }
        let selected = updateCandidates.filter { ids.contains($0.id) }
        for update in selected {
            _ = try await updater.apply(update)
        }
        updateCandidates.removeAll { ids.contains($0.id) }
        await rescan()
        await refreshOperations()
    }

    public func planRemoval(
        _ installation: SkillInstallation
    ) async throws -> ManagedMutationPlan {
        try await manager.plan(
            [MutationRequest(
                destinationURL: installation.entryURL,
                action: .remove,
                expectedHash: installation.contentHash,
                proposedText: nil
            )],
            kind: .remove
        )
    }

    @discardableResult
    public func execute(
        _ plan: ManagedMutationPlan
    ) async throws -> ManagedMutationReceipt {
        let receipt = try await manager.execute(plan)
        await rescan()
        await refreshOperations()
        return receipt
    }

    public func restore(_ operation: ManagedOperationRecord) async throws {
        guard
            operation.targetURLs.count == 1,
            operation.recoveryURLs.count == 1,
            let destinationURL = operation.targetURLs.first,
            let recoveryURL = operation.recoveryURLs.first
        else { throw SkillMutationError.invalidPlan }
        let expectedHash = try? await manager.read(at: destinationURL).contentHash
        _ = try await manager.restore(
            recoveryURL: recoveryURL,
            to: destinationURL,
            expectedHash: expectedHash
        )
        await rescan()
        await refreshOperations()
    }

    public func planRestore(
        _ operation: ManagedOperationRecord
    ) async throws -> ManagedMutationPlan {
        guard
            operation.targetURLs.count == 1,
            operation.recoveryURLs.count == 1,
            let destinationURL = operation.targetURLs.first,
            let recoveryURL = operation.recoveryURLs.first
        else { throw SkillMutationError.invalidPlan }
        let recoveryContent = try await manager.read(at: recoveryURL)
        let currentContent = try? await manager.read(at: destinationURL)
        return try await manager.plan(
            [MutationRequest(
                destinationURL: destinationURL,
                action: .write,
                expectedHash: currentContent?.contentHash,
                proposedText: recoveryContent.text
            )],
            kind: .restore
        )
    }

    @discardableResult
    public func remove(_ installation: SkillInstallation) async throws -> FileMutationReceipt {
        let receipt = try await manager.remove(
            at: installation.entryURL,
            expectedHash: installation.contentHash
        )
        await rescan()
        await refreshOperations()
        return receipt
    }

    public func savePreferences() {
        defaults.set(viewMode.rawValue, forKey: PreferenceKey.viewMode)
        defaults.set(appearanceMode.rawValue, forKey: PreferenceKey.appearance)
        defaults.set(density.rawValue, forKey: PreferenceKey.density)
        defaults.set(textScale.rawValue, forKey: PreferenceKey.textScale)
        defaults.set(readerWidth.rawValue, forKey: PreferenceKey.readerWidth)
        defaults.set(readerTextScale.rawValue, forKey: PreferenceKey.readerTextScale)
        defaults.set(wrapsCode, forKey: PreferenceKey.wrapsCode)
        defaults.set(alwaysShowsPackageGroups, forKey: PreferenceKey.alwaysShowsPackageGroups)
        defaults.set(scanOnLaunch, forKey: PreferenceKey.scanOnLaunch)
        defaults.set(preferRepositoryTitles, forKey: PreferenceKey.preferRepositoryTitles)
        defaults.set(searchesEntireHome, forKey: PreferenceKey.searchEntireHome)
        defaults.set(skillSortMode.rawValue, forKey: PreferenceKey.skillSortMode)
        defaults.set(agentSortMode.rawValue, forKey: PreferenceKey.agentSortMode)
        defaults.set(groupsFirst, forKey: PreferenceKey.groupsFirst)
    }

    public func artworkUpload(for packageID: PackageID) -> PackageArtworkUpload? {
        artworkUploadsByPackage[packageID]
    }

    public func thumbnail(for skill: SkillRecord) -> SkillThumbnail {
        // The projection owns display identity. A selected record can be a
        // synthesized provisional cluster whose primary package differs from
        // the package that supplied the sidebar thumbnail.
        if let projected = selectedProjectedSkill,
           projected.memberSkillIDs.contains(skill.id) {
            return projected.thumbnail
        }
        let package = snapshot.package(id: skill.packageID)
        return SkillThumbnailResolver.resolveSkill(
            package: package,
            skill: skill,
            upload: artworkUpload(for: skill.packageID),
            evidence: artworkEvidenceByPackage[skill.packageID] ?? [],
            category: artworkCategory(for: skill.packageID)
        )
    }

    public func thumbnail(for package: SkillPackageRecord) -> SkillThumbnail {
        SkillThumbnailResolver.resolvePackage(
            package: package,
            upload: artworkUpload(for: package.id),
            evidence: artworkEvidenceByPackage[package.id] ?? [],
            category: artworkCategory(for: package.id)
        )
    }

    public func importArtwork(
        from url: URL,
        for packageID: PackageID
    ) async throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let stored = try await ArtworkDataCache.shared.storeUploadData(
            data,
            suggestedExtension: url.pathExtension.isEmpty ? "png" : url.pathExtension
        )
        let upload = PackageArtworkUpload(
            packageID: packageID,
            localURL: stored.url,
            contentHash: stored.hash
        )
        let previous = artworkUpload(for: packageID)
        packageArtworkUploads.removeAll { $0.packageID == packageID }
        packageArtworkUploads.append(upload)
        do {
            try await catalog?.savePackageArtworkUploads(packageArtworkUploads)
            if let previous,
               previous.localURL != upload.localURL,
               !isUploadStorageReferenced(previous) {
                await ArtworkDataCache.shared.removeStoredUpload(at: previous.localURL)
            }
        } catch {
            packageArtworkUploads.removeAll { $0.packageID == packageID }
            if let previous { packageArtworkUploads.append(previous) }
            if previous?.localURL != upload.localURL,
               !isUploadStorageReferenced(upload) {
                await ArtworkDataCache.shared.removeStoredUpload(at: upload.localURL)
            }
            catalogError = error.localizedDescription
            throw error
        }
    }

    public func removeArtworkUpload(for packageID: PackageID) async {
        guard let upload = artworkUpload(for: packageID) else { return }
        packageArtworkUploads.removeAll { $0.packageID == packageID }
        do {
            try await catalog?.savePackageArtworkUploads(packageArtworkUploads)
            if !isUploadStorageReferenced(upload) {
                await ArtworkDataCache.shared.removeStoredUpload(at: upload.localURL)
            }
        } catch {
            packageArtworkUploads.append(upload)
            catalogError = error.localizedDescription
        }
    }

    private func isUploadStorageReferenced(_ upload: PackageArtworkUpload) -> Bool {
        packageArtworkUploads.contains {
            $0.localURL.standardizedFileURL == upload.localURL.standardizedFileURL
                || $0.contentHash == upload.contentHash
        }
    }

    public func addSourceSearchRoot(_ url: URL) async {
        let root = SourceSearchRootRecord(url: url)
        guard !sourceSearchRoots.contains(where: { $0.id == root.id }) else { return }
        sourceSearchRoots.append(root)
        sourceSearchRoots.sort { $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending }
        do {
            try await catalog?.saveSourceSearchRoots(sourceSearchRoots)
        } catch {
            catalogError = error.localizedDescription
        }
    }

    public func removeSourceSearchRoot(_ root: SourceSearchRootRecord) async {
        sourceSearchRoots.removeAll { $0.id == root.id }
        do {
            try await catalog?.saveSourceSearchRoots(sourceSearchRoots)
        } catch {
            catalogError = error.localizedDescription
        }
    }

    public func setSearchesEntireHome(_ enabled: Bool) async {
        searchesEntireHome = enabled
        savePreferences()
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        sourceSearchRoots.removeAll { !$0.isTrusted && $0.url.standardizedFileURL == home }
        if enabled, !sourceSearchRoots.contains(where: { !$0.isTrusted && $0.url.standardizedFileURL == home }) {
            sourceSearchRoots.append(SourceSearchRootRecord(url: home, isTrusted: false))
            sourceSearchRoots.sort { $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending }
        }
        do {
            try await catalog?.saveSourceSearchRoots(sourceSearchRoots)
        } catch {
            catalogError = error.localizedDescription
        }
    }

    public func splitSelectedSkillCluster() async {
        guard
            let projected = selectedProjectedSkill,
            projected.isProvisionalCluster
        else { return }
        let members = projected.memberSkillIDs.compactMap(snapshot.skill(id:))
        let decision = IdentityClusterDecision(
            normalizedName: projected.name.lowercased(),
            memberSkillIDs: projected.memberSkillIDs,
            evidenceFingerprint: LibraryProjection.clusterFingerprint(members),
            isRejected: true
        )
        identityClusterDecisions.removeAll { $0.id == decision.id }
        identityClusterDecisions.append(decision)
        do {
            try await catalog?.saveIdentityClusterDecisions(identityClusterDecisions)
            selection = LibrarySelection(skillID: projected.skillID)
        } catch {
            catalogError = error.localizedDescription
        }
    }

    public func mergeCompatibleCopies(of skill: SkillRecord) async {
        let normalized = skill.name.lowercased()
        identityClusterDecisions.removeAll {
            $0.normalizedName == normalized && $0.isRejected
        }
        do {
            try await catalog?.saveIdentityClusterDecisions(identityClusterDecisions)
        } catch {
            catalogError = error.localizedDescription
        }
    }

    public func canMergeCompatibleCopies(of skill: SkillRecord) -> Bool {
        identityClusterDecisions.contains { decision in
            decision.isRejected && decision.memberSkillIDs.contains(skill.id)
        }
    }

    public func isPackageExpanded(_ groupID: String) -> Bool {
        let key = PreferenceKey.packageDisclosurePrefix + groupID
        guard defaults.object(forKey: key) != nil else { return true }
        return defaults.bool(forKey: key)
    }

    public func setPackageExpanded(_ expanded: Bool, groupID: String) {
        defaults.set(expanded, forKey: PreferenceKey.packageDisclosurePrefix + groupID)
    }

    private func selectFirstSkillIfNeeded() {
        if let selection, snapshot.skill(id: selection.skillID) != nil {
            return
        }
        guard let candidate = projection.nodes.lazy.compactMap(Self.firstSelection).first else { return }
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            if let selection = self.selection,
               self.snapshot.skill(id: selection.skillID) != nil {
                return
            }
            self.selection = candidate
        }
    }

    private func loadCachedLibrary() async {
        guard let catalog else { return }
        do {
            if let cached = try await catalog.loadSnapshot() {
                snapshot = cached
                selectFirstSkillIfNeeded()
            }
            catalogError = nil
        } catch {
            catalogError = error.localizedDescription
        }
    }

    private func saveCachedLibrary(_ snapshot: LibrarySnapshot) async {
        guard let catalog else { return }
        do {
            try await catalog.saveSnapshot(snapshot)
            catalogError = nil
        } catch {
            catalogError = error.localizedDescription
        }
    }

    private func refreshDiscoveryRoots() async {
        guard let rootManager else { return }
        do {
            discoveryRoots = try await rootManager.roots()
            rootError = nil
        } catch {
            rootError = error.localizedDescription
        }
    }

    private func refreshOperations() async {
        guard let catalog else { return }
        do {
            let history = try await catalog.recentOperations(limit: 2_000)
            recentOperations = Array(history.prefix(12))
            snapshot = applyingInstallOperations(history, to: snapshot)
            catalogError = nil
        } catch {
            catalogError = error.localizedDescription
        }
    }

    private func applyingInstallOperations(
        _ operations: [ManagedOperationRecord],
        to snapshot: LibrarySnapshot
    ) -> LibrarySnapshot {
        let installs = operations
            .filter { $0.kind == .apply && $0.status == .committed }
            .flatMap { operation in operation.targetURLs.map { ($0.standardizedFileURL.path, operation.finishedAt) } }
        let earliestByPath = Dictionary(grouping: installs, by: \.0).mapValues { values in
            values.map(\.1).min()!
        }
        guard !earliestByPath.isEmpty else { return snapshot }
        let skills = snapshot.skills.map { skill in
            let updated = skill.installations.map { installation in
                guard let date = earliestByPath[installation.entryURL.standardizedFileURL.path] else { return installation }
                let existingRank = installation.installationDateEvidence?.source
                if existingRank == .installerReceipt { return installation }
                return installation.settingInstallationDateEvidence(InstallationDateEvidence(
                    installedAt: date,
                    source: .spellbookOperation,
                    confidence: .verified
                ))
            }
            return skill.replacingInstallations(updated)
        }
        return LibrarySnapshot(packages: snapshot.packages, skills: skills, scannedAt: snapshot.scannedAt)
    }

    private func refreshSourceConnections() async {
        guard let catalog else { return }
        do {
            sourceConnections = try await catalog.loadSourceConnections()
            snapshot = enriched(snapshot)
            catalogError = nil
        } catch {
            catalogError = error.localizedDescription
        }
    }

    private func refreshProvenance() async {
        guard let catalog else { return }
        do {
            async let loadedProvenance = catalog.loadPackageProvenance()
            async let loadedEvidence = catalog.loadSourceEvidence()
            async let loadedCandidates = catalog.loadSourceCandidates()
            async let loadedRepositories = catalog.loadRepositories()
            async let loadedPublishingTargets = catalog.loadPublishingTargets()
            async let loadedPublishingReceipts = catalog.loadPublishingReceipts()
            async let loadedInstallationStates = catalog.loadInstallationSourceStates()
            async let loadedReceipts = catalog.loadInstallerPackageReceipts()
            async let loadedNameEvidence = catalog.loadPackageNameEvidence()
            async let loadedSearchRoots = catalog.loadSourceSearchRoots()
            async let loadedClusterDecisions = catalog.loadIdentityClusterDecisions()
            async let loadedArtworkEvidence = catalog.loadPackageArtworkEvidence()
            async let loadedArtworkUploads = catalog.loadPackageArtworkUploads()
            packageProvenance = try await loadedProvenance
            sourceEvidence = try await loadedEvidence
            sourceCandidates = try await loadedCandidates
            repositories = try await loadedRepositories
            publishingTargets = try await loadedPublishingTargets
            publishingReceipts = try await loadedPublishingReceipts
            installationSourceStates = try await loadedInstallationStates
            installerPackageReceipts = try await loadedReceipts
            packageNameEvidence = try await loadedNameEvidence
            sourceSearchRoots = try await loadedSearchRoots
            identityClusterDecisions = try await loadedClusterDecisions
            packageArtworkEvidence = try await loadedArtworkEvidence
            packageArtworkUploads = try await loadedArtworkUploads
            if sourceSearchRoots.isEmpty {
                let defaultRoot = SourceSearchRootRecord(url: URL(filePath: "/Users/keding/Cursor", directoryHint: .isDirectory))
                sourceSearchRoots = [defaultRoot]
                try await catalog.saveSourceSearchRoots(sourceSearchRoots)
            }
            if searchesEntireHome {
                let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
                if !sourceSearchRoots.contains(where: { !$0.isTrusted && $0.url.standardizedFileURL == home }) {
                    sourceSearchRoots.append(SourceSearchRootRecord(url: home, isTrusted: false))
                    try await catalog.saveSourceSearchRoots(sourceSearchRoots)
                }
            }
            snapshot = enriched(snapshot)
            catalogError = nil
        } catch {
            catalogError = error.localizedDescription
        }
    }

    private func schedulePackageTitleBackfill() {
        guard packageTitleDiscovery != nil else { return }
        Task { @MainActor [weak self] in
            await self?.refreshPackageTitles()
        }
    }

    private func schedulePackageArtworkBackfill() {
        guard packageArtworkDiscovery != nil else { return }
        Task { @MainActor [weak self] in
            await self?.refreshPackageArtwork()
        }
    }

    private func refreshPackageArtwork() async {
        guard let packageArtworkDiscovery, let catalog else { return }
        let verified: [PackageID: URL] = Dictionary(uniqueKeysWithValues: packageProvenance.compactMap { provenance -> (PackageID, URL)? in
            guard provenance.confidence == .verified,
                  let url = provenance.originURL ?? provenance.updateURL,
                  url.isFileURL || url.host?.lowercased() == "github.com"
            else { return nil }
            return (provenance.packageID, url)
        })
        var refreshed = packageArtworkEvidence
        var changed = false

        for package in snapshot.packages {
            let sourceURL: URL?
            if let verifiedURL = verified[package.id] {
                sourceURL = verifiedURL
            } else if let declaredSource = package.sourceURL {
                // A declared network source still needs verified provenance.
                // File URLs are local-only and safe to inspect directly.
                sourceURL = declaredSource.isFileURL ? declaredSource : nil
            } else {
                sourceURL = package.skillIDs
                    .compactMap { snapshot.skill(id: $0) }
                    .flatMap(\.installations)
                    .map(\.rootURL)
                    .first(where: \.isFileURL)
            }
            guard let sourceURL else { continue }
            let revision = installationSourceStates.first { $0.packageID == package.id }?.installedRevision
            do {
                let newEvidence = try await packageArtworkDiscovery.discoverArtwork(for: PackageArtworkQuery(
                    packageID: package.id,
                    sourceURL: sourceURL,
                    revision: revision
                ))
                let oldEvidence = refreshed.filter { $0.packageID == package.id }
                if oldEvidence != newEvidence {
                    refreshed.removeAll { $0.packageID == package.id }
                    refreshed.append(contentsOf: newEvidence)
                    changed = true
                }
            } catch {
                // Keep the last verified evidence while offline or rate-limited.
            }
        }
        guard changed else { return }
        packageArtworkEvidence = refreshed
        do {
            try await catalog.savePackageArtworkEvidence(refreshed)
        } catch {
            catalogError = error.localizedDescription
        }
    }

    private func refreshPackageTitles() async {
        guard let packageTitleDiscovery, let catalog else { return }
        var byID = Dictionary(uniqueKeysWithValues: packageNameEvidence.map { ($0.id, $0) })
        var changed = false
        for provenance in packageProvenance where provenance.confidence == .verified {
            guard let sourceURL = provenance.originURL ?? provenance.updateURL else { continue }
            let revision = installationSourceStates.first { $0.packageID == provenance.packageID }?.installedRevision
            do {
                let evidence = try await packageTitleDiscovery.discoverTitle(for: PackageTitleQuery(
                    packageID: provenance.packageID,
                    sourceURL: sourceURL,
                    revision: revision
                ))
                if byID[evidence.id] != evidence {
                    byID[evidence.id] = evidence
                    changed = true
                }
            } catch {
                // Cached verified evidence remains available when GitHub or a local repository is offline.
            }
        }
        guard changed else { return }
        packageNameEvidence = Array(byID.values)
        do {
            try await catalog.savePackageNameEvidence(packageNameEvidence)
            snapshot = enriched(snapshot)
        } catch {
            catalogError = error.localizedDescription
        }
    }

    private func sourceDiscoveryQuery(for skill: SkillRecord) -> SourceDiscoveryQuery {
        let package = snapshot.package(id: skill.packageID)
        return SourceDiscoveryQuery(
            packageID: skill.packageID,
            packageName: package?.name ?? skill.name,
            skillNames: package?.skillIDs.compactMap { snapshot.skill(id: $0)?.name } ?? [skill.name],
            author: package?.author ?? skill.author,
            filenames: skill.installations.map { $0.entryURL.lastPathComponent }
        )
    }

    private func enriched(_ snapshot: LibrarySnapshot) -> LibrarySnapshot {
        let connected = snapshot
            .applyingSourceConnections(sourceConnections)
            .settingUpdateAvailability(for: updateCandidates)
        let evidenceByPackage = Dictionary(grouping: packageNameEvidence, by: \.packageID)
        let packages = connected.packages.map { package in
            let title = resolvedPackageTitle(
                package: package,
                evidence: evidenceByPackage[package.id] ?? []
            )
            return title == package.name ? package : package.settingName(title)
        }
        return LibrarySnapshot(packages: packages, skills: connected.skills, scannedAt: connected.scannedAt)
    }

    private var resolvedArtworkCategories: [PackageID: PackageArtworkCategory] {
        if let cachedArtworkCategories { return cachedArtworkCategories }
        let result = Dictionary(uniqueKeysWithValues: snapshot.packages.map { package in
            let skills = package.skillIDs.compactMap { snapshot.skill(id: $0) }
            return (package.id, PackageArtworkCategory.infer(package: package, skills: skills))
        })
        cachedArtworkCategories = result
        return result
    }

    private var artworkEvidenceByPackage: [PackageID: [PackageArtworkEvidence]] {
        if let cachedArtworkEvidenceByPackage { return cachedArtworkEvidenceByPackage }
        let result = Dictionary(grouping: packageArtworkEvidence, by: \.packageID)
        cachedArtworkEvidenceByPackage = result
        return result
    }

    private var artworkUploadsByPackage: [PackageID: PackageArtworkUpload] {
        if let cachedArtworkUploadsByPackage { return cachedArtworkUploadsByPackage }
        let result = Dictionary(uniqueKeysWithValues: packageArtworkUploads.map { ($0.packageID, $0) })
        cachedArtworkUploadsByPackage = result
        return result
    }

    private func artworkCategory(for packageID: PackageID) -> PackageArtworkCategory {
        resolvedArtworkCategories[packageID] ?? .generalUtility
    }

    private func resolvedPackageTitle(
        package: SkillPackageRecord,
        evidence: [PackageNameEvidence]
    ) -> String {
        let generic = Self.isGenericPackageName(package.name)
        let wantsRepositoryTitle = preferRepositoryTitles || generic
        guard wantsRepositoryTitle else { return package.name }
        return evidence.sorted {
            if $0.confidence != $1.confidence { return $0.confidence > $1.confidence }
            return $0.observedAt > $1.observedAt
        }.first?.title ?? package.name
    }

    private static func isGenericPackageName(_ value: String) -> Bool {
        let lowered = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalized = String(lowered.filter { $0.isLetter || $0.isNumber })
        return ["skill", "skills", "plugin", "package", "repository", "tools"].contains(normalized)
            || lowered.hasSuffix("-skills")
    }

    private static func firstSelection(in node: LibraryNode) -> LibrarySelection? {
        switch node {
        case .skill(let skill): skill.id
        case .group(let group): group.skills.first?.id
        }
    }

    private func rememberInstallation(_ installationID: InstallationID, for skillID: SkillID) {
        defaults.set(
            installationID.rawValue,
            forKey: PreferenceKey.installationSelectionPrefix + skillID.rawValue
        )
    }

    private func installationRequiringAction(in skill: SkillRecord) -> SkillInstallation? {
        skill.installations.max { lhs, rhs in
            actionPriority(lhs) < actionPriority(rhs)
        }
    }

    private func actionPriority(_ installation: SkillInstallation) -> Int {
        switch installation.localState {
        case .conflict: 4
        case .missing, .accessRequired: 3
        case .modified: 2
        default: installation.updateAvailable ? 1 : 0
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0.lowercased()).inserted }
    }
}
