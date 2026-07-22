import SpellbookMarkdown
import SwiftUI

struct MarkdownTableView: View {
    let table: MarkdownTable

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                MarkdownTableRowView(cells: table.header, isHeader: true)
                ForEach(table.rows.indices, id: \.self) { index in
                    MarkdownTableRowView(cells: table.rows[index], isHeader: false)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: SpellbookDesign.Radius.medium)
                    .stroke(SpellbookDesign.Palette.separator, lineWidth: SpellbookDesign.Stroke.hairline)
            }
        }
    }
}
