import SpellbookMarkdown
import SwiftUI

struct MarkdownBlockView: View {
    @Environment(\.readerTextScale) private var readerTextScale
    let block: MarkdownBlock

    var body: some View {
        switch block {
        case .paragraph(let content):
            if let image = content.standaloneImage {
                MarkdownImageView(
                    source: image.source,
                    altText: image.altText,
                    title: image.title
                )
            } else {
                Text(MarkdownAttributedStringBuilder.build(content))
                    .font(readerTextScale.bodyFont)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .heading(let heading, let content):
            Text(MarkdownAttributedStringBuilder.build(content))
                .font(readerTextScale.headingFont(level: heading.level))
                .bold()
                .padding(.top, heading.level <= 2 ? SpellbookDesign.Space.medium : SpellbookDesign.Space.micro)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .code(let codeBlock):
            MarkdownCodeBlockView(codeBlock: codeBlock)
        case .quote(let blocks):
            MarkdownQuoteView(blocks: blocks)
        case .unorderedList(let items):
            MarkdownListView(items: items, startIndex: nil)
        case .orderedList(let start, let items):
            MarkdownListView(items: items, startIndex: start)
        case .thematicBreak:
            Divider()
                .padding(.vertical, SpellbookDesign.Space.xSmall)
        case .table(let table):
            MarkdownTableView(table: table)
        case .html(let html):
            MarkdownFallbackView(label: "HTML", text: html)
        case .unsupported(let kind, let text):
            MarkdownFallbackView(label: kind, text: text)
        }
    }

}

private extension MarkdownText {
    var standaloneImage: (altText: String, source: String?, title: String?)? {
        guard inlines.count == 1, case .image(let alt, let source, let title) = inlines[0] else {
            return nil
        }
        return (alt.map(\.plainText).joined(), source, title)
    }
}
