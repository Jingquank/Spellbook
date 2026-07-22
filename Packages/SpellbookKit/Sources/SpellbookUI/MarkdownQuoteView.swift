import SpellbookMarkdown
import SwiftUI

struct MarkdownQuoteView: View {
    let blocks: [MarkdownBlock]

    var body: some View {
        HStack(alignment: .top, spacing: SpellbookDesign.Space.large) {
            Image(systemName: "quote.opening")
                .foregroundStyle(SpellbookDesign.Palette.textTertiary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SpellbookDesign.Space.large) {
                ForEach(blocks.indices, id: \.self) { index in
                    MarkdownBlockView(block: blocks[index])
                }
            }
        }
        .padding(SpellbookDesign.Space.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SpellbookDesign.Palette.grouped, in: .rect(cornerRadius: SpellbookDesign.Radius.medium))
    }
}
