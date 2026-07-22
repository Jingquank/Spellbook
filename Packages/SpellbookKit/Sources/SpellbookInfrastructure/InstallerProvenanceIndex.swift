import Foundation
import SpellbookCore

struct InstallerProvenanceIndex: Sendable {
    private let hintsByInstallation: [String: InstallerProvenanceHint]
    let receipts: [InstallerPackageReceipt]

    static let empty = InstallerProvenanceIndex(hintsByInstallation: [:], receipts: [])

    static func load(
        roots: [SkillDiscoveryRoot] = SkillDiscoveryRoot.known,
        sourceSearchRoots: [SourceSearchRootRecord] = [
            SourceSearchRootRecord(url: URL(filePath: "/Users/keding/Cursor", directoryHint: .isDirectory))
        ],
        fileManager: FileManager = .default
    ) -> InstallerProvenanceIndex {
        let home = fileManager.homeDirectoryForCurrentUser
        var hints = [String: InstallerProvenanceHint]()
        var receipts = [InstallerPackageReceipt]()

        loadAgentSkillLock(
            at: home.appending(path: ".agents/.skill-lock.json"),
            installRoot: home.appending(path: ".agents/skills", directoryHint: .isDirectory),
            agent: .codex,
            into: &hints
        )
        loadCodexCuratedCache(
            at: home.appending(path: ".codex/vendor_imports/skills-curated-cache.json"),
            installRoot: home.appending(path: ".codex/skills", directoryHint: .isDirectory),
            into: &hints
        )

        for root in roots {
            loadPackageReceipts(
                in: root,
                into: &hints,
                receipts: &receipts,
                sourceSearchRoots: sourceSearchRoots,
                fileManager: fileManager
            )
        }
        return InstallerProvenanceIndex(hintsByInstallation: hints, receipts: receipts)
    }

    func hint(for entryURL: URL, agent: AgentKind) -> InstallerProvenanceHint? {
        let lexical = Self.key(agent: agent, url: entryURL)
        if let hint = hintsByInstallation[lexical] { return hint }
        let resolved = Self.key(agent: agent, url: entryURL.resolvingSymlinksInPath())
        return hintsByInstallation[resolved]
    }

    private static func loadAgentSkillLock(
        at url: URL,
        installRoot: URL,
        agent: AgentKind,
        into hints: inout [String: InstallerProvenanceHint]
    ) {
        guard
            let data = try? Data(contentsOf: url, options: .mappedIfSafe),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let skills = root["skills"] as? [String: Any]
        else { return }

        for (name, rawValue) in skills {
            guard let value = rawValue as? [String: Any] else { continue }
            let sourceString = value["sourceUrl"] as? String ?? value["source"] as? String
            let sourceURL = sourceString.flatMap(repositoryURL)
            let pluginName = value["pluginName"] as? String
            let sourcePackageName = sourceURL?.deletingPathExtension().lastPathComponent
            let packageName = pluginName ?? sourcePackageName
            let packageKey = sourceURL.map { "source::\(RepositoryURLNormalizer.stableString($0))" }
                ?? pluginName.map { "plugin::\(normalized($0))" }
            let entryURL = installRoot.appending(path: name).appending(path: "SKILL.md")
            hints[key(agent: agent, url: entryURL)] = InstallerProvenanceHint(
                sourceURL: sourceURL,
                skillPath: value["skillPath"] as? String,
                contentHash: value["skillFolderHash"] as? String ?? value["computedHash"] as? String,
                installedAt: parseDate(value["installedAt"] as? String),
                updatedAt: parseDate(value["updatedAt"] as? String),
                sourceConfidence: sourceURL == nil ? nil : .verified,
                packageMembershipKey: packageKey,
                packageName: packageName,
                packageVersion: value["version"] as? String,
                sourceRevision: value["revision"] as? String ?? value["commit"] as? String,
                receiptID: url.path,
                explanation: "Matched the agent installer receipt at this exact installation path."
            )
        }
    }

    private static func loadCodexCuratedCache(
        at url: URL,
        installRoot: URL,
        into hints: inout [String: InstallerProvenanceHint]
    ) {
        guard
            let data = try? Data(contentsOf: url, options: .mappedIfSafe),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let skills = root["skills"] as? [[String: Any]],
            let sourceURL = URL(string: "https://github.com/openai/skills.git")
        else { return }

        for skill in skills {
            guard let id = skill["id"] as? String else { continue }
            let entryURL = installRoot.appending(path: id).appending(path: "SKILL.md")
            hints[key(agent: .codex, url: entryURL)] = InstallerProvenanceHint(
                sourceURL: sourceURL,
                skillPath: skill["repoPath"] as? String,
                contentHash: nil,
                installedAt: nil,
                updatedAt: nil,
                sourceConfidence: .verified,
                packageMembershipKey: "source::\(RepositoryURLNormalizer.stableString(sourceURL))",
                packageName: "OpenAI Skills",
                packageVersion: nil,
                sourceRevision: nil,
                receiptID: url.path,
                explanation: "Matched the Codex curated catalog at this exact installation path."
            )
        }
    }

    private static func loadPackageReceipts(
        in root: SkillDiscoveryRoot,
        into hints: inout [String: InstallerProvenanceHint],
        receipts: inout [InstallerPackageReceipt],
        sourceSearchRoots: [SourceSearchRootRecord],
        fileManager: FileManager
    ) {
        guard let children = try? fileManager.contentsOfDirectory(
            at: root.url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            // Hidden installer receipts are intentionally included by the fallback listing below.
            return loadHiddenPackageReceipts(
                in: root,
                into: &hints,
                receipts: &receipts,
                sourceSearchRoots: sourceSearchRoots,
                fileManager: fileManager
            )
        }
        _ = children
        loadHiddenPackageReceipts(
            in: root,
            into: &hints,
            receipts: &receipts,
            sourceSearchRoots: sourceSearchRoots,
            fileManager: fileManager
        )
    }

    private static func loadHiddenPackageReceipts(
        in root: SkillDiscoveryRoot,
        into hints: inout [String: InstallerProvenanceHint],
        receipts: inout [InstallerPackageReceipt],
        sourceSearchRoots: [SourceSearchRootRecord],
        fileManager: FileManager
    ) {
        guard let children = try? fileManager.contentsOfDirectory(
            at: root.url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []
        ) else { return }

        for receiptURL in children where receiptURL.lastPathComponent.hasPrefix(".")
            && receiptURL.lastPathComponent.hasSuffix("-install.json") {
            guard let unconnectedReceipt = validatedPackageReceipt(
                at: receiptURL,
                root: root,
                fileManager: fileManager
            ) else { continue }
            let receipt = connectingLocalSource(
                to: unconnectedReceipt,
                searchRoots: sourceSearchRoots,
                fileManager: fileManager
            )
            receipts.append(receipt)
            for component in receipt.components {
                let entryURL = root.url
                    .appending(path: component.relativePath, directoryHint: .isDirectory)
                    .appending(path: "SKILL.md")
                let pathKey = key(agent: root.agent, url: entryURL)
                guard hints[pathKey] == nil else { continue }
                hints[pathKey] = InstallerProvenanceHint(
                    sourceURL: receipt.sourceURL,
                    skillPath: component.relativePath + "/SKILL.md",
                    contentHash: nil,
                    installedAt: receipt.observedAt,
                    updatedAt: receipt.observedAt,
                    sourceConfidence: receipt.sourceURL == nil ? nil : .verified,
                    packageMembershipKey: "installer-package::\(receipt.membershipKey)",
                    packageName: receipt.displayName ?? humanized(receipt.packageSlug),
                    packageVersion: receipt.version,
                    sourceRevision: receipt.sourceRevision,
                    receiptID: receipt.id,
                    explanation: "Verified package membership from \(receiptURL.lastPathComponent) at this agent root."
                )
            }
        }
    }

    private static func validatedPackageReceipt(
        at url: URL,
        root: SkillDiscoveryRoot,
        fileManager: FileManager
    ) -> InstallerPackageReceipt? {
        guard
            let data = try? Data(contentsOf: url, options: .mappedIfSafe),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let skillMap = object["skills"] as? [String: Any],
            !skillMap.isEmpty
        else { return nil }

        let filename = url.deletingPathExtension().lastPathComponent
        let slug = filename.dropFirst().replacingOccurrences(of: "-install", with: "")
        guard !slug.isEmpty else { return nil }
        let canonicalRoot = root.url.resolvingSymlinksInPath().standardizedFileURL
        var components = [InstallerPackageComponent]()

        for (componentName, rawFiles) in skillMap.sorted(by: { $0.key < $1.key }) {
            guard
                !componentName.isEmpty,
                !componentName.contains("/"),
                !componentName.contains(".."),
                let files = rawFiles as? [String],
                files.contains(where: { $0.caseInsensitiveCompare("SKILL.md") == .orderedSame })
            else { return nil }
            let componentRoot = root.url.appending(path: componentName, directoryHint: .isDirectory)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: componentRoot.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                return nil
            }
            let canonicalComponent = componentRoot.resolvingSymlinksInPath().standardizedFileURL
            guard canonicalComponent.isDescendant(of: canonicalRoot) else { return nil }

            for file in files {
                guard isSafeRelativePath(file) else { return nil }
                let installed = componentRoot.appending(path: file).standardizedFileURL
                guard fileManager.fileExists(atPath: installed.path) else { return nil }
                let resolved = installed.resolvingSymlinksInPath().standardizedFileURL
                guard resolved.isDescendant(of: canonicalComponent) else { return nil }
            }
            components.append(InstallerPackageComponent(
                name: componentName,
                relativePath: componentName,
                installedFiles: files.sorted()
            ))
        }

        let sourceString = object["sourceUrl"] as? String ?? object["repository"] as? String
        let sourceURL = sourceString.flatMap(repositoryURL)
        let modifiedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .now
        return InstallerPackageReceipt(
            id: "\(root.agent.rawValue)::\(url.standardizedFileURL.path)",
            packageSlug: String(slug),
            displayName: object["displayName"] as? String,
            version: object["version"] as? String,
            agent: root.agent,
            receiptURL: url.standardizedFileURL,
            skillRootURL: root.url,
            components: components,
            sourceURL: sourceURL,
            sourceRevision: object["revision"] as? String ?? object["commit"] as? String,
            observedAt: modifiedAt
        )
    }

    private static func connectingLocalSource(
        to receipt: InstallerPackageReceipt,
        searchRoots: [SourceSearchRootRecord],
        fileManager: FileManager
    ) -> InstallerPackageReceipt {
        guard receipt.sourceURL == nil else { return receipt }
        let normalizedSlug = normalized(receipt.packageSlug)
        let candidates = searchRoots.flatMap { root -> [URL] in
            if !root.isTrusted {
                return spotlightRepositories(beneath: root.url).filter { candidate in
                    normalized(candidate.lastPathComponent) == normalizedSlug
                        && fileManager.fileExists(atPath: candidate.appending(path: ".git").path)
                }
            }
            guard let children = try? fileManager.contentsOfDirectory(
                at: root.url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }
            return children.filter { candidate in
                normalized(candidate.lastPathComponent) == normalizedSlug
                    && fileManager.fileExists(atPath: candidate.appending(path: ".git").path)
            }
        }
        let uniqueCandidates = Dictionary(grouping: candidates, by: { $0.resolvingSymlinksInPath().path })
            .compactMap(\.value.first)
        guard uniqueCandidates.count == 1,
              let candidate = uniqueCandidates.first,
              let match = exactHistoricalMatch(receipt: receipt, repository: candidate),
              let remote = gitOutput(["config", "--get", "remote.origin.url"], in: candidate)
                .flatMap(RepositoryURLNormalizer.url(from:))
        else { return receipt }

        return InstallerPackageReceipt(
            id: receipt.id,
            packageSlug: receipt.packageSlug,
            displayName: receipt.displayName,
            version: receipt.version,
            agent: receipt.agent,
            receiptURL: receipt.receiptURL,
            skillRootURL: receipt.skillRootURL,
            components: receipt.components,
            sourceURL: remote,
            sourceRevision: match,
            observedAt: receipt.observedAt
        )
    }

    private static func spotlightRepositories(beneath root: URL) -> [URL] {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/mdfind")
        process.arguments = ["-onlyin", root.path, "kMDItemFSName == '.git'c"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }
        guard process.terminationStatus == 0 else { return [] }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        let standardizedRoot = root.resolvingSymlinksInPath().standardizedFileURL
        return text.split(separator: "\n").prefix(5_000).compactMap { line in
            let gitDirectory = URL(filePath: String(line)).resolvingSymlinksInPath().standardizedFileURL
            guard gitDirectory.lastPathComponent == ".git" else { return nil }
            let repository = gitDirectory.deletingLastPathComponent()
            guard repository.isDescendant(of: standardizedRoot) else { return nil }
            return repository
        }
    }

    private static func exactHistoricalMatch(
        receipt: InstallerPackageReceipt,
        repository: URL
    ) -> String? {
        guard let version = receipt.version else { return nil }
        let revisions = gitOutput(["rev-list", "--all", "--", "package.json"], in: repository)?
            .split(separator: "\n").map(String.init) ?? []
        for revision in revisions.prefix(500) {
            guard
                let packageJSON = gitOutput(["show", "\(revision):package.json"], in: repository),
                let data = packageJSON.data(using: .utf8),
                let package = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                package["version"] as? String == version,
                let installer = gitOutput(["show", "\(revision):bin/install.js"], in: repository)
            else { continue }
            let allComponentsPresent = receipt.components.allSatisfy { component in
                installer.contains("name: \"\(component.name)\"")
                    || installer.contains("name: '\(component.name)'")
            }
            if allComponentsPresent { return revision }
        }
        return nil
    }

    private static func gitOutput(_ arguments: [String], in repository: URL) -> String? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.arguments = ["-C", repository.path] + arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch { return nil }
        guard process.terminationStatus == 0 else { return nil }
        return String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func key(agent: AgentKind, url: URL) -> String {
        "\(agent.rawValue)::\(url.standardizedFileURL.path)"
    }

    private static func isSafeRelativePath(_ value: String) -> Bool {
        guard !value.isEmpty, !value.hasPrefix("/"), !value.hasPrefix("~") else { return false }
        return !value.split(separator: "/", omittingEmptySubsequences: false).contains("..")
    }

    private static func repositoryURL(_ value: String) -> URL? {
        if value.contains("://") || value.hasPrefix("git@") {
            return RepositoryURLNormalizer.url(from: value)
        }
        return RepositoryURLNormalizer.url(from: "https://github.com/\(value).git")
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return try? Date(value, strategy: .iso8601)
    }

    private static func normalized(_ value: String) -> String {
        String(value.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    private static func humanized(_ value: String) -> String {
        value.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

private extension URL {
    func isDescendant(of ancestor: URL) -> Bool {
        let components = standardizedFileURL.pathComponents
        let root = ancestor.standardizedFileURL.pathComponents
        return components.count >= root.count && Array(components.prefix(root.count)) == root
    }
}
