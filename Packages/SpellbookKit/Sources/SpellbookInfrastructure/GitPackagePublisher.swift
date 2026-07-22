import Foundation
import SpellbookCore

public actor GitPackagePublisher: SkillPublishing {
    private let cacheRoot: URL
    private let fileManager: FileManager

    public init(cacheRoot: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.cacheRoot = cacheRoot ?? base.appending(path: "Spellbook/Publishing", directoryHint: .isDirectory)
    }

    public func preview(
        package: SkillPackageRecord,
        skills: [SkillRecord],
        agent: AgentKind,
        target: PublishingTarget
    ) async throws -> PublishingPlan {
        try Task.checkCancellation()
        let installations = skills.compactMap { skill in
            skill.installations.first(where: { $0.agent == agent }).map { (skill, $0) }
        }
        guard !installations.isEmpty else { throw PublishingError.noInstallations(agent) }

        try fileManager.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
        let stagingURL = cacheRoot.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let expectedRevision = try remoteRevision(target)
        let clone = runGit([
            "clone", "--quiet", "--branch", target.branch, "--single-branch",
            target.repositoryURL.absoluteString, stagingURL.path
        ])
        guard clone.status == 0 else {
            throw PublishingError.invalidRepository(
                clone.message(fallback: "Spellbook could not clone the configured publishing branch.")
            )
        }

        let packageSlug = slug(package.name)
        let destination = stagingURL
            .appending(path: "packages", directoryHint: .isDirectory)
            .appending(path: packageSlug, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        try copyPackage(installations, to: destination)
        try updateManifest(
            at: stagingURL,
            package: package,
            slug: packageSlug,
            agent: agent
        )
        let changes = try changedFiles(in: stagingURL)
        return PublishingPlan(
            id: UUID().uuidString,
            target: target,
            packageID: package.id,
            packageName: package.name,
            agent: agent,
            expectedRemoteRevision: expectedRevision,
            stagingURL: stagingURL,
            changes: changes
        )
    }

    public func publish(_ plan: PublishingPlan, approveNewFiles: Bool) async throws -> PublishingReceipt {
        try Task.checkCancellation()
        if plan.changes.contains(where: \.isNew), !approveNewFiles {
            throw PublishingError.newFilesNeedApproval
        }
        guard try remoteRevision(plan.target) == plan.expectedRemoteRevision else {
            throw PublishingError.remoteMoved
        }
        guard !plan.changes.isEmpty else {
            throw PublishingError.commandFailed("There are no package changes to publish.")
        }
        let add = runGit(["-C", plan.stagingURL.path, "add", "--", ".spellbook", "packages"])
        guard add.status == 0 else { throw PublishingError.commandFailed(add.message(fallback: "Git could not stage the package.")) }
        let commit = runGit([
            "-C", plan.stagingURL.path,
            "-c", "user.name=Spellbook",
            "-c", "user.email=spellbook@localhost",
            "commit", "--quiet", "-m", "Update \(plan.packageName) from \(plan.agent.displayName)"
        ])
        guard commit.status == 0 else {
            throw PublishingError.commandFailed(commit.message(fallback: "Git could not create the publishing commit."))
        }
        let push = runGit([
            "-C", plan.stagingURL.path,
            "push", "--quiet", "origin", "HEAD:refs/heads/\(plan.target.branch)"
        ])
        guard push.status == 0 else {
            throw PublishingError.commandFailed(push.message(fallback: "Git refused the push. Review the remote branch and try again."))
        }
        let revision = runGit(["-C", plan.stagingURL.path, "rev-parse", "HEAD"])
        guard revision.status == 0, !revision.output.isEmpty else {
            throw PublishingError.commandFailed("The published commit could not be read.")
        }
        return PublishingReceipt(
            packageID: plan.packageID,
            agent: plan.agent,
            repositoryURL: plan.target.repositoryURL,
            branch: plan.target.branch,
            commit: revision.output
        )
    }

    private func copyPackage(
        _ installations: [(SkillRecord, SkillInstallation)],
        to destination: URL
    ) throws {
        let roots = Set(installations.map { $0.1.rootURL.standardizedFileURL })
        if roots.count == 1, let root = roots.first {
            try copyContents(of: root, to: destination)
            return
        }
        for (skill, installation) in installations {
            let skillDestination = destination.appending(path: slug(skill.name), directoryHint: .isDirectory)
            try fileManager.createDirectory(at: skillDestination, withIntermediateDirectories: true)
            try copyContents(of: installation.rootURL, to: skillDestination)
        }
    }

    private func copyContents(of source: URL, to destination: URL) throws {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
        guard let enumerator = fileManager.enumerator(
            at: source,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return }
        while let item = enumerator.nextObject() as? URL {
            try Task.checkCancellation()
            let relative = item.path.replacingOccurrences(of: source.path + "/", with: "")
            guard !relative.isEmpty, !relative.split(separator: "/").contains(".git") else { continue }
            let resolved = item.resolvingSymlinksInPath()
            guard resolved.isDescendantOrEqual(to: source.resolvingSymlinksInPath()) else { continue }
            let target = destination.appending(path: relative)
            let values = try item.resourceValues(forKeys: Set(keys))
            if values.isDirectory == true {
                try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
            } else if values.isRegularFile == true, values.isSymbolicLink != true {
                try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fileManager.fileExists(atPath: target.path) { try fileManager.removeItem(at: target) }
                try fileManager.copyItem(at: item, to: target)
            }
        }
    }

    private func updateManifest(
        at repository: URL,
        package: SkillPackageRecord,
        slug: String,
        agent: AgentKind
    ) throws {
        let directory = repository.appending(path: ".spellbook", directoryHint: .isDirectory)
        let url = directory.appending(path: "manifest.json")
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var manifest = (try? Data(contentsOf: url))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        var packages = manifest["packages"] as? [String: Any] ?? [:]
        packages[slug] = [
            "packageID": package.id.rawValue,
            "name": package.name,
            "path": "packages/\(slug)",
            "lastPublishedAgent": agent.rawValue
        ]
        manifest["version"] = 1
        manifest["packages"] = packages
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    private func changedFiles(in repository: URL) throws -> [PublishingFileChange] {
        let status = runGit(["-C", repository.path, "status", "--porcelain", "--untracked-files=all"])
        guard status.status == 0 else {
            throw PublishingError.commandFailed(status.message(fallback: "Git could not prepare the publishing preview."))
        }
        return status.output.split(separator: "\n").compactMap { rawLine in
            let line = String(rawLine)
            guard line.count > 3 else { return nil }
            let path = String(line.dropFirst(3))
            let fileURL = repository.appending(path: path)
            guard let data = try? Data(contentsOf: fileURL) else { return nil }
            let old = runGit(["-C", repository.path, "show", "HEAD:\(path)"])
            let previousHash = old.status == 0 ? StableHasher.sha256(Data(old.output.utf8)) : nil
            let ext = fileURL.pathExtension.lowercased()
            return PublishingFileChange(
                relativePath: path,
                previousHash: previousHash,
                proposedHash: StableHasher.sha256(data),
                isArtwork: ["png", "jpg", "jpeg", "webp", "svg", "icns"].contains(ext)
            )
        }
        .sorted { $0.relativePath < $1.relativePath }
    }

    private func remoteRevision(_ target: PublishingTarget) throws -> String? {
        let result = runGit([
            "ls-remote", "--heads", target.repositoryURL.absoluteString,
            "refs/heads/\(target.branch)"
        ])
        guard result.status == 0 else {
            throw PublishingError.invalidRepository(result.message(fallback: "The publishing repository is unavailable."))
        }
        return result.output.split(separator: "\t").first.map(String.init)
    }

    private func slug(_ value: String) -> String {
        let result = value.lowercased().map { character -> Character in
            character.isLetter || character.isNumber ? character : "-"
        }
        return String(result).split(separator: "-").joined(separator: "-")
    }

    private func runGit(_ arguments: [String]) -> GitPublisherResult {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = errors
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return GitPublisherResult(status: -1, output: "", error: error.localizedDescription)
        }
        return GitPublisherResult(
            status: process.terminationStatus,
            output: String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            error: String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
    }
}

private struct GitPublisherResult {
    let status: Int32
    let output: String
    let error: String

    func message(fallback: String) -> String { error.isEmpty ? fallback : error }
}

private extension URL {
    func isDescendantOrEqual(to ancestor: URL) -> Bool {
        let path = standardizedFileURL.pathComponents
        let root = ancestor.standardizedFileURL.pathComponents
        return path.count >= root.count && Array(path.prefix(root.count)) == root
    }
}
