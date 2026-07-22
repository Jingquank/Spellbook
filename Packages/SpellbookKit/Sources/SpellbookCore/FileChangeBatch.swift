import Foundation

public struct FileChangeBatch: Hashable, Sendable {
    public let urls: [URL]

    public init(urls: [URL]) {
        self.urls = urls.map(\.standardizedFileURL)
    }
}
