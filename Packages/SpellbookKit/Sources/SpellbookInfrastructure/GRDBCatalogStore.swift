import Foundation
import GRDB
import SpellbookCore

public actor GRDBCatalogStore: CatalogStore {
    private let database: DatabasePool
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(databaseURL: URL? = nil) throws {
        let resolvedURL = databaseURL ?? Self.applicationDatabaseURL
        try FileManager.default.createDirectory(
            at: resolvedURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        database = try DatabasePool(path: resolvedURL.path)
        try Self.migrator.migrate(database)
    }

    public func loadSnapshot() throws -> LibrarySnapshot? {
        try database.read { db in
            let packages = try Row.fetchAll(
                db,
                sql: "SELECT payload FROM packages ORDER BY name COLLATE NOCASE"
            ).map { row -> SkillPackageRecord in
                let data: Data = row["payload"]
                return try decoder.decode(SkillPackageRecord.self, from: data)
            }
            let skills = try Row.fetchAll(
                db,
                sql: "SELECT payload FROM skills ORDER BY name COLLATE NOCASE"
            ).map { row -> SkillRecord in
                let data: Data = row["payload"]
                return try decoder.decode(SkillRecord.self, from: data)
            }
            guard !packages.isEmpty || !skills.isEmpty else { return nil }
            let scannedAt = try Date.fetchOne(
                db,
                sql: "SELECT scannedAt FROM catalogMetadata WHERE id = 1"
            )
            return LibrarySnapshot(packages: packages, skills: skills, scannedAt: scannedAt)
        }
    }

    public func saveSnapshot(_ snapshot: LibrarySnapshot) throws {
        try database.write { db in
            try replaceCatalog(snapshot, in: db)
        }
    }

    public func searchSkillIDs(matching query: String) throws -> [SkillID] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let escaped = trimmed.replacingOccurrences(of: "\"", with: "\"\"")
        let expression = "\"\(escaped)\"*"

        return try database.read { db in
            try String.fetchAll(
                db,
                sql: "SELECT skillID FROM skillSearch WHERE skillSearch MATCH ? ORDER BY rank",
                arguments: [expression]
            ).map(SkillID.init(rawValue:))
        }
    }

    public func rebuildIndex(from snapshot: LibrarySnapshot) throws {
        try database.write { db in
            try db.execute(sql: "DELETE FROM skillSearch")
            for skill in snapshot.skills {
                try db.execute(
                    sql: "INSERT INTO skillSearch (skillID, text) VALUES (?, ?)",
                    arguments: [skill.id.rawValue, skill.searchText]
                )
            }
        }
    }

    public func loadCustomRoots() throws -> [DiscoveryRootRecord] {
        try database.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT agent, path FROM grantedRoots ORDER BY agent, path COLLATE NOCASE"
            ).compactMap { row in
                let rawAgent: String = row["agent"]
                let path: String = row["path"]
                guard let agent = AgentKind(rawValue: rawAgent) else { return nil }
                return DiscoveryRootRecord(
                    agent: agent,
                    url: URL(filePath: path, directoryHint: .isDirectory),
                    isKnown: false
                )
            }
        }
    }

    public func saveCustomRoots(_ roots: [DiscoveryRootRecord]) throws {
        try database.write { db in
            try db.execute(sql: "DELETE FROM grantedRoots")
            for root in roots where !root.isKnown {
                try db.execute(
                    sql: "INSERT INTO grantedRoots (id, agent, path) VALUES (?, ?, ?)",
                    arguments: [root.id, root.agent.rawValue, root.url.path]
                )
            }
        }
    }

    public func recordOperation(_ operation: ManagedOperationRecord) throws {
        try database.write { db in
            try db.execute(
                sql: """
                INSERT INTO operations (id, kind, status, finishedAt, payload)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    kind = excluded.kind,
                    status = excluded.status,
                    finishedAt = excluded.finishedAt,
                    payload = excluded.payload
                """,
                arguments: [
                    operation.id,
                    operation.kind.rawValue,
                    operation.status.rawValue,
                    operation.finishedAt,
                    try encoder.encode(operation)
                ]
            )
        }
    }

    public func recentOperations(limit: Int) throws -> [ManagedOperationRecord] {
        let safeLimit = max(0, limit)
        return try database.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT payload FROM operations ORDER BY finishedAt DESC LIMIT ?",
                arguments: [safeLimit]
            ).map { row -> ManagedOperationRecord in
                let payload: Data = row["payload"]
                return try decoder.decode(ManagedOperationRecord.self, from: payload)
            }
        }
    }

    public func baseline(for entryURL: URL) throws -> InstallationBaseline? {
        let path = entryURL.standardizedFileURL.path
        return try database.read { db in
            guard let payload = try Data.fetchOne(
                db,
                sql: "SELECT payload FROM baselines WHERE entryPath = ?",
                arguments: [path]
            ) else { return nil }
            return try decoder.decode(InstallationBaseline.self, from: payload)
        }
    }

    public func saveBaseline(_ baseline: InstallationBaseline) throws {
        try database.write { db in
            try db.execute(
                sql: """
                INSERT INTO baselines (entryPath, contentHash, setAt, payload)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(entryPath) DO UPDATE SET
                    contentHash = excluded.contentHash,
                    setAt = excluded.setAt,
                    payload = excluded.payload
                """,
                arguments: [
                    baseline.entryURL.path,
                    baseline.contentHash,
                    baseline.setAt,
                    try encoder.encode(baseline)
                ]
            )
        }
    }

    public func loadSourceConnections() throws -> [SourceConnection] {
        try database.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT payload FROM sources ORDER BY connectedAt"
            ).map { row -> SourceConnection in
                let payload: Data = row["payload"]
                return try decoder.decode(SourceConnection.self, from: payload)
            }
        }
    }

    public func saveSourceConnection(_ connection: SourceConnection) throws {
        try database.write { db in
            try db.execute(
                sql: """
                INSERT INTO sources (packageID, kind, sourceURL, connectedAt, payload)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(packageID) DO UPDATE SET
                    kind = excluded.kind,
                    sourceURL = excluded.sourceURL,
                    connectedAt = excluded.connectedAt,
                    payload = excluded.payload
                """,
                arguments: [
                    connection.packageID.rawValue,
                    connection.kind.rawValue,
                    connection.sourceURL.absoluteString,
                    connection.connectedAt,
                    try encoder.encode(connection)
                ]
            )
        }
    }

    public func removeSourceConnection(packageID: PackageID) throws {
        try database.write { db in
            try db.execute(
                sql: "DELETE FROM sources WHERE packageID = ?",
                arguments: [packageID.rawValue]
            )
        }
    }

    public func loadRepositories() async throws -> [SourceRepositoryRecord] {
        try loadPayloads(from: "repositories", orderedBy: "id")
    }

    public func saveRepositories(_ repositories: [SourceRepositoryRecord]) async throws {
        try replacePayloads(repositories, in: "repositories", id: \SourceRepositoryRecord.id)
    }

    public func loadPackageProvenance() async throws -> [PackageProvenance] {
        try loadPayloads(from: "packageProvenance", orderedBy: "id")
    }

    public func savePackageProvenance(_ provenance: [PackageProvenance]) async throws {
        try replacePayloads(provenance, in: "packageProvenance") { $0.packageID.rawValue }
    }

    public func loadSourceEvidence() async throws -> [SourceEvidence] {
        try loadPayloads(from: "sourceEvidence", orderedBy: "observedAt DESC")
    }

    public func saveSourceEvidence(_ evidence: [SourceEvidence]) async throws {
        try replacePayloads(evidence, in: "sourceEvidence", id: \SourceEvidence.id) { db, value in
            try db.execute(
                sql: "INSERT INTO sourceEvidence (id, observedAt, payload) VALUES (?, ?, ?)",
                arguments: [value.id, value.observedAt, try encoder.encode(value)]
            )
        }
    }

    public func loadInstallationSourceStates() async throws -> [InstallationSourceState] {
        try loadPayloads(from: "installationSourceStates", orderedBy: "id")
    }

    public func saveInstallationSourceStates(_ states: [InstallationSourceState]) async throws {
        try replacePayloads(states, in: "installationSourceStates") { $0.installationID.rawValue }
    }

    public func loadSourceCandidates() async throws -> [SourceCandidate] {
        try loadPayloads(from: "sourceCandidates", orderedBy: "discoveredAt DESC")
    }

    public func saveSourceCandidates(_ candidates: [SourceCandidate]) async throws {
        try replacePayloads(candidates, in: "sourceCandidates", id: \SourceCandidate.id) { db, value in
            try db.execute(
                sql: "INSERT INTO sourceCandidates (id, discoveredAt, payload) VALUES (?, ?, ?)",
                arguments: [value.id, value.discoveredAt, try encoder.encode(value)]
            )
        }
    }

    public func loadIdentityAliases() async throws -> [IdentityAlias] {
        try loadPayloads(from: "identityAliases", orderedBy: "id")
    }

    public func saveIdentityAliases(_ aliases: [IdentityAlias]) async throws {
        try replacePayloads(aliases, in: "identityAliases", id: \IdentityAlias.id)
    }

    public func loadArtworkReferences() async throws -> [ArtworkReference] {
        try loadPayloads(from: "artworkReferences", orderedBy: "id")
    }

    public func saveArtworkReferences(_ references: [ArtworkReference]) async throws {
        try replacePayloads(references, in: "artworkReferences", id: \ArtworkReference.id)
    }

    public func loadPublishingTargets() async throws -> [PublishingTarget] {
        try loadPayloads(from: "publishingTargets", orderedBy: "id")
    }

    public func savePublishingTargets(_ targets: [PublishingTarget]) async throws {
        try replacePayloads(targets, in: "publishingTargets", id: \PublishingTarget.id)
    }

    public func loadPublishingReceipts() async throws -> [PublishingReceipt] {
        try loadPayloads(from: "publishingReceipts", orderedBy: "publishedAt DESC")
    }

    public func savePublishingReceipts(_ receipts: [PublishingReceipt]) async throws {
        try replacePayloads(receipts, in: "publishingReceipts", id: \PublishingReceipt.id) { db, value in
            try db.execute(
                sql: "INSERT INTO publishingReceipts (id, publishedAt, payload) VALUES (?, ?, ?)",
                arguments: [value.id, value.publishedAt, try encoder.encode(value)]
            )
        }
    }

    public func loadInstallerPackageReceipts() async throws -> [InstallerPackageReceipt] {
        try loadPayloads(from: "installerPackageReceipts", orderedBy: "id")
    }

    public func saveInstallerPackageReceipts(_ receipts: [InstallerPackageReceipt]) async throws {
        try replacePayloads(receipts, in: "installerPackageReceipts", id: \.id)
    }

    public func loadPackageNameEvidence() async throws -> [PackageNameEvidence] {
        try loadPayloads(from: "packageNameEvidence", orderedBy: "observedAt DESC")
    }

    public func savePackageNameEvidence(_ evidence: [PackageNameEvidence]) async throws {
        try replacePayloads(evidence, in: "packageNameEvidence", id: \.id) { db, value in
            try db.execute(
                sql: "INSERT INTO packageNameEvidence (id, observedAt, payload) VALUES (?, ?, ?)",
                arguments: [value.id, value.observedAt, try encoder.encode(value)]
            )
        }
    }

    public func loadSourceSearchRoots() async throws -> [SourceSearchRootRecord] {
        try loadPayloads(from: "sourceSearchRoots", orderedBy: "id")
    }

    public func saveSourceSearchRoots(_ roots: [SourceSearchRootRecord]) async throws {
        try replacePayloads(roots, in: "sourceSearchRoots", id: \.id)
    }

    public func loadIdentityClusterDecisions() async throws -> [IdentityClusterDecision] {
        try loadPayloads(from: "identityClusterDecisions", orderedBy: "id")
    }

    public func saveIdentityClusterDecisions(_ decisions: [IdentityClusterDecision]) async throws {
        try replacePayloads(decisions, in: "identityClusterDecisions", id: \.id)
    }

    public func loadPackageArtworkEvidence() async throws -> [PackageArtworkEvidence] {
        try loadPayloads(from: "packageArtworkEvidence", orderedBy: "observedAt DESC")
    }

    public func savePackageArtworkEvidence(_ evidence: [PackageArtworkEvidence]) async throws {
        try replacePayloads(evidence, in: "packageArtworkEvidence", id: \.id) { db, value in
            try db.execute(
                sql: "INSERT INTO packageArtworkEvidence (id, observedAt, payload) VALUES (?, ?, ?)",
                arguments: [value.id, value.observedAt, try encoder.encode(value)]
            )
        }
    }

    public func loadPackageArtworkUploads() async throws -> [PackageArtworkUpload] {
        try loadPayloads(from: "packageArtworkUploads", orderedBy: "id")
    }

    public func savePackageArtworkUploads(_ uploads: [PackageArtworkUpload]) async throws {
        try replacePayloads(uploads, in: "packageArtworkUploads", id: \.id)
    }

    private func loadPayloads<Value: Decodable>(
        from table: String,
        orderedBy order: String
    ) throws -> [Value] {
        try database.read { db in
            try Row.fetchAll(db, sql: "SELECT payload FROM \(table) ORDER BY \(order)").map { row in
                let payload: Data = row["payload"]
                return try decoder.decode(Value.self, from: payload)
            }
        }
    }

    private func replacePayloads<Value: Encodable>(
        _ values: [Value],
        in table: String,
        id: (Value) -> String
    ) throws {
        try replacePayloads(values, in: table, id: id) { db, value in
            try db.execute(
                sql: "INSERT INTO \(table) (id, payload) VALUES (?, ?)",
                arguments: [id(value), try encoder.encode(value)]
            )
        }
    }

    private func replacePayloads<Value>(
        _ values: [Value],
        in table: String,
        id: (Value) -> String,
        insert: (Database, Value) throws -> Void
    ) throws {
        try database.write { db in
            try db.execute(sql: "DELETE FROM \(table)")
            for value in values {
                _ = id(value)
                try insert(db, value)
            }
        }
    }

    private func replaceCatalog(_ snapshot: LibrarySnapshot, in db: Database) throws {
        try db.execute(sql: "DELETE FROM installations")
        try db.execute(sql: "DELETE FROM skills")
        try db.execute(sql: "DELETE FROM packages")
        try db.execute(sql: "DELETE FROM skillSearch")

        for package in snapshot.packages {
            try db.execute(
                sql: "INSERT INTO packages (id, name, payload) VALUES (?, ?, ?)",
                arguments: [package.id.rawValue, package.name, try encoder.encode(package)]
            )
        }

        for skill in snapshot.skills {
            try db.execute(
                sql: "INSERT INTO skills (id, packageID, name, payload) VALUES (?, ?, ?, ?)",
                arguments: [skill.id.rawValue, skill.packageID.rawValue, skill.name, try encoder.encode(skill)]
            )
            try db.execute(
                sql: "INSERT INTO skillSearch (skillID, text) VALUES (?, ?)",
                arguments: [skill.id.rawValue, skill.searchText]
            )
            for installation in skill.installations {
                try db.execute(
                    sql: """
                    INSERT INTO installations (id, skillID, agent, entryPath, payload)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        installation.id.rawValue,
                        skill.id.rawValue,
                        installation.agent.rawValue,
                        installation.entryURL.path,
                        try encoder.encode(installation)
                    ]
                )
            }
        }

        try db.execute(
            sql: """
            INSERT INTO catalogMetadata (id, scannedAt)
            VALUES (1, ?)
            ON CONFLICT(id) DO UPDATE SET scannedAt = excluded.scannedAt
            """,
            arguments: [snapshot.scannedAt]
        )
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1.catalog") { db in
            try db.create(table: "packages") { table in
                table.column("id", .text).primaryKey()
                table.column("name", .text).notNull()
                table.column("payload", .blob).notNull()
            }
            try db.create(table: "skills") { table in
                table.column("id", .text).primaryKey()
                table.column("packageID", .text).notNull().indexed()
                table.column("name", .text).notNull()
                table.column("payload", .blob).notNull()
            }
            try db.create(table: "installations") { table in
                table.column("id", .text).primaryKey()
                table.column("skillID", .text).notNull().indexed()
                table.column("agent", .text).notNull().indexed()
                table.column("entryPath", .text).notNull().unique()
                table.column("payload", .blob).notNull()
            }
            try db.create(table: "catalogMetadata") { table in
                table.column("id", .integer).primaryKey()
                table.column("scannedAt", .datetime)
            }
            try db.create(virtualTable: "skillSearch", using: FTS5()) { table in
                table.column("skillID").notIndexed()
                table.column("text")
            }
        }
        migrator.registerMigration("v2.discoveryRoots") { db in
            try db.create(table: "grantedRoots") { table in
                table.column("id", .text).primaryKey()
                table.column("agent", .text).notNull().indexed()
                table.column("path", .text).notNull()
            }
        }
        migrator.registerMigration("v3.operations") { db in
            try db.create(table: "operations") { table in
                table.column("id", .text).primaryKey()
                table.column("kind", .text).notNull().indexed()
                table.column("status", .text).notNull().indexed()
                table.column("finishedAt", .datetime).notNull().indexed()
                table.column("payload", .blob).notNull()
            }
        }
        migrator.registerMigration("v4.baselines") { db in
            try db.create(table: "baselines") { table in
                table.column("entryPath", .text).primaryKey()
                table.column("contentHash", .text).notNull().indexed()
                table.column("setAt", .datetime).notNull().indexed()
                table.column("payload", .blob).notNull()
            }
        }
        migrator.registerMigration("v5.sources") { db in
            try db.create(table: "sources") { table in
                table.column("packageID", .text).primaryKey()
                table.column("kind", .text).notNull().indexed()
                table.column("sourceURL", .text).notNull()
                table.column("connectedAt", .datetime).notNull().indexed()
                table.column("payload", .blob).notNull()
            }
        }
        migrator.registerMigration("v6.provenanceAndArtwork") { db in
            for tableName in [
                "repositories",
                "packageProvenance",
                "installationSourceStates",
                "identityAliases",
                "artworkReferences"
            ] {
                try db.create(table: tableName) { table in
                    table.column("id", .text).primaryKey()
                    table.column("payload", .blob).notNull()
                }
            }
            try db.create(table: "sourceEvidence") { table in
                table.column("id", .text).primaryKey()
                table.column("observedAt", .datetime).notNull().indexed()
                table.column("payload", .blob).notNull()
            }
            try db.create(table: "sourceCandidates") { table in
                table.column("id", .text).primaryKey()
                table.column("discoveredAt", .datetime).notNull().indexed()
                table.column("payload", .blob).notNull()
            }

            let sourceRows = try Row.fetchAll(db, sql: "SELECT payload FROM sources")
            let decoder = JSONDecoder()
            let encoder = JSONEncoder()
            for row in sourceRows {
                let payload: Data = row["payload"]
                let connection = try decoder.decode(SourceConnection.self, from: payload)
                let provenance = PackageProvenance(
                    packageID: connection.packageID,
                    originURL: connection.sourceURL,
                    updateURL: connection.sourceURL,
                    branch: connection.branch,
                    confidence: .verified,
                    lastVerifiedAt: connection.connectedAt
                )
                try db.execute(
                    sql: "INSERT OR REPLACE INTO packageProvenance (id, payload) VALUES (?, ?)",
                    arguments: [connection.packageID.rawValue, try encoder.encode(provenance)]
                )
                let evidence = SourceEvidence(
                    id: "manual-source::\(connection.packageID.rawValue)",
                    packageID: connection.packageID,
                    kind: "manual-connection",
                    sourceURL: connection.sourceURL,
                    packagePath: connection.subdirectory,
                    revision: connection.lastRevision,
                    confidence: .verified,
                    explanation: "Connected manually in Spellbook.",
                    observedAt: connection.connectedAt
                )
                try db.execute(
                    sql: "INSERT OR REPLACE INTO sourceEvidence (id, observedAt, payload) VALUES (?, ?, ?)",
                    arguments: [evidence.id, evidence.observedAt, try encoder.encode(evidence)]
                )
            }
        }
        migrator.registerMigration("v7.publishing") { db in
            try db.create(table: "publishingTargets") { table in
                table.column("id", .text).primaryKey()
                table.column("payload", .blob).notNull()
            }
            try db.create(table: "publishingReceipts") { table in
                table.column("id", .text).primaryKey()
                table.column("publishedAt", .datetime).notNull().indexed()
                table.column("payload", .blob).notNull()
            }
        }
        migrator.registerMigration("v8.identityNamingAndReceipts") { db in
            for tableName in [
                "installerPackageReceipts",
                "packageTitleOverrides",
                "sourceSearchRoots",
                "identityClusterDecisions"
            ] {
                try db.create(table: tableName) { table in
                    table.column("id", .text).primaryKey()
                    table.column("payload", .blob).notNull()
                }
            }
            try db.create(table: "packageNameEvidence") { table in
                table.column("id", .text).primaryKey()
                table.column("observedAt", .datetime).notNull().indexed()
                table.column("payload", .blob).notNull()
            }
        }
        migrator.registerMigration("v9.sidebarArtworkAndSorting") { db in
            try db.create(table: "artworkGalleryCandidates") { table in
                table.column("id", .text).primaryKey()
                table.column("createdAt", .datetime).notNull().indexed()
                table.column("payload", .blob).notNull()
            }
            try db.create(table: "packageArtworkPreferences") { table in
                table.column("id", .text).primaryKey()
                table.column("payload", .blob).notNull()
            }
        }
        migrator.registerMigration("v10.simplifiedThumbnails") { db in
            try db.create(table: "packageArtworkEvidence") { table in
                table.column("id", .text).primaryKey()
                table.column("observedAt", .datetime).notNull().indexed()
                table.column("payload", .blob).notNull()
            }
            try db.create(table: "packageArtworkUploads") { table in
                table.column("id", .text).primaryKey()
                table.column("payload", .blob).notNull()
            }

            let decoder = JSONDecoder()
            let encoder = JSONEncoder()
            let candidateRows = try Row.fetchAll(
                db,
                sql: "SELECT payload FROM artworkGalleryCandidates ORDER BY createdAt DESC"
            )
            let candidates = candidateRows.compactMap { row -> LegacyArtworkCandidate? in
                let payload: Data = row["payload"]
                return try? decoder.decode(LegacyArtworkCandidate.self, from: payload)
            }
            let preferenceRows = try Row.fetchAll(db, sql: "SELECT payload FROM packageArtworkPreferences")
            let preferences = preferenceRows.compactMap { row -> LegacyArtworkPreference? in
                let payload: Data = row["payload"]
                return try? decoder.decode(LegacyArtworkPreference.self, from: payload)
            }
            let preferenceByPackage = Dictionary(uniqueKeysWithValues: preferences.map { ($0.packageID, $0) })
            let grouped = Dictionary(grouping: candidates.filter { $0.origin == "imported" }, by: \.packageID)
            var uploads = [PackageArtworkUpload]()
            for (packageID, imports) in grouped {
                let selectedID = preferenceByPackage[packageID]?.selectedCandidateID
                let selected = imports.first { $0.id == selectedID }
                    ?? imports.max { $0.createdAt < $1.createdAt }
                guard let selected else { continue }
                uploads.append(PackageArtworkUpload(
                    packageID: packageID,
                    localURL: selected.localURL,
                    contentHash: selected.contentHash,
                    createdAt: selected.createdAt
                ))
            }
            for upload in uploads {
                try db.execute(
                    sql: "INSERT INTO packageArtworkUploads (id, payload) VALUES (?, ?)",
                    arguments: [upload.id, try encoder.encode(upload)]
                )
            }

            let referenceRows = try Row.fetchAll(db, sql: "SELECT payload FROM artworkReferences")
            let references = referenceRows.compactMap { row -> ArtworkReference? in
                let payload: Data = row["payload"]
                return try? decoder.decode(ArtworkReference.self, from: payload)
            }
            let survivingURLs = Set(
                uploads.map { $0.localURL.standardizedFileURL }
                    + references.compactMap { $0.localURL?.standardizedFileURL }
            )
            let survivingHashes = Set(
                uploads.map(\.contentHash)
                    + references.compactMap(\.contentHash)
            )
            for generated in candidates where generated.origin == "generated"
                && !survivingURLs.contains(generated.localURL.standardizedFileURL)
                && !survivingHashes.contains(generated.contentHash) {
                try? FileManager.default.removeItem(at: generated.localURL)
            }
            try db.drop(table: "artworkGalleryCandidates")
            try db.drop(table: "packageArtworkPreferences")
        }
        migrator.registerMigration("v11.removePackageTitleOverrides") { db in
            if try db.tableExists("packageTitleOverrides") {
                try db.drop(table: "packageTitleOverrides")
            }
        }
        return migrator
    }

    public static var applicationDatabaseURL: URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return applicationSupport
            .appending(path: "Spellbook", directoryHint: .isDirectory)
            .appending(path: "Spellbook.sqlite", directoryHint: .notDirectory)
    }
}

private struct LegacyArtworkCandidate: Decodable {
    let id: String
    let packageID: PackageID
    let origin: String
    let localURL: URL
    let contentHash: String
    let createdAt: Date
}

private struct LegacyArtworkPreference: Decodable {
    let packageID: PackageID
    let selectedCandidateID: String?
}
