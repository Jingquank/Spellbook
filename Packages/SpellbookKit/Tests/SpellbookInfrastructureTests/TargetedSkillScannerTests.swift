import Foundation
import SpellbookCore
import XCTest
@testable import SpellbookInfrastructure

final class TargetedSkillScannerTests: XCTestCase {
    func testReconcilesOnlyAffectedRootAndPreservesOtherRoots() async throws {
        let fixture = try TemporarySkillLibrary()
        let firstRoot = try fixture.makeDirectory(at: "first")
        let secondRoot = try fixture.makeDirectory(at: "second")
        let changedEntry = try fixture.write("# First\n\nBefore", at: "first/first/SKILL.md")
        _ = try fixture.write("# Second\n\nUntouched", at: "second/second/SKILL.md")
        let scanner = FileSystemSkillScanner(roots: [
            SkillDiscoveryRoot(agent: .claude, url: firstRoot),
            SkillDiscoveryRoot(agent: .codex, url: secondRoot)
        ])
        let initial = try await finalSnapshot(from: scanner.scan())

        try Data("# First\n\nAfter".utf8).write(to: changedEntry)
        let reconciled = try await finalSnapshot(from: scanner.reconcile(
            snapshot: initial,
            changes: FileChangeBatch(urls: [changedEntry])
        ))

        XCTAssertEqual(reconciled.skills.count, 2)
        XCTAssertEqual(reconciled.skills.first { $0.name == "First" }?.markdownSource, "# First\n\nAfter")
        XCTAssertEqual(reconciled.skills.first { $0.name == "Second" }?.markdownSource, "# Second\n\nUntouched")
    }

    func testReconciliationRemovesDeletedSkillWithoutDroppingOtherRoots() async throws {
        let fixture = try TemporarySkillLibrary()
        let firstRoot = try fixture.makeDirectory(at: "first")
        let secondRoot = try fixture.makeDirectory(at: "second")
        let deletedEntry = try fixture.write("# First", at: "first/first/SKILL.md")
        _ = try fixture.write("# Second", at: "second/second/SKILL.md")
        let scanner = FileSystemSkillScanner(roots: [
            SkillDiscoveryRoot(agent: .claude, url: firstRoot),
            SkillDiscoveryRoot(agent: .codex, url: secondRoot)
        ])
        let initial = try await finalSnapshot(from: scanner.scan())

        try FileManager.default.removeItem(at: deletedEntry)
        let reconciled = try await finalSnapshot(from: scanner.reconcile(
            snapshot: initial,
            changes: FileChangeBatch(urls: [deletedEntry])
        ))

        XCTAssertEqual(reconciled.skills.map(\.name), ["Second"])
    }

    func testMissingRootPreservesCachedSkillAsMissing() async throws {
        let fixture = try TemporarySkillLibrary()
        let root = try fixture.makeDirectory(at: "removable")
        _ = try fixture.write("# Durable", at: "removable/durable/SKILL.md")
        let catalog = try GRDBCatalogStore(databaseURL: fixture.url.appending(path: "catalog.sqlite"))
        let scanner = FileSystemSkillScanner(
            roots: [SkillDiscoveryRoot(agent: .cursor, url: root)],
            catalog: catalog
        )
        let initial = try await finalSnapshot(from: scanner.scan())
        try await catalog.saveSnapshot(initial)

        try FileManager.default.removeItem(at: root)
        let unavailable = try await finalSnapshot(from: scanner.scan())

        XCTAssertEqual(unavailable.skills.map(\.name), ["Durable"])
        XCTAssertEqual(unavailable.skills.first?.installations.first?.localState, .missing)
    }

    private func finalSnapshot(
        from stream: AsyncThrowingStream<ScanUpdate, any Error>
    ) async throws -> LibrarySnapshot {
        var result = LibrarySnapshot.empty
        for try await update in stream {
            if case .finished(let snapshot, _) = update {
                result = snapshot
            }
        }
        return result
    }
}
