import Foundation
import GRDB
import SpellbookCore
import XCTest
@testable import SpellbookInfrastructure

final class GRDBCatalogStoreTests: XCTestCase {
    func testMigratesV9CatalogByRemovingPackageTitleOverrides() async throws {
        let fixture = try TemporarySkillLibrary()
        let databaseURL = fixture.url.appending(path: "Spellbook.sqlite")
        let legacyDatabase = try DatabaseQueue(path: databaseURL.path)
        try await legacyDatabase.write { db in
            try db.execute(sql: "CREATE TABLE grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
            for identifier in [
                "v1.catalog",
                "v2.discoveryRoots",
                "v3.operations",
                "v4.baselines",
                "v5.sources",
                "v6.provenanceAndArtwork",
                "v7.publishing",
                "v8.identityNamingAndReceipts",
                "v9.sidebarArtworkAndSorting"
            ] {
                try db.execute(
                    sql: "INSERT INTO grdb_migrations (identifier) VALUES (?)",
                    arguments: [identifier]
                )
            }
            try db.execute(sql: "CREATE TABLE packageTitleOverrides (id TEXT PRIMARY KEY, payload BLOB NOT NULL)")
            try db.execute(
                sql: "INSERT INTO packageTitleOverrides (id, payload) VALUES (?, ?)",
                arguments: ["package-one", Data(#"{"strategy":"custom","customTitle":"Local"}"#.utf8)]
            )
            try db.execute(sql: "CREATE TABLE artworkGalleryCandidates (id TEXT PRIMARY KEY, createdAt DATETIME NOT NULL, payload BLOB NOT NULL)")
            try db.execute(sql: "CREATE TABLE packageArtworkPreferences (id TEXT PRIMARY KEY, payload BLOB NOT NULL)")
            try db.execute(sql: "CREATE TABLE artworkReferences (id TEXT PRIMARY KEY, payload BLOB NOT NULL)")
        }

        _ = try GRDBCatalogStore(databaseURL: databaseURL)

        let migratedDatabase = try DatabaseQueue(path: databaseURL.path)
        let tableExists = try await migratedDatabase.read { db in
            try db.tableExists("packageTitleOverrides")
        }
        XCTAssertFalse(tableExists)
    }

    func testPersistsCatalogAcrossStoreInstancesAndSearchesMarkdown() async throws {
        let fixture = try TemporarySkillLibrary()
        let databaseURL = fixture.url.appending(path: "catalog/Spellbook.sqlite")
        let snapshot = makeSnapshot()

        let firstStore = try GRDBCatalogStore(databaseURL: databaseURL)
        try await firstStore.saveSnapshot(snapshot)

        let relaunchedStore = try GRDBCatalogStore(databaseURL: databaseURL)
        let restored = try await relaunchedStore.loadSnapshot()
        let results = try await relaunchedStore.searchSkillIDs(matching: "recoverable workflow")

        XCTAssertEqual(restored, snapshot)
        XCTAssertEqual(results, [SkillID(rawValue: "skill-safe-edit")])
    }

    func testRebuildsSearchIndexWithoutChangingCatalog() async throws {
        let fixture = try TemporarySkillLibrary()
        let store = try GRDBCatalogStore(databaseURL: fixture.url.appending(path: "Spellbook.sqlite"))
        let snapshot = makeSnapshot()
        try await store.saveSnapshot(snapshot)

        try await store.rebuildIndex(from: snapshot)

        let restored = try await store.loadSnapshot()
        let results = try await store.searchSkillIDs(matching: "Claude Code")
        XCTAssertEqual(restored, snapshot)
        XCTAssertEqual(results, [SkillID(rawValue: "skill-safe-edit")])
    }

    func testPersistsAndRemovesExplicitSourceConnection() async throws {
        let fixture = try TemporarySkillLibrary()
        let databaseURL = fixture.url.appending(path: "Spellbook.sqlite")
        let store = try GRDBCatalogStore(databaseURL: databaseURL)
        let connection = SourceConnection(
            packageID: PackageID(rawValue: "package-spellbook"),
            kind: .gitRepository,
            sourceURL: URL(string: "https://github.com/example/spellbook.git")!,
            branch: "main",
            subdirectory: "skills/spellbook"
        )

        try await store.saveSourceConnection(connection)
        let relaunchedStore = try GRDBCatalogStore(databaseURL: databaseURL)
        let restoredConnections = try await relaunchedStore.loadSourceConnections()
        XCTAssertEqual(restoredConnections, [connection])

        try await relaunchedStore.removeSourceConnection(packageID: connection.packageID)
        let remaining = try await relaunchedStore.loadSourceConnections()
        XCTAssertEqual(remaining, [])
    }

    func testPersistsProvenanceArtworkAliasesCandidatesAndPublishingRecords() async throws {
        let fixture = try TemporarySkillLibrary()
        let databaseURL = fixture.url.appending(path: "Spellbook.sqlite")
        let store = try GRDBCatalogStore(databaseURL: databaseURL)
        let packageID = PackageID(rawValue: "package-one")
        let installationID = InstallationID(rawValue: "installation-one")
        let sourceURL = URL(string: "https://github.com/acme/one")!
        let repository = SourceRepositoryRecord(id: "repo-one", sourceURL: sourceURL, provider: "github")
        let provenance = PackageProvenance(packageID: packageID, originURL: sourceURL, confidence: .verified)
        let evidence = SourceEvidence(packageID: packageID, installationID: installationID, kind: "git", sourceURL: sourceURL, confidence: .verified, explanation: "Exact Git match")
        let state = InstallationSourceState(installationID: installationID, packageID: packageID, installedRevision: "abc")
        let candidate = SourceCandidate(packageID: packageID, sourceURL: sourceURL, confidence: .possible, explanation: "Name match")
        let alias = IdentityAlias(previousID: "old", survivingID: "new", kind: "skill")
        let artwork = ArtworkReference(scope: .package, declaredPath: "logo.png", remoteURL: sourceURL, confidence: .verified)
        let target = PublishingTarget(id: "personal", repositoryURL: sourceURL, branch: "main")
        let receipt = PublishingReceipt(packageID: packageID, agent: .codex, repositoryURL: sourceURL, branch: "main", commit: "abc")

        try await store.saveRepositories([repository])
        try await store.savePackageProvenance([provenance])
        try await store.saveSourceEvidence([evidence])
        try await store.saveInstallationSourceStates([state])
        try await store.saveSourceCandidates([candidate])
        try await store.saveIdentityAliases([alias])
        try await store.saveArtworkReferences([artwork])
        try await store.savePublishingTargets([target])
        try await store.savePublishingReceipts([receipt])

        let restored = try GRDBCatalogStore(databaseURL: databaseURL)
        let restoredRepositories = try await restored.loadRepositories()
        let restoredProvenance = try await restored.loadPackageProvenance()
        let restoredEvidence = try await restored.loadSourceEvidence()
        let restoredStates = try await restored.loadInstallationSourceStates()
        let restoredCandidates = try await restored.loadSourceCandidates()
        let restoredAliases = try await restored.loadIdentityAliases()
        let restoredArtwork = try await restored.loadArtworkReferences()
        let restoredTargets = try await restored.loadPublishingTargets()
        let restoredReceipts = try await restored.loadPublishingReceipts()
        XCTAssertEqual(restoredRepositories, [repository])
        XCTAssertEqual(restoredProvenance, [provenance])
        XCTAssertEqual(restoredEvidence, [evidence])
        XCTAssertEqual(restoredStates, [state])
        XCTAssertEqual(restoredCandidates, [candidate])
        XCTAssertEqual(restoredAliases, [alias])
        XCTAssertEqual(restoredArtwork, [artwork])
        XCTAssertEqual(restoredTargets, [target])
        XCTAssertEqual(restoredReceipts, [receipt])
    }

    func testPersistsArtworkEvidenceAndSingleUpload() async throws {
        let fixture = try TemporarySkillLibrary()
        let databaseURL = fixture.url.appending(path: "Spellbook.sqlite")
        let store = try GRDBCatalogStore(databaseURL: databaseURL)
        let packageID = PackageID(rawValue: "package-art")
        let upload = PackageArtworkUpload(
            packageID: packageID,
            localURL: fixture.url.appending(path: "art.png"),
            contentHash: "hash"
        )
        let evidence = PackageArtworkEvidence(
            packageID: packageID,
            sourceKind: .githubOwnerAvatar,
            artwork: ArtworkReference(
                scope: .package,
                declaredPath: "owner.png",
                remoteURL: URL(string: "https://example.com/owner.png"),
                confidence: .verified
            )
        )

        try await store.savePackageArtworkEvidence([evidence])
        try await store.savePackageArtworkUploads([upload])

        let restored = try GRDBCatalogStore(databaseURL: databaseURL)
        let restoredEvidence = try await restored.loadPackageArtworkEvidence()
        let restoredUploads = try await restored.loadPackageArtworkUploads()
        XCTAssertEqual(restoredEvidence, [evidence])
        XCTAssertEqual(restoredUploads, [upload])
    }

    func testSimplifiedThumbnailMigrationPreservesImportsAndPurgesOnlyUnreferencedGeneration() async throws {
        let fixture = try TemporarySkillLibrary()
        let databaseURL = fixture.url.appending(path: "legacy.sqlite")
        let packageID = PackageID(rawValue: "package-legacy")
        let fallbackPackageID = PackageID(rawValue: "package-fallback")
        let selectedImportURL = fixture.url.appending(path: "selected.png")
        let newerImportURL = fixture.url.appending(path: "newer.png")
        let fallbackImportURL = fixture.url.appending(path: "fallback.png")
        let generatedSharedUploadURL = fixture.url.appending(path: "generated-shared-upload.png")
        let generatedSharedReferenceURL = fixture.url.appending(path: "generated-shared-reference.png")
        let referencedURL = fixture.url.appending(path: "declared-reference.png")
        let orphanedGeneratedURL = fixture.url.appending(path: "generated-orphan.png")
        for url in [
            selectedImportURL,
            newerImportURL,
            fallbackImportURL,
            generatedSharedUploadURL,
            generatedSharedReferenceURL,
            referencedURL,
            orphanedGeneratedURL
        ] {
            try Data("image".utf8).write(to: url)
        }

        let oldDate = Date(timeIntervalSinceReferenceDate: 100)
        let newDate = Date(timeIntervalSinceReferenceDate: 200)
        let candidates = [
            LegacyCandidateFixture(
                id: "selected-import",
                packageID: packageID,
                origin: "imported",
                localURL: selectedImportURL,
                contentHash: "selected-hash",
                createdAt: oldDate
            ),
            LegacyCandidateFixture(
                id: "newer-import",
                packageID: packageID,
                origin: "imported",
                localURL: newerImportURL,
                contentHash: "newer-hash",
                createdAt: newDate
            ),
            LegacyCandidateFixture(
                id: "fallback-import",
                packageID: fallbackPackageID,
                origin: "imported",
                localURL: fallbackImportURL,
                contentHash: "fallback-hash",
                createdAt: newDate
            ),
            LegacyCandidateFixture(
                id: "generated-shared-upload",
                packageID: packageID,
                origin: "generated",
                localURL: generatedSharedUploadURL,
                contentHash: "selected-hash",
                createdAt: newDate
            ),
            LegacyCandidateFixture(
                id: "generated-shared-reference",
                packageID: packageID,
                origin: "generated",
                localURL: generatedSharedReferenceURL,
                contentHash: "reference-hash",
                createdAt: newDate
            ),
            LegacyCandidateFixture(
                id: "generated-orphan",
                packageID: packageID,
                origin: "generated",
                localURL: orphanedGeneratedURL,
                contentHash: "orphan-hash",
                createdAt: newDate
            )
        ]
        let preferences = [
            LegacyPreferenceFixture(packageID: packageID, selectedCandidateID: "selected-import"),
            LegacyPreferenceFixture(packageID: fallbackPackageID, selectedCandidateID: "generated-orphan")
        ]
        let reference = ArtworkReference(
            scope: .package,
            declaredPath: "icon.png",
            localURL: referencedURL,
            contentHash: "reference-hash",
            confidence: .verified
        )
        let encoder = JSONEncoder()

        do {
            let legacyDatabase = try DatabaseQueue(path: databaseURL.path)
            try await legacyDatabase.write { db in
                try db.execute(sql: "CREATE TABLE grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
                for identifier in [
                    "v1.catalog",
                    "v2.discoveryRoots",
                    "v3.operations",
                    "v4.baselines",
                    "v5.sources",
                    "v6.provenanceAndArtwork",
                    "v7.publishing",
                    "v8.identityNamingAndReceipts",
                    "v9.sidebarArtworkAndSorting"
                ] {
                    try db.execute(
                        sql: "INSERT INTO grdb_migrations (identifier) VALUES (?)",
                        arguments: [identifier]
                    )
                }
                try db.execute(sql: "CREATE TABLE artworkGalleryCandidates (id TEXT PRIMARY KEY, createdAt DATETIME NOT NULL, payload BLOB NOT NULL)")
                try db.execute(sql: "CREATE TABLE packageArtworkPreferences (id TEXT PRIMARY KEY, payload BLOB NOT NULL)")
                try db.execute(sql: "CREATE TABLE artworkReferences (id TEXT PRIMARY KEY, payload BLOB NOT NULL)")
                for candidate in candidates {
                    try db.execute(
                        sql: "INSERT INTO artworkGalleryCandidates (id, createdAt, payload) VALUES (?, ?, ?)",
                        arguments: [candidate.id, candidate.createdAt, try encoder.encode(candidate)]
                    )
                }
                for preference in preferences {
                    try db.execute(
                        sql: "INSERT INTO packageArtworkPreferences (id, payload) VALUES (?, ?)",
                        arguments: [preference.packageID.rawValue, try encoder.encode(preference)]
                    )
                }
                try db.execute(
                    sql: "INSERT INTO artworkReferences (id, payload) VALUES (?, ?)",
                    arguments: [reference.id, try encoder.encode(reference)]
                )
            }
        }

        let migratedStore = try GRDBCatalogStore(databaseURL: databaseURL)
        let uploads = try await migratedStore.loadPackageArtworkUploads()
        XCTAssertEqual(uploads.count, 2)
        XCTAssertEqual(uploads.first { $0.packageID == packageID }?.localURL, selectedImportURL)
        XCTAssertEqual(uploads.first { $0.packageID == fallbackPackageID }?.localURL, fallbackImportURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: generatedSharedUploadURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: generatedSharedReferenceURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphanedGeneratedURL.path))

        let reopenedStore = try GRDBCatalogStore(databaseURL: databaseURL)
        let reopenedUploads = try await reopenedStore.loadPackageArtworkUploads()
        XCTAssertEqual(Set(reopenedUploads), Set(uploads))
    }

    private func makeSnapshot() -> LibrarySnapshot {
        let packageID = PackageID(rawValue: "package-spellbook")
        let skillID = SkillID(rawValue: "skill-safe-edit")
        let installation = SkillInstallation(
            id: InstallationID(rawValue: "installation-claude"),
            agent: .claude,
            entryURL: URL(filePath: "/tmp/spellbook/SKILL.md"),
            rootURL: URL(filePath: "/tmp/spellbook", directoryHint: .isDirectory),
            observedModifiedAt: Date(timeIntervalSince1970: 1_700_000_000),
            contentHash: String(repeating: "a", count: 64),
            localState: .clean
        )
        let package = SkillPackageRecord(
            id: packageID,
            name: "Spellbook",
            author: "Ke Ding",
            sourceURL: URL(string: "https://github.com/example/spellbook"),
            skillIDs: [skillID]
        )
        let skill = SkillRecord(
            id: skillID,
            packageID: packageID,
            name: "Safe Edit",
            summary: "Edits one installation",
            author: "Ke Ding",
            markdownSource: "# Safe Edit\n\nUse a recoverable workflow.",
            installations: [installation]
        )
        return LibrarySnapshot(
            packages: [package],
            skills: [skill],
            scannedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
    }
}

private struct LegacyCandidateFixture: Encodable {
    let id: String
    let packageID: PackageID
    let origin: String
    let localURL: URL
    let contentHash: String
    let createdAt: Date
}

private struct LegacyPreferenceFixture: Encodable {
    let packageID: PackageID
    let selectedCandidateID: String?
}
