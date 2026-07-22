import Foundation
import SpellbookCore

public actor ConnectedSourceUpdater: SkillUpdating {
    private let catalog: any CatalogStore
    private let manager: any SkillManaging
    private let cacheRoot: URL
    private let fileManager: FileManager

    public init(
        catalog: any CatalogStore,
        manager: any SkillManaging,
        cacheRoot: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.catalog = catalog
        self.manager = manager
        self.fileManager = fileManager
        self.cacheRoot = cacheRoot ?? Self.defaultCacheRoot(fileManager: fileManager)
    }

    public func check(snapshot: LibrarySnapshot) async throws -> [PackageUpdate] {
        let connections = try await catalog.loadSourceConnections()
        var updates = [PackageUpdate]()
        for connection in connections {
            guard
                let package = snapshot.package(id: connection.packageID),
                !package.skillIDs.isEmpty
            else { continue }
            let packageSkills = package.skillIDs.compactMap(snapshot.skill(id:))
            guard !packageSkills.isEmpty else { continue }
            switch connection.kind {
            case .gitRepository:
                let found = try await checkGit(
                    connection: connection,
                    package: package,
                    skills: packageSkills
                )
                updates.append(contentsOf: found)
            case .directFile:
                let found = try await checkDirectFile(
                    connection: connection,
                    package: package,
                    skills: packageSkills
                )
                updates.append(contentsOf: found)
            }
        }
        return updates.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    public func apply(_ update: PackageUpdate) async throws -> PackageUpdateReceipt {
        guard
            let plan = update.mutationPlan,
            let connection = update.sourceConnection,
            update.canApply
        else { throw PackageUpdateError.repositoryChanged }
        _ = try await manager.execute(plan)
        try await catalog.saveSourceConnection(
            connection.settingLastRevision(update.targetRevision)
        )
        let updatedPaths = Set(plan.targets.map { $0.destinationURL.standardizedFileURL.path })
        let proposedHashByPath = Dictionary(uniqueKeysWithValues: plan.targets.compactMap { target in
            target.proposedHash.map { (target.destinationURL.standardizedFileURL.path, $0) }
        })
        let existingStates = try await catalog.loadInstallationSourceStates()
        let snapshot = try await catalog.loadSnapshot()
        let installationByPath = Dictionary(uniqueKeysWithValues: (snapshot?.skills ?? []).flatMap { skill in
            skill.installations.map { ($0.entryURL.standardizedFileURL.path, (skill.packageID, $0)) }
        })
        let updatedIDs = Set(updatedPaths.compactMap { installationByPath[$0]?.1.id })
        var states = existingStates.filter { !updatedIDs.contains($0.installationID) }
        states.append(contentsOf: updatedPaths.compactMap { path in
            guard let (packageID, installation) = installationByPath[path] else { return nil }
            return InstallationSourceState(
                installationID: installation.id,
                packageID: packageID,
                track: connection.branch,
                installedRevision: update.targetRevision,
                baselineHash: proposedHashByPath[path],
                lastCheckedAt: .now
            )
        })
        try await catalog.saveInstallationSourceStates(states)
        return PackageUpdateReceipt(
            repositoryURL: connection.sourceURL,
            previousRevision: update.currentRevision,
            resultingRevision: update.targetRevision
        )
    }

    private func checkGit(
        connection: SourceConnection,
        package: SkillPackageRecord,
        skills: [SkillRecord]
    ) async throws -> [PackageUpdate] {
        let checkout = try prepareGitCheckout(connection)
        let targets = try candidateTargets(skills: skills, candidateRoot: checkout.rootURL)
        let existingNames = Set(skills.map { normalized($0.name) })
        let offeredSkillNames = SkillFileEnumerator.entries(in: checkout.rootURL)
            .map { entry in
                entry.lastPathComponent.lowercased() == "skill.md"
                    ? entry.deletingLastPathComponent().lastPathComponent
                    : entry.deletingPathExtension().lastPathComponent
            }
            .filter { !existingNames.contains(normalized($0)) }
            .map(humanized)
            .uniqued()
        return try await makeUpdates(
            connection: connection,
            package: package,
            targets: targets,
            targetRevision: checkout.revision,
            strategy: .connectedGit,
            offeredSkillNames: offeredSkillNames
        )
    }

    private func checkDirectFile(
        connection: SourceConnection,
        package: SkillPackageRecord,
        skills: [SkillRecord]
    ) async throws -> [PackageUpdate] {
        guard skills.count == 1 else {
            return [blockedUpdate(
                connection: connection,
                package: package,
                targetRevision: "unsupported",
                strategy: .directFile,
                reason: "A direct Markdown source can update only a one-skill package."
            )]
        }
        let data: Data
        if connection.sourceURL.isFileURL {
            data = try Data(contentsOf: connection.sourceURL, options: .mappedIfSafe)
        } else {
            let response = try await URLSession.shared.data(from: connection.sourceURL)
            guard let http = response.1 as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw PackageUpdateError.commandFailed("The direct source did not return a successful response.")
            }
            data = response.0
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw PackageUpdateError.commandFailed("The direct source is not valid UTF-8 Markdown.")
        }
        let skill = skills[0]
        let targets = [CandidateSkillTarget(skill: skill, text: text)]
        return try await makeUpdates(
            connection: connection,
            package: package,
            targets: targets,
            targetRevision: StableHasher.sha256(data),
            strategy: .directFile,
            offeredSkillNames: []
        )
    }

    private func makeUpdates(
        connection: SourceConnection,
        package: SkillPackageRecord,
        targets: [CandidateSkillTarget],
        targetRevision: String,
        strategy: PackageUpdateStrategy,
        offeredSkillNames: [String]
    ) async throws -> [PackageUpdate] {
        let agents = Set(targets.flatMap { $0.skill.installations.map(\.agent) })
        var updates = [PackageUpdate]()
        for agent in agents.sorted(by: { $0.rawValue < $1.rawValue }) {
            let changedTargets = targets.filter { candidate in
                candidate.skill.installations.contains { installation in
                    installation.agent == agent
                        && installation.contentHash != StableHasher.sha256(Data(candidate.text.utf8))
                }
            }
            guard !changedTargets.isEmpty else { continue }
            let targetInstallations = changedTargets.flatMap(\.skill.installations).filter { $0.agent == agent }
            let blockedInstallations = targetInstallations.filter { $0.localState != .clean }
            let currentRevision = connection.lastRevision
                ?? combinedRevision(for: targetInstallations)
            if !blockedInstallations.isEmpty {
                updates.append(PackageUpdate(
                    id: "connected::\(package.id.rawValue)::\(agent.rawValue)",
                    packageIDs: [package.id],
                    packageNames: [package.name],
                    repositoryURL: connection.sourceURL,
                    sourceURL: connection.sourceURL,
                    currentRevision: currentRevision,
                    targetRevision: targetRevision,
                    canApply: false,
                    blockingReason: "This \(agent.displayName) installation is modified, conflicting, or unverified and requires individual review.",
                    strategy: strategy,
                    affectedSkillNames: changedTargets.map(\.skill.name).sorted(),
                    affectedInstallationCount: targetInstallations.count,
                    sourceConnection: connection,
                    targetAgent: agent,
                    offeredSkillNames: offeredSkillNames
                ))
                continue
            }

            let requests = changedTargets.compactMap { candidate -> MutationRequest? in
                guard let installation = candidate.skill.installations.first(where: { $0.agent == agent }) else {
                    return nil
                }
                return MutationRequest(
                    destinationURL: installation.entryURL,
                    action: .write,
                    expectedHash: installation.contentHash,
                    proposedText: candidate.text
                )
            }
            let plan = try await manager.plan(requests, kind: .update)
            updates.append(PackageUpdate(
                id: "connected::\(package.id.rawValue)::\(agent.rawValue)",
                packageIDs: [package.id],
                packageNames: [package.name],
                repositoryURL: connection.sourceURL,
                sourceURL: connection.sourceURL,
                currentRevision: currentRevision,
                targetRevision: targetRevision,
                canApply: true,
                blockingReason: nil,
                strategy: strategy,
                affectedSkillNames: changedTargets.map(\.skill.name).sorted(),
                affectedInstallationCount: requests.count,
                mutationPlan: plan,
                sourceConnection: connection,
                targetAgent: agent,
                offeredSkillNames: offeredSkillNames
            ))
        }
        guard !updates.isEmpty else {
            if connection.lastRevision != targetRevision {
                try await catalog.saveSourceConnection(connection.settingLastRevision(targetRevision))
            }
            return []
        }
        return updates
    }

    private func candidateTargets(
        skills: [SkillRecord],
        candidateRoot: URL
    ) throws -> [CandidateSkillTarget] {
        let availableEntries = SkillFileEnumerator.entries(in: candidateRoot)
        return try skills.map { skill in
            let relativeCandidates = skill.installations.compactMap { installation in
                relativePath(installation.entryURL, to: installation.rootURL)
            }
            let exactCandidates = relativeCandidates.map { candidateRoot.appending(path: $0) }
            let fallback = availableEntries.first { entry in
                entry.deletingLastPathComponent().lastPathComponent
                    .localizedCaseInsensitiveCompare(skill.name.replacingOccurrences(of: " ", with: "-")) == .orderedSame
            } ?? (skills.count == 1 ? availableEntries.first : nil)
            guard
                let entryURL = exactCandidates.first(where: { fileManager.fileExists(atPath: $0.path) }) ?? fallback,
                let data = try? Data(contentsOf: entryURL, options: .mappedIfSafe),
                let text = String(data: data, encoding: .utf8)
            else {
                throw PackageUpdateError.commandFailed("The connected source does not contain an entry for \(skill.name).")
            }
            return CandidateSkillTarget(skill: skill, text: text)
        }
    }

    private func prepareGitCheckout(_ connection: SourceConnection) throws -> GitCheckout {
        let sourceKey = StableHasher.sha256(Data(connection.sourceURL.absoluteString.utf8))
        let repositoryURL = cacheRoot
            .appending(path: "Repositories", directoryHint: .isDirectory)
            .appending(path: "\(sourceKey).git", directoryHint: .isDirectory)
        try fileManager.createDirectory(
            at: repositoryURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: repositoryURL.path) {
            let fetch = runGit(["--git-dir", repositoryURL.path, "fetch", "--quiet", "--prune", "origin"])
            guard fetch.status == 0 else {
                throw PackageUpdateError.commandFailed(fetch.message(fallback: "Git could not refresh the connected source."))
            }
        } else {
            let clone = runGit(["clone", "--quiet", "--mirror", connection.sourceURL.absoluteString, repositoryURL.path])
            guard clone.status == 0 else {
                throw PackageUpdateError.commandFailed(clone.message(fallback: "Git could not clone the connected source."))
            }
        }

        let requestedRevision = connection.branch ?? "HEAD"
        let revisionResult = runGit([
            "--git-dir", repositoryURL.path,
            "rev-parse", "--verify", "\(requestedRevision)^{commit}"
        ])
        guard revisionResult.status == 0, !revisionResult.output.isEmpty else {
            throw PackageUpdateError.commandFailed("The requested branch or tag is missing from the connected source.")
        }
        let revision = revisionResult.output
        let checkoutURL = cacheRoot
            .appending(path: "Candidates", directoryHint: .isDirectory)
            .appending(path: sourceKey, directoryHint: .isDirectory)
            .appending(path: revision, directoryHint: .isDirectory)
        if !fileManager.fileExists(atPath: checkoutURL.path) {
            try fileManager.createDirectory(
                at: checkoutURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let worktree = runGit([
                "--git-dir", repositoryURL.path,
                "worktree", "add", "--detach", checkoutURL.path, revision
            ])
            guard worktree.status == 0 else {
                throw PackageUpdateError.commandFailed(worktree.message(fallback: "Git could not stage the connected source."))
            }
        }
        let rootURL = try resolvedSubdirectory(connection.subdirectory, in: checkoutURL)
        return GitCheckout(rootURL: rootURL, revision: revision)
    }

    private func resolvedSubdirectory(_ subdirectory: String?, in checkoutURL: URL) throws -> URL {
        guard let subdirectory, !subdirectory.isEmpty else { return checkoutURL }
        let resolved = checkoutURL.appending(path: subdirectory).standardizedFileURL
        guard resolved.isDescendantOrEqual(to: checkoutURL) else {
            throw PackageUpdateError.commandFailed("The source subdirectory escapes the connected repository.")
        }
        return resolved
    }

    private func relativePath(_ url: URL, to ancestor: URL) -> String? {
        let path = url.standardizedFileURL.pathComponents
        let ancestorPath = ancestor.standardizedFileURL.pathComponents
        guard path.count >= ancestorPath.count, Array(path.prefix(ancestorPath.count)) == ancestorPath else {
            return nil
        }
        return path.dropFirst(ancestorPath.count).joined(separator: "/")
    }

    private func combinedRevision(for installations: [SkillInstallation]) -> String {
        let value = installations
            .sorted { $0.entryURL.path < $1.entryURL.path }
            .map(\.contentHash)
            .joined(separator: ":")
        return StableHasher.sha256(Data(value.utf8))
    }

    private func normalized(_ value: String) -> String {
        value.lowercased().filter(\.isLetter)
    }

    private func humanized(_ value: String) -> String {
        value.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private func blockedUpdate(
        connection: SourceConnection,
        package: SkillPackageRecord,
        targetRevision: String,
        strategy: PackageUpdateStrategy,
        reason: String
    ) -> PackageUpdate {
        PackageUpdate(
            id: "connected::\(package.id.rawValue)",
            packageIDs: [package.id],
            packageNames: [package.name],
            repositoryURL: connection.sourceURL,
            sourceURL: connection.sourceURL,
            currentRevision: connection.lastRevision ?? "local",
            targetRevision: targetRevision,
            canApply: false,
            blockingReason: reason,
            strategy: strategy,
            sourceConnection: connection
        )
    }

    private func runGit(_ arguments: [String]) -> ConnectedGitResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ConnectedGitResult(status: -1, output: "", error: error.localizedDescription)
        }
        return ConnectedGitResult(
            status: process.terminationStatus,
            output: String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            error: String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
    }

    private static func defaultCacheRoot(fileManager: FileManager) -> URL {
        let cache = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return cache.appending(path: "Spellbook/Sources", directoryHint: .isDirectory)
    }
}

private struct CandidateSkillTarget {
    let skill: SkillRecord
    let text: String
}

private struct GitCheckout {
    let rootURL: URL
    let revision: String
}

private struct ConnectedGitResult {
    let status: Int32
    let output: String
    let error: String

    func message(fallback: String) -> String {
        error.isEmpty ? fallback : error
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

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0.lowercased()).inserted }
    }
}
