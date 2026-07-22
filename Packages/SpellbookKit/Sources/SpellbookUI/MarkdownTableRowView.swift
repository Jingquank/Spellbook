import SpellbookMarkdown
import SwiftUI

struct MarkdownTableRowView: View {
    @Environment(\.readerTextScale) private var readerTextScale
    let cells: [MarkdownTableCell]
    let isHeader: Bool

    var body: some View {
        GridRow {
            ForEach(cells.indices, id: \.self) { index in
                Text(MarkdownAttributedStringBuilder.build(cells[index].content))
                    .font(isHeader ? readerTextScale.tableFont.bold() : readerTextScale.tableFont)
                    .padding(.horizontal, SpellbookDesign.Space.large)
                    .padding(.vertical, SpellbookDesign.Space.medium)
                    .frame(minWidth: SpellbookDesign.Reader.tableColumnMinimumWidth, alignment: .leading)
                    .background(isHeader ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
            }
        }
    }
}
