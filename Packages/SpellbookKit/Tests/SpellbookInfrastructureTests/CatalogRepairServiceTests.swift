import Foundation
import SpellbookCore
import XCTest
@testable import SpellbookInfrastructure

final class CatalogRepairServiceTests: XCTestCase {
    func testPreservesCorruptDatabaseBeforeInstallingFreshCatalog() async throws {
        let fixture = try TemporarySkillLibrary()
        let databaseURL = try fixture.write(Data("not a sqlite database".utf8), at: "catalog/Spellbook.sqlite")
        XCTAssertThrowsError(try GRDBCatalogStore(databaseURL: databaseURL))
        let proxy = CatalogStoreProxy(
            store: nil,
            unavailableReason: "Catalog needs repair."
        )
        let service = CatalogRepairService(
            databaseURL: databaseURL,
            proxy: proxy
        )

        let receipt = try await service.rebuildCatalog()

        let preservedURL = try XCTUnwrap(receipt.preservedCatalogURL)
        let preservedDatabase = preservedURL.appending(path: databaseURL.lastPathComponent)
        XCTAssertEqual(
            try String(contentsOf: preservedDatabase, encoding: .utf8),
            "not a sqlite database"
        )
        let root = DiscoveryRootRecord(
            agent: .claude,
            url: fixture.url.appending(path: "skills"),
            isKnown: false
        )
        try await proxy.saveCustomRoots([root])
        let restoredRoots = try await proxy.loadCustomRoots()
        XCTAssertEqual(restoredRoots.map(\.agent), [.claude])
        XCTAssertEqual(restoredRoots.map { $0.url.standardizedFileURL.path }, [root.url.standardizedFileURL.path])
    }
}
