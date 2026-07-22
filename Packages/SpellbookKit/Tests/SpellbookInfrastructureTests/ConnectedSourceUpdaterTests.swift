import Foundation
import SpellbookCore
import XCTest
@testable import SpellbookInfrastructure

final class ConnectedSourceUpdaterTests: XCTestCase {
    func testDirectFileUpdateStagesReviewPlanAndUsesRecoveryPipeline() async throws {
        let fixture = try TemporarySkillLibrary()
        let installed = try fixture.write("# Before\n", at: "installed/example/SKILL.md")
        let source = try fixture.write("# After\n", at: "source/SKILL.md")
        let store = try GRDBCatalogStore(databaseURL: fixture.url.appending(path: "catalog.sqlite"))
        let manager = FileSystemSkillManager(
            roots: [],
            recoveryRoot: fixture.url.appending(path: "recovery"),
            catalog: store
        )
        let snapshot = snapshot(
            packageName: "Single",
            entries: [("Single", installed, installed.deletingLastPathComponent())]
        )
        let packageID = try XCTUnwrap(snapshot.packages.first?.id)
        try await store.saveSourceConnection(SourceConnection(
            packageID: packageID,
            kind: .directFile,
            sourceURL: source
        ))
        let updater = ConnectedSourceUpdater(
            catalog: store,
            manager: manager,
            cacheRoot: fixture.url.appending(path: "cache")
        )

        let updates = try await updater.check(snapshot: snapshot)

        let update = try XCTUnwrap(updates.first)
        XCTAssertTrue(update.canApply)
        XCTAssertEqual(update.affectedSkillNames, ["Single"])
        XCTAssertEqual(update.affectedInstallationCount, 1)
        XCTAssertEqual(update.mutationPlan?.targets.first?.proposedText, "# After\n")

        _ = try await updater.apply(update)
        XCTAssertEqual(try String(contentsOf: installed, encoding: .utf8), "# After\n")
        let operations = try await store.recentOperations(limit: 5)
        XCTAssertEqual(operations.first?.kind, .update)
        XCTAssertEqual(operations.first?.status, .committed)
    }

    func testGitPackageUpdateNamesAndPlansAllFiveBenchSkills() async throws {
        let fixture = try TemporarySkillLibrary()
        let sourceRepository = try fixture.makeDirectory(at: "source-repository")
        try runGit(["init", "-b", "main"], in: sourceRepository)
        try runGit(["config", "user.name", "Spellbook Tests"], in: sourceRepository)
        try runGit(["config", "user.email", "spellbook@example.test"], in: sourceRepository)

        let names = ["Plan", "Build", "Test", "Review", "Ship"]
        for name in names {
            _ = try fixture.write("# \(name) v1\n", at: "source-repository/skills/\(name.lowercased())/SKILL.md")
        }
        try runGit(["add", "."], in: sourceRepository)
        try runGit(["commit", "-m", "v1"], in: sourceRepository)

        let installedRoot = try fixture.makeDirectory(at: "installed-bench")
        var entries = [(String, URL, URL)]()
        for name in names {
            let installed = try fixture.write(
                "# \(name) v1\n",
                at: "installed-bench/skills/\(name.lowercased())/SKILL.md"
            )
            entries.append((name, installed, installedRoot))
            _ = try fixture.write(
                "# \(name) v2\n",
                at: "source-repository/skills/\(name.lowercased())/SKILL.md"
            )
        }
        try runGit(["add", "."], in: sourceRepository)
        try runGit(["commit", "-m", "v2"], in: sourceRepository)

        let store = try GRDBCatalogStore(databaseURL: fixture.url.appending(path: "catalog.sqlite"))
        let manager = FileSystemSkillManager(
            roots: [],
            recoveryRoot: fixture.url.appending(path: "recovery"),
            catalog: store
        )
        let snapshot = snapshot(packageName: "Bench", entries: entries)
        let packageID = try XCTUnwrap(snapshot.packages.first?.id)
        try await store.saveSourceConnection(SourceConnection(
            packageID: packageID,
            kind: .gitRepository,
            sourceURL: sourceRepository,
            branch: "main"
        ))
        let updater = ConnectedSourceUpdater(
            catalog: store,
            manager: manager,
            cacheRoot: fixture.url.appending(path: "cache")
        )

        let updates = try await updater.check(snapshot: snapshot)

        let update = try XCTUnwrap(updates.first)
        XCTAssertTrue(update.canApply)
        XCTAssertEqual(update.affectedSkillNames, names.sorted())
        XCTAssertEqual(update.affectedInstallationCount, 5)
        XCTAssertEqual(update.mutationPlan?.targets.count, 5)

        _ = try await updater.apply(update)
        for (name, installed, _) in entries {
            XCTAssertEqual(try String(contentsOf: installed, encoding: .utf8), "# \(name) v2\n")
        }
    }

    private func snapshot(
        packageName: String,
        entries: [(name: String, entry: URL, root: URL)]
    ) -> LibrarySnapshot {
        let packageID = PackageID(rawValue: "package-\(packageName.lowercased())")
        let skills = entries.map { item in
            let data = (try? Data(contentsOf: item.entry)) ?? Data()
            let skillID = SkillID(rawValue: "skill-\(item.name.lowercased())")
            return SkillRecord(
                id: skillID,
                packageID: packageID,
                name: item.name,
                summary: "",
                markdownSource: String(data: data, encoding: .utf8) ?? "",
                installations: [SkillInstallation(
                    id: InstallationID(rawValue: "installation-\(item.name.lowercased())"),
                    agent: .codex,
                    entryURL: item.entry,
                    rootURL: item.root,
                    contentHash: StableHasher.sha256(data),
                    localState: .clean
                )]
            )
        }
        return LibrarySnapshot(
            packages: [SkillPackageRecord(
                id: packageID,
                name: packageName,
                skillIDs: skills.map(\.id)
            )],
            skills: skills,
            scannedAt: .now
        )
    }

    private func runGit(_ arguments: [String], in directory: URL) throws {
        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.arguments = ["-C", directory.path] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(
                data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? "Git failed"
            throw NSError(
                domain: "ConnectedSourceUpdaterTests",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }
}
