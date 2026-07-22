import Foundation

public actor MarkdownDocumentCache {
    public static let shared = MarkdownDocumentCache()

    private let capacity: Int
    private var documents = [String: MarkdownDocument]()
    private var recency = [String]()

    public init(capacity: Int = 32) {
        self.capacity = max(1, capacity)
    }

    public func document(for source: String, sourceURL: URL? = nil) -> MarkdownDocument {
        if let cached = documents[source] {
            markRecentlyUsed(source)
            return cached
        }
        let parsed = MarkdownParser().parse(source, sourceURL: sourceURL)
        documents[source] = parsed
        markRecentlyUsed(source)
        while documents.count > capacity, let oldest = recency.first {
            recency.removeFirst()
            documents.removeValue(forKey: oldest)
        }
        return parsed
    }

    private func markRecentlyUsed(_ source: String) {
        recency.removeAll { $0 == source }
        recency.append(source)
    }
}
