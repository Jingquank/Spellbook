import Foundation
import SpellbookCore
import XCTest
@testable import SpellbookInfrastructure

final class InstallerPackageReceiptTests: XCTestCase {
    func testReceiptRegroupingMigratesAnExistingCatalogWithoutDuplicateIDs() async throws {
        let fixture = try TemporarySkillLibrary()
        let components = ["vigglify", "xray", "drill", "realitycheck", "lore", "grid"]
        var roots = [SkillDiscoveryRoot]()

        for agent in AgentKind.allCases {
            let root = try fixture.makeDirectory(at: agent.rawValue)
            for component in components {
                _ = try fixture.write(
                    "---\nname: \(component)\ndescription: \(agent.rawValue) \(component)\n---\n# \(component)\n\(agent.rawValue)",
                    at: "\(agent.rawValue)/\(component)/SKILL.md"
                )
            }
            roots.append(SkillDiscoveryRoot(agent: agent, url: root))
        }

        let store = try GRDBCatalogStore(databaseURL: fixture.url.appending(path: "catalog.sqlite"))
        let beforeReceipts = try await finishedSnapshot(from: FileSystemSkillScanner(roots: roots))
        try await store.saveSnapshot(beforeReceipts)

        for agent in AgentKind.allCases {
            let skills = Dictionary(uniqueKeysWithValues: components.map { ($0, ["SKILL.md"]) })
            let data = try JSONSerialization.data(
                withJSONObject: ["version": "1.9.1", "skills": skills],
                options: [.prettyPrinted, .sortedKeys]
            )
            _ = try fixture.write(data, at: "\(agent.rawValue)/.vigglify-install.json")
        }

        let regrouped = try await finishedSnapshot(from: FileSystemSkillScanner(roots: roots, catalog: store))
        let package = try XCTUnwrap(regrouped.packages.first { $0.name == "Vigglify" })
        let skills = regrouped.skills.filter { $0.packageID == package.id }

        XCTAssertEqual(regrouped.packages.filter { $0.name == "Vigglify" }.count, 1)
        XCTAssertEqual(package.skillIDs.count, 6)
        XCTAssertEqual(skills.count, 6)
        XCTAssertEqual(Set(skills.map { $0.name.lowercased() }), Set(components))
        XCTAssertTrue(skills.allSatisfy { $0.installations.count == 3 })
        XCTAssertEqual(Set(regrouped.skills.map(\.id)).count, regrouped.skills.count)
        XCTAssertEqual(Set(regrouped.packages.map(\.id)).count, regrouped.packages.count)

        try await store.saveSnapshot(regrouped)
        let loaded = try await store.loadSnapshot()
        let restored = try XCTUnwrap(loaded)
        XCTAssertEqual(restored.skills.count, regrouped.skills.count)
        XCTAssertEqual(restored.packages.count, regrouped.packages.count)
    }
    func testVigglifyReceiptGroupsSixSkillsAcrossThreeAgents() async throws {
        let fixture = try TemporarySkillLibrary()
        let components = ["vigglify", "xray", "drill", "realitycheck", "lore", "grid"]
        var roots = [SkillDiscoveryRoot]()

        for agent in AgentKind.allCases {
            let root = try fixture.makeDirectory(at: agent.rawValue)
            for component in components {
                _ = try fixture.write(
                    "---\nname: \(component)\ndescription: \(agent.rawValue) \(component)\n---\n# \(component)",
                    at: "\(agent.rawValue)/\(component)/SKILL.md"
                )
            }
            let skills = Dictionary(uniqueKeysWithValues: components.map { ($0, ["SKILL.md"]) })
            let data = try JSONSerialization.data(
                withJSONObject: ["version": "1.9.1", "skills": skills],
                options: [.prettyPrinted, .sortedKeys]
            )
            _ = try fixture.write(data, at: "\(agent.rawValue)/.vigglify-install.json")
            roots.append(SkillDiscoveryRoot(agent: agent, url: root))
        }

        let snapshot = try await finishedSnapshot(from: FileSystemSkillScanner(roots: roots))

        XCTAssertEqual(snapshot.packages.count, 1)
        XCTAssertEqual(snapshot.packages.first?.name, "Vigglify")
        XCTAssertEqual(snapshot.skills.count, 6)
        XCTAssertEqual(Set(snapshot.skills.map { $0.name.lowercased() }), Set(components))
        XCTAssertTrue(snapshot.skills.allSatisfy { $0.installations.count == 3 })
    }

    func testReceiptEvidenceIsScopedToAgentAndExactInstallationPath() throws {
        let fixture = try TemporarySkillLibrary()
        let codexRoot = try fixture.makeDirectory(at: "codex")
        let cursorRoot = try fixture.makeDirectory(at: "cursor")
        _ = try fixture.write("# Drill", at: "codex/drill/SKILL.md")
        _ = try fixture.write("# Drill", at: "cursor/drill/SKILL.md")
        _ = try fixture.write(
            Data(#"{"version":"1","skills":{"drill":["SKILL.md"]}}"#.utf8),
            at: "codex/.vigglify-install.json"
        )
        let roots = [
            SkillDiscoveryRoot(agent: .codex, url: codexRoot),
            SkillDiscoveryRoot(agent: .cursor, url: cursorRoot)
        ]

        let index = InstallerProvenanceIndex.load(roots: roots, sourceSearchRoots: [])

        XCTAssertNotNil(index.hint(for: codexRoot.appending(path: "drill/SKILL.md"), agent: .codex)?.packageMembershipKey)
        XCTAssertNil(index.hint(for: cursorRoot.appending(path: "drill/SKILL.md"), agent: .cursor))
    }

    func testRejectsReceiptWithTraversalOrEscapingSymlink() throws {
        let fixture = try TemporarySkillLibrary()
        let root = try fixture.makeDirectory(at: "codex")
        _ = try fixture.write("# Unsafe", at: "codex/unsafe/SKILL.md")
        _ = try fixture.write("secret", at: "outside.txt")
        try FileManager.default.createSymbolicLink(
            at: root.appending(path: "unsafe/escape.txt"),
            withDestinationURL: fixture.url.appending(path: "outside.txt")
        )
        _ = try fixture.write(
            Data(#"{"version":"1","skills":{"unsafe":["SKILL.md","escape.txt"]}}"#.utf8),
            at: "codex/.unsafe-install.json"
        )

        let index = InstallerProvenanceIndex.load(
            roots: [SkillDiscoveryRoot(agent: .codex, url: root)],
            sourceSearchRoots: []
        )

        XCTAssertTrue(index.receipts.isEmpty)
        XCTAssertNil(index.hint(for: root.appending(path: "unsafe/SKILL.md"), agent: .codex))
    }

    private func finishedSnapshot(from scanner: FileSystemSkillScanner) async throws -> LibrarySnapshot {
        var result: LibrarySnapshot?
        for try await update in scanner.scan() {
            if case .finished(let snapshot, _) = update { result = snapshot }
        }
        return try XCTUnwrap(result)
    }
}
