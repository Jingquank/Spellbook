public protocol CatalogRepairing: Sendable {
    func rebuildCatalog() async throws -> CatalogRepairReceipt
}
