import Foundation
import SpellbookCore

struct IdentityReconciliation: Sendable {
    let snapshot: LibrarySnapshot
    let aliases: [IdentityAlias]
}

enum IdentityReconciler {
    static func reconcile(
        discovered: LibrarySnapshot,
        with existing: LibrarySnapshot?
    ) -> IdentityReconciliation {
        guard let existing else {
            return IdentityReconciliation(snapshot: discovered, aliases: [])
        }

        let previousByPath = Dictionary(
            uniqueKeysWithValues: existing.skills.flatMap { skill in
                skill.installations.map { ($0.entryURL.standardizedFileURL.path, skill) }
            }
        )
        let previousInstallationByPath = Dictionary(
            uniqueKeysWithValues: existing.skills.flatMap { skill in
                skill.installations.map { ($0.entryURL.standardizedFileURL.path, $0) }
            }
        )
        var skillIDMap = [SkillID: SkillID]()
        var packageIDMap = [PackageID: PackageID]()
        var claimedSkillIDs = Set<SkillID>()
        var claimedPackageIDs = Set<PackageID>()
        var aliases = [IdentityAlias]()

        for skill in discovered.skills {
            let previous = skill.installations.compactMap {
                previousByPath[$0.entryURL.standardizedFileURL.path]
            }
            let previousSkillIDs = Set(previous.map(\.id)).sorted { $0.rawValue < $1.rawValue }
            let survivingSkillID = uniqueSkillID(
                candidates: previousSkillIDs + [skill.id],
                claimed: claimedSkillIDs,
                seed: skill.installations.map { $0.entryURL.path }.sorted().joined(separator: "|")
            )
            claimedSkillIDs.insert(survivingSkillID)
            skillIDMap[skill.id] = survivingSkillID
            aliases.append(contentsOf: previousSkillIDs.filter {
                $0 != survivingSkillID && !claimedSkillIDs.contains($0)
            }.map {
                IdentityAlias(previousID: $0.rawValue, survivingID: survivingSkillID.rawValue, kind: "skill")
            })
            if skill.id != survivingSkillID, previousSkillIDs.isEmpty {
                aliases.append(IdentityAlias(
                    previousID: skill.id.rawValue,
                    survivingID: survivingSkillID.rawValue,
                    kind: "skill"
                ))
            }

            if packageIDMap[skill.packageID] == nil {
                let previousPackageIDs = Set(previous.map(\.packageID)).sorted { $0.rawValue < $1.rawValue }
                let survivingPackageID = uniquePackageID(
                    candidates: previousPackageIDs + [skill.packageID],
                    claimed: claimedPackageIDs,
                    seed: skill.packageID.rawValue + "::" + skill.name
                )
                claimedPackageIDs.insert(survivingPackageID)
                packageIDMap[skill.packageID] = survivingPackageID
                aliases.append(contentsOf: previousPackageIDs.filter {
                    $0 != survivingPackageID && !claimedPackageIDs.contains($0)
                }.map {
                    IdentityAlias(previousID: $0.rawValue, survivingID: survivingPackageID.rawValue, kind: "package")
                })
            }
        }

        let reconciledSkills = discovered.skills.map { skill in
            SkillRecord(
                id: skillIDMap[skill.id] ?? skill.id,
                packageID: packageIDMap[skill.packageID] ?? skill.packageID,
                name: skill.name,
                summary: skill.summary,
                author: skill.author,
                websiteURL: skill.websiteURL,
                sourceURL: skill.sourceURL,
                artwork: skill.artwork,
                markdownSource: skill.markdownSource,
                installations: skill.installations.map { installation in
                    guard let previous = previousInstallationByPath[
                        installation.entryURL.standardizedFileURL.path
                    ] else { return installation }
                    return installation.settingInstallationDateEvidence(
                        preferredInstallationDate(
                            installation.installationDateEvidence,
                            previous.installationDateEvidence
                        )
                    )
                }
            )
        }
        let reconciledPackages = discovered.packages.map { package in
            SkillPackageRecord(
                id: packageIDMap[package.id] ?? package.id,
                name: package.name,
                author: package.author,
                sourceURL: package.sourceURL,
                websiteURL: package.websiteURL,
                artwork: package.artwork,
                skillIDs: package.skillIDs.map { skillIDMap[$0] ?? $0 }
            )
        }

        return IdentityReconciliation(
            snapshot: LibrarySnapshot(
                packages: reconciledPackages,
                skills: reconciledSkills,
                scannedAt: discovered.scannedAt
            ),
            aliases: aliases.uniqued()
        )
    }

    private static func preferredInstallationDate(
        _ discovered: InstallationDateEvidence?,
        _ existing: InstallationDateEvidence?
    ) -> InstallationDateEvidence? {
        guard let existing else { return discovered }
        guard let discovered else { return existing }
        let rank: (InstallationDateEvidence) -> Int = { evidence in
            switch evidence.source {
            case .installerReceipt: 4
            case .spellbookOperation: 3
            case .filesystemCreation: 2
            case .firstSeen: 1
            }
        }
        if rank(existing) > rank(discovered) { return existing }
        if rank(existing) < rank(discovered) { return discovered }
        if existing.source == .firstSeen {
            return existing.installedAt <= discovered.installedAt ? existing : discovered
        }
        return discovered
    }

    private static func uniqueSkillID(
        candidates: [SkillID],
        claimed: Set<SkillID>,
        seed: String
    ) -> SkillID {
        if let candidate = candidates.first(where: { !claimed.contains($0) }) { return candidate }
        var suffix = 0
        while true {
            let candidate = SkillID(rawValue: "skill-\(StableHasher.sha256("\(seed)::\(suffix)"))")
            if !claimed.contains(candidate) { return candidate }
            suffix += 1
        }
    }

    private static func uniquePackageID(
        candidates: [PackageID],
        claimed: Set<PackageID>,
        seed: String
    ) -> PackageID {
        if let candidate = candidates.first(where: { !claimed.contains($0) }) { return candidate }
        var suffix = 0
        while true {
            let candidate = PackageID(rawValue: "package-\(StableHasher.sha256("\(seed)::\(suffix)"))")
            if !claimed.contains(candidate) { return candidate }
            suffix += 1
        }
    }
}

private extension Array where Element == IdentityAlias {
    func uniqued() -> [IdentityAlias] {
        var seen = Set<String>()
        return filter { seen.insert($0.id).inserted }
    }
}
