import Foundation

public struct CatalogRepairReceipt: Hashable, Sendable {
    public let preservedCatalogURL: URL?

    public init(preservedCatalogURL: URL?) {
        self.preservedCatalogURL = preservedCatalogURL
    }
}
