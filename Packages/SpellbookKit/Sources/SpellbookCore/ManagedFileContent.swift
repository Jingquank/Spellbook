import Foundation

public struct ManagedFileContent: Hashable, Sendable {
    public let url: URL
    public let text: String
    public let contentHash: String

    public init(url: URL, text: String, contentHash: String) {
        self.url = url
        self.text = text
        self.contentHash = contentHash
    }
}
