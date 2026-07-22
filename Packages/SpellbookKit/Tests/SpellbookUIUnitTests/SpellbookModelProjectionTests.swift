import Foundation
import SpellbookCore
import SpellbookInfrastructure
import Testing
@testable import SpellbookUI

@Suite("Spellbook model projection caching")
@MainActor
struct SpellbookModelProjectionTests {
    @Test("Reuses a projection until one of its inputs changes")
    func reusesProjectionUntilAnInputChanges() async {
        let defaultsName = "SpellbookModelProjectionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }

        let model = SpellbookModel(
            scanner: StaticScanner(snapshot: Self.snapshot),
            manager: FileSystemSkillManager(
                roots: [],
                recoveryRoot: FileManager.default.temporaryDirectory
                    .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            ),
            defaults: defaults
        )
        await model.rescan()

        let computationCountAfterScan = model.projectionComputationCount
        for _ in 0..<50 {
            _ = model.projection.nodes.count
        }

        #expect(model.projectionComputationCount == computationCountAfterScan)

        model.searchText = "needle"
        _ = model.projection.nodes.count

        #expect(model.projectionComputationCount == computationCountAfterScan + 1)
    }

    @Test("A failed scan has one unambiguous terminal phase")
    func failedScanHasOneTerminalPhase() async {
        let defaultsName = "SpellbookModelProjectionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let model = SpellbookModel(
            scanner: FailingScanner(),
            manager: FileSystemSkillManager(
                roots: [],
                recoveryRoot: FileManager.default.temporaryDirectory
                    .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            ),
            defaults: defaults
        )

        await model.rescan()

        #expect(model.scanPhase == .failed(message: "Fixture scan failed"))
        #expect(!model.isScanning)
        #expect(model.scanError == "Fixture scan failed")
    }

    @Test("Selected skill uses the same thumbnail in sidebar and detail")
    func selectedSkillThumbnailIsConsistentAcrossContexts() async throws {
        let defaultsName = "SpellbookModelProjectionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let databaseURL = FileManager.default.temporaryDirectory
            .appending(path: "\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: databaseURL) }
        let catalog = try GRDBCatalogStore(databaseURL: databaseURL)

        let repositoryPackageID = PackageID(rawValue: "package.repository")
        let singlePackageID = PackageID(rawValue: "package.single")
        let repositorySkillID = SkillID(rawValue: "z-grill-repository")
        let singleSkillID = SkillID(rawValue: "a-grill-single")
        let supportingSkillID = SkillID(rawValue: "supporting-skill")
        let repositorySkill = SkillRecord(
            id: repositorySkillID,
            packageID: repositoryPackageID,
            name: "grill-me",
            summary: "A relentless interview",
            author: "creator",
            markdownSource: "# grill-me",
            installations: [Self.installation(agent: .codex, suffix: "repository")]
        )
        let singleSkill = SkillRecord(
            id: singleSkillID,
            packageID: singlePackageID,
            name: "grill-me",
            summary: "A relentless interview",
            author: "creator",
            markdownSource: "# grill-me",
            installations: [Self.installation(agent: .claude, suffix: "single")]
        )
        let supportingSkill = SkillRecord(
            id: supportingSkillID,
            packageID: repositoryPackageID,
            name: "supporting",
            summary: "Keeps the repository package grouped",
            markdownSource: "# supporting",
            installations: [Self.installation(agent: .codex, suffix: "supporting")]
        )
        let snapshot = LibrarySnapshot(
            packages: [
                SkillPackageRecord(
                    id: repositoryPackageID,
                    name: "Creator Skills",
                    skillIDs: [repositorySkillID, supportingSkillID]
                ),
                SkillPackageRecord(
                    id: singlePackageID,
                    name: "grill-me",
                    skillIDs: [singleSkillID]
                )
            ],
            skills: [repositorySkill, singleSkill, supportingSkill],
            scannedAt: .now
        )
        let ownerArtwork = ArtworkReference(
            scope: .package,
            declaredPath: "github-owner-avatar.png",
            remoteURL: URL(string: "https://avatars.githubusercontent.com/u/1"),
            confidence: .verified
        )
        try await catalog.savePackageArtworkEvidence([
            PackageArtworkEvidence(
                packageID: repositoryPackageID,
                sourceKind: .githubOwnerAvatar,
                artwork: ownerArtwork
            )
        ])
        let model = SpellbookModel(
            scanner: StaticScanner(snapshot: snapshot),
            manager: FileSystemSkillManager(
                roots: [],
                recoveryRoot: FileManager.default.temporaryDirectory
                    .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            ),
            catalog: catalog,
            defaults: defaults
        )
        await model.rescan()
        model.selection = LibrarySelection(skillID: singleSkillID)

        let sidebarThumbnail = try #require(model.selectedProjectedSkill?.thumbnail)
        let selectedSkill = try #require(model.selectedSkill)
        let detailThumbnail = model.thumbnail(for: selectedSkill)

        #expect(sidebarThumbnail == detailThumbnail)
    }

    @Test("Resolves a library of thumbnails within the interaction budget")
    func resolvesLibraryThumbnailsWithinInteractionBudget() async {
        let defaultsName = "SpellbookModelProjectionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }

        let repeatedText = String(repeating: "documentation artwork interface automation ", count: 24)
        let skills = (0..<100).map { index in
            SkillRecord(
                id: SkillID(rawValue: "thumbnail-skill-\(index)"),
                packageID: PackageID(rawValue: "thumbnail-package-\(index)"),
                name: "Thumbnail Skill \(index)",
                summary: "Exercises artwork category inference",
                markdownSource: repeatedText,
                installations: []
            )
        }
        let snapshot = LibrarySnapshot(
            packages: skills.map { skill in
                SkillPackageRecord(id: skill.packageID, name: skill.name, skillIDs: [skill.id])
            },
            skills: skills,
            scannedAt: .now
        )
        let model = SpellbookModel(
            scanner: StaticScanner(snapshot: snapshot),
            manager: FileSystemSkillManager(
                roots: [],
                recoveryRoot: FileManager.default.temporaryDirectory
                    .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            ),
            defaults: defaults
        )
        await model.rescan()
        let clock = ContinuousClock()

        let elapsed = clock.measure {
            for package in snapshot.packages {
                _ = model.thumbnail(for: package)
            }
        }

        print("Spellbook 100-package thumbnail resolution: \(elapsed)")
        #expect(elapsed < .milliseconds(250))
    }

    private static let snapshot: LibrarySnapshot = {
        let skillID = SkillID(rawValue: "needle-skill")
        let packageID = PackageID(rawValue: "needle-package")
        let skill = SkillRecord(
            id: skillID,
            packageID: packageID,
            name: "Needle Skill",
            summary: "Exercises projection invalidation",
            markdownSource: "# Needle Skill",
            installations: []
        )
        return LibrarySnapshot(
            packages: [SkillPackageRecord(id: packageID, name: "Needle", skillIDs: [skillID])],
            skills: [skill],
            scannedAt: .now
        )
    }()

    private static func installation(agent: AgentKind, suffix: String) -> SkillInstallation {
        SkillInstallation(
            id: InstallationID(rawValue: "\(agent.rawValue).\(suffix)"),
            agent: agent,
            entryURL: URL(filePath: "/tmp/\(agent.rawValue)/\(suffix)/SKILL.md"),
            rootURL: URL(filePath: "/tmp/\(agent.rawValue)/\(suffix)", directoryHint: .isDirectory),
            observedModifiedAt: .now,
            contentHash: String(repeating: suffix.first ?? "a", count: 64),
            localState: .unverified
        )
    }
}

private struct StaticScanner: SkillScanning {
    let snapshot: LibrarySnapshot

    func scan() -> AsyncThrowingStream<ScanUpdate, any Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.finished(snapshot: snapshot, scannedFileCount: snapshot.skills.count))
            continuation.finish()
        }
    }
}

private struct FailingScanner: SkillScanning {
    func scan() -> AsyncThrowingStream<ScanUpdate, any Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: FixtureScanError())
        }
    }
}

private struct FixtureScanError: LocalizedError {
    var errorDescription: String? { "Fixture scan failed" }
}
