import Foundation
import SpellbookCore

public actor CatalogRepairService: CatalogRepairing {
    private let databaseURL: URL
    private let proxy: CatalogStoreProxy
    private let fileManager: FileManager

    public init(
        databaseURL: URL = GRDBCatalogStore.applicationDatabaseURL,
        proxy: CatalogStoreProxy,
        fileManager: FileManager = .default
    ) {
        self.databaseURL = databaseURL
        self.proxy = proxy
        self.fileManager = fileManager
    }

    public func rebuildCatalog() async throws -> CatalogRepairReceipt {
        let preservedURL = try preserveExistingCatalog()
        let store = try GRDBCatalogStore(databaseURL: databaseURL)
        await proxy.install(store)
        return CatalogRepairReceipt(preservedCatalogURL: preservedURL)
    }

    private func preserveExistingCatalog() throws -> URL? {
        let relatedURLs = [
            databaseURL,
            URL(filePath: databaseURL.path + "-wal"),
            URL(filePath: databaseURL.path + "-shm")
        ].filter { fileManager.fileExists(atPath: $0.path) }
        guard !relatedURLs.isEmpty else { return nil }

        let preservationRoot = databaseURL.deletingLastPathComponent()
            .appending(path: "Corrupt Catalogs", directoryHint: .isDirectory)
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: preservationRoot, withIntermediateDirectories: true)
        for sourceURL in relatedURLs {
            try fileManager.moveItem(
                at: sourceURL,
                to: preservationRoot.appending(path: sourceURL.lastPathComponent)
            )
        }
        return preservationRoot
    }
}
