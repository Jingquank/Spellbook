import Foundation
import SpellbookCore

enum DiscoveredSkillReader {
    static func read(
        entryURL: URL,
        discoveryRoot: SkillDiscoveryRoot,
        provenanceIndex: InstallerProvenanceIndex = .empty,
        artworkCache: ArtworkResolutionCache? = nil,
        manifestCache: PackageManifestResolutionCache? = nil,
        gitCache: GitRepositoryInspectionCache? = nil
    ) -> DiscoveredSkill? {
        guard
            let data = try? Data(contentsOf: entryURL, options: .mappedIfSafe),
            let markdown = String(data: data, encoding: .utf8)
        else { return nil }

        let boundary = directoryBoundary(for: discoveryRoot.url)
        let entryDirectory = entryURL.deletingLastPathComponent()
        let frontmatter = FrontmatterMetadata.parse(markdown)
        let provenanceHint = provenanceIndex.hint(for: entryURL, agent: discoveryRoot.agent)
        let git = GitRepositoryInspector.inspect(
            from: entryDirectory,
            boundedBy: boundary,
            cache: gitCache
        )
        let manifest = PackageManifestReader.read(
            from: entryDirectory,
            boundedBy: boundary,
            cache: manifestCache
        )
        let packageRoot = manifest?.rootURL ?? git?.rootURL ?? structuralPackageRoot(
            entryURL: entryURL,
            discoveryRoot: boundary
        )

        let sourceURL = provenanceHint?.sourceURL
            ?? frontmatter.sourceURL
            ?? manifest?.sourceURL
            ?? git?.sourceURL
        let sourceConfidence = provenanceHint?.sourceConfidence
            ?? (git == nil ? (sourceURL == nil ? nil : .likely) : .verified)
        let aliasTarget = AliasRelationshipReader.targetName(in: markdown)
        let contentIdentityKey = contentIdentity(
            name: nonempty(frontmatter.name) ?? inferredSkillName(entryURL),
            markdown: markdown
        )
        let packageIdentity = packageIdentityKey(
            sourceURL: sourceURL,
            sourceConfidence: sourceConfidence,
            packageMembershipKey: provenanceHint?.packageMembershipKey,
            aliasTarget: aliasTarget,
            contentIdentityKey: contentIdentityKey,
            manifest: manifest,
            git: git,
            packageRoot: packageRoot,
            entryURL: entryURL,
            discoveryRoot: boundary,
            agent: discoveryRoot.agent
        )
        let packageID = PackageID(rawValue: "package-\(StableHasher.sha256(packageIdentity))")
        let skillKey = skillIdentityKey(
            explicitID: frontmatter.stableID,
            contentIdentityKey: contentIdentityKey,
            entryURL: entryURL,
            packageRoot: packageRoot,
            discoveryRoot: boundary,
            hasDeclaredPackageBoundary: manifest != nil || git != nil
        )
        let skillID = SkillID(rawValue: "skill-\(StableHasher.sha256("\(packageIdentity)::\(skillKey)"))")

        let inferredName = inferredSkillName(entryURL)
        let name = nonempty(frontmatter.name) ?? inferredName
        let summary = nonempty(frontmatter.summary) ?? inferredSummary(markdown)
        let author = nonempty(frontmatter.author) ?? nonempty(manifest?.author) ?? inferredAuthor(sourceURL)
        let websiteURL = frontmatter.websiteURL ?? manifest?.websiteURL ?? sourceURL
        let packageName = nonempty(provenanceHint?.packageName)
            ?? nonempty(frontmatter.packageName)
            ?? nonempty(manifest?.name)
            ?? aliasTarget.map(humanized)
            ?? inferredPackageName(sourceURL: sourceURL, packageRoot: packageRoot, fallback: name)
        let resourceDates = try? entryURL.resourceValues(forKeys: [
            .contentModificationDateKey,
            .creationDateKey
        ])
        let modifiedAt = resourceDates?.contentModificationDate
        let installationDateEvidence: InstallationDateEvidence
        if let installedAt = provenanceHint?.installedAt {
            installationDateEvidence = InstallationDateEvidence(
                installedAt: installedAt,
                source: .installerReceipt,
                confidence: provenanceHint?.contentHash == nil ? .likely : .verified
            )
        } else if let createdAt = resourceDates?.creationDate {
            installationDateEvidence = InstallationDateEvidence(
                installedAt: createdAt,
                source: .filesystemCreation,
                confidence: .possible
            )
        } else {
            installationDateEvidence = InstallationDateEvidence(
                installedAt: .now,
                source: .firstSeen,
                confidence: .possible
            )
        }
        let lexicalEntry = entryURL.standardizedFileURL
        let canonicalEntry = lexicalEntry.resolvingSymlinksInPath()
        let installationKey = "\(discoveryRoot.agent.rawValue)::\(lexicalEntry.path)"
        let installationID = InstallationID(rawValue: "installation-\(StableHasher.sha256(installationKey))")
        let contentHash = StableHasher.sha256(data)
        let localState: LocalState
        if let git, let trackedHash = GitRepositoryInspector.trackedContentHash(for: entryURL, in: git) {
            localState = trackedHash == contentHash ? .clean : .modified
        } else {
            localState = .unverified
        }
        let interfaceMetadata = AgentInterfaceMetadataReader.read(from: entryDirectory)
        let declaredSkillArtworkPath = interfaceMetadata?.smallIconPath
            ?? interfaceMetadata?.largeIconPath
            ?? frontmatter.artworkPath
        let skillArtwork = ArtworkResolver.resolveSkillArtwork(
            skillRoot: entryDirectory,
            packageRoot: packageRoot,
            skillName: name,
            interfaceMetadata: interfaceMetadata,
            frontmatterPath: frontmatter.artworkPath,
            cache: artworkCache
        ).map { artworkWithRevision($0, revision: git?.revision) }
            ?? remoteArtworkReference(
                declaredPath: declaredSkillArtworkPath,
                scope: .skill,
                relativeTo: entryDirectory,
                git: git
            )
        let packageArtwork = ArtworkResolver.resolvePackageArtwork(
            packageRoot: packageRoot,
            declaredPath: manifest?.artworkPath,
            cache: artworkCache
        ).map { artworkWithRevision($0, revision: git?.revision) }
            ?? remoteArtworkReference(
                declaredPath: manifest?.artworkPath,
                scope: .package,
                relativeTo: packageRoot,
                git: git
            )

        return DiscoveredSkill(
            packageID: packageID,
            packageName: packageName,
            packageAuthor: author,
            packageSourceURL: sourceURL,
            packageWebsiteURL: manifest?.websiteURL ?? frontmatter.websiteURL ?? sourceURL,
            packageArtwork: packageArtwork,
            skillID: skillID,
            name: name,
            summary: summary,
            author: author,
            websiteURL: websiteURL,
            sourceURL: sourceURL,
            skillArtwork: skillArtwork,
            markdownSource: markdown,
            installation: SkillInstallation(
                id: installationID,
                agent: discoveryRoot.agent,
                entryURL: lexicalEntry,
                rootURL: packageRoot.standardizedFileURL,
                resolvedEntryURL: canonicalEntry,
                markdownSource: markdown,
                observedModifiedAt: modifiedAt,
                managedUpdatedAt: provenanceHint?.updatedAt ?? provenanceHint?.installedAt,
                installationDateEvidence: installationDateEvidence,
                contentHash: contentHash,
                localState: localState
            ),
            contentIdentityKey: contentIdentityKey,
            aliasTarget: aliasTarget,
            provenanceHint: provenanceHint,
            sourceConfidence: sourceConfidence,
            sourceRevision: provenanceHint?.sourceRevision ?? git?.revision
        )
    }

    private static func directoryBoundary(for rootURL: URL) -> URL {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            return rootURL.deletingLastPathComponent().standardizedFileURL
        }
        return rootURL.standardizedFileURL
    }

    private static func structuralPackageRoot(entryURL: URL, discoveryRoot: URL) -> URL {
        let rootComponents = discoveryRoot.standardizedFileURL.pathComponents
        let entryComponents = entryURL.standardizedFileURL.pathComponents
        guard
            entryComponents.count > rootComponents.count,
            Array(entryComponents.prefix(rootComponents.count)) == rootComponents
        else { return entryURL.deletingLastPathComponent() }

        let relative = Array(entryComponents.dropFirst(rootComponents.count))
        guard relative.count > 1 else { return discoveryRoot }
        return discoveryRoot.appending(path: relative[0], directoryHint: .isDirectory)
    }

    private static func packageIdentityKey(
        sourceURL: URL?,
        sourceConfidence: ProvenanceConfidence?,
        packageMembershipKey: String?,
        aliasTarget: String?,
        contentIdentityKey: String,
        manifest: PackageManifestMetadata?,
        git: GitRepositoryMetadata?,
        packageRoot: URL,
        entryURL: URL,
        discoveryRoot: URL,
        agent: AgentKind
    ) -> String {
        if let aliasTarget {
            return "alias-package:\(aliasTarget)"
        }
        if let packageMembershipKey {
            return packageMembershipKey
        }
        if let sourceURL {
            var key = sourceConfidence == .verified
                ? "source:\(RepositoryURLNormalizer.stableString(sourceURL))"
                : "declared-source:\(agent.rawValue):\(RepositoryURLNormalizer.stableString(sourceURL))"
            if let git, packageRoot != git.rootURL, let subdirectory = relativePath(packageRoot, to: git.rootURL) {
                key += "::subdirectory:\(subdirectory)"
            }
            return key
        }

        if let manifestID = nonempty(manifest?.stableID), isNamespaced(manifestID) {
            return "manifest:\(manifestID)"
        }

        var localPath = packageRoot.standardizedFileURL.resolvingSymlinksInPath().path
        if packageRoot.standardizedFileURL == discoveryRoot.standardizedFileURL,
           entryURL.deletingLastPathComponent().standardizedFileURL == discoveryRoot.standardizedFileURL {
            localPath = entryURL.standardizedFileURL.resolvingSymlinksInPath().path
        }
        _ = contentIdentityKey
        return "local:\(agent.rawValue):\(localPath)"
    }

    private static func skillIdentityKey(
        explicitID: String?,
        contentIdentityKey: String,
        entryURL: URL,
        packageRoot: URL,
        discoveryRoot: URL,
        hasDeclaredPackageBoundary: Bool
    ) -> String {
        if let explicitID = nonempty(explicitID) {
            return "declared:\(explicitID)"
        }

        if !contentIdentityKey.isEmpty {
            return "content:\(contentIdentityKey)"
        }

        let filename = entryURL.lastPathComponent.lowercased()
        if filename == "skill.md" {
            let entryDirectory = entryURL.deletingLastPathComponent()
            let identityRoot = !hasDeclaredPackageBoundary && entryDirectory.standardizedFileURL == packageRoot.standardizedFileURL
                ? discoveryRoot
                : packageRoot
            let relativeDirectory = relativePath(entryDirectory, to: identityRoot) ?? ""
            return relativeDirectory.isEmpty ? "skill" : relativeDirectory
        }

        let relative = relativePath(entryURL, to: packageRoot) ?? entryURL.lastPathComponent
        return relative.replacingOccurrences(of: ".agent.claude.md", with: "", options: [.caseInsensitive])
    }

    private static func relativePath(_ url: URL, to ancestor: URL) -> String? {
        let path = url.standardizedFileURL.pathComponents
        let ancestorPath = ancestor.standardizedFileURL.pathComponents
        guard path.count >= ancestorPath.count, Array(path.prefix(ancestorPath.count)) == ancestorPath else {
            return nil
        }
        return path.dropFirst(ancestorPath.count).joined(separator: "/")
    }

    private static func artworkWithRevision(
        _ artwork: ArtworkReference,
        revision: String?
    ) -> ArtworkReference {
        ArtworkReference(
            scope: artwork.scope,
            declaredPath: artwork.declaredPath,
            localURL: artwork.localURL,
            remoteURL: artwork.remoteURL,
            sourceRevision: revision,
            contentHash: artwork.contentHash,
            confidence: artwork.confidence
        )
    }

    private static func remoteArtworkReference(
        declaredPath: String?,
        scope: ArtworkScope,
        relativeTo root: URL,
        git: GitRepositoryMetadata?
    ) -> ArtworkReference? {
        guard
            let declaredPath,
            let git,
            let revision = git.revision,
            let sourceURL = git.sourceURL,
            sourceURL.host?.lowercased() == "github.com"
        else { return nil }
        let cleanPath = declaredPath.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "./", with: "", options: [.anchored])
        guard !cleanPath.isEmpty, !cleanPath.split(separator: "/").contains("..") else { return nil }
        let repositoryPath = sourceURL.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .replacingOccurrences(of: ".git", with: "", options: [.anchored, .backwards])
        let rootPath = relativePath(root, to: git.rootURL)
        let assetPath = [rootPath, cleanPath].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: "/")
        guard let remoteURL = URL(string: "https://raw.githubusercontent.com/\(repositoryPath)/\(revision)/\(assetPath)") else {
            return nil
        }
        return ArtworkReference(
            scope: scope,
            declaredPath: cleanPath,
            remoteURL: remoteURL,
            sourceRevision: revision,
            confidence: .verified
        )
    }

    private static func inferredSkillName(_ entryURL: URL) -> String {
        if entryURL.lastPathComponent.lowercased() == "skill.md" {
            return humanized(entryURL.deletingLastPathComponent().lastPathComponent)
        }
        let basename = entryURL.lastPathComponent.replacingOccurrences(
            of: ".agent.claude.md",
            with: "",
            options: [.caseInsensitive]
        )
        return humanized(basename.isEmpty ? entryURL.deletingLastPathComponent().lastPathComponent : basename)
    }

    private static func inferredSummary(_ markdown: String) -> String {
        var lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").split(
            separator: "\n",
            omittingEmptySubsequences: false
        ).map(String.init)

        if lines.first?.trimmingCharacters(in: .whitespaces) == "---",
           let closingIndex = lines.dropFirst().firstIndex(where: {
               let line = $0.trimmingCharacters(in: .whitespaces)
               return line == "---" || line == "..."
           }) {
            lines.removeFirst(closingIndex + 1)
        }

        var paragraph = [String]()
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                if !paragraph.isEmpty { break }
                continue
            }
            if trimmed.hasPrefix("#") || trimmed.hasPrefix("```") { continue }
            paragraph.append(trimmed)
        }
        return paragraph.joined(separator: " ")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "`", with: "")
    }

    private static func inferredPackageName(sourceURL: URL?, packageRoot: URL, fallback: String) -> String {
        if let sourceName = sourceURL?.lastPathComponent, !sourceName.isEmpty {
            return humanized(sourceName)
        }
        let rootName = packageRoot.lastPathComponent
        return rootName.isEmpty ? fallback : humanized(rootName)
    }

    private static func inferredAuthor(_ sourceURL: URL?) -> String? {
        guard sourceURL?.host?.lowercased() == "github.com" else { return nil }
        return sourceURL?.pathComponents.dropFirst().first
    }

    private static func humanized(_ value: String) -> String {
        value.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private static func isNamespaced(_ value: String) -> Bool {
        value.contains(".") || value.contains("/") || value.contains(":")
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func contentIdentity(name: String, markdown: String) -> String {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let body = markdownBody(markdown)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(normalizedName)::\(StableHasher.sha256(body))"
    }

    private static func markdownBody(_ markdown: String) -> String {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return markdown }
        guard let closing = lines.dropFirst().firstIndex(where: {
            let value = $0.trimmingCharacters(in: .whitespaces)
            return value == "---" || value == "..."
        }) else { return markdown }
        return lines.dropFirst(closing + 1).joined(separator: "\n")
    }
}
