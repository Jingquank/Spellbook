import Foundation
import SpellbookCore
import XCTest
@testable import SpellbookInfrastructure

final class FileSystemSkillManagerTests: XCTestCase {
    func testInjectedFailureAtEveryMutationCheckpointPreservesOriginalFile() async throws {
        struct InjectedFailure: Error {}

        for checkpoint in MutationCheckpoint.allCases {
            let fixture = try TemporarySkillLibrary()
            let entry = try fixture.write("# Original\n", at: "skills/example/SKILL.md")
            let manager = FileSystemSkillManager(
                roots: [],
                recoveryRoot: fixture.url.appending(path: "recovery"),
                faultInjector: { current in
                    if current == checkpoint { throw InjectedFailure() }
                }
            )
            let current = try await manager.read(at: entry)
            let plan = try await manager.plan([
                MutationRequest(
                    destinationURL: entry,
                    action: .write,
                    expectedHash: current.contentHash,
                    proposedText: "# Proposed\n"
                )
            ], kind: .edit)

            do {
                _ = try await manager.execute(plan)
                XCTFail("Expected injected failure at \(checkpoint.rawValue)")
            } catch is InjectedFailure {
                // Expected.
            }

            XCTAssertEqual(
                try String(contentsOf: entry, encoding: .utf8),
                "# Original\n",
                "Checkpoint \(checkpoint.rawValue) did not preserve the original file"
            )
        }
    }

    func testRecordsCommittedAndRejectedOperationsWithRecoveryEvidence() async throws {
        let fixture = try TemporarySkillLibrary()
        let store = try GRDBCatalogStore(databaseURL: fixture.url.appending(path: "catalog.sqlite"))
        let entry = try fixture.write("# Before\n", at: "skills/example/SKILL.md")
        let manager = FileSystemSkillManager(
            roots: [],
            recoveryRoot: fixture.url.appending(path: "recovery"),
            catalog: store
        )
        let reviewed = try await manager.read(at: entry)

        _ = try await manager.write(
            "# After\n",
            to: entry,
            expectedHash: reviewed.contentHash,
            kind: .edit
        )
        do {
            _ = try await manager.write(
                "# Stale edit\n",
                to: entry,
                expectedHash: reviewed.contentHash,
                kind: .edit
            )
            XCTFail("Expected stale edit rejection")
        } catch {
            // Expected: the second write reviewed an obsolete fingerprint.
        }

        let operations = try await store.recentOperations(limit: 10)
        XCTAssertEqual(operations.map(\.status), [.failed, .committed])
        XCTAssertEqual(operations.last?.kind, .edit)
        XCTAssertEqual(operations.last?.targetURLs, [entry.standardizedFileURL])
        XCTAssertEqual(operations.last?.recoveryURLs.count, 1)
    }

    func testWritesOnlyWhenReviewedHashStillMatchesAndCreatesBackup() async throws {
        let fixture = try TemporarySkillLibrary()
        let recovery = fixture.url.appending(path: "recovery", directoryHint: .isDirectory)
        let entry = try fixture.write("# Before\n", at: "skills/example/SKILL.md")
        let manager = FileSystemSkillManager(roots: [], recoveryRoot: recovery)
        let reviewed = try await manager.read(at: entry)

        let receipt = try await manager.write(
            "# After\n",
            to: entry,
            expectedHash: reviewed.contentHash,
            kind: .edit
        )

        XCTAssertEqual(try String(contentsOf: entry, encoding: .utf8), "# After\n")
        XCTAssertNotNil(receipt.recoveryURL)
        XCTAssertEqual(
            try receipt.recoveryURL.map { try String(contentsOf: $0, encoding: .utf8) },
            "# Before\n"
        )
        let saved = try await manager.read(at: entry)
        XCTAssertEqual(receipt.resultingHash, saved.contentHash)
    }

    func testRejectsWriteWhenFileChangedAfterReview() async throws {
        let fixture = try TemporarySkillLibrary()
        let entry = try fixture.write("# Before\n", at: "skills/example/SKILL.md")
        let manager = FileSystemSkillManager(roots: [], recoveryRoot: fixture.url.appending(path: "recovery"))
        let reviewed = try await manager.read(at: entry)
        _ = try fixture.write("# Agent edit\n", at: "skills/example/SKILL.md")

        do {
            _ = try await manager.write(
                "# Spellbook edit\n",
                to: entry,
                expectedHash: reviewed.contentHash,
                kind: .edit
            )
            XCTFail("Expected a changed-since-review error")
        } catch let error as SkillMutationError {
            guard case .changedSinceReview = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertEqual(try String(contentsOf: entry, encoding: .utf8), "# Agent edit\n")
    }

    func testCreatesNewAgentInstallationButNeverSilentlyReplacesOne() async throws {
        let fixture = try TemporarySkillLibrary()
        let destination = fixture.url.appending(path: "cursor/example/SKILL.md")
        let manager = FileSystemSkillManager(roots: [], recoveryRoot: fixture.url.appending(path: "recovery"))

        _ = try await manager.write("# Skill\n", to: destination, expectedHash: nil, kind: .apply)
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "# Skill\n")

        do {
            _ = try await manager.write("# Replacement\n", to: destination, expectedHash: nil, kind: .apply)
            XCTFail("Expected destination-already-exists")
        } catch let error as SkillMutationError {
            guard case .destinationAlreadyExists = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testMultiTargetPlanStagesCandidatesAndCreatesEveryBackupBeforeCommit() async throws {
        let fixture = try TemporarySkillLibrary()
        let recovery = fixture.url.appending(path: "recovery")
        let first = try fixture.write("# First before\n", at: "skills/first/SKILL.md")
        let second = try fixture.write("# Second before\n", at: "skills/second/SKILL.md")
        let manager = FileSystemSkillManager(roots: [], recoveryRoot: recovery)
        let firstContent = try await manager.read(at: first)
        let secondContent = try await manager.read(at: second)

        let plan = try await manager.plan([
            MutationRequest(
                destinationURL: first,
                action: .write,
                expectedHash: firstContent.contentHash,
                proposedText: "# First after\n"
            ),
            MutationRequest(
                destinationURL: second,
                action: .write,
                expectedHash: secondContent.contentHash,
                proposedText: "# Second after\n"
            )
        ], kind: .apply)

        XCTAssertEqual(plan.targets.count, 2)
        XCTAssertTrue(plan.targets.allSatisfy { target in
            target.stagedURL.map { FileManager.default.fileExists(atPath: $0.path) } == true
        })
        XCTAssertTrue(plan.targets.allSatisfy { $0.diff.addedLineCount > 0 && $0.diff.removedLineCount > 0 })

        let receipt = try await manager.execute(plan)

        XCTAssertEqual(receipt.outcomes.count, 2)
        XCTAssertEqual(receipt.outcomes.compactMap(\.recoveryURL).count, 2)
        XCTAssertEqual(try String(contentsOf: first, encoding: .utf8), "# First after\n")
        XCTAssertEqual(try String(contentsOf: second, encoding: .utf8), "# Second after\n")
    }

    func testMultiTargetPlanRejectsStaleTargetBeforeChangingAnyFile() async throws {
        let fixture = try TemporarySkillLibrary()
        let first = try fixture.write("# First before\n", at: "skills/first/SKILL.md")
        let second = try fixture.write("# Second before\n", at: "skills/second/SKILL.md")
        let manager = FileSystemSkillManager(
            roots: [],
            recoveryRoot: fixture.url.appending(path: "recovery")
        )
        let firstContent = try await manager.read(at: first)
        let secondContent = try await manager.read(at: second)
        let plan = try await manager.plan([
            MutationRequest(
                destinationURL: first,
                action: .write,
                expectedHash: firstContent.contentHash,
                proposedText: "# First after\n"
            ),
            MutationRequest(
                destinationURL: second,
                action: .write,
                expectedHash: secondContent.contentHash,
                proposedText: "# Second after\n"
            )
        ], kind: .apply)
        try Data("# External edit\n".utf8).write(to: second)

        do {
            _ = try await manager.execute(plan)
            XCTFail("Expected stale plan rejection")
        } catch let error as SkillMutationError {
            guard case .changedSinceReview = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertEqual(try String(contentsOf: first, encoding: .utf8), "# First before\n")
        XCTAssertEqual(try String(contentsOf: second, encoding: .utf8), "# External edit\n")
    }

    func testLaunchRecoveryRollsBackInterruptedWriteFromDurableJournal() async throws {
        let fixture = try TemporarySkillLibrary()
        let recoveryRoot = try fixture.makeDirectory(at: "recovery")
        let operationRoot = try fixture.makeDirectory(at: "recovery/interrupted")
        let backup = try fixture.write("# Original\n", at: "recovery/interrupted/Backups/0-SKILL.md")
        let destination = try fixture.write("# Proposed\n", at: "skills/example/SKILL.md")
        let originalHash = StableHasher.sha256(Data("# Original\n".utf8))
        let proposedHash = StableHasher.sha256(Data("# Proposed\n".utf8))
        let journal = RecoveryJournal(
            operationID: "interrupted",
            kind: .edit,
            startedAt: .now,
            phase: .mutating,
            targets: [RecoveryJournalTarget(
                id: "target-0",
                destinationURL: destination,
                action: .write,
                expectedHash: originalHash,
                proposedHash: proposedHash,
                backupURL: backup,
                existed: true
            )]
        )
        try JSONEncoder().encode(journal).write(
            to: operationRoot.appending(path: "journal.json"),
            options: .atomic
        )
        let manager = FileSystemSkillManager(roots: [], recoveryRoot: recoveryRoot)

        let records = try await manager.recoverInterruptedOperations()

        XCTAssertEqual(records.map(\.status), [.recovered])
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "# Original\n")
    }
}
