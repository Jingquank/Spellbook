import SwiftUI

private struct MarkdownAssetRootKey: EnvironmentKey {
    static let defaultValue: URL? = nil
}

extension EnvironmentValues {
    var markdownAssetRootURL: URL? {
        get { self[MarkdownAssetRootKey.self] }
        set { self[MarkdownAssetRootKey.self] = newValue }
    }
}
