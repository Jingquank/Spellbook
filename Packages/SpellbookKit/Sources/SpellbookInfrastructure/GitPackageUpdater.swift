import Foundation
import SpellbookCore

public actor GitPackageUpdater: SkillUpdating {
    private let catalog: (any CatalogStore)?

    public init(catalog: (any CatalogStore)? = nil) {
        self.catalog = catalog
    }

    public func check(snapshot: LibrarySnapshot) throws -> [PackageUpdate] {
        let groups = repositoryGroups(snapshot: snapshot)
        var updates = [PackageUpdate]()

        for group in groups {
            let fetch = runGit(["fetch", "--quiet", "--prune", "origin"], in: group.repositoryURL)
            guard fetch.status == 0 else {
                throw PackageUpdateError.commandFailed(fetch.message(fallback: "Couldn’t check \(group.names.joined(separator: ", ")) for updates."))
            }

            guard
                let current = successfulOutput(["rev-parse", "HEAD"], in: group.repositoryURL),
                let target = upstreamRevision(in: group.repositoryURL),
                current != target
            else { continue }

            let clean = successfulOutput(
                ["status", "--porcelain", "--untracked-files=no"],
                in: group.repositoryURL
            )?.isEmpty == true
            let fastForward = runGit(
                ["merge-base", "--is-ancestor", current, target],
                in: group.repositoryURL
            ).status == 0
            let blockingReason: String? = if !clean {
                "Local Git changes must be reviewed first."
            } else if !fastForward {
                "Upstream and local history have diverged."
            } else {
                nil
            }

            updates.append(PackageUpdate(
                id: group.repositoryURL.standardizedFileURL.path,
                packageIDs: group.packageIDs.sorted { $0.rawValue < $1.rawValue },
                packageNames: group.names.sorted(),
                repositoryURL: group.repositoryURL,
                sourceURL: group.sourceURL,
                currentRevision: current,
                targetRevision: target,
                canApply: clean && fastForward,
                blockingReason: blockingReason,
                affectedSkillNames: Array(group.skillNames).sorted(),
                affectedInstallationCount: group.installationCount
            ))
        }

        return updates.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    public func apply(_ update: PackageUpdate) async throws -> PackageUpdateReceipt {
        let operationID = UUID().uuidString
        let startedAt = Date.now
        do {
            guard successfulOutput(["rev-parse", "HEAD"], in: update.repositoryURL) == update.currentRevision else {
                throw PackageUpdateError.repositoryChanged
            }
            guard successfulOutput(
                ["status", "--porcelain", "--untracked-files=no"],
                in: update.repositoryURL
            )?.isEmpty == true else {
                throw PackageUpdateError.localChanges
            }
            guard runGit(
                ["merge-base", "--is-ancestor", update.currentRevision, update.targetRevision],
                in: update.repositoryURL
            ).status == 0 else {
                throw PackageUpdateError.notFastForward
            }

            let merge = runGit(["merge", "--ff-only", update.targetRevision], in: update.repositoryURL)
            guard merge.status == 0 else {
                throw PackageUpdateError.commandFailed(merge.message(fallback: "Git could not apply the reviewed update."))
            }
            guard let resultingRevision = successfulOutput(["rev-parse", "HEAD"], in: update.repositoryURL) else {
                throw PackageUpdateError.commandFailed("Git updated the package, but Spellbook could not verify the resulting revision.")
            }

            let receipt = PackageUpdateReceipt(
                repositoryURL: update.repositoryURL,
                previousRevision: update.currentRevision,
                resultingRevision: resultingRevision
            )
            await recordOperation(
                id: operationID,
                status: .committed,
                startedAt: startedAt,
                repositoryURL: update.repositoryURL,
                message: "\(update.currentRevision) → \(resultingRevision)"
            )
            return receipt
        } catch {
            await recordOperation(
                id: operationID,
                status: .failed,
                startedAt: startedAt,
                repositoryURL: update.repositoryURL,
                message: error.localizedDescription
            )
            throw error
        }
    }

    private func repositoryGroups(snapshot: LibrarySnapshot) -> [RepositoryGroup] {
        var groups = [URL: RepositoryGroup]()

        for package in snapshot.packages {
            let roots = snapshot.skills
                .filter { $0.packageID == package.id }
                .flatMap(\.installations)
                .compactMap { repositoryRoot(from: $0.rootURL) }

            for root in Set(roots) {
                var group = groups[root] ?? RepositoryGroup(
                    repositoryURL: root,
                    packageIDs: [],
                    names: [],
                    sourceURL: package.sourceURL,
                    skillNames: [],
                    installationCount: 0
                )
                group.packageIDs.insert(package.id)
                group.names.insert(package.name)
                if group.sourceURL == nil { group.sourceURL = package.sourceURL }
                let affectedSkills = snapshot.skills.filter { skill in
                    skill.packageID == package.id
                        && skill.installations.contains { repositoryRoot(from: $0.rootURL) == root }
                }
                group.skillNames.formUnion(affectedSkills.map(\.name))
                group.installationCount += affectedSkills.flatMap(\.installations).filter {
                    repositoryRoot(from: $0.rootURL) == root
                }.count
                groups[root] = group
            }
        }
        return Array(groups.values)
    }

    private func repositoryRoot(from startURL: URL) -> URL? {
        var current = startURL.standardizedFileURL
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL

        while current.pathComponents.count >= home.pathComponents.count {
            if FileManager.default.fileExists(atPath: current.appending(path: ".git").path) {
                return current
            }
            if current == home { break }
            let parent = current.deletingLastPathComponent()
            if parent == current { break }
            current = parent
        }
        return nil
    }

    private func upstreamRevision(in repositoryURL: URL) -> String? {
        successfulOutput(["rev-parse", "--verify", "@{upstream}^{commit}"], in: repositoryURL)
            ?? successfulOutput(["rev-parse", "--verify", "origin/HEAD^{commit}"], in: repositoryURL)
    }

    private func successfulOutput(_ arguments: [String], in repositoryURL: URL) -> String? {
        let result = runGit(arguments, in: repositoryURL)
        return result.status == 0 ? result.output : nil
    }

    private func runGit(_ arguments: [String], in repositoryURL: URL) -> GitCommandResult {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.arguments = ["-C", repositoryURL.path] + arguments
        process.standardOutput = standardOutput
        process.standardError = standardError

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return GitCommandResult(status: -1, output: "", error: error.localizedDescription)
        }

        let output = String(
            data: standardOutput.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let error = String(
            data: standardError.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return GitCommandResult(status: process.terminationStatus, output: output, error: error)
    }

    private func recordOperation(
        id: String,
        status: ManagedOperationStatus,
        startedAt: Date,
        repositoryURL: URL,
        message: String
    ) async {
        let operation = ManagedOperationRecord(
            id: id,
            kind: .update,
            status: status,
            startedAt: startedAt,
            finishedAt: .now,
            targetURLs: [repositoryURL],
            recoveryURLs: [],
            message: message
        )
        try? await catalog?.recordOperation(operation)
    }
}

private struct RepositoryGroup {
    let repositoryURL: URL
    var packageIDs: Set<PackageID>
    var names: Set<String>
    var sourceURL: URL?
    var skillNames: Set<String>
    var installationCount: Int
}

private struct GitCommandResult {
    let status: Int32
    let output: String
    let error: String

    func message(fallback: String) -> String {
        error.isEmpty ? fallback : error
    }
}
