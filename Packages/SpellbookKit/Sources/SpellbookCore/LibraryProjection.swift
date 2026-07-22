import Foundation

public struct LibraryProjection: Equatable, Sendable {
    public let nodes: [LibraryNode]

    public var logicalSkillCount: Int {
        nodes.reduce(0) { count, node in
            switch node {
            case .skill: count + 1
            case .group(let group): count + group.skills.count
            }
        }
    }

    public init(
        snapshot: LibrarySnapshot,
        mode: LibraryViewMode,
        searchText: String,
        alwaysShowsPackageGroups: Bool,
        matchingSkillIDs: Set<SkillID>? = nil,
        verifiedSourceByPackage: [PackageID: URL] = [:],
        rejectedClusterFingerprints: Set<String> = [],
        sortMode: SidebarSortMode = .alphabeticalAscending,
        groupsFirst: Bool = false,
        artworkCategoryByPackage: [PackageID: PackageArtworkCategory] = [:],
        artworkUploadsByPackage: [PackageID: PackageArtworkUpload] = [:],
        artworkEvidenceByPackage: [PackageID: [PackageArtworkEvidence]] = [:]
    ) {
        let allSkills = snapshot.skills
            .uniqued(on: \.id)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        let visibleSkillIDs = Set(allSkills.filter { skill in
            if searchText.isEmpty { return true }
            if let matchingSkillIDs { return matchingSkillIDs.contains(skill.id) }
            return skill.searchText.localizedStandardContains(searchText)
        }.map(\.id))

        nodes = switch mode {
        case .skillFirst:
            Self.skillFirstNodes(
                skills: allSkills,
                packages: snapshot.packages,
                alwaysShowsPackageGroups: alwaysShowsPackageGroups,
                visibleSkillIDs: visibleSkillIDs,
                verifiedSourceByPackage: verifiedSourceByPackage,
                rejectedClusterFingerprints: rejectedClusterFingerprints,
                sortMode: sortMode,
                groupsFirst: groupsFirst,
                artworkCategoryByPackage: artworkCategoryByPackage,
                artworkUploadsByPackage: artworkUploadsByPackage,
                artworkEvidenceByPackage: artworkEvidenceByPackage
            )
        case .agentFirst:
            Self.agentFirstNodes(
                skills: allSkills.filter { visibleSkillIDs.contains($0.id) },
                packages: snapshot.packages,
                sortMode: sortMode,
                artworkCategoryByPackage: artworkCategoryByPackage,
                artworkUploadsByPackage: artworkUploadsByPackage,
                artworkEvidenceByPackage: artworkEvidenceByPackage
            )
        }
    }

    private static func skillFirstNodes(
        skills: [SkillRecord],
        packages: [SkillPackageRecord],
        alwaysShowsPackageGroups: Bool,
        visibleSkillIDs: Set<SkillID>,
        verifiedSourceByPackage: [PackageID: URL],
        rejectedClusterFingerprints: Set<String>,
        sortMode: SidebarSortMode,
        groupsFirst: Bool,
        artworkCategoryByPackage: [PackageID: PackageArtworkCategory],
        artworkUploadsByPackage: [PackageID: PackageArtworkUpload],
        artworkEvidenceByPackage: [PackageID: [PackageArtworkEvidence]]
    ) -> [LibraryNode] {
        let skillsByID = Dictionary(skills.map { ($0.id, $0) }, uniquingKeysWith: { existing, _ in existing })
        var includedSkillIDs = Set<SkillID>()
        var nodes = [LibraryNode]()

        let clusters = provisionalClusters(
            in: skills,
            packages: packages,
            verifiedSourceByPackage: verifiedSourceByPackage,
            rejectedFingerprints: rejectedClusterFingerprints
        )
        let clusteredIDs = Set(clusters.flatMap { $0.map(\.id) })
        let clusterOwners: [(skills: [SkillRecord], packageID: PackageID?)] = clusters.map { cluster in
            let candidatePackages = Set(cluster.map(\.packageID)).compactMap { packageByID in
                packages.first { $0.id == packageByID }
            }.filter { $0.skillIDs.count > 1 }
            let owner = candidatePackages.sorted {
                if $0.skillIDs.count != $1.skillIDs.count { return $0.skillIDs.count > $1.skillIDs.count }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }.first
            return (cluster, owner?.id)
        }

        for package in packages.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) {
            let packageSkills = package.skillIDs.compactMap { skillsByID[$0] }
                .filter { !clusteredIDs.contains($0.id) && visibleSkillIDs.contains($0.id) }
            let ownedClusters = clusterOwners.filter { entry in
                entry.packageID == package.id
                    && !visibleSkillIDs.isDisjoint(with: entry.skills.map(\.id))
            }
            guard !packageSkills.isEmpty || !ownedClusters.isEmpty else { continue }
            includedSkillIDs.formUnion(packageSkills.map(\.id))
            includedSkillIDs.formUnion(ownedClusters.flatMap { $0.skills.map(\.id) })
            let category = artworkCategoryByPackage[package.id] ?? .generalUtility
            let upload = artworkUploadsByPackage[package.id]
            let evidence = artworkEvidenceByPackage[package.id] ?? []
            let isGroup = packageSkills.count + ownedClusters.count > 1 || alwaysShowsPackageGroups
            let projectedSkills = sorted(
                packageSkills.map {
                    projectedSkill(
                        $0,
                        thumbnail: SkillThumbnailResolver.resolveSkill(
                            package: package,
                            skill: $0,
                            upload: upload,
                            evidence: evidence,
                            category: category
                        )
                    )
                } + ownedClusters.map {
                    projectedCluster(
                        $0.skills,
                        thumbnail: SkillThumbnailResolver.resolvePackage(
                            package: package,
                            upload: upload,
                            evidence: evidence,
                            category: category
                        )
                    )
                },
                by: sortMode
            )

            if isGroup {
                nodes.append(.group(ProjectedGroup(
                    id: "package::\(package.id.rawValue)",
                    kind: .package,
                    packageID: package.id,
                    title: package.name,
                    thumbnail: SkillThumbnailResolver.resolvePackage(
                        package: package,
                        upload: upload,
                        evidence: evidence,
                        category: category
                    ),
                    skills: projectedSkills,
                    actionableStatus: projectedSkills.compactMap(\.actionableStatus).max(),
                    effectiveInstalledAt: projectedSkills.compactMap(\.effectiveInstalledAt).max(),
                    fallbackCategory: category
                )))
            } else if let onlySkill = projectedSkills.first {
                nodes.append(.skill(onlySkill))
            }
        }

        for entry in clusterOwners where entry.packageID == nil
            && !visibleSkillIDs.isDisjoint(with: entry.skills.map(\.id)) {
            nodes.append(.skill(projectedCluster(entry.skills)))
            includedSkillIDs.formUnion(entry.skills.map(\.id))
        }

        nodes.append(contentsOf: skills
            .filter { !includedSkillIDs.contains($0.id) && visibleSkillIDs.contains($0.id) }
            .map { .skill(projectedSkill($0)) })

        return sorted(nodes, by: sortMode, groupsFirst: groupsFirst)
    }

    private static func agentFirstNodes(
        skills: [SkillRecord],
        packages: [SkillPackageRecord],
        sortMode: SidebarSortMode,
        artworkCategoryByPackage: [PackageID: PackageArtworkCategory],
        artworkUploadsByPackage: [PackageID: PackageArtworkUpload],
        artworkEvidenceByPackage: [PackageID: [PackageArtworkEvidence]]
    ) -> [LibraryNode] {
        let packageByID = Dictionary(uniqueKeysWithValues: packages.map { ($0.id, $0) })
        return AgentKind.allCases.compactMap { agent in
            let projectedSkills = skills.compactMap { skill -> ProjectedSkill? in
                guard let installation = skill.installations.first(where: { $0.agent == agent }) else {
                    return nil
                }
                let package = packageByID[skill.packageID]
                let category = artworkCategoryByPackage[skill.packageID] ?? .generalUtility
                let evidence = artworkEvidenceByPackage[skill.packageID] ?? []
                return ProjectedSkill(
                    id: LibrarySelection(skillID: skill.id, installationID: installation.id),
                    skillID: skill.id,
                    packageID: skill.packageID,
                    name: skill.name,
                    summary: skill.summary,
                    thumbnail: SkillThumbnailResolver.resolveSkill(
                        package: package,
                        skill: skill,
                        upload: artworkUploadsByPackage[skill.packageID],
                        evidence: evidence,
                        category: category
                    ),
                    fallbackCategory: category,
                    effectiveInstalledAt: installation.installationDateEvidence?.installedAt,
                    actionableStatus: installation.actionableStatus
                )
            }
            guard !projectedSkills.isEmpty else { return nil }
            let orderedSkills = sorted(projectedSkills, by: sortMode)
            return .group(ProjectedGroup(
                id: "agent::\(agent.rawValue)",
                kind: .agent,
                title: agent.displayName,
                skills: orderedSkills,
                actionableStatus: orderedSkills.compactMap(\.actionableStatus).max(),
                effectiveInstalledAt: orderedSkills.compactMap(\.effectiveInstalledAt).max()
            ))
        }
    }

    private static func projectedSkill(
        _ skill: SkillRecord,
        thumbnail: SkillThumbnail? = nil,
        fallbackCategory: PackageArtworkCategory = .generalUtility
    ) -> ProjectedSkill {
        ProjectedSkill(
            id: LibrarySelection(skillID: skill.id),
            skillID: skill.id,
            packageID: skill.packageID,
            name: skill.name,
            summary: skill.summary,
            artwork: skill.artwork,
            thumbnail: thumbnail,
            fallbackCategory: fallbackCategory,
            effectiveInstalledAt: skill.installations.compactMap {
                $0.installationDateEvidence?.installedAt
            }.max(),
            actionableStatus: skill.actionableStatus
        )
    }

    private static func projectedCluster(
        _ skills: [SkillRecord],
        thumbnail: SkillThumbnail? = nil,
        fallbackCategory: PackageArtworkCategory = .generalUtility
    ) -> ProjectedSkill {
        let ordered = skills.sorted { $0.id.rawValue < $1.id.rawValue }
        let primary = ordered[0]
        let status = ordered.compactMap(\.actionableStatus).max()
        return ProjectedSkill(
            id: LibrarySelection(skillID: primary.id),
            skillID: primary.id,
            packageID: primary.packageID,
            memberSkillIDs: ordered.map(\.id),
            name: primary.name,
            summary: ordered.first(where: { !$0.summary.isEmpty })?.summary ?? "",
            artwork: ordered.compactMap(\.artwork).first,
            thumbnail: thumbnail,
            fallbackCategory: fallbackCategory,
            effectiveInstalledAt: ordered.flatMap(\.installations).compactMap {
                $0.installationDateEvidence?.installedAt
            }.max(),
            actionableStatus: status,
            isProvisionalCluster: true
        )
    }

    private static func provisionalClusters(
        in skills: [SkillRecord],
        packages: [SkillPackageRecord],
        verifiedSourceByPackage: [PackageID: URL],
        rejectedFingerprints: Set<String>
    ) -> [[SkillRecord]] {
        let packageByID = Dictionary(uniqueKeysWithValues: packages.map { ($0.id, $0) })
        return Dictionary(grouping: skills, by: { normalized($0.name) }).values.flatMap { candidates in
            guard candidates.count > 1 else { return [[SkillRecord]]() }

            let authors = Set(candidates.compactMap { $0.author?.trimmedLowercase }.filter { !$0.isEmpty })
            guard authors.count <= 1 else { return [] }

            let verifiedSources = Set(candidates.compactMap { skill in
                verifiedSourceByPackage[skill.packageID]?.absoluteString.normalizedRepositoryString
            })
            guard verifiedSources.count <= 1 else { return [] }

            let packageNames = Set(candidates.compactMap { packageByID[$0.packageID]?.name.trimmedLowercase })
            let skillName = candidates[0].name.trimmedLowercase
            let meaningfulPackageNames = packageNames.filter {
                !isGenericPackageName($0) && normalized($0) != normalized(skillName)
            }
            guard meaningfulPackageNames.count <= 1 else { return [] }

            // A machine can expose more than one root for the same agent (for
            // example `.agents/skills` and `.codex/skills`). Keep those copies
            // distinct, while still folding one compatible copy from each
            // other agent. Deterministic rounds make the projection stable.
            let ordered = candidates.sorted { $0.id.rawValue < $1.id.rawValue }
            var clusters = [[SkillRecord]]()
            for candidate in ordered {
                let candidateAgents = Set(candidate.installations.map(\.agent))
                guard !candidateAgents.isEmpty else { continue }
                if let index = clusters.firstIndex(where: { cluster in
                    let clusterAgents = Set(cluster.flatMap { $0.installations.map(\.agent) })
                    return clusterAgents.isDisjoint(with: candidateAgents)
                }) {
                    clusters[index].append(candidate)
                } else {
                    clusters.append([candidate])
                }
            }

            return clusters.filter { cluster in
                guard cluster.count > 1 else { return false }
                return !rejectedFingerprints.contains(clusterFingerprint(cluster))
            }
        }
    }

    public static func clusterFingerprint(_ skills: [SkillRecord]) -> String {
        let evidence = skills.sorted { $0.id.rawValue < $1.id.rawValue }.map { skill in
            let installations = skill.installations.sorted { $0.id.rawValue < $1.id.rawValue }
                .map { "\($0.agent.rawValue):\($0.entryURL.path):\($0.contentHash)" }
                .joined(separator: "|")
            return "\(skill.id.rawValue)::\(installations)"
        }.joined(separator: "||")
        return evidence
    }

    private static func normalized(_ value: String) -> String {
        String(value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber })
    }

    private static func isGenericPackageName(_ value: String) -> Bool {
        let normalizedValue = normalized(value)
        return ["skill", "skills", "plugin", "package", "repository", "tools"].contains(normalizedValue)
    }

    private static func nodeTitle(_ node: LibraryNode) -> String {
        switch node {
        case .skill(let skill): skill.name
        case .group(let group): group.title
        }
    }

    private static func sorted(
        _ skills: [ProjectedSkill],
        by mode: SidebarSortMode
    ) -> [ProjectedSkill] {
        skills.sorted { lhs, rhs in
            compare(
                lhsName: lhs.name,
                lhsDate: lhs.effectiveInstalledAt,
                lhsID: lhs.id.id,
                rhsName: rhs.name,
                rhsDate: rhs.effectiveInstalledAt,
                rhsID: rhs.id.id,
                mode: mode
            )
        }
    }

    private static func sorted(
        _ nodes: [LibraryNode],
        by mode: SidebarSortMode,
        groupsFirst: Bool
    ) -> [LibraryNode] {
        nodes.sorted { lhs, rhs in
            if groupsFirst {
                let lhsGroup = if case .group = lhs { true } else { false }
                let rhsGroup = if case .group = rhs { true } else { false }
                if lhsGroup != rhsGroup { return lhsGroup }
            }
            return compare(
                lhsName: nodeTitle(lhs),
                lhsDate: nodeInstalledAt(lhs),
                lhsID: lhs.id,
                rhsName: nodeTitle(rhs),
                rhsDate: nodeInstalledAt(rhs),
                rhsID: rhs.id,
                mode: mode
            )
        }
    }

    private static func compare(
        lhsName: String,
        lhsDate: Date?,
        lhsID: String,
        rhsName: String,
        rhsDate: Date?,
        rhsID: String,
        mode: SidebarSortMode
    ) -> Bool {
        switch mode {
        case .alphabeticalAscending, .alphabeticalDescending:
            let order = lhsName.localizedStandardCompare(rhsName)
            if order != .orderedSame {
                return mode == .alphabeticalAscending ? order == .orderedAscending : order == .orderedDescending
            }
        case .newestInstalled, .oldestInstalled:
            if lhsDate == nil || rhsDate == nil {
                if lhsDate == nil, rhsDate != nil { return false }
                if lhsDate != nil, rhsDate == nil { return true }
            } else if lhsDate != rhsDate {
                return mode == .newestInstalled ? lhsDate! > rhsDate! : lhsDate! < rhsDate!
            }
            let order = lhsName.localizedStandardCompare(rhsName)
            if order != .orderedSame { return order == .orderedAscending }
        }
        return lhsID < rhsID
    }

    private static func nodeInstalledAt(_ node: LibraryNode) -> Date? {
        switch node {
        case .skill(let skill): skill.effectiveInstalledAt
        case .group(let group): group.effectiveInstalledAt
        }
    }

}

private extension String {
    var trimmedLowercase: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var normalizedRepositoryString: String {
        lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .replacingOccurrences(of: ".git", with: "")
    }
}

private extension Array {
    func uniqued<Key: Hashable>(on keyPath: KeyPath<Element, Key>) -> [Element] {
        var seen = Set<Key>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}
