import Foundation
import SpellbookCore
import XCTest
@testable import SpellbookInfrastructure

final class FileSystemSkillScannerTests: XCTestCase {
    func testScansBothEntryPatternsAndParsesCommonFrontmatter() async throws {
        let fixture = try TemporarySkillLibrary()
        let modifiedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = try fixture.write(
            """
            ---
            name: Quiet Review
            description: >
              Reviews a change
              without rewriting it.
            metadata:
              author: Ada Lovelace
            repository: git@github.com:example/quiet-review.git
            homepage: https://example.com/quiet-review
            id: review
            ---
            # Quiet Review
            """,
            at: "quiet/review.agent.claude.md"
        )
        try FileManager.default.setAttributes([.modificationDate: modifiedDate], ofItemAtPath: entry.path)
        _ = try fixture.write("Just another file", at: "quiet/README.md")

        let result = try await scan([
            SkillDiscoveryRoot(agent: .claude, url: fixture.url)
        ])

        XCTAssertEqual(result.progressCount, 1)
        XCTAssertEqual(result.scannedFileCount, 1)
        XCTAssertEqual(result.snapshot.skills.count, 1)
        let skill = try XCTUnwrap(result.snapshot.skills.first)
        XCTAssertEqual(skill.name, "Quiet Review")
        XCTAssertEqual(skill.summary, "Reviews a change without rewriting it.")
        XCTAssertEqual(skill.author, "Ada Lovelace")
        XCTAssertEqual(skill.sourceURL?.absoluteString, "https://github.com/example/quiet-review")
        XCTAssertEqual(skill.websiteURL?.absoluteString, "https://example.com/quiet-review")
        XCTAssertEqual(skill.installations.first?.observedModifiedAt?.timeIntervalSince1970, modifiedDate.timeIntervalSince1970)
        XCTAssertEqual(skill.installations.first?.contentHash.count, 64)
        XCTAssertEqual(skill.installations.first?.localState, .unverified)
    }

    func testGroupsBenchLikeManifestAsOnePackageWithFiveSkills() async throws {
        let fixture = try TemporarySkillLibrary()
        let manifest = """
        {
          "name": "Bench",
          "author": { "name": "Jingquank" },
          "repository": { "url": "https://github.com/Jingquank/Bench.git" },
          "homepage": "https://github.com/Jingquank/Bench"
        }
        """
        _ = try fixture.write(manifest, at: "Bench/package.json")

        for index in 1...5 {
            _ = try fixture.write(
                "---\nname: Bench Skill \(index)\ndescription: Skill \(index)\n---\n# Skill \(index)",
                at: "Bench/skills/skill-\(index)/SKILL.md"
            )
        }

        let result = try await scan([
            SkillDiscoveryRoot(agent: .codex, url: fixture.url)
        ])

        XCTAssertGreaterThanOrEqual(result.progressCount, 1)
        XCTAssertEqual(result.scannedFileCount, 5)
        XCTAssertEqual(result.snapshot.packages.count, 1)
        XCTAssertEqual(result.snapshot.skills.count, 5)
        let package = try XCTUnwrap(result.snapshot.packages.first)
        XCTAssertEqual(package.name, "Bench")
        XCTAssertEqual(package.author, "Jingquank")
        XCTAssertEqual(package.sourceURL?.absoluteString, "https://github.com/Jingquank/Bench")
        XCTAssertEqual(package.skillIDs.count, 5)
    }

    func testMastermindAliasesBecomeTwoSkillsWithThreeIndependentInstallationsEach() async throws {
        let fixture = try TemporarySkillLibrary()
        let roots = try AgentKind.allCases.map { agent -> SkillDiscoveryRoot in
            let root = try fixture.makeDirectory(at: agent.rawValue)
            _ = try fixture.write(
                "---\nname: Master\ndescription: Alias of /mastermind.\n---\nAlias of /mastermind.",
                at: "\(agent.rawValue)/master/SKILL.md"
            )
            _ = try fixture.write(
                "---\nname: Mastermind\ndescription: Review Markdown visually.\n---\n# Mastermind\n\nReview Markdown visually.",
                at: "\(agent.rawValue)/mastermind/SKILL.md"
            )
            return SkillDiscoveryRoot(agent: agent, url: root)
        }

        let result = try await scan(roots)

        XCTAssertEqual(result.snapshot.packages.count, 1)
        XCTAssertEqual(result.snapshot.packages.first?.name, "Mastermind")
        XCTAssertEqual(result.snapshot.skills.map(\.name).sorted(), ["Master", "Mastermind"])
        XCTAssertTrue(result.snapshot.skills.allSatisfy { $0.installations.count == 3 })
        XCTAssertEqual(result.snapshot.skills.flatMap(\.installations).count, 6)
        let agentProjection = LibraryProjection(
            snapshot: result.snapshot,
            mode: .agentFirst,
            searchText: "",
            alwaysShowsPackageGroups: false
        )
        XCTAssertEqual(agentProjection.nodes.count, 3)
        XCTAssertTrue(agentProjection.nodes.allSatisfy { node in
            guard case .group(let group) = node else { return false }
            return group.kind == .agent && group.skills.map(\.name).sorted() == ["Master", "Mastermind"]
        })
    }

    func testScannerKeepsDeclaredIconsWhileProjectionPrefersPackageArtwork() async throws {
        let fixture = try TemporarySkillLibrary()
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x01])
        _ = try fixture.write(
            "{\"name\":\"Artwork Pack\",\"logo\":\"logo.png\",\"repository\":\"https://github.com/acme/artwork-pack\"}",
            at: "pack/package.json"
        )
        _ = try fixture.write(png, at: "pack/logo.png")
        _ = try fixture.write("---\nname: One\n---\n# One", at: "pack/skills/one/SKILL.md")
        _ = try fixture.write("interface:\n  icon_small: assets/icon.png\n", at: "pack/skills/one/agents/openai.yaml")
        _ = try fixture.write(png + Data([0x02]), at: "pack/skills/one/assets/icon.png")
        _ = try fixture.write("---\nname: Two\n---\n# Two", at: "pack/skills/two/SKILL.md")

        let result = try await scan([SkillDiscoveryRoot(agent: .codex, url: fixture.url)])
        let package = try XCTUnwrap(result.snapshot.packages.first)
        let one = try XCTUnwrap(result.snapshot.skills.first { $0.name == "One" })
        let two = try XCTUnwrap(result.snapshot.skills.first { $0.name == "Two" })

        XCTAssertEqual(package.artwork?.declaredPath, "logo.png")
        XCTAssertEqual(one.artwork?.declaredPath, "assets/icon.png")
        XCTAssertNil(two.artwork)
        let projection = LibraryProjection(
            snapshot: result.snapshot,
            mode: .skillFirst,
            searchText: "",
            alwaysShowsPackageGroups: false
        )
        guard case .group(let group) = try XCTUnwrap(projection.nodes.first) else {
            return XCTFail("Expected a grouped package")
        }
        // The resolver keeps the skill icon as evidence but consistently
        // prefers the package icon wherever both are available.
        XCTAssertEqual(group.skills.first { $0.skillID == one.id }?.artwork?.declaredPath, "logo.png")
        XCTAssertEqual(group.skills.first { $0.skillID == two.id }?.artwork?.declaredPath, "logo.png")
    }

    func testMergesIndependentAgentInstallationsWithMatchingGitEvidence() async throws {
        let fixture = try TemporarySkillLibrary()
        let claudeRoot = try fixture.makeDirectory(at: "claude")
        let cursorRoot = try fixture.makeDirectory(at: "cursor")
        let gitConfigA = "[remote \"origin\"]\n    url = git@github.com:acme/shared-skill.git\n"
        let gitConfigB = "[remote \"origin\"]\n    url = https://github.com/acme/shared-skill.git\n"
        _ = try fixture.write(gitConfigA, at: "claude/Shared/.git/config")
        _ = try fixture.write(gitConfigB, at: "cursor/Shared/.git/config")
        _ = try fixture.write("---\nname: Shared\ndescription: Claude copy\n---", at: "claude/Shared/SKILL.md")
        _ = try fixture.write("---\nname: Shared\ndescription: Cursor copy\n---", at: "cursor/Shared/SKILL.md")

        let result = try await scan([
            SkillDiscoveryRoot(agent: .claude, url: claudeRoot),
            SkillDiscoveryRoot(agent: .cursor, url: cursorRoot)
        ])

        XCTAssertEqual(result.snapshot.packages.count, 1)
        XCTAssertEqual(result.snapshot.skills.count, 1)
        let skill = try XCTUnwrap(result.snapshot.skills.first)
        XCTAssertEqual(Set(skill.installations.map(\.agent)), [.claude, .cursor])
        XCTAssertEqual(skill.installations.count, 2)
        XCTAssertNotEqual(skill.installations[0].id, skill.installations[1].id)
        XCTAssertNotEqual(skill.installations[0].entryURL, skill.installations[1].entryURL)
    }

    func testDoesNotMergeSkillsBasedOnlyOnMatchingNameAndContent() async throws {
        let fixture = try TemporarySkillLibrary()
        let claudeRoot = try fixture.makeDirectory(at: "claude")
        let codexRoot = try fixture.makeDirectory(at: "codex")
        let markdown = "---\nname: Same Name\ndescription: Same content\n---\n# Same"
        _ = try fixture.write(markdown, at: "claude/same/SKILL.md")
        _ = try fixture.write(markdown, at: "codex/same/SKILL.md")

        let result = try await scan([
            SkillDiscoveryRoot(agent: .claude, url: claudeRoot),
            SkillDiscoveryRoot(agent: .codex, url: codexRoot)
        ])

        XCTAssertEqual(result.snapshot.packages.count, 2)
        XCTAssertEqual(result.snapshot.skills.count, 2)
        XCTAssertEqual(Set(result.snapshot.skills.map(\.id)).count, 2)
        XCTAssertEqual(Set(result.snapshot.skills.flatMap(\.installations).map(\.contentHash)).count, 1)
    }

    func testSplitsAStaleContentMergedCatalogWithoutReusingTheSurvivorIDTwice() async throws {
        let fixture = try TemporarySkillLibrary()
        let claudeRoot = try fixture.makeDirectory(at: "claude")
        let codexRoot = try fixture.makeDirectory(at: "codex")
        let markdown = "---\nname: Same Name\n---\n# Same"
        _ = try fixture.write(markdown, at: "claude/same/SKILL.md")
        _ = try fixture.write(markdown, at: "codex/same/SKILL.md")
        let initial = try await scan([
            SkillDiscoveryRoot(agent: .claude, url: claudeRoot),
            SkillDiscoveryRoot(agent: .codex, url: codexRoot)
        ])
        let installations = initial.snapshot.skills.flatMap(\.installations)
        let stalePackageID = PackageID(rawValue: "stale-package")
        let staleSkillID = SkillID(rawValue: "stale-skill")
        let stale = LibrarySnapshot(
            packages: [SkillPackageRecord(id: stalePackageID, name: "Same", skillIDs: [staleSkillID])],
            skills: [SkillRecord(
                id: staleSkillID,
                packageID: stalePackageID,
                name: "Same Name",
                summary: "",
                markdownSource: markdown,
                installations: installations
            )],
            scannedAt: .now
        )
        let store = try GRDBCatalogStore(databaseURL: fixture.url.appending(path: "catalog.sqlite"))
        try await store.saveSnapshot(stale)

        let reconciled = try await scan([
            SkillDiscoveryRoot(agent: .claude, url: claudeRoot),
            SkillDiscoveryRoot(agent: .codex, url: codexRoot)
        ], catalog: store)

        XCTAssertEqual(reconciled.snapshot.skills.count, 2)
        XCTAssertEqual(Set(reconciled.snapshot.skills.map(\.id)).count, 2)
        XCTAssertEqual(reconciled.snapshot.skills.filter { $0.id == staleSkillID }.count, 1)
    }

    func testRepositoryPackageDoesNotCollapseDistinctFlattenedSkillDirectories() async throws {
        let fixture = try TemporarySkillLibrary()
        let source = "https://github.com/acme/toolkit"
        _ = try fixture.write(
            "---\nname: Review\nsource: \(source)\n---",
            at: "review/SKILL.md"
        )
        _ = try fixture.write(
            "---\nname: Refactor\nsource: \(source)\n---",
            at: "refactor/SKILL.md"
        )

        let result = try await scan([
            SkillDiscoveryRoot(agent: .codex, url: fixture.url)
        ])

        XCTAssertEqual(result.snapshot.packages.count, 1)
        XCTAssertEqual(result.snapshot.skills.count, 2)
        XCTAssertEqual(result.snapshot.packages.first?.skillIDs.count, 2)
    }

    func testSkipsSymlinksAndInvalidUTF8WithoutFailingTheScan() async throws {
        let fixture = try TemporarySkillLibrary()
        let validEntry = try fixture.write("# Valid\nA useful skill.", at: "valid/SKILL.md")
        _ = try fixture.write(Data([0xFF, 0xFE]), at: "invalid/SKILL.md")
        let linkedEntry = fixture.url.appending(path: "linked/SKILL.md")
        try FileManager.default.createDirectory(at: linkedEntry.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: linkedEntry, withDestinationURL: validEntry)

        let result = try await scan([
            SkillDiscoveryRoot(agent: .cursor, url: fixture.url)
        ])

        XCTAssertEqual(result.scannedFileCount, 2)
        XCTAssertEqual(result.snapshot.skills.count, 1)
        XCTAssertEqual(result.snapshot.skills.first?.name, "Valid")
        XCTAssertEqual(result.snapshot.skills.first?.summary, "A useful skill.")
        XCTAssertEqual(
            result.snapshot.skills.first?.installations.first?.contentHash,
            "33cee0b132f9f293525ab7a889281f0ee30d3f6c92b1318ed4d455cad3bba285"
        )
    }

    func testFollowsTopLevelSymlinkedSkillStoreAndPreservesLexicalAndResolvedPaths() async throws {
        let fixture = try TemporarySkillLibrary()
        let root = try fixture.makeDirectory(at: "agent")
        let store = try fixture.makeDirectory(at: "managed/example")
        let target = try fixture.write("# Managed\n", at: "managed/example/SKILL.md")
        let link = root.appending(path: "example")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: store)

        let result = try await scan([SkillDiscoveryRoot(agent: .codex, url: root)])
        let installation = try XCTUnwrap(result.snapshot.skills.first?.installations.first)

        XCTAssertEqual(installation.entryURL.path, link.appending(path: "SKILL.md").path)
        XCTAssertEqual(installation.resolvedEntryURL?.path, target.path)
    }

    func testLiteralAgentClaudeFilenameFallsBackToItsDirectoryName() async throws {
        let fixture = try TemporarySkillLibrary()
        _ = try fixture.write("# Instructions", at: "careful-review/.agent.claude.md")

        let result = try await scan([
            SkillDiscoveryRoot(agent: .claude, url: fixture.url)
        ])

        XCTAssertEqual(result.snapshot.skills.first?.name, "Careful Review")
        XCTAssertEqual(result.snapshot.skills.first?.installations.first?.entryURL.lastPathComponent, ".agent.claude.md")
    }

    func testUserBaselineMakesModificationClaimsEvidenceBased() async throws {
        let fixture = try TemporarySkillLibrary()
        let entry = try fixture.write("# Original\n", at: "example/SKILL.md")
        let store = try GRDBCatalogStore(databaseURL: fixture.url.appending(path: "catalog.sqlite"))
        let root = SkillDiscoveryRoot(agent: .codex, url: fixture.url)
        let initial = try await scan([root], catalog: store)
        let installation = try XCTUnwrap(initial.snapshot.skills.first?.installations.first)
        XCTAssertEqual(installation.localState, .unverified)
        let baselineDate = Date(timeIntervalSince1970: 1_700_000_000)
        try await store.saveBaseline(
            InstallationBaseline(
                entryURL: entry,
                contentHash: installation.contentHash,
                sourceRevision: nil,
                setAt: baselineDate
            )
        )

        let clean = try await scan([root], catalog: store)
        XCTAssertEqual(clean.snapshot.skills.first?.installations.first?.localState, .clean)
        XCTAssertEqual(clean.snapshot.skills.first?.installations.first?.managedUpdatedAt, baselineDate)

        _ = try fixture.write("# Agent changed it\n", at: "example/SKILL.md")
        let modified = try await scan([root], catalog: store)
        XCTAssertEqual(modified.snapshot.skills.first?.installations.first?.localState, .modified)
    }

    private func scan(
        _ roots: [SkillDiscoveryRoot],
        catalog: (any CatalogStore)? = nil
    ) async throws -> ScanResult {
        var progressCount = 0
        var finishedSnapshot: LibrarySnapshot?
        var finishedCount = 0

        for try await update in FileSystemSkillScanner(roots: roots, catalog: catalog).scan() {
            switch update {
            case .progress:
                progressCount += 1
            case .finished(let snapshot, let scannedFileCount):
                finishedSnapshot = snapshot
                finishedCount = scannedFileCount
            }
        }

        return ScanResult(
            snapshot: try XCTUnwrap(finishedSnapshot),
            scannedFileCount: finishedCount,
            progressCount: progressCount
        )
    }
}

private struct ScanResult {
    let snapshot: LibrarySnapshot
    let scannedFileCount: Int
    let progressCount: Int
}
