import Foundation
import Testing
@testable import SpellbookCore

@Suite("Library projection")
struct LibraryProjectionTests {
    @Test("A one-skill package is flattened by default")
    func flattensSingleSkillPackage() {
        let fixture = makeFixture(skillCount: 1)
        let projection = LibraryProjection(
            snapshot: fixture,
            mode: .skillFirst,
            searchText: "",
            alwaysShowsPackageGroups: false
        )

        #expect(projection.nodes.count == 1)
        guard case .skill = projection.nodes[0] else {
            Issue.record("Expected a flattened skill")
            return
        }
    }

    @Test("A one-skill package can be shown explicitly")
    func showsSingleSkillPackageWhenRequested() {
        let fixture = makeFixture(skillCount: 1)
        let projection = LibraryProjection(
            snapshot: fixture,
            mode: .skillFirst,
            searchText: "",
            alwaysShowsPackageGroups: true
        )

        #expect(projection.nodes.count == 1)
        guard case .group(let group) = projection.nodes[0] else {
            Issue.record("Expected a package group")
            return
        }
        #expect(group.kind == .package)
        #expect(group.skills.count == 1)
    }

    @Test("A multi-skill package remains grouped")
    func groupsMultiSkillPackage() {
        let fixture = makeFixture(skillCount: 5)
        let projection = LibraryProjection(
            snapshot: fixture,
            mode: .skillFirst,
            searchText: "",
            alwaysShowsPackageGroups: false
        )

        guard case .group(let group) = projection.nodes[0] else {
            Issue.record("Expected a package group")
            return
        }
        #expect(group.skills.count == 5)
    }

    @Test("Package groups omit skill-specific artwork")
    func packageGroupsOmitSkillArtwork() {
        let packageID = PackageID(rawValue: "package.artwork")
        let firstID = SkillID(rawValue: "skill.artwork")
        let secondID = SkillID(rawValue: "skill.plain")
        let skillArtwork = ArtworkReference(
            scope: .skill,
            declaredPath: "icon.png",
            remoteURL: URL(string: "https://example.com/icon.png"),
            confidence: .verified
        )
        let artworkSkill = SkillRecord(
            id: firstID,
            packageID: packageID,
            name: "Artwork",
            summary: "Fixture",
            artwork: skillArtwork,
            markdownSource: "# Artwork",
            installations: [makeInstallation(agent: .codex, suffix: "artwork")]
        )
        let plainSkill = makeSkill(
            id: secondID,
            packageID: packageID,
            name: "Plain",
            installations: [makeInstallation(agent: .codex, suffix: "plain")]
        )
        let snapshot = LibrarySnapshot(
            packages: [SkillPackageRecord(
                id: packageID,
                name: "Artwork Package",
                skillIDs: [firstID, secondID]
            )],
            skills: [artworkSkill, plainSkill],
            scannedAt: .now
        )

        let projection = LibraryProjection(
            snapshot: snapshot,
            mode: .skillFirst,
            searchText: "",
            alwaysShowsPackageGroups: false
        )

        guard case .group(let group) = projection.nodes[0] else {
            Issue.record("Expected a package group")
            return
        }
        #expect(group.thumbnail?.sourceKind == .generatedFallback)
        #expect(group.skills.first { $0.skillID == firstID }?.thumbnail.sourceKind == .skillIcon)
    }

    @Test("Agent-first mode keeps independent installations")
    func groupsIndependentInstallationsByAgent() {
        let fixture = makeMultiAgentFixture()
        let projection = LibraryProjection(
            snapshot: fixture,
            mode: .agentFirst,
            searchText: "",
            alwaysShowsPackageGroups: false
        )

        #expect(projection.nodes.count == 3)
        for node in projection.nodes {
            guard case .group(let group) = node else {
                Issue.record("Expected agent groups")
                return
            }
            #expect(group.kind == .agent)
            #expect(group.skills.count == 1)
            #expect(group.skills[0].id.installationID != nil)
        }
    }

    @Test("Skill-first provisionally folds compatible same-name agent copies")
    func provisionallyFoldsCompatibleCopies() {
        let skills = AgentKind.allCases.enumerated().map { index, agent in
            let packageID = PackageID(rawValue: "package.\(agent.rawValue)")
            return makeSkill(
                id: SkillID(rawValue: "skill.\(agent.rawValue)"),
                packageID: packageID,
                name: "Drill",
                installations: [makeInstallation(agent: agent, suffix: "\(index)")]
            )
        }
        let snapshot = LibrarySnapshot(
            packages: skills.map {
                SkillPackageRecord(id: $0.packageID, name: "Drill", skillIDs: [$0.id])
            },
            skills: skills,
            scannedAt: .now
        )

        let projection = LibraryProjection(
            snapshot: snapshot,
            mode: .skillFirst,
            searchText: "",
            alwaysShowsPackageGroups: false
        )

        #expect(projection.logicalSkillCount == 1)
        guard case .skill(let skill) = projection.nodes[0] else {
            Issue.record("Expected one folded skill")
            return
        }
        #expect(skill.isProvisionalCluster)
        #expect(skill.memberSkillIDs.count == 3)
    }

    @Test("A rejected cluster remains split until its evidence changes")
    func honorsRejectedClusterFingerprint() {
        let skills = [
            makeSkill(
                id: SkillID(rawValue: "skill.claude"),
                packageID: PackageID(rawValue: "package.claude"),
                name: "Drill",
                installations: [makeInstallation(agent: .claude, suffix: "a")]
            ),
            makeSkill(
                id: SkillID(rawValue: "skill.cursor"),
                packageID: PackageID(rawValue: "package.cursor"),
                name: "Drill",
                installations: [makeInstallation(agent: .cursor, suffix: "b")]
            )
        ]
        let snapshot = LibrarySnapshot(
            packages: skills.map { SkillPackageRecord(id: $0.packageID, name: "Drill", skillIDs: [$0.id]) },
            skills: skills,
            scannedAt: .now
        )
        let fingerprint = LibraryProjection.clusterFingerprint(skills)

        let projection = LibraryProjection(
            snapshot: snapshot,
            mode: .skillFirst,
            searchText: "",
            alwaysShowsPackageGroups: false,
            rejectedClusterFingerprints: [fingerprint]
        )

        #expect(projection.logicalSkillCount == 2)
    }

    @Test("A second root for one agent stays separate without blocking the cross-agent fold")
    func keepsSameAgentCopiesSeparateWhileFoldingOtherAgents() {
        let agents: [AgentKind] = [.claude, .cursor, .codex, .codex]
        let skills = agents.enumerated().map { index, agent in
            let packageID = PackageID(rawValue: "package.\(index)")
            return makeSkill(
                id: SkillID(rawValue: "skill.\(index)"),
                packageID: packageID,
                name: "Interface Craft",
                installations: [makeInstallation(agent: agent, suffix: "\(index)")]
            )
        }
        let snapshot = LibrarySnapshot(
            packages: skills.map {
                SkillPackageRecord(id: $0.packageID, name: "Interface Craft", skillIDs: [$0.id])
            },
            skills: skills,
            scannedAt: .now
        )

        let projection = LibraryProjection(
            snapshot: snapshot,
            mode: .skillFirst,
            searchText: "",
            alwaysShowsPackageGroups: false
        )

        #expect(projection.logicalSkillCount == 2)
        let memberCounts = projection.nodes.compactMap { node -> Int? in
            guard case .skill(let skill) = node else { return nil }
            return skill.memberSkillIDs.count
        }.sorted()
        #expect(memberCounts == [1, 3])
    }

    @Test("Groups First partitions package groups ahead of flattened skills")
    func groupsFirstPartitionsWithoutChangingAlphabeticalOrder() {
        let group = makeFixture(skillCount: 2)
        let singlePackageID = PackageID(rawValue: "package.alpha")
        let single = makeSkill(
            id: SkillID(rawValue: "skill.alpha"), packageID: singlePackageID,
            name: "Alpha", installations: [makeInstallation(agent: .codex, suffix: "alpha")]
        )
        let snapshot = LibrarySnapshot(
            packages: group.packages + [SkillPackageRecord(id: singlePackageID, name: "Alpha", skillIDs: [single.id])],
            skills: group.skills + [single], scannedAt: .now
        )

        let projection = LibraryProjection(
            snapshot: snapshot, mode: .skillFirst, searchText: "",
            alwaysShowsPackageGroups: false, groupsFirst: true
        )

        guard case .group = projection.nodes.first else {
            Issue.record("Expected the multi-skill group first")
            return
        }
        guard case .skill(let skill) = projection.nodes.last else {
            Issue.record("Expected the flattened skill last")
            return
        }
        #expect(skill.name == "Alpha")
    }

    @Test("Installed-date sorting keeps unknown dates last")
    func sortsByInstalledEvidence() {
        let packageID = PackageID(rawValue: "package.dates")
        let old = makeSkill(id: SkillID(rawValue: "old"), packageID: packageID, name: "Old", installations: [
            makeInstallation(agent: .codex, suffix: "old", installedAt: Date(timeIntervalSince1970: 100))
        ])
        let recent = makeSkill(id: SkillID(rawValue: "new"), packageID: packageID, name: "Recent", installations: [
            makeInstallation(agent: .cursor, suffix: "new", installedAt: Date(timeIntervalSince1970: 200))
        ])
        let unknown = makeSkill(id: SkillID(rawValue: "unknown"), packageID: packageID, name: "Unknown", installations: [
            makeInstallation(agent: .claude, suffix: "unknown")
        ])
        let snapshot = LibrarySnapshot(
            packages: [SkillPackageRecord(id: packageID, name: "Dates", skillIDs: [old.id, recent.id, unknown.id])],
            skills: [old, recent, unknown], scannedAt: .now
        )
        let projection = LibraryProjection(
            snapshot: snapshot, mode: .skillFirst, searchText: "",
            alwaysShowsPackageGroups: false, sortMode: .newestInstalled
        )
        guard case .group(let group) = projection.nodes[0] else {
            Issue.record("Expected group")
            return
        }
        #expect(group.skills.map(\.name) == ["Recent", "Old", "Unknown"])
    }

    private func makeFixture(skillCount: Int) -> LibrarySnapshot {
        let packageID = PackageID(rawValue: "package.bench")
        let skills = (0..<skillCount).map { index in
            makeSkill(
                id: SkillID(rawValue: "skill.\(index)"),
                packageID: packageID,
                name: "Skill \(index)",
                installations: [makeInstallation(agent: .codex, suffix: "\(index)")]
            )
        }
        let package = SkillPackageRecord(
            id: packageID,
            name: "Bench",
            skillIDs: skills.map(\.id)
        )
        return LibrarySnapshot(packages: [package], skills: skills, scannedAt: .now)
    }

    private func makeMultiAgentFixture() -> LibrarySnapshot {
        let packageID = PackageID(rawValue: "package.shared")
        let skill = makeSkill(
            id: SkillID(rawValue: "skill.shared"),
            packageID: packageID,
            name: "Shared",
            installations: AgentKind.allCases.map { makeInstallation(agent: $0, suffix: $0.rawValue) }
        )
        return LibrarySnapshot(
            packages: [SkillPackageRecord(id: packageID, name: "Shared", skillIDs: [skill.id])],
            skills: [skill],
            scannedAt: .now
        )
    }

    private func makeSkill(
        id: SkillID,
        packageID: PackageID,
        name: String,
        installations: [SkillInstallation]
    ) -> SkillRecord {
        SkillRecord(
            id: id,
            packageID: packageID,
            name: name,
            summary: "Fixture",
            markdownSource: "# \(name)",
            installations: installations
        )
    }

    private func makeInstallation(
        agent: AgentKind,
        suffix: String,
        state: LocalState = .unverified,
        updateAvailable: Bool = false,
        installedAt: Date? = nil
    ) -> SkillInstallation {
        let url = URL(filePath: "/tmp/\(agent.rawValue)/\(suffix)/SKILL.md")
        return SkillInstallation(
            id: InstallationID(rawValue: "\(agent.rawValue).\(suffix)"),
            agent: agent,
            entryURL: url,
            rootURL: url.deletingLastPathComponent(),
            installationDateEvidence: installedAt.map {
                InstallationDateEvidence(installedAt: $0, source: .installerReceipt, confidence: .verified)
            },
            contentHash: suffix,
            localState: state,
            updateAvailable: updateAvailable
        )
    }
}
