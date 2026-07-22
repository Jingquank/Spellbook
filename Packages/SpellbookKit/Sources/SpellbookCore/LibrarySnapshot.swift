import Foundation

public struct LibrarySnapshot: Equatable, Codable, Sendable {
    public let packages: [SkillPackageRecord]
    public let skills: [SkillRecord]
    public let scannedAt: Date?

    public static let empty = LibrarySnapshot(packages: [], skills: [], scannedAt: nil)

    public init(
        packages: [SkillPackageRecord],
        skills: [SkillRecord],
        scannedAt: Date?
    ) {
        self.packages = packages
        self.skills = skills
        self.scannedAt = scannedAt
    }

    public func skill(id: SkillID) -> SkillRecord? {
        skills.first { $0.id == id }
    }

    public func package(id: PackageID) -> SkillPackageRecord? {
        packages.first { $0.id == id }
    }

    public func settingUpdateAvailability(for packageIDs: Set<PackageID>) -> LibrarySnapshot {
        LibrarySnapshot(
            packages: packages,
            skills: skills.map { skill in
                skill.settingUpdateAvailable(packageIDs.contains(skill.packageID))
            },
            scannedAt: scannedAt
        )
    }

    public func settingUpdateAvailability(for updates: [PackageUpdate]) -> LibrarySnapshot {
        LibrarySnapshot(
            packages: packages,
            skills: skills.map { skill in
                let matching = updates.filter { $0.packageIDs.contains(skill.packageID) }
                let installations = skill.installations.map { installation in
                    let available = matching.contains { update in
                        update.targetAgent == nil || update.targetAgent == installation.agent
                    }
                    return installation.settingUpdateAvailable(available)
                }
                return skill.replacingInstallations(installations)
            },
            scannedAt: scannedAt
        )
    }

    public func replacingRoots(
        _ roots: [DiscoveryRootRecord],
        with partial: LibrarySnapshot
    ) -> LibrarySnapshot {
        let retainedSkillPairs: [(SkillID, SkillRecord)] = skills.compactMap { skill in
            let installations = skill.installations.filter { installation in
                !roots.contains { root in
                    root.agent == installation.agent && installation.entryURL.isDescendant(of: root.url)
                }
            }
            guard !installations.isEmpty else { return nil }
            return (skill.id, skill.replacingInstallations(installations))
        }
        var skillsByID: [SkillID: SkillRecord] = Dictionary(
            uniqueKeysWithValues: retainedSkillPairs
        )

        for partialSkill in partial.skills {
            if let existing = skillsByID[partialSkill.id] {
                let merged = (existing.installations + partialSkill.installations)
                    .uniqued(on: \.id)
                    .sorted { lhs, rhs in
                        if lhs.agent != rhs.agent { return lhs.agent.rawValue < rhs.agent.rawValue }
                        return lhs.entryURL.path < rhs.entryURL.path
                    }
                skillsByID[partialSkill.id] = partialSkill.replacingInstallations(merged)
            } else {
                skillsByID[partialSkill.id] = partialSkill
            }
        }

        let resultingSkills = skillsByID.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        let groupedSkills: [PackageID: [SkillRecord]] = Dictionary(
            grouping: resultingSkills,
            by: { $0.packageID }
        )
        let packageSkillIDs: [PackageID: [SkillID]] = groupedSkills.mapValues { skills in
            skills.map(\.id).sorted { $0.rawValue < $1.rawValue }
        }
        var packagesByID = Dictionary(uniqueKeysWithValues: packages.map { ($0.id, $0) })
        for package in partial.packages { packagesByID[package.id] = package }
        let resultingPackages = packageSkillIDs.compactMap { packageID, skillIDs in
            packagesByID[packageID]?.replacingSkillIDs(skillIDs)
        }.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }

        return LibrarySnapshot(
            packages: resultingPackages,
            skills: resultingSkills,
            scannedAt: partial.scannedAt
        )
    }

    public func projectingRoots(
        _ roots: [DiscoveryRootRecord],
        localState: LocalState,
        scannedAt: Date
    ) -> LibrarySnapshot {
        let projectedSkills = skills.compactMap { skill -> SkillRecord? in
            let installations = skill.installations.compactMap { installation -> SkillInstallation? in
                guard roots.contains(where: { root in
                    root.agent == installation.agent && installation.entryURL.isDescendant(of: root.url)
                }) else { return nil }
                return installation.settingLocalState(localState)
            }
            guard !installations.isEmpty else { return nil }
            return skill.replacingInstallations(installations)
        }
        let projectedSkillIDs = Set(projectedSkills.map(\.id))
        let projectedPackages = packages.compactMap { package -> SkillPackageRecord? in
            let skillIDs = package.skillIDs.filter(projectedSkillIDs.contains)
            guard !skillIDs.isEmpty else { return nil }
            return package.replacingSkillIDs(skillIDs)
        }
        return LibrarySnapshot(
            packages: projectedPackages,
            skills: projectedSkills,
            scannedAt: scannedAt
        )
    }

    public func applyingSourceConnections(
        _ connections: [SourceConnection]
    ) -> LibrarySnapshot {
        let byPackageID = Dictionary(uniqueKeysWithValues: connections.map { ($0.packageID, $0) })
        return LibrarySnapshot(
            packages: packages.map { package in
                guard let connection = byPackageID[package.id] else { return package }
                return package.settingSourceURL(connection.sourceURL)
            },
            skills: skills.map { skill in
                guard let connection = byPackageID[skill.packageID] else { return skill }
                return skill.settingSourceURL(connection.sourceURL)
            },
            scannedAt: scannedAt
        )
    }
}

private extension URL {
    func isDescendant(of ancestor: URL) -> Bool {
        let components = standardizedFileURL.pathComponents
        let ancestorComponents = ancestor.standardizedFileURL.pathComponents
        return components.count >= ancestorComponents.count
            && Array(components.prefix(ancestorComponents.count)) == ancestorComponents
    }
}

private extension Array {
    func uniqued<Key: Hashable>(on keyPath: KeyPath<Element, Key>) -> [Element] {
        var seen = Set<Key>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}
