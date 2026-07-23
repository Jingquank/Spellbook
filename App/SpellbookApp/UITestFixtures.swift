import Foundation
import SpellbookCore
import SpellbookInfrastructure
import SpellbookUI

enum UITestFixtures {
    @MainActor
    static func makeModel() -> SpellbookModel {
        let defaults = UserDefaults(suiteName: "com.keding.Spellbook.UITests")!
        defaults.removePersistentDomain(forName: "com.keding.Spellbook.UITests")
        defaults.set(true, forKey: "general.scanOnLaunch")
        return SpellbookModel(
            scanner: FixtureScanner(snapshot: snapshot),
            manager: FileSystemSkillManager(
                roots: [],
                recoveryRoot: FileManager.default.temporaryDirectory
                    .appending(path: "SpellbookUITestRecovery", directoryHint: .isDirectory)
            ),
            updater: FixtureUpdater(update: update),
            defaults: defaults
        )
    }

    private static let packageID = PackageID(rawValue: "ui-fixture-package")

    private static let snapshot: LibrarySnapshot = {
        let alpha = skill(name: "Alpha Fixture", id: "alpha", agent: .codex)
        let beta = skill(name: "Beta Fixture", id: "beta", agent: .claude)
        return LibrarySnapshot(
            packages: [
                SkillPackageRecord(
                    id: packageID,
                    name: "Fixture Package",
                    skillIDs: [alpha.id, beta.id]
                )
            ],
            skills: [alpha, beta],
            scannedAt: .now
        )
    }()

    private static let update = PackageUpdate(
        id: "ui-fixture-update",
        packageIDs: [packageID],
        packageNames: ["Fixture Package"],
        repositoryURL: URL(string: "https://github.com/example/fixture")!,
        sourceURL: nil,
        currentRevision: "1111111",
        targetRevision: "2222222",
        canApply: false,
        blockingReason: "UI fixture review only",
        affectedSkillNames: ["Alpha Fixture", "Beta Fixture"],
        affectedInstallationCount: 2
    )

    private static func skill(name: String, id: String, agent: AgentKind) -> SkillRecord {
        let root = URL(filePath: "/tmp/spellbook-ui-fixture/\(id)", directoryHint: .isDirectory)
        let readerSections = (1...12)
            .map { section in
                """
                ## Fixture Section \(section)

                Deterministic reader content used to verify fixed chrome while the skill page scrolls.
                """
            }
            .joined(separator: "\n\n")
        let markdownSource = "# \(name)\n\n\(readerSections)"
        let installation = SkillInstallation(
            id: InstallationID(rawValue: "installation-\(id)"),
            agent: agent,
            entryURL: root.appending(path: "SKILL.md"),
            rootURL: root,
            markdownSource: markdownSource,
            contentHash: String(repeating: id.first ?? "a", count: 64),
            localState: .clean
        )
        return SkillRecord(
            id: SkillID(rawValue: "skill-\(id)"),
            packageID: packageID,
            name: name,
            summary: "A deterministic skill used to verify Spellbook interface behavior.",
            markdownSource: markdownSource,
            installations: [installation]
        )
    }
}

private struct FixtureScanner: SkillScanning {
    let snapshot: LibrarySnapshot

    func scan() -> AsyncThrowingStream<ScanUpdate, any Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.finished(snapshot: snapshot, scannedFileCount: snapshot.skills.count))
            continuation.finish()
        }
    }
}

private struct FixtureUpdater: SkillUpdating {
    let update: PackageUpdate

    func check(snapshot: LibrarySnapshot) async throws -> [PackageUpdate] {
        [update]
    }

    func apply(_ update: PackageUpdate) async throws -> PackageUpdateReceipt {
        PackageUpdateReceipt(
            repositoryURL: update.repositoryURL,
            previousRevision: update.currentRevision,
            resultingRevision: update.targetRevision
        )
    }
}
