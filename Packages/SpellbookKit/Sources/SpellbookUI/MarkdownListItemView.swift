import SpellbookMarkdown
import SwiftUI

struct MarkdownListItemView: View {
    let item: MarkdownListItem
    let marker: String

    var body: some View {
        HStack(alignment: .top, spacing: SpellbookDesign.Space.medium) {
            if let taskState = item.taskState {
                Image(systemName: taskState == .checked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(taskState == .checked ? .secondary : .tertiary)
                    .accessibilityLabel(taskState == .checked ? "Completed" : "Not completed")
            } else {
                Text(marker)
                    .foregroundStyle(SpellbookDesign.Palette.textSecondary)
                    .frame(minWidth: SpellbookDesign.Reader.listMarkerWidth, alignment: .trailing)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: SpellbookDesign.Space.medium) {
                ForEach(item.blocks.indices, id: \.self) { index in
                    MarkdownBlockView(block: item.blocks[index])
                }
            }
        }
    }
}
