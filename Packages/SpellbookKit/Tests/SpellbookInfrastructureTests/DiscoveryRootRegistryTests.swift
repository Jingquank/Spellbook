import Foundation
import SpellbookCore
import XCTest
@testable import SpellbookInfrastructure

final class DiscoveryRootRegistryTests: XCTestCase {
    func testPersistsCustomRootWithAgentAndNeverRemovesFolder() async throws {
        let fixture = try TemporarySkillLibrary()
        let databaseURL = fixture.url.appending(path: "catalog.sqlite")
        let customFolder = try fixture.makeDirectory(at: "external-skills")
        let store = try GRDBCatalogStore(databaseURL: databaseURL)
        let registry = DiscoveryRootRegistry(knownRoots: [], catalog: store)
        let root = DiscoveryRootRecord(agent: .cursor, url: customFolder, isKnown: false)

        try await registry.addRoot(root)

        let relaunchedStore = try GRDBCatalogStore(databaseURL: databaseURL)
        let relaunchedRegistry = DiscoveryRootRegistry(knownRoots: [], catalog: relaunchedStore)
        let restoredRoots = try await relaunchedRegistry.roots()
        XCTAssertEqual(restoredRoots, [root])

        try await relaunchedRegistry.removeRoot(id: root.id)

        XCTAssertTrue(FileManager.default.fileExists(atPath: customFolder.path))
        let remainingRoots = try await relaunchedRegistry.roots()
        let storedRoots = try await relaunchedStore.loadCustomRoots()
        XCTAssertEqual(remainingRoots, [])
        XCTAssertEqual(storedRoots, [])
    }

    func testScannerResolvesLatestRegistryRootsForEveryScan() async throws {
        let fixture = try TemporarySkillLibrary()
        let firstRoot = try fixture.makeDirectory(at: "first")
        let secondRoot = try fixture.makeDirectory(at: "second")
        _ = try fixture.write("# First", at: "first/first/SKILL.md")
        _ = try fixture.write("# Second", at: "second/second/SKILL.md")
        let registry = DiscoveryRootRegistry(knownRoots: [], catalog: nil)
        let scanner = FileSystemSkillScanner(registry: registry)
        try await registry.addRoot(
            DiscoveryRootRecord(agent: .claude, url: firstRoot, isKnown: false)
        )

        let firstSnapshot = try await finalSnapshot(from: scanner)
        XCTAssertEqual(firstSnapshot.skills.map(\.name), ["First"])

        try await registry.addRoot(
            DiscoveryRootRecord(agent: .codex, url: secondRoot, isKnown: false)
        )
        let secondSnapshot = try await finalSnapshot(from: scanner)
        XCTAssertEqual(Set(secondSnapshot.skills.map(\.name)), ["First", "Second"])
    }

    private func finalSnapshot(from scanner: FileSystemSkillScanner) async throws -> LibrarySnapshot {
        var result = LibrarySnapshot.empty
        for try await update in scanner.scan() {
            if case .finished(let snapshot, _) = update {
                result = snapshot
            }
        }
        return result
    }
}
