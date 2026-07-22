import SpellbookCore
import SpellbookMarkdown
import SwiftUI

struct NativeMarkdownReaderView: View {
    @Environment(\.systemDynamicTypeSize) private var systemDynamicTypeSize
    let source: String
    let assetRootURL: URL?
    let textScale: ReaderTextScale
    @State private var document: MarkdownDocument?

    var body: some View {
        Group {
            if let document {
                LazyVStack(alignment: .leading, spacing: SpellbookDesign.Space.xLarge) {
                    ForEach(document.blocks.indices, id: \.self) { index in
                        MarkdownBlockView(block: document.blocks[index])
                    }
                }
            } else {
                Text("Rendering…")
                    .font(SpellbookDesign.Typography.metadata)
                    .foregroundStyle(SpellbookDesign.Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .environment(\.markdownAssetRootURL, assetRootURL)
        .environment(\.readerTextScale, textScale)
        .dynamicTypeSize(systemDynamicTypeSize)
        .task(id: source) {
            document = await MarkdownDocumentCache.shared.document(for: source)
        }
    }
}
